/*
 Copyright 2017-2018 Craig Barnes.
 Copyright 2010 Google Inc.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "util.h"
#include "nokogiri_gumbo.h"

#ifdef GUMBO_NIF
/* Campfire NIF build: allocation state is per scheduler thread, every live
   allocation is listed so a failed parse can release them all, and failures
   return to the caller through gumbo_allocation_failed() instead of
   aborting the VM. */
#include <stddef.h>

typedef union GumboAllocationHeader {
  struct {
    size_t size;
    union GumboAllocationHeader* prev;
    union GumboAllocationHeader* next;
  } live;
  long double align;
  void* pointer;
} GumboAllocationHeader;

static _Thread_local size_t allocation_limit = 0;
static _Thread_local size_t allocated = 0;
static _Thread_local GumboAllocationHeader* live = NULL;

static void allocation_failed(void) {
  gumbo_allocation_failed();
}

void gumbo_set_allocation_limit(size_t size) {
  allocation_limit = size;
}

void gumbo_free_all(void) {
  while (live) {
    GumboAllocationHeader* next = live->live.next;
    free(live);
    live = next;
  }
  allocated = 0;
}

static void link_allocation(GumboAllocationHeader* header, size_t total) {
  header->live.size = total;
  header->live.prev = NULL;
  header->live.next = live;
  if (live) live->live.prev = header;
  live = header;
  allocated += total;
}

static void unlink_allocation(GumboAllocationHeader* header) {
  if (header->live.prev) header->live.prev->live.next = header->live.next;
  else live = header->live.next;
  if (header->live.next) header->live.next->live.prev = header->live.prev;
  allocated -= header->live.size;
}

void* gumbo_alloc(size_t size) {
  if (size > SIZE_MAX - sizeof(GumboAllocationHeader)) allocation_failed();
  const size_t total = sizeof(GumboAllocationHeader) + size;
  if (allocation_limit != 0 && total > allocation_limit - allocated) allocation_failed();
  GumboAllocationHeader* header = malloc(total);
  if (unlikely(header == NULL)) allocation_failed();
  link_allocation(header, total);
  return header + 1;
}

void* gumbo_realloc(void* ptr, size_t size) {
  if (ptr == NULL) return gumbo_alloc(size);
  GumboAllocationHeader* header = (GumboAllocationHeader*)ptr - 1;
  if (size > SIZE_MAX - sizeof(*header)) allocation_failed();
  const size_t total = sizeof(*header) + size;
  if (allocation_limit != 0 && total > allocation_limit - (allocated - header->live.size))
    allocation_failed();
  unlink_allocation(header);
  GumboAllocationHeader* resized = realloc(header, total);
  if (unlikely(resized == NULL)) {
    link_allocation(header, header->live.size);
    allocation_failed();
  }
  link_allocation(resized, total);
  return resized + 1;
}

void gumbo_free(void* ptr) {
  if (ptr == NULL) return;
  GumboAllocationHeader* header = (GumboAllocationHeader*)ptr - 1;
  unlink_allocation(header);
  free(header);
}
#else
typedef union {
  size_t size;
  long double align;
  void* pointer;
} GumboAllocationHeader;

static size_t allocation_limit = 0;
static size_t allocated = 0;

static void allocation_failed(void) {
  errno = ENOMEM;
  perror("gumbo_alloc");
  abort();
}

void gumbo_set_allocation_limit(size_t size) {
  if (allocated != 0) abort();
  allocation_limit = size;
}

void* gumbo_alloc(size_t size) {
  if (allocation_limit != 0) {
    if (size > SIZE_MAX - sizeof(GumboAllocationHeader)) allocation_failed();
    const size_t total = sizeof(GumboAllocationHeader) + size;
    if (total > allocation_limit - allocated) {
      allocation_failed();
    }
    GumboAllocationHeader* header = malloc(total);
    if (unlikely(header == NULL)) allocation_failed();
    header->size = total;
    allocated += total;
    return header + 1;
  }

  void* ptr = malloc(size);
  if (unlikely(ptr == NULL)) {
    perror(__func__);
    abort();
  }
  return ptr;
}

void* gumbo_realloc(void* ptr, size_t size) {
  if (allocation_limit != 0) {
    if (ptr == NULL) return gumbo_alloc(size);
    GumboAllocationHeader* header = (GumboAllocationHeader*)ptr - 1;
    const size_t previous = header->size;
    if (size > SIZE_MAX - sizeof(*header)) allocation_failed();
    const size_t total = sizeof(*header) + size;
    if (total > allocation_limit - (allocated - previous)) {
      allocation_failed();
    }
    header = realloc(header, total);
    if (unlikely(header == NULL)) allocation_failed();
    header->size = total;
    allocated = allocated - previous + total;
    return header + 1;
  }

  ptr = realloc(ptr, size);
  if (unlikely(ptr == NULL)) {
    perror(__func__);
    abort();
  }
  return ptr;
}

void gumbo_free(void* ptr) {
  if (allocation_limit != 0 && ptr != NULL) {
    GumboAllocationHeader* header = (GumboAllocationHeader*)ptr - 1;
    allocated -= header->size;
    free(header);
    return;
  }
  free(ptr);
}

#endif

char* gumbo_strdup(const char* str) {
  const size_t size = strlen(str) + 1;
  // The strdup(3) function isn't available in strict "-std=c99" mode
  // (it's part of POSIX, not C99), so use malloc(3) and memcpy(3)
  // instead:
  char* buffer = gumbo_alloc(size);
  return memcpy(buffer, str, size);
}

#ifdef GUMBO_DEBUG
#include <stdarg.h>
// Debug function to trace operation of the parser
// (define GUMBO_DEBUG to use).
void gumbo_debug(const char* format, ...) {
  va_list args;
  va_start(args, format);
  vprintf(format, args);
  va_end(args);
  fflush(stdout);
}
#endif
