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

static ERL_NIF_TERM atom_comment, atom_error;
static _Thread_local jmp_buf *allocation_failure = NULL;

void gumbo_allocation_failed(void) {
  if (allocation_failure) longjmp(*allocation_failure, 1);
  abort();
}

static ERL_NIF_TERM text(ErlNifEnv *env, const char *prefix, const char *s) {
  size_t p = strlen(prefix), n = strlen(s);
  ERL_NIF_TERM term;
  unsigned char *data = enif_make_new_binary(env, p + n, &term);
  memcpy(data, prefix, p);
  memcpy(data + p, s, n);
  return term;
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

static ERL_NIF_TERM node(ErlNifEnv *env, const GumboNode *n) {
  if (n->type == GUMBO_NODE_ELEMENT || n->type == GUMBO_NODE_TEMPLATE) {
    const GumboVector *a = &n->v.element.attributes;
    ERL_NIF_TERM *attributes = enif_alloc(sizeof(ERL_NIF_TERM) * (a->length ? a->length : 1));
    for (unsigned i = 0; i < a->length; i++) {
      const GumboAttribute *v = a->data[i];
      attributes[i] = enif_make_tuple2(env, text(env, attribute_prefix(v), v->name), text(env, "", v->value));
    }
    ERL_NIF_TERM list = enif_make_list_from_array(env, attributes, a->length);
    enif_free(attributes);
    return enif_make_tuple3(env, text(env, "", n->v.element.name), list, children(env, &n->v.element.children));
  }
  if (n->type == GUMBO_NODE_COMMENT) return enif_make_tuple2(env, atom_comment, text(env, "", n->v.text.text));
  return text(env, "", n->v.text.text);
}

static ERL_NIF_TERM children(ErlNifEnv *env, const GumboVector *v) {
  ERL_NIF_TERM *nodes = enif_alloc(sizeof(ERL_NIF_TERM) * (v->length ? v->length : 1));
  for (unsigned i = 0; i < v->length; i++) nodes[i] = node(env, v->data[i]);
  ERL_NIF_TERM list = enif_make_list_from_array(env, nodes, v->length);
  enif_free(nodes);
  return list;
}

static ERL_NIF_TERM parse(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  ErlNifBinary html;
  if (argc != 1 || !enif_inspect_binary(env, argv[0], &html)) return enif_make_badarg(env);

  char *input = enif_alloc(html.size + 1);
  if (!input) return enif_make_tuple2(env, atom_error, text(env, "", "Cannot allocate memory"));
  memcpy(input, html.data, html.size);
  input[html.size] = 0;

  jmp_buf failure;
  if (setjmp(failure)) {
    allocation_failure = NULL;
    gumbo_free_all();
    enif_free(input);
    return enif_make_tuple2(env, atom_error, text(env, "", "HTML parser allocation limit exceeded"));
  }
  allocation_failure = &failure;
  gumbo_set_allocation_limit(ALLOCATION_LIMIT);

  GumboOptions options = kGumboDefaultOptions;
  options.fragment_context = "body";
  options.max_tree_depth = 401;
  options.max_attributes = 400;
  options.max_errors = 0;
  GumboOutput *output = gumbo_parse_with_options(&options, input, html.size);
  allocation_failure = NULL;

  ERL_NIF_TERM result = output->status == GUMBO_STATUS_OK
    ? children(env, &output->root->v.element.children)
    : enif_make_tuple2(env, atom_error, text(env, "", gumbo_status_to_string(output->status)));

  gumbo_destroy_output(output);
  enif_free(input);
  return result;
}

static int load(ErlNifEnv *env, void **priv, ERL_NIF_TERM info) {
  atom_comment = enif_make_atom(env, "comment");
  atom_error = enif_make_atom(env, "error");
  return 0;
}

static ErlNifFunc functions[] = {
  {"parse_nif", 1, parse, 0},
  {"parse_dirty", 1, parse, ERL_NIF_DIRTY_JOB_CPU_BOUND}
};

ERL_NIF_INIT(Elixir.Campfire.HtmlParser, functions, load, NULL, NULL, NULL)
