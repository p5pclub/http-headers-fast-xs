#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include "glog.h"
#include "gmem.h"
#include "hlist.h"

static SNode* snode_alloc(const char* str, void* obj) {
  if (str && obj) {
    return 0;
  }

  SNode* snode = 0;
  GMEM_NEW(snode, SNode*, sizeof(SNode));
  if (snode == 0) {
    return 0;
  }

  memset(&snode->data, 0, sizeof(snode->data));
  snode->nxt = 0;
  snode->refcnt = 0;
  snode->type = SNODE_TYPE_NONE;

  if (str) {
    snode->type = SNODE_TYPE_STR;
    GMEM_STRNEW(snode->data.str.str, str, -1, snode->data.str.alen);
    snode->data.str.ulen = snode->data.str.alen;
    GLOG(("=C= SNode allocating [%s]",
          snode->data.str.str ? snode->data.str.str : "*NULL*"));
  }

  if (obj) {
    snode->type = SNODE_TYPE_OBJ;
    snode->data.obj.obj = obj;
    GLOG(("=C= SNode allocating [%p]", snode->data.obj.obj));
  }

  return snode;
}

static void snode_dealloc(SNode* snode) {
  if (snode == 0) {
    return;
  }

  switch (snode->type) {
  case SNODE_TYPE_STR:
    GLOG(("=C= SNode deallocating str [%s]",
          snode->data.str.str ? snode->data.str.str : "*NULL*"));
    GMEM_DEL(snode->data.str.str, char*, snode->data.str.alen);
    break;

  case SNODE_TYPE_OBJ:
    GLOG(("=C= SNode deallocating obj [%p]", snode->data.obj.obj));
    break;
  }

  GMEM_DEL(snode, SNode*, sizeof(SNode));
}

// Manage reference-counted SNode* elements.
static SNode* snode_ref(SNode* snode)
{
  if (snode == 0) {
    return 0;
  }

  ++snode->refcnt;
  return snode;
}

static SNode* snode_unref(SNode* snode)
{
  if (snode == 0) {
    return 0;
  }

  if (--snode->refcnt > 0) {
    GLOG(("=C= Snode %p still has refcnt %d", snode, snode->refcnt));
    return snode;
  }

  snode_dealloc(snode);
  return 0;
}


static SList* slist_alloc(void) {
  SList* p = 0;
  GMEM_NEW(p, SList*, sizeof(SList));
  if (p == 0) {
    return 0;
  }

  p->head = 0;
  p->tail = 0;
  p->size = 0;

  return p;
}

static void slist_dealloc(SList* slist) {
  if (slist == 0) {
    return;
  }

  slist_clear(slist);
  GMEM_DEL(slist, SList*, sizeof(SList));
}

SList* slist_create(void) {
  return slist_clone(0);
}

void slist_destroy(SList* slist) {
  if (!slist) {
    return;
  }
  slist_dealloc(slist);
}

SList* slist_clone(SList* slist) {
  SList* p = slist_alloc();
  if (slist) {
    p->head = slist->head;
    p->tail = slist->tail;
    p->size = slist->size;

    snode_ref(p->head);
  }

  return p;
}

int slist_clear(SList* slist) {
  if (!slist) {
    return 0;
  }

  int free_list = 1;
  SNode* n = slist->head;
  while (n) {
    int last = n == slist->tail;
    SNode* q = n->nxt;
    if (snode_unref(n)) {
      GLOG(("=C= while clearing list %p, node %p still referenced",
            slist, n));
      last = 1;
      free_list = 0;
    }

    if (last) {
      n = 0;
      break;
    }

    n = q;
  }

  slist->head = 0;
  slist->tail = 0;
  slist->size = 0;
  GLOG(("=C= while clearing list %p, returning %d", slist, free_list));
  return free_list;
}

int slist_empty(const SList* slist) {
  return slist == 0 ? 1 : slist->size == 0;
}

int slist_size(const SList* slist) {
  return slist == 0 ? 0 : slist->size;
}

