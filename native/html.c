#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "nokogiri_gumbo.h"
/* A persistent, packet-4 JSON interface. HTML is data, never shell arguments. */
static void string(FILE *f, const char *s) {
  fputc('"',f);
  for (const unsigned char *p=(const unsigned char *)s; *p; p++) {
    switch(*p) {
      case '"': fputs("\\\"",f); break;
      case '\\': fputs("\\\\",f); break;
      default: if (*p<32) fprintf(f,"\\u%04x",*p); else fputc(*p,f);
    }
  }
  fputc('"',f);
}
static void children(FILE *, const GumboVector *);
static void node(FILE *f, const GumboNode *n) {
  if (n->type==GUMBO_NODE_ELEMENT || n->type==GUMBO_NODE_TEMPLATE) {
    fputc('[',f); string(f,n->v.element.name); fputs(",[",f);
    const GumboVector *a=&n->v.element.attributes;
    for (unsigned i=0;i<a->length;i++) {
      const GumboAttribute *v=a->data[i];
      if(i) fputc(',',f);
      fputc('[',f);
      char *key=NULL;
      const char *prefix=v->attr_namespace==GUMBO_ATTR_NAMESPACE_XLINK?"xlink:":v->attr_namespace==GUMBO_ATTR_NAMESPACE_XML?"xml:":v->attr_namespace==GUMBO_ATTR_NAMESPACE_XMLNS && strcmp(v->name,"xmlns")?"xmlns:":"";
      if(asprintf(&key,"%s%s",prefix,v->name)<0) exit(2);
      string(f,key); free(key); fputc(',',f); string(f,v->value); fputc(']',f);
    }
    fputs("],",f); children(f,&n->v.element.children); fputc(']',f);
  } else if(n->type==GUMBO_NODE_COMMENT) {
    fputs("{\"comment\":",f); string(f,n->v.text.text); fputc('}',f);
  } else string(f,n->v.text.text);
}
static void children(FILE *f,const GumboVector *v) {
  fputc('[',f);
  for(unsigned i=0;i<v->length;i++) {if(i) fputc(',',f); node(f,v->data[i]);}
  fputc(']',f);
}
int main(void) {
  unsigned char h[4];
  while(fread(h,1,4,stdin)==4) {
    uint32_t len=((uint32_t)h[0]<<24)|((uint32_t)h[1]<<16)|((uint32_t)h[2]<<8)|h[3];
    char *input=malloc((size_t)len+1); if(!input) return 2;
    if(fread(input,1,len,stdin)!=len) {free(input); return 2;} input[len]=0;
    GumboOptions opts=kGumboDefaultOptions;
    opts.fragment_context="body"; opts.max_tree_depth=401; opts.max_attributes=400; opts.max_errors=0;
    GumboOutput *output=gumbo_parse_with_options(&opts,input,len);
    char *data=NULL; size_t size=0; FILE *f=open_memstream(&data,&size); if(!f) return 2;
    if(output->status!=GUMBO_STATUS_OK) {fputs("{\"error\":",f);string(f,gumbo_status_to_string(output->status));fputc('}',f);}
    else children(f,&output->root->v.element.children);
    fclose(f); gumbo_destroy_output(output); free(input);
    h[0]=(size>>24)&255;h[1]=(size>>16)&255;h[2]=(size>>8)&255;h[3]=size&255;
    if(fwrite(h,1,4,stdout)!=4 || fwrite(data,1,size,stdout)!=size) return 2;
    fflush(stdout); free(data);
  }
  return ferror(stdin)?2:0;
}
