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
  snode->refcnt = 0;
  snode->type = SNODE_TYPE_NONE;

  if (str) {
    snode->type = SNODE_TYPE_STR;
    gstr_init(&snode->data.gstr, str, -1);
    GLOG(("=C= SNode allocating str [%s]", snode->data.gstr.str));
  }

  if (obj) {
    snode->type = SNODE_TYPE_OBJ;
    snode->data.pobj.obj = obj;
    GLOG(("=C= SNode allocating obj [%p]", snode->data.pobj.obj));
  }

  return snode;
}

static void snode_dealloc(SNode* snode) {
  if (snode == 0) {
    return;
  }

  switch (snode->type) {
  case SNODE_TYPE_STR:
    GLOG(("=C= SNode deallocating str [%s]", snode->data.gstr.str));
    gstr_clear(&snode->data.gstr);
    break;

  case SNODE_TYPE_OBJ:
    GLOG(("=C= SNode deallocating obj [%p]", snode->data.pobj.obj));
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

  p->data = 0;
  p->alen = p->ulen = 0;

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
  if (slist && slist->alen > 0) {
    p->alen = slist->alen;
    p->ulen = slist->ulen;
    p->data = (SNode*) calloc(p->alen, sizeof(SNode)); // TODO macro GMEM
    for (int j = 0; j < p->alen; ++j) {
      p->data[j].type = slist->data[j].type;
      if (j < slist->ulen) {
        gstr_init(&p->data[j].data.gstr,
                  slist->data[j].data.gstr.str,
                  slist->data[j].data.gstr.ulen);
      } else {
        gstr_init(&p->data[j].data.gstr, 0, 0);
      }
    }
  }

  return p;
}

int slist_clear(SList* slist) {
  if (!slist) {
    return 0;
  }

#if 0
  for (int j = 0; j < slist->ulen; ++j) {
    snode_unref(slist->data[j]);
  }
#endif
  for (int j = 0; j < slist->ulen; ++j) {
    gstr_clear(&slist->data[j].data.gstr);
  }
  free(slist->data);  // TODO macro GMEM
  slist->data = 0;
  slist->alen = slist->ulen = 0;
  return 1;
}

int slist_empty(const SList* slist) {
  return slist == 0 ? 1 : slist->ulen == 0;
}

int slist_size(const SList* slist) {
  return slist == 0 ? 0 : slist->ulen;
}

void slist_dump(SList* slist, FILE* fp)
{
  static char* ctype[SNODE_TYPE_SIZE] = {
    "NONE",
    "STR",
    "OBJ",
  };

  if (!slist) {
    return;
  }

  fprintf(fp, "SList at 0x%p with %d elements:\n", slist, slist_size(slist));
  for (int j = 0; j < slist->ulen; ++j) {
    SNode* s = &slist->data[j];
    fprintf(fp, ">  %3d [%2d|%s|%p]: ",
            j, s->refcnt, ctype[s->type], s);
    switch (s->type) {
    case SNODE_TYPE_STR:
      fprintf(fp, "[%s]", s->data.gstr.str);
      break;

    case SNODE_TYPE_OBJ:
      fprintf(fp, "[%p]", s->data.pobj.obj);
      break;
    }
    fprintf(fp, "\n");
  }
  fflush(fp);
}

static void slist_grow(SList* slist) {
  if (slist->ulen < slist->alen) {
    return;
  }

  int len = slist->alen ? 2*slist->alen : SLIST_INITIAL_SIZE;
  GLOG(("=C= growing SList %p from %d to %d", slist, slist->alen, len));

  SNode* data = (SNode*) calloc(len, sizeof(SNode)); // TODO macro GMEM
  for (int j = 0; j < slist->alen; ++j) {
    data[j].type = slist->data[j].type;
    gstr_init(&data[j].data.gstr, 0, 0);
    if (j >= slist->ulen) {
      continue;
    }

    data[j].data.gstr.ulen = slist->data[j].data.gstr.ulen;
    if (slist->data[j].data.gstr.alen <= 0) {
      memcpy(data[j].data.gstr.buf, slist->data[j].data.gstr.buf, slist->data[j].data.gstr.ulen);
    } else {
      data[j].data.gstr.str  = slist->data[j].data.gstr.str;
      data[j].data.gstr.alen = slist->data[j].data.gstr.alen;
    }
    gstr_init(&slist->data[j].data.gstr, 0, 0);
  }
  free(slist->data); // TODO macro GMEM
  slist->data = data;
  slist->alen = len;
}

void slist_add_str(SList* slist, const char* str)
{
  if (!slist) {
    return;
  }
  if (!str) {
    return;
  }

  slist_grow(slist);

  gstr_init(&slist->data[slist->ulen].data.gstr, str, 0);
  slist->data[slist->ulen].type = SNODE_TYPE_STR;
  GLOG(("=C= added str [%s] at pos %d", str, slist->ulen));
  ++slist->ulen;
}

void slist_add_obj(SList* slist, void* obj)
{
  if (!slist) {
    return;
  }
  if (!obj) {
    return;
  }

  slist_grow(slist);

  // TODO gstr_init(&slist->data[slist->ulen].data.gstr, str, 0);
  slist->data[slist->ulen].type = SNODE_TYPE_OBJ;
  GLOG(("=C= added obj [%p] at pos %d", obj, slist->ulen));
  ++slist->ulen;
}


void siter_reset(SIter* siter, const SList* slist) {
  siter->slist = slist;
  siter->pos = 0;
}

int siter_more(const SIter* siter) {
  return siter->pos < siter->slist->ulen;
}

SNode* siter_fetch(SIter* siter) {
  return &siter->slist->data[siter->pos];
}

void siter_next(SIter* siter) {
  ++siter->pos;
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
  hnode->slist = 0;

  hnode->canonical_offset = canonical_offset;
  int l = 0;
  GMEM_STRNEW(hnode->name, name, -1, l);
  GMEM_STRNEW(hnode->canonical_name, canonical_name, -1, l);

  GLOG(("=C= HNode allocating at %p [%s/%s]",
        hnode,
        hnode->canonical_name ? hnode->canonical_name + hnode->canonical_offset : "*NULL*",
        hnode->name ? hnode->name : "*NULL*"));
  return hnode;
}

static void hnode_dealloc(HNode* hnode) {
  if (hnode == 0) {
    return;
  }

  GLOG(("=C= Hnode deallocating at %p [%s/%s]",
        hnode,
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

  p->alen = HLIST_INITIAL_SIZE;
  p->ulen = 0;
  memset(p->data, 0, p->alen * sizeof(HNode*));
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

int hlist_clear(HList* hlist) {
  if (!hlist) {
    return 0;
  }

  for (int j = 0; j < hlist->alen; ++j) {
    for (HNode* h = hlist->data[j]; h != 0; ) {
      HNode* q = h->nxt;
      hnode_dealloc(h);
      h = q;
    }
    hlist->data[j] = 0;
  }

  hlist->ulen = 0;

  return 1;
}

HList* hlist_clone(HList* hlist) {
  GLOG(("=C= cloning hlist %p", hlist));
  // hlist_dump(hlist, stderr);

  HList* nl = hlist_alloc();
  if (!nl) {
    return 0;
  }

  if (hlist) {
    for (int j = 0; j < hlist->alen; ++j) {
      HNode* q = 0;
      for (HNode* h = hlist->data[j]; h != 0; h = h->nxt) {
        HNode* p = hnode_alloc(h->name, h->canonical_name, h->canonical_offset);
        p->slist = slist_clone(h->slist);
        ++nl->ulen;

        if (q == 0) {
          nl->data[j] = p;
        } else {
          q->nxt = p;
        }
        q = p;
      }
    }
  }

  GLOG(("=C= cloned hlist %p -> %p", hlist, nl));
  // hlist_dump(h, stderr);

  return nl;
}

int hlist_empty(const HList* hlist) {
  return hlist == 0 ? 1 : hlist->ulen == 0;
}

int hlist_size(const HList* hlist) {
  return hlist == 0 ? 0 : hlist->ulen;
}

void hlist_dump(HList* hlist, FILE* fp)
{
  if (!hlist) {
    return;
  }
  fprintf(fp, "HList at 0x%p with %d elements:\n", hlist, hlist_size(hlist));
  for (int j = 0; j < hlist->alen; ++j) {
    for (HNode* h = hlist->data[j]; h != 0; h = h->nxt) {
      fprintf(fp, "> Name: [%p] %s (%s)\n",
              h, h->canonical_name + h->canonical_offset, h->name);
      slist_dump(h->slist, fp);
    }
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

// I've had nice results with djb2 by Dan Bernstein.
static unsigned long hash(const char *str)
{
  unsigned long h = 5381;
  int c;

  while ((c = *str++))
    h = ((h << 5) + h) + c; /* h * 33 + c */

  return h;
}

static HNode* hlist_lookup(HList* hlist, int translate_underscore,
                           const char* name, int insert, int* hpos, HNode** hprv)
{
  if (hpos) {
    *hpos = 0;
  }
  if (hprv) {
    *hprv = 0;
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
  int pos = hash(canonical) % hlist->alen;
  if (hpos) {
    *hpos = pos;
  }
  HNode* h = 0;
  HNode* q = 0;
  for (h = hlist->data[pos]; h != 0; h = h->nxt) {
    if (memcmp(h->canonical_name, canonical, l) == 0) {
      break;
    }
    q = h;
  }
  if (hprv) {
    *hprv = q;
  }

  GLOG(("=C= lookup header [%s] -> pos %d - %p", name, pos, h));
  if (h) {
    // If it already exists, we won't need this
    GMEM_DEL(canonical, char*, l);
    return h;
  }

  if (!insert) {
    GMEM_DEL(canonical, char*, l);
  } else {
    // Not found and we were asked to insert
    h = hnode_alloc(0, 0, 0);
    h->slist = slist_clone(0);

    ++hlist->ulen;
    if (q == 0) {
      hlist->data[pos] = h;
    } else {
      q->nxt = h;
    }

    int l = 0;
    GMEM_STRNEW(h->name, name, -1, l);
    h->canonical_name = canonical;
    h->canonical_offset = (name[0] == ':');
  }

  return h;
}

HNode* hlist_get_header(HList* hlist, int translate_underscore,
                        HNode* h, const char* name)
{
  if (h) {
    GLOG(("=C= get_header using [%s] at %p", name, h));
  } else {
    h = hlist_lookup(hlist, translate_underscore,
                     name, 0, 0, 0);
    if (h) {
      GLOG(("=C= get_header found [%s] at %p", name, h->slist));
    } else {
      GLOG(("=C= get_header found nothing for [%s]", name));
    }
  }

  // slist_dump(h->slist, stderr);
  return h;
}

HNode* hlist_add_header(HList* hlist, int translate_underscore,
                        HNode* h, const char* name, const char* str, void* obj)
{
  if (str && obj) {
    GLOG(("=C= add_header have both str [%s] and obj [%p] -- BAD",
          str, obj));
    return 0;
  }

  if (h) {
    GLOG(("=C= add_header using [%s] at %p", name, h));
  } else {
    h = hlist_lookup(hlist, translate_underscore,
                     name, 1, 0, 0);
    if (h) {
      GLOG(("=C= add_header found / created [%s] at %p", name, h));
    } else {
      GLOG(("=C= add_header found nothing for [%s] -- BAD", name));
      return 0;
    }
  }

  if (str) {
    slist_add_str(h->slist, str);
  }
  if (obj) {
    slist_add_obj(h->slist, obj);
  }

  // slist_dump(h->slist, stderr);
  return h;
}

HNode* hlist_del_header(HList* hlist, int translate_underscore,
                        HNode* h, const char* name)
{
  int hpos = 0;
  HNode* hprv = 0;

  h = hlist_lookup(hlist, translate_underscore,
                   name, 0, &hpos, &hprv);
  if (h) {
    GLOG(("=C= del_header found [%s] at [%p]", name, h));
  } else {
    GLOG(("=C= del_header found nothing for [%s]", name));
    return 0;
  }

  if (hlist->data[hpos] == h) {
    hlist->data[hpos] = h->nxt;
  }
  if (hprv) {
    hprv->nxt = h->nxt;
  }

  hnode_dealloc(h);
  --hlist->ulen;
  GLOG(("=C= del_header deleted [%s]", name));
  return 0;
}


void hiter_reset(HIter* hiter, const HList* hlist) {
  hiter->hlist = hlist;
  hiter->pos = -1;
  hiter->node = 0;
  hiter_next(hiter);
}

int hiter_more(const HIter* hiter) {
  return hiter->node != 0;
}

HNode* hiter_fetch(HIter* hiter) {
  return hiter->node;
}

void hiter_next(HIter* hiter) {
  if (hiter->pos < 0) {
    hiter->pos = 0;
    hiter->node = 0;
  } else if (hiter->node) {
    hiter->node = hiter->node->nxt;
    if (!hiter->node) {
      ++hiter->pos;
    }
  }
  int found = 0;
  for (; !found && hiter->pos < hiter->hlist->alen; ++hiter->pos) {
    if (!hiter->node) {
      hiter->node = hiter->hlist->data[hiter->pos];
    }
    if (hiter->node) {
      break;
    }
  }
}
