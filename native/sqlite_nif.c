#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <erl_nif.h>
#include <sqlite3.h>

/* SQLite connections as NIF resources.

   Values cross the boundary as they are stored: integers, floats, text and
   blobs as binaries, and NULL as nil. Parameters bind with SQLITE_STATIC,
   pointing straight at the caller's binaries: they are alive for the whole
   call and every statement is reset and its bindings cleared before the call
   returns, so no cached statement holds bindings or a WAL read snapshot.

   Each connection keeps an LRU cache of prepared statements. A cached
   statement's column names live in its own environment as refcounted
   binaries, so results reference them instead of allocating new ones; they
   are rebuilt when SQLite re-prepares the statement after a schema change.

   A connection is used by one thread at a time: every call holds its mutex
   for the whole operation. Calls run on dirty IO schedulers. */

typedef struct {
  char *sql;
  size_t sql_size;
  sqlite3_stmt *stmt;
  ErlNifEnv *env;
  ERL_NIF_TERM *columns;
  int column_count;
  int duplicate_columns;
  int reprepares;
  uint64_t used;
} statement_t;

typedef struct {
  sqlite3 *db;
  ErlNifMutex *mutex;
  statement_t *statements;
  int statement_count;
  int statement_limit;
  uint64_t clock;
} connection_t;

static ErlNifResourceType *connection_type;
static ERL_NIF_TERM atom_ok, atom_error, atom_nil, atom_undefined, atom_blob, atom_arity,
    atom_unsupported, atom_unknown_parameter, atom_true, atom_false;

static void free_statement(statement_t *s) {
  sqlite3_finalize(s->stmt);
  free(s->sql);
  if (s->env) enif_free_env(s->env);
  free(s->columns);
  memset(s, 0, sizeof(*s));
}

static void close_connection(connection_t *c) {
  for (int i = 0; i < c->statement_count; i++) free_statement(&c->statements[i]);
  c->statement_count = 0;
  if (c->db) sqlite3_close_v2(c->db);
  c->db = NULL;
}

static void connection_destructor(ErlNifEnv *env, void *object) {
  connection_t *c = object;
  close_connection(c);
  free(c->statements);
  if (c->mutex) enif_mutex_destroy(c->mutex);
}

/* A new binary holding data; 0 when it cannot be allocated. */
static int make_binary(ErlNifEnv *env, const void *data, size_t size, ERL_NIF_TERM *term) {
  unsigned char *buffer = enif_make_new_binary(env, size, term);
  if (!buffer) return 0;
  if (size) memcpy(buffer, data, size);
  return 1;
}

/* {error, Message}, or {error, enomem} if the message cannot be allocated. */
static ERL_NIF_TERM error_text(ErlNifEnv *env, const char *message) {
  ERL_NIF_TERM text;
  if (!make_binary(env, message, strlen(message), &text)) text = enif_make_atom(env, "enomem");
  return enif_make_tuple2(env, atom_error, text);
}

static ERL_NIF_TERM error_message(ErlNifEnv *env, connection_t *c) {
  return error_text(env, c->db ? sqlite3_errmsg(c->db) : "connection closed");
}

static char *nul_terminated(ErlNifBinary *bin) {
  char *copy = malloc(bin->size + 1);
  if (!copy) return NULL;
  memcpy(copy, bin->data, bin->size);
  copy[bin->size] = 0;
  return copy;
}

/* open(path, readonly, busy_timeout_ms, statement_limit) */
static ERL_NIF_TERM open_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  ErlNifBinary path;
  int busy_timeout, statement_limit;
  if (!enif_inspect_iolist_as_binary(env, argv[0], &path) ||
      !enif_get_int(env, argv[2], &busy_timeout) ||
      !enif_get_int(env, argv[3], &statement_limit) || statement_limit < 1)
    return enif_make_badarg(env);

  int flags = SQLITE_OPEN_NOMUTEX |
              (enif_is_identical(argv[1], atom_true) ? SQLITE_OPEN_READONLY
                                                      : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE);
  char *filename = nul_terminated(&path);
  if (!filename) return enif_raise_exception(env, enif_make_atom(env, "enomem"));

  sqlite3 *db = NULL;
  int rc = sqlite3_open_v2(filename, &db, flags, NULL);
  free(filename);
  if (rc != SQLITE_OK) {
    ERL_NIF_TERM error = error_text(env, db ? sqlite3_errmsg(db) : sqlite3_errstr(rc));
    sqlite3_close_v2(db);
    return error;
  }
  sqlite3_busy_timeout(db, busy_timeout);

  connection_t *c = enif_alloc_resource(connection_type, sizeof(connection_t));
  if (!c) {
    sqlite3_close_v2(db);
    return enif_raise_exception(env, enif_make_atom(env, "enomem"));
  }
  memset(c, 0, sizeof(*c));
  c->db = db;
  c->mutex = enif_mutex_create("campfire_sqlite");
  c->statement_limit = statement_limit;
  c->statements = calloc(statement_limit, sizeof(statement_t));
  ERL_NIF_TERM term = enif_make_resource(env, c);
  enif_release_resource(c);
  if (!c->mutex || !c->statements) return enif_raise_exception(env, enif_make_atom(env, "enomem"));
  return enif_make_tuple2(env, atom_ok, term);
}

