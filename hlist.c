#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "gmem.h"
#include "hlist.h"

static SList* slist_alloc(SList* s) {
  SList* n = 0;
  GMEM_NEW(n, SList*, sizeof(SList));
  if (n == 0) {
    return 0;
  }

  // The head node is always empty, to signal an empty list.
  n->nxt = 0;
  n->str = 0;
  n->refcnt = 0;

  if (s) {
    if (s->str) {
      int l = strlen(s->str) + 1;
      GMEM_NEW(n->str, char*, l);
      memcpy(n->str, s->str, l);
    }
    n->refcnt = s->refcnt;
  }

  return n;
}

static void slist_dealloc(SList* slist) {
  if (slist == 0) {
    return;
  }

  fprintf(stderr, "@@@ SLIST deleting [%s]\n", slist->str ? slist->str : "*NULL*");
  GMEM_DEL(slist->str, char*, -1);
  GMEM_DEL(slist, SList*, sizeof(SList));
}

SList* slist_ref(SList* slist) {
  if (slist == 0) {
    slist = slist_alloc(0);
    if (slist == 0) {
      return 0;
    }
  }

  ++slist->refcnt;
  return slist;
}

SList* slist_unref(SList* slist) {
  if (slist == 0) {
    return 0;
  }

  if (--slist->refcnt > 0) {
    fprintf(stderr, "@@@ WOW SLIST has refcnt %d for [%s]\n", slist->refcnt, slist->str ? slist->str : "*NULL*");
    return slist;
  }

  while (slist != 0) {
    SList* q = slist;
    slist = slist->nxt;
    slist_dealloc(q);
  }

  return 0;
}

SList* slist_clone(SList* slist) {
  SList* h = 0;
  SList* q = 0;
  for (SList* p = slist; p != 0; p = p->nxt) {
    SList* n = slist_alloc(p);
    if (q != 0) {
      q->nxt = n;
    }
    q = n;
    if (h == 0) {
      h = n;
    }
  }
  return h;
}

SList* slist_create(void) {
  return slist_ref(0);
}

int slist_empty(const SList* slist) {
  return (slist == 0 || slist->nxt == 0);
}

int slist_size(const SList* slist) {
  int size = 0;
  for (const SList* s = slist; s != 0; s = s->nxt) {
    if (!s->str) {
      continue;
    }
    ++size;
  }
  return size;
}

void slist_add(SList* slist, const char* str)
{
  if (!str) {
    return;
  }

  SList* q = 0;
  for (SList* s = slist; s != 0; s = s->nxt) {
    q = s;
  }
  if (!q) {
    return;
  }

  int l = strlen(str) + 1;
  SList* s = slist_ref(0);
  GMEM_NEW(s->str, char*, l);
  memcpy(s->str, str, l);
  q->nxt = s;
}

char* slist_format(const SList* slist, char separator, char* buffer, int length)
{
  int total = 0;
  for (const SList* s = slist; s != 0; s = s->nxt) {
    if (!s->str) {
      continue;
    }
    ++total;
    total += strlen(s->str);
  }

  if (!buffer || !length) {
    length = total;
    GMEM_NEW(buffer, char*, total);
  }
  if (total > length) {
    return 0;
  }

  int current = 0;
  for (const SList* s = slist; s != 0; s = s->nxt) {
    if (!s->str) {
      continue;
    }
    if (current > 0) {
      buffer[current++] = separator;
    }
    int l = strlen(s->str);
    memcpy(buffer + current, s->str, l);
    current += l;
  }
  buffer[current] = '\0';
  return buffer;
}

static HList* hlist_alloc(HList* h)
{
  HList* n = 0;
  GMEM_NEW(n, HList*, sizeof(HList));
  if (n == 0) {
    return 0;
  }

  // The head node is always empty, to signal an empty list.
  n->nxt = 0;
  n->name = 0;
  n->canonical_name = 0;
  n->canonical_offset = 0;
  n->slist = 0;
  n->refcnt = 0;

  if (h) {
    if (h->name) {
      int l = strlen(h->name) + 1;
      GMEM_NEW(n->name, char*, l);
      memcpy(n->name, h->name, l);
    }
    if (h->canonical_name) {
      int l = strlen(h->canonical_name) + 1;
      GMEM_NEW(n->canonical_name, char*, l);
      memcpy(n->canonical_name, h->canonical_name, l);
    }
    n->canonical_offset = h->canonical_offset;
    n->slist = slist_clone(h->slist);
    n->refcnt = h->refcnt;
  }

  return n;
}

static void hlist_dealloc(HList* h)
{
  if (h == 0) {
    return;
  }

  fprintf(stderr, "@@@ HLIST deleting [%s/%s]\n",
          h->canonical_name ? h->canonical_name : "*NULL*",
          h->name ? h->name : "*NULL*");
  GMEM_DEL(h->canonical_name, char*, -1);
  GMEM_DEL(h->name, char*, -1);
  slist_unref(h->slist);
  GMEM_DEL(h, HList*, sizeof(HList));
}

HList* hlist_ref(HList* h)
{
  if (h == 0) {
    h = hlist_alloc(0);
    if (h == 0) {
      return 0;
    }
  }

  ++h->refcnt;
  return h;
}

HList* hlist_unref(HList* h)
{
  if (h == 0) {
    return 0;
  }

  if (--h->refcnt > 0) {
    fprintf(stderr, "@@@ WOW HLIST has refcnt %d for [%s/%s]\n",
            h->refcnt,
            h->canonical_name ? h->canonical_name : "*NULL*",
            h->name ? h->name : "*NULL*");
    return h;
  }

  while (h != 0) {
    HList* q = h;
    h = h->nxt;
    hlist_dealloc(q);
  }

  return 0;
}

