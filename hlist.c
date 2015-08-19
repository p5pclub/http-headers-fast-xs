#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include "glog.h"
#include "gmem.h"
#include "hlist.h"

static SNode* snode_alloc(const char* str) {
  SNode* x = 0;
  GMEM_NEW(x, SNode*, sizeof(SNode));
  if (x == 0) {
    return 0;
  }

  x->str = 0;
  x->nxt = 0;

  if (str) {
    int l = strlen(str) + 1;
    GMEM_NEW(x->str, char*, l);
    memcpy(x->str, str, l);
  }

  return x;
}

static void snode_dealloc(SNode* snode) {
  if (snode == 0) {
    return;
  }

  // GLOG(("@@@ SNODE deleting [%s]\n", snode->str));
  GMEM_DEL(snode->str, char*, -1);
  GMEM_DEL(snode, SNode*, sizeof(SNode));
}

static SList* slist_alloc(SList* s) {
  SList* x = 0;
  GMEM_NEW(x, SList*, sizeof(SList));
  if (x == 0) {
    return 0;
  }

  x->head = 0;
  x->tail = 0;
  x->size = 0;
  x->refcnt = 0;

  if (s) {
  }

  return x;
}

static void slist_dealloc(SList* slist) {
  if (slist == 0) {
    return;
  }
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
    GLOG(("@@@ WOW SLIST %p has refcnt %d\n", slist, slist->refcnt));
    return slist;
  }

  for (SNode* n = slist->head; n != 0; ) {
    SNode* x = n;
    n = n->nxt;
    snode_dealloc(x);
  }

  slist_dealloc(slist);

  return 0;
}

SList* slist_clone(SList* slist) {
  SList* x = slist_alloc(slist);
  ++x->refcnt;

  if (slist != 0) {
    for (SNode* n = slist->head; n != 0; n = n->nxt) {
      SNode* y = snode_alloc(n->str);
      if (x->head == 0) {
        x->head = y;
      }
      if (x->tail) {
        x->tail->nxt = y;
      }
      x->tail = y;
      ++x->size;
    }
  }

  return x;
}

SList* slist_create(void) {
  return slist_ref(0);
}

int slist_empty(const SList* slist) {
  return (slist == 0 || slist->size == 0);
}

int slist_size(const SList* slist) {
  return slist == 0 ? 0 : slist->size;
}

void slist_add(SList* slist, const char* str)
{
  if (!str) {
    return;
  }

  SNode* n = snode_alloc(str);
  if (slist->head == 0) {
    slist->head = n;
  }
  if (slist->tail) {
    slist->tail->nxt = n;
  }
  slist->tail = n;
  ++slist->size;
}

char* slist_format(const SList* slist, char separator, char* buffer, int length)
{
  int total = 0;
  for (const SNode* n = slist->head; n != 0; n = n->nxt) {
    ++total;
    total += strlen(n->str);
  }

  if (!buffer || !length) {
    length = total;
    GMEM_NEW(buffer, char*, total);
  }
  if (total > length) {
    return 0;
  }

  int current = 0;
  for (const SNode* n = slist->head; n != 0; n = n->nxt) {
    if (current > 0) {
      buffer[current++] = separator;
    }
    int l = strlen(n->str);
    memcpy(buffer + current, n->str, l);
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
  }

  return n;
}

static void hlist_dealloc(HList* h)
{
  if (h == 0) {
    return;
  }

  GLOG(("@@@ HLIST deleting [%s/%s]\n",
        h->canonical_name ? h->canonical_name : "*NULL*",
        h->name ? h->name : "*NULL*"));
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
    GLOG(("@@@ WOW HLIST has refcnt %d for [%s/%s]\n",
          h->refcnt,
          h->canonical_name ? h->canonical_name : "*NULL*",
          h->name ? h->name : "*NULL*"));
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
  if (!hlist) {
    return 0;
  }

  HList* h = 0;
  HList* q = 0;
  for (HList* p = hlist; p != 0; p = p->nxt) {
    HList* n = hlist_alloc(p);
    if (h == 0) {
      h = n;
    }
    if (q != 0) {
      q->nxt = n;
    }
    q = n;
  }
  if (h) {
    ++h->refcnt;
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
    for (const SNode* n = h->slist->head; n != 0; n = n->nxt) {
      fprintf(fp, ">  %3d: [%s]\n", ++count, n->str);
    }
    char* t = slist_format(h->slist, ':', 0, 0);
    fprintf(fp, "> Format: [%s]\n", t);
    GMEM_DEL(t, char*, -1);
  }
  fflush(fp);
}

static char* canonicalise(const char* name, int translate_underscore, int* length)
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
      canonical[j] = translate_underscore && name[j] == '_' ? '-' : name[j];
      in_word = 0;
    }
  }
  canonical[j] = '\0';

  for (int j = 0; exceptions[j].result != 0; ++j) {
    if (strcmp(canonical, exceptions[j].result) == 0) {
      GLOG(("@@@ Exception: [%s] => [%s]\n", canonical, exceptions[j].change));
      strcpy(canonical, exceptions[j].change);
      break;
    }
  }

  return canonical;
}

static HList* hlist_lookup(HList* hlist, int translate_underscore,
                           const char* name, int insert, HList** prev)
{
  if (prev) {
    *prev = 0;
  }

  if (!name) {
    return 0;
  }

  int l = 0;
  char* canonical = canonicalise(name, translate_underscore, &l);
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

  GLOG(("@@@ Lookup header [%s] -> %p\n", name, h));
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

SList* hlist_add_header(HList* hlist, int translate_underscore,
                        const char* name, const char* value)
{
  HList* h = hlist_lookup(hlist, translate_underscore,
                          name, 1, 0);
  slist_add(h->slist, value);
  GLOG(("@@@ add_header added [%s] to [%s]\n", value, name));
  return h->slist;
}

void hlist_del_header(HList* hlist, int translate_underscore,
                      const char* name)
{
  HList* q = 0;
  HList* h = hlist_lookup(hlist, translate_underscore,
                          name, 0, &q);

  if (!h) {
    GLOG(("@@@ del_header found nothing for [%s]\n", name));
    return;
  }

  q->nxt = h->nxt;
  hlist_dealloc(h);
  GLOG(("@@@ del_header deleted [%s]\n", name));
}

SList* hlist_get_header(HList* hlist, int translate_underscore,
                        const char* name)
{
  HList* h = hlist_lookup(hlist, translate_underscore,
                          name, 0, 0);

  if (!h) {
    GLOG(("@@@ get_header found nothing for [%s]\n", name));
    return 0;
  }

  GLOG(("@@@ get_header found %p for [%s]\n", h->slist, name));
  return h->slist;
}
