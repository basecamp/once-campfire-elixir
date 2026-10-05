#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "nokogiri_gumbo.h"
#include "util.h"

/* Fault-isolated fallback for documents that exceed the in-process node budget. */
static void string(FILE *file, const char *value) {
  fputc('"', file);
  for (const unsigned char *cursor = (const unsigned char *)value; *cursor; cursor++) {
    switch (*cursor) {
      case '"': fputs("\\\"", file); break;
      case '\\': fputs("\\\\", file); break;
      default:
        if (*cursor < 32) fprintf(file, "\\u%04x", *cursor);
        else fputc(*cursor, file);
    }
  }
  fputc('"', file);
}

static void children(FILE *, const GumboVector *);

static void node(FILE *file, const GumboNode *gumbo_node) {
  if (gumbo_node->type == GUMBO_NODE_ELEMENT || gumbo_node->type == GUMBO_NODE_TEMPLATE) {
    fputc('[', file);
    string(file, gumbo_node->v.element.name);
    fputs(",[", file);
    const GumboVector *attributes = &gumbo_node->v.element.attributes;
    for (unsigned i = 0; i < attributes->length; i++) {
      const GumboAttribute *attribute = attributes->data[i];
      if (i) fputc(',', file);
      fputc('[', file);
      const char *prefix =
        attribute->attr_namespace == GUMBO_ATTR_NAMESPACE_XLINK ? "xlink:" :
        attribute->attr_namespace == GUMBO_ATTR_NAMESPACE_XML ? "xml:" :
        attribute->attr_namespace == GUMBO_ATTR_NAMESPACE_XMLNS && strcmp(attribute->name, "xmlns") ? "xmlns:" : "";
      char *key = NULL;
      if (asprintf(&key, "%s%s", prefix, attribute->name) < 0) exit(2);
      string(file, key);
      free(key);
      fputc(',', file);
      string(file, attribute->value);
      fputc(']', file);
    }
    fputs("],", file);
    children(file, &gumbo_node->v.element.children);
    fputc(']', file);
  } else if (gumbo_node->type == GUMBO_NODE_COMMENT) {
    fputs("{\"comment\":", file);
    string(file, gumbo_node->v.text.text);
    fputc('}', file);
  } else {
    string(file, gumbo_node->v.text.text);
  }
}

static void children(FILE *file, const GumboVector *nodes) {
  fputc('[', file);
  for (unsigned i = 0; i < nodes->length; i++) {
    if (i) fputc(',', file);
    node(file, nodes->data[i]);
  }
  fputc(']', file);
}

int main(void) {
  gumbo_set_allocation_limit(256 * 1024 * 1024);

  unsigned char header[4];
  while (fread(header, 1, 4, stdin) == 4) {
    alarm(25);
    uint32_t length =
      ((uint32_t)header[0] << 24) |
      ((uint32_t)header[1] << 16) |
      ((uint32_t)header[2] << 8) |
      header[3];
    char *input = malloc((size_t)length + 1);
    if (!input) return 2;
    if (fread(input, 1, length, stdin) != length) {
      free(input);
      return 2;
    }
    input[length] = 0;

    GumboOptions options = kGumboDefaultOptions;
    options.fragment_context = "body";
    options.max_tree_depth = 401;
    options.max_attributes = 400;
    options.max_errors = 0;
    GumboOutput *output = gumbo_parse_with_options(&options, input, length);

    FILE *file = tmpfile();
    if (!file) return 2;
    if (output->status != GUMBO_STATUS_OK) {
      fputs("{\"error\":", file);
      string(file, gumbo_status_to_string(output->status));
      fputc('}', file);
    } else {
      children(file, &output->root->v.element.children);
    }
    gumbo_destroy_output(output);
    free(input);

    long offset = ftell(file);
    if (offset < 0 || (unsigned long)offset > UINT32_MAX || fseek(file, 0, SEEK_SET) != 0) return 2;
    uint32_t size = (uint32_t)offset;
    header[0] = (size >> 24) & 255;
    header[1] = (size >> 16) & 255;
    header[2] = (size >> 8) & 255;
    header[3] = size & 255;
    if (fwrite(header, 1, 4, stdout) != 4) return 2;
    char data[16 * 1024];
    size_t bytes;
    while ((bytes = fread(data, 1, sizeof(data), file)) > 0) {
      if (fwrite(data, 1, bytes, stdout) != bytes) return 2;
    }
    if (ferror(file)) return 2;
    fflush(stdout);
    fclose(file);
    alarm(0);
  }
  return ferror(stdin) ? 2 : 0;
}