void slist_dump(SList* slist, FILE* fp)
{
  static char* ctype[SNODE_TYPE_SIZE] = {
    "NONE",
    "STR",
    "DATA",
  };

  if (!slist) {
    return;
  }
  fprintf(fp, "SList at 0x%p with %d elements:\n", slist, slist_size(slist));
  int count = 0;
  SNode* s = slist->head;
  while (s) {
    int last = s == slist->tail;
    fprintf(fp, ">  %3d [%2d|%s|%p]: ",
            ++count, s->refcnt, ctype[s->type], s);
    switch (s->type) {
    case SNODE_TYPE_STR:
      fprintf(fp, "[%*s]", s->data.str.ulen, s->data.str.str);
      break;

    case SNODE_TYPE_OBJ:
      fprintf(fp, "[%p]", s->data.obj.obj);
      break;
    }
    fprintf(fp, "\n");

    if (last) {
      s = 0;
      break;
    }
    s = s->nxt;
  }

#if 0
  char* t = slist_format(slist, ':', 0, 0);
  fprintf(fp, "> Format: [%s]\n", t);
  GMEM_DEL(t, char*, -1);
#endif

  fflush(fp);
}

void slist_add_str(SList* slist, const char* str)
{
  if (!slist) {
    return;
  }
  if (!str) {
    return;
  }

  GLOG(("=C= creating SNode str for [%s]", str));
  SNode* n = snode_ref(snode_alloc(str, 0));
  if (slist->head == 0) {
    slist->head = n;
  }
  if (slist->tail) {
    slist->tail->nxt = n;
  }
  slist->tail = n;
  ++slist->size;
}

void slist_add_obj(SList* slist, void* obj)
{
  if (!slist) {
    return;
  }
  if (!obj) {
    return;
  }

  GLOG(("=C= creating SNode obj for [%p]", obj));
  SNode* n = snode_ref(snode_alloc(0, obj));
  if (slist->head == 0) {
    slist->head = n;
  }
  if (slist->tail) {
    slist->tail->nxt = n;
  }
  slist->tail = n;
  ++slist->size;
}


void siter_reset(SIter* siter, const SList* slist) {
  siter->slist = slist;
  siter->current = siter->slist->head;
  siter->used = 0;
}

int siter_more(const SIter* siter) {
  if (!siter->current) {
    return 0;
  }
  if (siter->current != siter->slist->tail) {
    return 1;
  }

  return !siter->used;
}

SNode* siter_fetch(SIter* siter) {
  siter->used = 1;
  return siter->current;
}

void siter_next(SIter* siter) {
  if (!siter->current) {
    return;
  }
  if (siter->current != siter->slist->tail) {
    siter->current = siter->current->nxt;
  } else {
    siter->current = siter->used ? 0 : siter->current->nxt;
  }
  siter->used = 0;
}


static HNode* hnode_alloc(const char* name,
                          const char* canonical_name,
                          int canonical_offset) {
  HNode* hnode = 0;
  GMEM_NEW(hnode, HNode*, sizeof(HNode));
  if (hnode == 0) {
    return 0;
  }

  hnode->nxt = 0;
  hnode->slist = slist_create();

  hnode->canonical_offset = canonical_offset;
  int l = 0;
  GMEM_STRNEW(hnode->name, name, -1, l);
  GMEM_STRNEW(hnode->canonical_name, canonical_name, -1, l);

  GLOG(("=C= HNode allocating [%s/%s]",
        hnode->canonical_name ? hnode->canonical_name + hnode->canonical_offset : "*NULL*",
        hnode->name ? hnode->name : "*NULL*"));
  return hnode;
}

static void hnode_dealloc(HNode* hnode) {
  if (hnode == 0) {
    return;
  }

  GLOG(("=C= Hnode deallocating [%s/%s]",
        hnode->canonical_name ? hnode->canonical_name + hnode->canonical_offset : "*NULL*",
        hnode->name ? hnode->name : "*NULL*"));
  GMEM_DEL(hnode->canonical_name, char*, -1);
  GMEM_DEL(hnode->name, char*, -1);
  slist_destroy(hnode->slist);
  GMEM_DEL(hnode, HNode*, sizeof(HNode));
}

