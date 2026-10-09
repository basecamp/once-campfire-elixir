// Single-call SQLite reads for Campfire.DB.
//
// query/3 looks up a cached prepared statement, binds, steps to completion and
// returns the rows as maps, all on the calling scheduler. It links the same
// system SQLite as Exqlite, so the process holds one copy of the library.
//
// wal_header/1 reads the WAL index header that Campfire.DB compares to notice commits by other
// SQLite clients, through one descriptor kept open instead of an open and close per request.
//
// Anything the short path should not handle is refused rather than attempted:
// a connection in use (busy), a statement that ran long last time (slow), a
// parameter type other than integer, float, binary or nil (unsupported), and
// every SQLite error (error). The caller then uses the regular reader.
//
// A statement never holds the scheduler for long: a progress handler checks
// the clock every PROGRESS_OPS virtual machine instructions and interrupts
// the statement once BUDGET_US have passed, which also marks it slow. What
// remains unbounded is a single page read from the file.
#define _POSIX_C_SOURCE 200809L
#include <erl_nif.h>
#include <fcntl.h>
#include <sqlite3.h>
#include <stdatomic.h>
#include <stdint.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define SLOTS 1024
#define MAX_STATEMENTS 512
#define MAX_COLUMNS 256
#define SLOW_US 1000
#define SLOW_RETRY 1000
#define BUDGET_US SLOW_US
#define PROGRESS_OPS 500

typedef struct {
    uint64_t hash;
    char* sql;
    size_t length;
    sqlite3_stmt* stmt;
    unsigned slow;
} entry_t;

typedef struct {
    sqlite3* db;
    atomic_flag busy;
    unsigned count;
    ErlNifTime deadline;
    entry_t entries[SLOTS];
} conn_t;

static ErlNifResourceType* conn_type;
static ERL_NIF_TERM am_ok, am_error, am_nil, am_busy, am_slow, am_unsupported;

static void clear_statements(conn_t* conn)
{
    for (int i = 0; i < SLOTS; i++) {
        if (conn->entries[i].stmt) {
            sqlite3_finalize(conn->entries[i].stmt);
            enif_free(conn->entries[i].sql);
        }
    }
    memset(conn->entries, 0, sizeof(conn->entries));
    conn->count = 0;
}

static void conn_destructor(ErlNifEnv* env, void* object)
{
    (void)env;
    conn_t* conn = object;
    if (conn->db) {
        clear_statements(conn);
        sqlite3_close_v2(conn->db);
        conn->db = NULL;
    }
}

static ERL_NIF_TERM make_binary(ErlNifEnv* env, const void* data, size_t size)
{
    ERL_NIF_TERM term;
    unsigned char* target = enif_make_new_binary(env, size, &term);
    if (size) memcpy(target, data, size);
    return term;
}

static ERL_NIF_TERM make_error(ErlNifEnv* env, const char* message)
{
    return enif_make_tuple2(env, am_error, make_binary(env, message, strlen(message)));
}

static int progress(void* arg)
{
    conn_t* conn = arg;
    return enif_monotonic_time(ERL_NIF_USEC) > conn->deadline;
}

static ERL_NIF_TERM nif_open(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    (void)argc;
    ErlNifBinary path;
    if (!enif_inspect_binary(env, argv[0], &path) || path.size > 4095) return enif_make_badarg(env);
    char name[4096];
    memcpy(name, path.data, path.size);
    name[path.size] = 0;

    conn_t* conn = enif_alloc_resource(conn_type, sizeof(conn_t));
    memset(conn, 0, sizeof(conn_t));
    atomic_flag_clear(&conn->busy);

    // Readers need write access to the WAL index; query_only forbids writes.
    // No busy timeout: a scheduler must never sleep in SQLite.
    int rc = sqlite3_open_v2(name, &conn->db, SQLITE_OPEN_READWRITE, NULL);
    if (rc == SQLITE_OK)
        rc = sqlite3_exec(conn->db,
            "PRAGMA cache_size=2000; PRAGMA query_only=ON;",
            NULL, NULL, NULL);

    ERL_NIF_TERM result;
    if (rc == SQLITE_OK) {
        sqlite3_progress_handler(conn->db, PROGRESS_OPS, progress, conn);
        result = enif_make_tuple2(env, am_ok, enif_make_resource(env, conn));
    } else {
        result = make_error(env, conn->db ? sqlite3_errmsg(conn->db) : "out of memory");
    }
    enif_release_resource(conn);
    return result;
}

static uint64_t fnv(const unsigned char* data, size_t size)
{
    uint64_t hash = 1469598103934665603ULL;
    for (size_t i = 0; i < size; i++) hash = (hash ^ data[i]) * 1099511628211ULL;
    return hash;
}