static int get_connection(ErlNifEnv *env, ERL_NIF_TERM term, connection_t **c) {
  return enif_get_resource(env, term, connection_type, (void **)c);
}

/* execute(conn, sql): one or more statements without results. */
static ERL_NIF_TERM execute_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  connection_t *c;
  ErlNifBinary sql;
  if (!get_connection(env, argv[0], &c) || !enif_inspect_iolist_as_binary(env, argv[1], &sql))
    return enif_make_badarg(env);
  char *text = nul_terminated(&sql);
  if (!text) return enif_raise_exception(env, enif_make_atom(env, "enomem"));

  enif_mutex_lock(c->mutex);
  ERL_NIF_TERM result;
  if (!c->db) {
    result = error_message(env, c);
  } else {
    char *message = NULL;
    if (sqlite3_exec(c->db, text, NULL, NULL, &message) == SQLITE_OK) {
      result = atom_ok;
    } else {
      result = error_text(env, message ? message : sqlite3_errmsg(c->db));
    }
    sqlite3_free(message);
  }
  enif_mutex_unlock(c->mutex);
  free(text);
  return result;
}

static statement_t *cached_statement(connection_t *c, ErlNifBinary *sql) {
  for (int i = 0; i < c->statement_count; i++) {
    statement_t *s = &c->statements[i];
    if (s->sql_size == sql->size && memcmp(s->sql, sql->data, sql->size) == 0) return s;
  }
  return NULL;
}

/* Prepares and caches a statement, evicting the least recently used one when
   full. Returns NULL with *rc set on failure, or with *rc == SQLITE_OK when the
   SQL has no statement (empty or only a comment). */
static statement_t *prepare(connection_t *c, ErlNifBinary *sql, int *rc) {
  sqlite3_stmt *stmt = NULL;
  *rc = sqlite3_prepare_v3(c->db, (const char *)sql->data, (int)sql->size, SQLITE_PREPARE_PERSISTENT,
                           &stmt, NULL);
  if (*rc != SQLITE_OK || !stmt) return NULL;

  char *copy = malloc(sql->size ? sql->size : 1);
  if (!copy) {
    sqlite3_finalize(stmt);
    *rc = SQLITE_NOMEM;
    return NULL;
  }
  memcpy(copy, sql->data, sql->size);

  statement_t *s;
  if (c->statement_count < c->statement_limit) {
    s = &c->statements[c->statement_count++];
  } else {
    s = &c->statements[0];
    for (int i = 1; i < c->statement_count; i++)
      if (c->statements[i].used < s->used) s = &c->statements[i];
    free_statement(s);
  }
  s->sql = copy;
  s->sql_size = sql->size;
  s->stmt = stmt;
  s->reprepares = -1;
  return s;
}

/* Column names as refcounted binaries in the statement's environment, rebuilt
   whenever SQLite has re-prepared the statement since they were made. */