static HList* hlist_alloc(void) {
  HList* p = 0;
  GMEM_NEW(p, HList*, sizeof(HList));
  if (p == 0) {
    return 0;
  }

  p->head = 0;
  p->tail = 0;
  p->size = 0;

  return p;
}

static void hlist_dealloc(HList* hlist) {
  if (hlist == 0) {
    return;
  }

  hlist_clear(hlist);
  GMEM_DEL(hlist, HList*, sizeof(HList));
}

HList* hlist_create(void) {
  return hlist_clone(0);
}

void hlist_destroy(HList* hlist) {
  if (hlist == 0) {
    return;
  }

  hlist_dealloc(hlist);
}

static HNode* hlist_add_empty(HList* hlist) {
  if (!hlist) {
    return 0;
  }

  GLOG(("=C= adding empty HNode to HList %p, %d elements",
        hlist, hlist_size(hlist)));
  HNode* h = hnode_alloc(0, 0, 0);
  if (!h) {
    return 0;
  }

  if (hlist->head == 0) {
    hlist->head = h;
  }
  if (hlist->tail) {
    hlist->tail->nxt = h;
  }
  hlist->tail = h;
  ++hlist->size;

  GLOG(("=C= added empty HNode to HList %p, %d elements",
        hlist, hlist_size(hlist)));
  return h;
}

HList* hlist_clone(HList* hlist) {
  GLOG(("=C= cloning hlist %p", hlist));
  // hlist_dump(hlist, stderr);

  HList* h = hlist_alloc();
  if (!hlist) {
    return h;
  }

  HNode* n = hlist->head;
  while (n) {
    int last = n == hlist->tail;

    HNode* q = hlist_add_empty(h);
    if (!h->head) {
      h->head = q;
    }
    h->tail = q;

    int l = 0;
    GMEM_STRNEW(q->name, n->name, -1, l);
    GMEM_STRNEW(q->canonical_name, n->canonical_name, -1, l);
    q->canonical_offset = n->canonical_offset;

    *q->slist = *n->slist;
    q->slist->head = snode_ref(q->slist->head);

    if (last) {
      n = 0;
      break;
    }
    n = n->nxt;
  }

  GLOG(("=C= cloned hlist %p -> %p", hlist, h));
  // hlist_dump(h, stderr);

  return h;
}

int hlist_clear(HList* hlist) {
  if (!hlist) {
    return 0;
  }

  HNode* n = hlist->head;
  while (n) {
    int last = n == hlist->tail;
    HNode* q = n->nxt;
    hnode_dealloc(n);

    if (last) {
      n = 0;
      break;
    }

    n = q;
  }

  hlist->head = 0;
  hlist->tail = 0;
  hlist->size = 0;
  return 1;
}

int hlist_empty(const HList* hlist) {
  return hlist == 0 ? 1 : hlist->size == 0;
}

int hlist_size(const HList* hlist) {
  return hlist == 0 ? 0 : hlist->size;
}

