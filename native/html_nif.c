#include <setjmp.h>
#include <stdlib.h>
#include <string.h>
#include <erl_nif.h>
#include "nokogiri_gumbo.h"
#include "util.h"

/* Gumbo, pinned to the Rails reference's Nokogiri, building terms directly:
   elements are {name, [{attribute, value}], children}, comments {comment, text}
   and text nodes binaries. Options match Nokogiri's HTML5 fragment parsing.

   Each parse may allocate at most ALLOCATION_LIMIT bytes. Gumbo is built with
   GUMBO_NIF, so exceeding it (or running out of memory) jumps back here instead
   of aborting the VM; every allocation from the failed parse is then freed and
   the caller gets {error, Reason}. */

#define ALLOCATION_LIMIT (256 * 1024 * 1024)

static ERL_NIF_TERM atom_comment, atom_error, atom_enomem;
static _Thread_local jmp_buf *allocation_failure = NULL;
/* Building the result's terms happens after Gumbo's allocations; a binary that
   cannot be allocated jumps here so the parse is freed and the caller gets
   {error, Reason} instead of the VM crashing. */
static _Thread_local jmp_buf *build_failure = NULL;

void gumbo_allocation_failed(void) {
  if (allocation_failure) longjmp(*allocation_failure, 1);
  abort();
}

static ERL_NIF_TERM text(ErlNifEnv *env, const char *prefix, const char *s) {
  size_t p = strlen(prefix), n = strlen(s);
  ERL_NIF_TERM term;
  unsigned char *data = enif_make_new_binary(env, p + n, &term);
  if (!data) {
    if (build_failure) longjmp(*build_failure, 1);
    abort();
  }
  memcpy(data, prefix, p);
  memcpy(data + p, s, n);
  return term;
}

/* {error, Message}, falling back to {error, enomem} if even the message cannot
   be allocated. */
static ERL_NIF_TERM error(ErlNifEnv *env, const char *message) {
  size_t n = strlen(message);
  ERL_NIF_TERM term;
  unsigned char *data = enif_make_new_binary(env, n, &term);
  if (!data) return enif_make_tuple2(env, atom_error, atom_enomem);
  memcpy(data, message, n);
  return enif_make_tuple2(env, atom_error, term);
}

static ERL_NIF_TERM children(ErlNifEnv *, const GumboVector *);

static const char *attribute_prefix(const GumboAttribute *a) {
  switch (a->attr_namespace) {
    case GUMBO_ATTR_NAMESPACE_XLINK: return "xlink:";
    case GUMBO_ATTR_NAMESPACE_XML: return "xml:";
    case GUMBO_ATTR_NAMESPACE_XMLNS: return strcmp(a->name, "xmlns") ? "xmlns:" : "";
    default: return "";
  }
}

/* Lists are built from the back, so no temporary arrays are allocated. */
static ERL_NIF_TERM node(ErlNifEnv *env, const GumboNode *n) {
  if (n->type == GUMBO_NODE_ELEMENT || n->type == GUMBO_NODE_TEMPLATE) {
    const GumboVector *a = &n->v.element.attributes;
    ERL_NIF_TERM list = enif_make_list(env, 0);
    for (unsigned i = a->length; i > 0; i--) {
      const GumboAttribute *v = a->data[i - 1];
      ERL_NIF_TERM attribute =
        enif_make_tuple2(env, text(env, attribute_prefix(v), v->name), text(env, "", v->value));
      list = enif_make_list_cell(env, attribute, list);
    }
    return enif_make_tuple3(env, text(env, "", n->v.element.name), list, children(env, &n->v.element.children));
  }
  if (n->type == GUMBO_NODE_COMMENT) return enif_make_tuple2(env, atom_comment, text(env, "", n->v.text.text));
  return text(env, "", n->v.text.text);
}

static ERL_NIF_TERM children(ErlNifEnv *env, const GumboVector *v) {
  ERL_NIF_TERM list = enif_make_list(env, 0);
  for (unsigned i = v->length; i > 0; i--) list = enif_make_list_cell(env, node(env, v->data[i - 1]), list);
  return list;
}

/* parse(Html) with the production limit, or parse(Html, Limit) in tests. */
static ERL_NIF_TERM parse(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  ErlNifBinary html;
  unsigned long limit = ALLOCATION_LIMIT;
  if (!enif_inspect_binary(env, argv[0], &html) ||
      (argc == 2 && (!enif_get_ulong(env, argv[1], &limit) || limit == 0)))
    return enif_make_badarg(env);

  jmp_buf failure;
  if (setjmp(failure)) {
    allocation_failure = NULL;
    gumbo_free_all();
    return error(env, "HTML parser allocation limit exceeded");
  }
  allocation_failure = &failure;
  gumbo_set_allocation_limit(limit);

  GumboOptions options = kGumboDefaultOptions;
  options.fragment_context = "body";
  options.max_tree_depth = 401;
  options.max_attributes = 400;
  options.max_errors = 0;
  /* Gumbo bounds every read of the input by its length, so it parses the
     binary in place; argv[0] keeps it alive for the whole call. */
  GumboOutput *volatile output =
    gumbo_parse_with_options(&options, (const char *)html.data, html.size);
  allocation_failure = NULL;

  jmp_buf built;
  if (setjmp(built)) {
    build_failure = NULL;
    gumbo_destroy_output(output);
    return error(env, "HTML parser could not allocate its result");
  }
  build_failure = &built;

  ERL_NIF_TERM result = output->status == GUMBO_STATUS_OK
    ? children(env, &output->root->v.element.children)
    : error(env, gumbo_status_to_string(output->status));

  build_failure = NULL;
  gumbo_destroy_output(output);
  return result;
}

static int load(ErlNifEnv *env, void **priv, ERL_NIF_TERM info) {
  atom_comment = enif_make_atom(env, "comment");
  atom_error = enif_make_atom(env, "error");
  atom_enomem = enif_make_atom(env, "enomem");
  return 0;
}

static ErlNifFunc functions[] = {
  {"parse_nif", 1, parse, 0},
  {"parse_dirty", 1, parse, ERL_NIF_DIRTY_JOB_CPU_BOUND},
  {"parse_limited", 2, parse, ERL_NIF_DIRTY_JOB_CPU_BOUND}
};

ERL_NIF_INIT(Elixir.Campfire.HtmlParser, functions, load, NULL, NULL, NULL)