static entry_t* statement(conn_t* conn, ErlNifBinary* sql)
{
    uint64_t hash = fnv(sql->data, sql->size);
    unsigned index = hash & (SLOTS - 1);
    for (;;) {
        entry_t* entry = &conn->entries[index];
        if (!entry->stmt) break;
        if (entry->hash == hash && entry->length == sql->size && !memcmp(entry->sql, sql->data, sql->size))
            return entry;
        index = (index + 1) & (SLOTS - 1);
    }

    if (conn->count >= MAX_STATEMENTS) {
        clear_statements(conn);
        index = hash & (SLOTS - 1);
    }

    sqlite3_stmt* stmt = NULL;
    const char* tail = NULL;
    if (sqlite3_prepare_v3(conn->db, (const char*)sql->data, (int)sql->size, SQLITE_PREPARE_PERSISTENT, &stmt, &tail) != SQLITE_OK || !stmt)
        return NULL;
    // Only single read-only statements belong here.
    for (const char* p = tail; p < (const char*)sql->data + sql->size; p++) {
        if (*p != ' ' && *p != '\t' && *p != '\n' && *p != '\r' && *p != ';') {
            sqlite3_finalize(stmt);
            return NULL;
        }
    }
    if (!sqlite3_stmt_readonly(stmt) || sqlite3_column_count(stmt) > MAX_COLUMNS) {
        sqlite3_finalize(stmt);
        return NULL;
    }

    entry_t* entry = &conn->entries[index];
    entry->sql = enif_alloc(sql->size ? sql->size : 1);
    memcpy(entry->sql, sql->data, sql->size);
    entry->hash = hash;
    entry->length = sql->size;
    entry->stmt = stmt;
    entry->slow = 0;
    conn->count++;
    return entry;
}

// Returns 1 when bound, 0 for an unsupported value, -1 for an SQLite error.
static int bind(ErlNifEnv* env, sqlite3_stmt* stmt, ERL_NIF_TERM params)
{
    unsigned length;
    if (!enif_get_list_length(env, params, &length) || (int)length != sqlite3_bind_parameter_count(stmt)) return 0;

    ERL_NIF_TERM head;
    for (int index = 1; enif_get_list_cell(env, params, &head, &params); index++) {
        ErlNifSInt64 integer;
        double number;
        ErlNifBinary binary;
        int rc;
        if (enif_get_int64(env, head, &integer)) {
            rc = sqlite3_bind_int64(stmt, index, integer);
        } else if (enif_is_binary(env, head) && enif_inspect_binary(env, head, &binary)) {
            // The binary outlives the call; bindings are cleared before returning.
            rc = sqlite3_bind_text64(stmt, index, (const char*)binary.data, binary.size, SQLITE_STATIC, SQLITE_UTF8);
        } else if (enif_is_identical(head, am_nil)) {
            rc = sqlite3_bind_null(stmt, index);
        } else if (enif_get_double(env, head, &number)) {
            rc = sqlite3_bind_double(stmt, index, number);
        } else {
            return 0;
        }
        if (rc != SQLITE_OK) return -1;
    }
    return 1;
}

static ERL_NIF_TERM cell(ErlNifEnv* env, sqlite3_stmt* stmt, int i)
{
    switch (sqlite3_column_type(stmt, i)) {
    case SQLITE_INTEGER:
        return enif_make_int64(env, sqlite3_column_int64(stmt, i));
    case SQLITE_FLOAT:
        return enif_make_double(env, sqlite3_column_double(stmt, i));
    case SQLITE_BLOB:
        return make_binary(env, sqlite3_column_blob(stmt, i), sqlite3_column_bytes(stmt, i));
    case SQLITE_TEXT:
        return make_binary(env, sqlite3_column_text(stmt, i), sqlite3_column_bytes(stmt, i));
    default:
        return am_nil;
    }
}