void hlist_dump(HList* hlist, FILE* fp)
{
  if (!hlist) {
    return;
  }
  fprintf(fp, "HList at 0x%p with %d elements:\n", hlist, hlist_size(hlist));
  const HNode* h = hlist->head;
  while (h) {
    int last = h == hlist->tail;
    fprintf(fp, "> Name: [%p] %s (%s)\n",
            h, h->canonical_name + h->canonical_offset, h->name);
    slist_dump(h->slist, fp);
    if (last) {
      h = 0;
      break;
    }
    h = h->nxt;
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

  for (j = 0; exceptions[j].result != 0; ++j) {
    if (strcmp(canonical, exceptions[j].result) == 0) {
      GLOG(("=C= exception: [%s] => [%s]", canonical, exceptions[j].change));
      strcpy(canonical, exceptions[j].change);
      break;
    }
  }

  return canonical;
}

static HNode* hlist_lookup(HList* hlist, int translate_underscore,
                           const char* name, int insert, HNode** prev)
{
  if (prev) {
    *prev = 0;
  }

  if (!hlist) {
    return 0;
  }
  if (!name) {
    return 0;
  }

  int l = 0;
  char* canonical = canonicalise(name, translate_underscore, &l);
  if (!canonical) {
    return 0;
  }

  GLOG(("=C= searching %s in list %p, %d elements",
        canonical, hlist, hlist_size(hlist)));
  HNode* h = hlist->head;
  HNode* q = 0;
  while (h) {
    int last = h == hlist->tail;
    int m = memcmp(h->canonical_name, canonical, l);
    if (m == 0) {
      break;
    }
    q = h;
    if (last) {
      h = 0;
      break;
    }
    h = h->nxt;
  }
  if (prev) {
    *prev = q;
  }

  GLOG(("=C= lookup header [%s] -> %p", name, h));
  if (h) {
    // If it already exists, we won't need this
    GMEM_DEL(canonical, char*, l);
    return h;
  }

  if (!insert) {
    GMEM_DEL(canonical, char*, l);
  } else {
    // Not found and we were asked to insert
    h = hlist_add_empty(hlist);

    int l = 0;
    GMEM_STRNEW(h->name, name, -1, l);
    h->canonical_name = canonical;
    h->canonical_offset = (name[0] == ':');
  }

  return h;
}

SList* hlist_get_header(HList* hlist, int translate_underscore,
                        const char* name)
{
  HNode* h = hlist_lookup(hlist, translate_underscore,
                          name, 0, 0);

  if (!h) {
    GLOG(("=C= get_header found nothing for [%s] -- OK", name));
    return 0;
  }

  GLOG(("=C= get_header found %p for [%s]", h->slist, name));
  // slist_dump(h->slist, stderr);
  return h->slist;
}

SList* hlist_add_header(HList* hlist, int translate_underscore,
                        const char* name, const char* str, void* obj)
{
  if (str && obj) {
    GLOG(("=C= add_header have both str [%s] and obj [%p] -- BAD",
          str, obj));
    return 0;
  }

  HNode* h = hlist_lookup(hlist, translate_underscore,
                          name, 1, 0);
  if (!h) {
    GLOG(("=C= add_header found nothing for [%s] -- BAD", name));
    return 0;
  }

  if (str) {
    slist_add_str(h->slist, str);
    GLOG(("=C= add_header added str [%s] to [%s]", str, name));
  }
  if (obj) {
    slist_add_obj(h->slist, obj);
    GLOG(("=C= add_header added obj [%p] to [%s]", obj, name));
  }

  return h->slist;
}

void hlist_del_header(HList* hlist, int translate_underscore,
                      const char* name)
{
  HNode* prev = 0;
  HNode* h = hlist_lookup(hlist, translate_underscore,
                          name, 0, &prev);
  if (!h) {
    GLOG(("=C= del_header found nothing for [%s] -- OK", name));
    return;
  }

  if (h == hlist->head) {
    hlist->head = hlist->head->nxt;
  }
  if (h == hlist->tail) {
    hlist->tail = prev;
  }
  if (prev) {
    prev->nxt = h->nxt;
  }

  hnode_dealloc(h);
  --hlist->size;
  GLOG(("=C= del_header deleted [%s]", name));
}


void hiter_reset(HIter* hiter, const HList* hlist) {
  hiter->hlist = hlist;
  hiter->current = hiter->hlist->head;
  hiter->used = 0;
}

int hiter_more(const HIter* hiter) {
  if (!hiter->current) {
    return 0;
  }
  if (hiter->current != hiter->hlist->tail) {
    return 1;
  }

  return !hiter->used;
}

HNode* hiter_fetch(HIter* hiter) {
  hiter->used = 1;
  return hiter->current;
}

void hiter_next(HIter* hiter) {
  if (!hiter->current) {
    return;
  }
  if (hiter->current != hiter->hlist->tail) {
    hiter->current = hiter->current->nxt;
  } else {
    hiter->current = hiter->used ? 0 : hiter->current->nxt;
  }
  hiter->used = 0;
}
