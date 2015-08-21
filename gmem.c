#include <stdio.h>
#include <stdlib.h>
#include "gmem.h"

#ifdef GMEM_CHECK

long gmem_new = 0;
long gmem_del = 0;

static int gmem_inited = 0;

static void gmem_init(void);
static void gmem_fini(void);

static void gmem_init(void) {
  if (gmem_inited) {
    return;
  }

  gmem_inited = 1;
  gmem_new = gmem_del = 0;

#if GMEM_CHECK >= 1
  fprintf(stderr, "=== MEM BEG %ld %ld ===\n", gmem_new, gmem_del);
#endif
  atexit(gmem_fini);
}

static void gmem_fini(void) {
  if (!gmem_inited) {
    return ;
  }

#if GMEM_CHECK >= 1
  fprintf(stderr, "=== MEM END %ld %ld ===\n", gmem_new, gmem_del);
  if (gmem_new == gmem_del) {
    fprintf(stderr, "=== MEM OK ===\n");
  } else {
    fprintf(stderr, "=== MEM ERR %ld BYTES ===\n", gmem_new - gmem_del);
  }
#endif
  gmem_inited = 0;
}

void gmem_new_called(const char* file, int line, void* var, long size) {
  gmem_init();

  if (!var) {
    return;
  }

  if (size <= 0) {
    return;
  }

#if GMEM_CHECK >= 2
  fprintf(stderr, "=== MEM NEW %ld %p %s %d ===\n", size, var, file, line);
#endif
  gmem_new += size;
}

void gmem_del_called(const char* file, int line, void* var, long size) {
  gmem_init();

  if (!var) {
    return;
  }

  if (size < 0 && var) {
    size = strlen((char*) var) + 1;
  }
  if (size <= 0) {
    return;
  }

#if GMEM_CHECK >= 2
  fprintf(stderr, "=== MEM DEL %ld %p %s %d ===\n", size, var, file, line);
#endif
  gmem_del += size;
}

#endif // #ifdef GMEM_CHECK

void gmem_strnew(char** tgt, const char* src, int len) {
  if (!tgt) {
    return;
  }
  *tgt = 0;
  if (!src) {
    return;
  }
  if (len <= 0) {
    len = strlen(src) + 1;
  }
  GMEM_NEW(*tgt, char*, len);
  memcpy(*tgt, src, len);
}

void gmem_strdel(char** str, int len) {
  if (!str || !*str) {
    return;
  }
  if (len <= 0) {
    len = strlen(*str) + 1;
  }
  GMEM_DEL(*str, char*, len);
  *str = 0;
}