static ERL_NIF_TERM run(ErlNifEnv* env, conn_t* conn, ErlNifBinary* sql, ERL_NIF_TERM params)
{
    // The handler also runs while preparing, so the budget starts here.
    ErlNifTime started = enif_monotonic_time(ERL_NIF_USEC);
    conn->deadline = started + BUDGET_US;

    entry_t* entry = statement(conn, sql);
    if (!entry) return am_unsupported;

    if (entry->slow) {
        if (entry->slow++ < SLOW_RETRY) return am_slow;
        entry->slow = 0;
    }

    sqlite3_stmt* stmt = entry->stmt;
    int bound = bind(env, stmt, params);
    if (bound != 1) {
        sqlite3_clear_bindings(stmt);
        return bound ? make_error(env, sqlite3_errmsg(conn->db)) : am_unsupported;
    }

    ERL_NIF_TERM keys[MAX_COLUMNS], values[MAX_COLUMNS];
    ERL_NIF_TERM rows = enif_make_list(env, 0), result;
    int columns = 0, rc, named = 0;

    while ((rc = sqlite3_step(stmt)) == SQLITE_ROW) {
        if (!named) {
            columns = sqlite3_column_count(stmt);
            for (int i = 0; i < columns; i++) {
                const char* name = sqlite3_column_name(stmt, i);
                if (!name) { rc = SQLITE_NOMEM; goto done; }
                keys[i] = make_binary(env, name, strlen(name));
            }
            named = 1;
        }
        for (int i = 0; i < columns; i++) values[i] = cell(env, stmt, i);
        ERL_NIF_TERM row;
        // Duplicate column names are left to the regular reader.
        if (!enif_make_map_from_arrays(env, keys, values, columns, &row)) { rc = SQLITE_MISUSE; goto done; }
        rows = enif_make_list_cell(env, row, rows);
    }

done:
    if (rc == SQLITE_DONE) {
        enif_make_reverse_list(env, rows, &result);
        result = enif_make_tuple2(env, am_ok, result);
    } else if (rc == SQLITE_MISUSE) {
        result = am_unsupported;
    } else if (rc == SQLITE_INTERRUPT) {
        result = am_slow;
    } else {
        result = make_error(env, sqlite3_errmsg(conn->db));
    }
    // A reset statement holds no read snapshot.
    sqlite3_reset(stmt);
    sqlite3_clear_bindings(stmt);

    ErlNifTime elapsed = enif_monotonic_time(ERL_NIF_USEC) - started;
    if (elapsed > SLOW_US || rc == SQLITE_INTERRUPT) entry->slow = 1;
    int percent = (int)(elapsed / 10);
    enif_consume_timeslice(env, percent < 1 ? 1 : percent > 100 ? 100 : percent);
    return result;
}

static ERL_NIF_TERM nif_query(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    (void)argc;
    conn_t* conn;
    ErlNifBinary sql;
    if (!enif_get_resource(env, argv[0], conn_type, (void**)&conn) || !enif_inspect_binary(env, argv[1], &sql))
        return enif_make_badarg(env);
    if (atomic_flag_test_and_set(&conn->busy)) return am_busy;
    ERL_NIF_TERM result = run(env, conn, &sql, argv[2]);
    atomic_flag_clear(&conn->busy);
    return result;
}

// The descriptor is shared by every scheduler; pread needs no position. It is reopened when
// the file it names was unlinked (SQLite removes the index when its last connection closes).
// The open descriptor and the path it was opened for. Replaced, never freed or closed: a
// reader may still be using the old one, and closing any descriptor of the index file would
// drop every POSIX lock this process holds on it, including SQLite's own.
typedef struct {
    int fd;
    size_t length;
    char name[];
} wal_t;

static _Atomic(wal_t*) wal_current;
static atomic_flag wal_opening = ATOMIC_FLAG_INIT;

static int wal_matches(const wal_t* wal, const ErlNifBinary* path)
{
    struct stat info;
    return wal && wal->length == path->size && !memcmp(wal->name, path->data, path->size) &&
        fstat(wal->fd, &info) == 0 && info.st_nlink > 0;
}

static ERL_NIF_TERM nif_wal_header(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    (void)argc;
    ErlNifBinary path;
    if (!enif_inspect_binary(env, argv[0], &path) || path.size > 4095) return enif_make_badarg(env);

    wal_t* wal = atomic_load(&wal_current);
    if (!wal_matches(wal, &path)) {
        if (atomic_flag_test_and_set(&wal_opening)) return am_busy;
        wal = enif_alloc(sizeof(wal_t) + path.size + 1);
        memcpy(wal->name, path.data, path.size);
        wal->name[path.size] = 0;
        wal->length = path.size;
        wal->fd = open(wal->name, O_RDONLY | O_CLOEXEC);
        if (wal->fd >= 0) {
            atomic_store(&wal_current, wal);
        } else {
            enif_free(wal);
            wal = NULL;
        }
        atomic_flag_clear(&wal_opening);
        if (!wal) return am_nil;
    }

    ERL_NIF_TERM header;
    unsigned char* data = enif_make_new_binary(env, 48, &header);
    if (pread(wal->fd, data, 48, 0) != 48) return am_nil;
    return header;
}

static int load(ErlNifEnv* env, void** priv, ERL_NIF_TERM info)
{
    (void)priv;
    (void)info;
    conn_type = enif_open_resource_type(env, NULL, "campfire_sqlite_read", conn_destructor, ERL_NIF_RT_CREATE, NULL);
    if (!conn_type) return 1;
    am_ok = enif_make_atom(env, "ok");
    am_error = enif_make_atom(env, "error");
    am_nil = enif_make_atom(env, "nil");
    am_busy = enif_make_atom(env, "busy");
    am_slow = enif_make_atom(env, "slow");
    am_unsupported = enif_make_atom(env, "unsupported");
    return 0;
}

static ErlNifFunc functions[] = {
    {"open", 1, nif_open, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"query", 3, nif_query, 0},
    {"wal_header", 1, nif_wal_header, 0},
};

ERL_NIF_INIT(Elixir.Campfire.DB.Native, functions, load, NULL, NULL, NULL)