static int refresh_columns(statement_t *s) {
  int reprepares = sqlite3_stmt_status(s->stmt, SQLITE_STMTSTATUS_REPREPARE, 0);
  int count = sqlite3_column_count(s->stmt);
  if (s->env && s->reprepares == reprepares && s->column_count == count) return 1;

  if (s->env) enif_clear_env(s->env);
  else if (!(s->env = enif_alloc_env())) return 0;
  free(s->columns);
  s->columns = count ? calloc(count, sizeof(ERL_NIF_TERM)) : NULL;
  if (count && !s->columns) return 0;

  s->duplicate_columns = 0;
  for (int i = 0; i < count; i++) {
    const char *name = sqlite3_column_name(s->stmt, i);
    size_t size = name ? strlen(name) : 0;
    ErlNifBinary bin;
    if (!enif_alloc_binary(size, &bin)) return 0;
    if (size) memcpy(bin.data, name, size);
    s->columns[i] = enif_make_binary(s->env, &bin);
    for (int j = 0; j < i && !s->duplicate_columns; j++)
      if (enif_is_identical(s->columns[i], s->columns[j])) s->duplicate_columns = 1;
  }
  s->column_count = count;
  s->reprepares = reprepares;
  return 1;
}

/* The column's value; 0 when a text or blob cannot be allocated. */
static int column_value(ErlNifEnv *env, sqlite3_stmt *stmt, int i, ERL_NIF_TERM *value) {
  switch (sqlite3_column_type(stmt, i)) {
    case SQLITE_INTEGER: *value = enif_make_int64(env, sqlite3_column_int64(stmt, i)); return 1;
    case SQLITE_FLOAT: *value = enif_make_double(env, sqlite3_column_double(stmt, i)); return 1;
    case SQLITE_TEXT: {
      const unsigned char *text = sqlite3_column_text(stmt, i);
      return make_binary(env, text, sqlite3_column_bytes(stmt, i), value);
    }
    case SQLITE_BLOB: {
      const void *blob = sqlite3_column_blob(stmt, i);
      return make_binary(env, blob, sqlite3_column_bytes(stmt, i), value);
    }
    default: *value = atom_nil; return 1;
  }
}

/* Binds one value; returns SQLITE_OK, an SQLite error, or -1 for an
   unsupported value. Atoms other than nil/undefined bind as their name. */
static int bind_value(ErlNifEnv *env, sqlite3_stmt *stmt, int index, ERL_NIF_TERM value) {
  ErlNifSInt64 integer;
  double number;
  ErlNifBinary bin;
  const ERL_NIF_TERM *tuple;
  int arity;
  unsigned length;

  if (enif_is_binary(env, value) && enif_inspect_binary(env, value, &bin))
    return sqlite3_bind_text(stmt, index, (const char *)bin.data, (int)bin.size, SQLITE_STATIC);
  if (enif_get_int64(env, value, &integer)) return sqlite3_bind_int64(stmt, index, integer);
  if (enif_get_double(env, value, &number)) return sqlite3_bind_double(stmt, index, number);
  if (enif_is_identical(value, atom_nil) || enif_is_identical(value, atom_undefined))
    return sqlite3_bind_null(stmt, index);
  if (enif_get_atom_length(env, value, &length, ERL_NIF_UTF8)) {
    char *name = malloc(length + 1);
    if (!name) return SQLITE_NOMEM;
    enif_get_atom(env, value, name, length + 1, ERL_NIF_UTF8);
    int rc = sqlite3_bind_text(stmt, index, name, (int)length, SQLITE_TRANSIENT);
    free(name);
    return rc;
  }
  if (enif_get_tuple(env, value, &arity, &tuple) && arity == 2 &&
      enif_is_identical(tuple[0], atom_blob) && enif_inspect_iolist_as_binary(env, tuple[1], &bin))
    return sqlite3_bind_blob(stmt, index, bin.data, (int)bin.size, SQLITE_STATIC);
  if (enif_is_list(env, value) && enif_inspect_iolist_as_binary(env, value, &bin))
    return sqlite3_bind_text(stmt, index, (const char *)bin.data, (int)bin.size, SQLITE_STATIC);
  return -1;
}

/* Binds a list or a map of parameters. On failure *problem holds the term to
   return: {arity, Expected}, {unsupported, Value}, {unknown_parameter, Name}
   or an SQLite error. */