HList* hlist_create(void)
{
  return hlist_ref(0);
}

HList* hlist_clone(HList* hlist)
{
  HList* h = 0;
  HList* q = 0;
  for (HList* p = hlist; p != 0; p = p->nxt) {
    HList* n = hlist_alloc(p);
    if (q != 0) {
      q->nxt = n;
    }
    q = n;
    if (h == 0) {
      h = n;
    }
  }
  return h;
}

void hlist_clear(HList* hlist) {
  for (HList* h = hlist; h != 0; ) {
    int empty = (!h->name);
    HList* q = h;
    h = h->nxt;
    if (empty) {
      q->nxt = 0;
      continue;
    }
    hlist_dealloc(q);
  }
}

void hlist_dump(HList* hlist, FILE* fp)
{
  fprintf(fp, "HList at 0x%p:\n", hlist);
  for (HList* h = hlist; h != 0; h = h->nxt) {
    if (!h->name) {
      continue;
    }
    fprintf(fp, "> Name: %s (%s)\n",
            h->canonical_name + h->canonical_offset, h->name);
    int count = 0;
    for (const SList* s = h->slist; s != 0; s = s->nxt) {
      if (!s->str) {
        continue;
      }
      fprintf(fp, ">  %3d: [%s]\n", ++count, s->str);
    }
    char* t = slist_format(h->slist, ':', 0, 0);
    printf("> Format: [%s]\n", t);
    GMEM_DEL(t, char*, -1);
  }
  fflush(fp);
}

static char* canonicalise(const char* name, int* length)
{
  /*
   * Exceptions:
   *
   * TE
   * ETag
   * WWW-Authenticate
   * Content-MD5
   */
  static struct Exceptions {
    const char* result;
    const char* change;
  } exceptions[] = {
    { "Te"              , "TE"               },
    { "Etag"            , "ETag"             },
    { "Www-Authenticate", "WWW-Authenticate" },
    { "Content-Md5"     , "Content-MD5"      },
    { 0, 0 },
  };

  if (!name) {
    return 0;
  }

  *length = strlen(name) + 1;
  if (*length <= 1) {
    return 0;
  }

  char* canonical = 0;
  GMEM_NEW(canonical, char*, *length);

  int literal = name[0] == ':';
  int in_word = 0;
  int j = 0;
  for (j = 0; name[j] != '\0'; ++j) {
    if (literal) {
      canonical[j] = name[j];
    } else if (isalnum(name[j])) {
      canonical[j] = in_word ? tolower(name[j]) : toupper(name[j]);
      in_word = 1;
    } else {
      canonical[j] = name[j] == '_' ? '-' : name[j];
      in_word = 0;
    }
  }
  canonical[j] = '\0';

  for (int j = 0; exceptions[j].result != 0; ++j) {
    if (strcmp(canonical, exceptions[j].result) == 0) {
      fprintf(stderr, "@@@ Exception: [%s] => [%s]\n", canonical, exceptions[j].change);
      strcpy(canonical, exceptions[j].change);
      break;
    }
  }

  return canonical;
}

static HList* hlist_lookup(HList* hlist, const char* name, int insert, HList** prev)
{
  if (prev) {
    *prev = 0;
  }

  if (!name) {
    return 0;
  }

  int l = 0;
  char* canonical = canonicalise(name, &l);
  if (!canonical) {
    return 0;
  }

  HList* h = 0;
  HList* q = 0;
  for (h = hlist; h != 0; h = h->nxt) {
    if (!h->name) {
      q = h;
      continue;
    }
    if (memcmp(h->canonical_name, canonical, l) == 0) {
      break;
    }
    q = h;
  }

  fprintf(stderr, "@@@ Lookup header [%s] -> %p\n", name, h);
  if (h) {
    // If it already exists, we don't need this
    GMEM_DEL(canonical, char*, l);
    if (prev) {
      *prev = q;
    }
    return h;
  }

  if (!insert) {
    GMEM_DEL(canonical, char*, l);
  } else {
    // Not found and we were asked to insert
    h = hlist_ref(0);
    GMEM_NEW(h->name, char*, l);
    memcpy(h->name, name, l);

    h->canonical_name = canonical;
    h->canonical_offset = (name[0] == ':');
    h->slist = slist_create();
    q->nxt = h;
    if (prev) {
      *prev = q;
    }
  }

  return h;
}

SList* hlist_add_header(HList* hlist, const char* name, const char* value)
{
  HList* h = hlist_lookup(hlist, name, 1, 0);
  slist_add(h->slist, value);
  fprintf(stderr, "@@@ add_header added [%s] to [%s]\n", value, name);
  return h->slist;
}

void hlist_del_header(HList* hlist, const char* name)
{
  HList* q = 0;
  HList* h = hlist_lookup(hlist, name, 0, &q);

  if (!h) {
    fprintf(stderr, "@@@ del_header found nothing for [%s]\n", name);
    return;
  }

  q->nxt = h->nxt;
  hlist_dealloc(h);
  fprintf(stderr, "@@@ del_header deleted [%s]\n", name);
}

SList* hlist_get_header(HList* hlist, const char* name)
{
  HList* h = hlist_lookup(hlist, name, 0, 0);

  if (!h) {
    fprintf(stderr, "@@@ get_header found nothing for [%s]\n", name);
    return 0;
  }

  fprintf(stderr, "@@@ get_header found %p for [%s]\n", h->slist, name);
  return h->slist;
}