static int bind(ErlNifEnv *env, connection_t *c, sqlite3_stmt *stmt, ERL_NIF_TERM params,
                ERL_NIF_TERM *problem) {
  int expected = sqlite3_bind_parameter_count(stmt);
  unsigned length;
  size_t size;

  if (enif_get_list_length(env, params, &length)) {
    if ((int)length != expected) {
      *problem = enif_make_tuple2(env, atom_arity, enif_make_int(env, expected));
      return 0;
    }
    ERL_NIF_TERM head, tail = params;
    for (int i = 1; enif_get_list_cell(env, tail, &head, &tail); i++) {
      int rc = bind_value(env, stmt, i, head);
      if (rc == -1) *problem = enif_make_tuple2(env, atom_unsupported, head);
      else if (rc != SQLITE_OK) *problem = error_message(env, c);
      if (rc != SQLITE_OK) return 0;
    }
    return 1;
  }

  if (enif_get_map_size(env, params, &size)) {
    if ((int)size != expected) {
      *problem = enif_make_tuple2(env, atom_arity, enif_make_int(env, expected));
      return 0;
    }
    ErlNifMapIterator iterator;
    ERL_NIF_TERM key, value;
    enif_map_iterator_create(env, params, &iterator, ERL_NIF_MAP_ITERATOR_FIRST);
    int ok = 1;
    while (ok && enif_map_iterator_get_pair(env, &iterator, &key, &value)) {
      ErlNifBinary name;
      char buffer[256];
      int index = 0;
      if (enif_inspect_binary(env, key, &name) && name.size < sizeof(buffer)) {
        memcpy(buffer, name.data, name.size);
        buffer[name.size] = 0;
        index = sqlite3_bind_parameter_index(stmt, buffer);
      } else if (enif_get_atom(env, key, buffer, sizeof(buffer), ERL_NIF_UTF8)) {
        index = sqlite3_bind_parameter_index(stmt, buffer);
      }
      if (index == 0) {
        *problem = enif_make_tuple2(env, atom_unknown_parameter, key);
        ok = 0;
        break;
      }
      int rc = bind_value(env, stmt, index, value);
      if (rc == -1) *problem = enif_make_tuple2(env, atom_unsupported, value);
      else if (rc != SQLITE_OK) *problem = error_message(env, c);
      if (rc != SQLITE_OK) ok = 0;
      enif_map_iterator_next(env, &iterator);
    }
    enif_map_iterator_destroy(env, &iterator);
    return ok;
  }

  *problem = enif_make_tuple2(env, atom_unsupported, params);
  return 0;
}

/* The current row as a map; 0 when a value cannot be allocated. */
static int make_row(ErlNifEnv *env, statement_t *s, ERL_NIF_TERM *keys, ERL_NIF_TERM *values,
                    ERL_NIF_TERM *row) {
  int count = s->column_count;
  for (int i = 0; i < count; i++)
    if (!column_value(env, s->stmt, i, &values[i])) return 0;
  if (!s->duplicate_columns && enif_make_map_from_arrays(env, keys, values, count, row)) return 1;
  /* Like Map.new/1: the last column with a name wins. */
  *row = enif_make_new_map(env);
  for (int i = 0; i < count; i++) enif_make_map_put(env, *row, keys[i], values[i], row);
  return 1;
}

/* query(conn, sql, params) -> {ok, Rows} | {error, Message} | {arity, N} | ... */
static ERL_NIF_TERM query_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  connection_t *c;
  ErlNifBinary sql;
  if (!get_connection(env, argv[0], &c) || !enif_inspect_iolist_as_binary(env, argv[1], &sql))
    return enif_make_badarg(env);

  enif_mutex_lock(c->mutex);
  ERL_NIF_TERM result;
  int rc = SQLITE_OK;
  statement_t *s = NULL;

  if (!c->db) {
    result = error_message(env, c);
    goto done;
  }

  s = cached_statement(c, &sql);
  if (!s) s = prepare(c, &sql, &rc);
  if (!s) {
    result = rc == SQLITE_OK ? enif_make_tuple2(env, atom_ok, enif_make_list(env, 0))
                             : error_message(env, c);
    goto done;
  }
  s->used = ++c->clock;

  ERL_NIF_TERM problem;
  if (!bind(env, c, s->stmt, argv[2], &problem)) {
    result = problem;
    goto reset;
  }

  ERL_NIF_TERM rows = enif_make_list(env, 0);
  ERL_NIF_TERM *keys = NULL, *values = NULL;
  int first = 1;
  while ((rc = sqlite3_step(s->stmt)) == SQLITE_ROW) {
    if (first) {
      first = 0;
      if (!refresh_columns(s)) {
        rc = SQLITE_NOMEM;
        break;
      }
      keys = malloc(sizeof(ERL_NIF_TERM) * (s->column_count ? s->column_count : 1));
      values = malloc(sizeof(ERL_NIF_TERM) * (s->column_count ? s->column_count : 1));
      if (!keys || !values) {
        rc = SQLITE_NOMEM;
        break;
      }
      for (int i = 0; i < s->column_count; i++) keys[i] = enif_make_copy(env, s->columns[i]);
    }
    ERL_NIF_TERM row;
    if (!make_row(env, s, keys, values, &row)) {
      rc = SQLITE_NOMEM;
      break;
    }
    rows = enif_make_list_cell(env, row, rows);
  }
  free(keys);
  free(values);

  if (rc == SQLITE_DONE) {
    ERL_NIF_TERM ordered;
    enif_make_reverse_list(env, rows, &ordered);
    result = enif_make_tuple2(env, atom_ok, ordered);
  } else if (rc == SQLITE_NOMEM) {
    result = error_text(env, "out of memory");
  } else {
    result = error_message(env, c);
  }

reset:
  sqlite3_reset(s->stmt);
  sqlite3_clear_bindings(s->stmt);
done:
  enif_mutex_unlock(c->mutex);
  return result;
}

static ERL_NIF_TERM close_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  connection_t *c;
  if (!get_connection(env, argv[0], &c)) return enif_make_badarg(env);
  enif_mutex_lock(c->mutex);
  close_connection(c);
  enif_mutex_unlock(c->mutex);
  return atom_ok;
}

/* True while a transaction is open on the connection. */
static ERL_NIF_TERM transaction_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  connection_t *c;
  if (!get_connection(env, argv[0], &c)) return enif_make_badarg(env);
  enif_mutex_lock(c->mutex);
  int open = c->db && !sqlite3_get_autocommit(c->db);
  enif_mutex_unlock(c->mutex);
  return open ? atom_true : atom_false;
}

/* SQL of the cached statements, least recently used first (for tests). */
static ERL_NIF_TERM statements_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  connection_t *c;
  if (!get_connection(env, argv[0], &c)) return enif_make_badarg(env);
  enif_mutex_lock(c->mutex);
  ERL_NIF_TERM list = enif_make_list(env, 0);
  for (uint64_t seen = UINT64_MAX;;) {
    statement_t *next = NULL;
    for (int i = 0; i < c->statement_count; i++)
      if (c->statements[i].used < seen && (!next || c->statements[i].used > next->used))
        next = &c->statements[i];
    if (!next) break;
    ERL_NIF_TERM sql;
    if (!make_binary(env, next->sql, next->sql_size, &sql)) {
      enif_mutex_unlock(c->mutex);
      return enif_raise_exception(env, enif_make_atom(env, "enomem"));
    }
    list = enif_make_list_cell(env, sql, list);
    seen = next->used;
  }
  enif_mutex_unlock(c->mutex);
  return list;
}

static int load(ErlNifEnv *env, void **priv, ERL_NIF_TERM info) {
  connection_type = enif_open_resource_type(env, NULL, "campfire_sqlite_connection",
                                            connection_destructor, ERL_NIF_RT_CREATE, NULL);
  atom_ok = enif_make_atom(env, "ok");
  atom_error = enif_make_atom(env, "error");
  atom_nil = enif_make_atom(env, "nil");
  atom_undefined = enif_make_atom(env, "undefined");
  atom_blob = enif_make_atom(env, "blob");
  atom_arity = enif_make_atom(env, "arity");
  atom_unsupported = enif_make_atom(env, "unsupported");
  atom_unknown_parameter = enif_make_atom(env, "unknown_parameter");
  atom_true = enif_make_atom(env, "true");
  atom_false = enif_make_atom(env, "false");
  return connection_type ? 0 : 1;
}

static ErlNifFunc functions[] = {
  {"open_nif", 4, open_nif, ERL_NIF_DIRTY_JOB_IO_BOUND},
  {"execute", 2, execute_nif, ERL_NIF_DIRTY_JOB_IO_BOUND},
  {"query_nif", 3, query_nif, ERL_NIF_DIRTY_JOB_IO_BOUND},
  {"close", 1, close_nif, ERL_NIF_DIRTY_JOB_IO_BOUND},
  {"transaction?", 1, transaction_nif, ERL_NIF_DIRTY_JOB_IO_BOUND},
  {"statements", 1, statements_nif, ERL_NIF_DIRTY_JOB_IO_BOUND}
};

ERL_NIF_INIT(Elixir.Campfire.SQLite, functions, load, NULL, NULL, NULL)
