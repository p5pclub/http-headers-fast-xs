#define PERL_NO_GET_CONTEXT     /* we want efficiency */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include "glog.h"
#include "hlist.h"

#define HLIST_KEY_STR "hlist"
#define HLIST_KEY_LEN 5

#define MY_CXT_KEY "HTTP::Headers::Fast::XS::_guts" XS_VERSION

typedef struct {
    SV **translate;
} my_cxt_t;

START_MY_CXT;

static HList* fetch_hlist(pTHX_  SV* self);
static HNode* set_scalar(pTHX_  HList* h, HNode* n, int trans, const char* ckey, SV* pval);
static HNode* set_array (pTHX_  HList* h, HNode* n, int trans, const char* ckey, AV* pval);
static HNode* set_value (pTHX_  HList* h, HNode* n, int trans, const char* ckey, SV* pval);

static HList* fetch_hlist(pTHX_  SV* self) {
  HList* h;

  h = (HList*) SvIV(*hv_fetch((HV*) SvRV(self),
                    HLIST_KEY_STR, HLIST_KEY_LEN, 0));
  return h;
}

static int fetch_translate(pTHX_ SV* self) {
  dMY_CXT;

  SV* ptrans = GvSV(*MY_CXT.translate);
  if (!ptrans) {
    croak("$TRANSLATE_UNDERSCORE variable does not exist");
  }
  int trans = SvOK(ptrans) && SvTRUE(ptrans);
  GLOG(("=X= translate_underscore is %d", trans));
  return trans;
}

static HNode* set_scalar(pTHX_  HList* h, HNode* n, int trans, const char* ckey, SV* pval) {
  STRLEN slen;
  const char* cval = SvPV(pval, slen);
  n = hlist_add_header(h, trans, n, ckey, cval, 0);
  GLOG(("=X= set scalar [%s] => [%s]", ckey, cval));
  return n;
}

static HNode* set_array(pTHX_  HList* h, HNode* n, int trans, const char* ckey, AV* pval) {
  int count = av_len(pval) + 1;
  for (int j = 0; j < count; ++j) {
    SV** svp = av_fetch(pval, j, 0);
    n = set_value(aTHX_  h, n, trans, ckey, *svp);
  }
  return n;
}

static HNode* set_value(pTHX_  HList* h, HNode* n, int trans, const char* ckey, SV* pval) {
  if (SvIOK(pval) || SvNOK(pval) || SvPOK(pval)) {
    n = set_scalar(aTHX_  h, n, trans, ckey, pval);
  }

  if (SvROK(pval)) {
    SV* deref = SvRV(pval);

    if (SvTYPE(deref) == SVt_PVAV) {
      AV* array = (AV*) SvRV(pval);
      n = set_array(aTHX_  h, n, trans, ckey, array);
    }
  }
  return n;
}

/*
 * Given an HList, return all of its nodes to Perl.
 */
static void return_hlist(pTHX_   HList* list, const char* func, int want) {

  dSP;

  if (want == G_VOID) {
    GLOG(("=X= %s: no return expected, nothing will be returned", func));
    return;
  }

  int count = hlist_size(list);
  if (count <= 0) {
    GLOG(("=X= %s: hlist is empty, returning nothing", func));
    return;
  }

  if (want == G_SCALAR) {
    GLOG(("=X= %s: returning number of elements", func));
    EXTEND(SP, 1);
    PUSHs(sv_2mortal(newSViv(count)));
    PUTBACK;
  }

  if (want == G_ARRAY) {
    GLOG(("=X= %s: returning as %d elements", func, count));
    EXTEND(SP, count);

    int num = 0;
    HIter hiter;
    for (hiter_reset(&hiter, list);
         hiter_more(&hiter);
         hiter_next(&hiter)) {
      HNode* node = hiter_fetch(&hiter);
      ++num;

      const char* s = node->name;
      GLOG(("=X= %s: returning %2d - str [%s]", func, num, s));
      PUSHs(sv_2mortal(newSVpv(s, 0)));
    }
    PUTBACK;
  }
}

/*
 * Given an SList, return all of its nodes to Perl.
 */
static void return_slist(pTHX_   SList* list, const char* func, int want) {

  dSP;

  if (want == G_VOID) {
    GLOG(("=X= %s: no return expected, nothing will be returned", func));
    return;
  }

  int count = slist_size(list);
  if (count <= 0) {
    if (want == G_ARRAY) {
      GLOG(("=X= %s: slist is empty, wantarray => 0", func));
      EXTEND(SP, 1);
      PUSHs(sv_2mortal(newSViv(0)));
      PUTBACK;
    } else {
      GLOG(("=X= %s: slist is empty, returning nothing", func));
    }
    return;
  }

  GLOG(("=X= %s: returning %d values", func, count));

  if (want == G_SCALAR) {
    GLOG(("=X= %s: returning as single string", func));

    char ret[1024]; // TODO
    int rpos = 0;
    int num = 0;
    SIter siter;
    for (siter_reset(&siter, list);
         siter_more(&siter);
         siter_next(&siter)) {
      SNode* node = siter_fetch(&siter);
      ++num;

      switch (node->type) {
      case SNODE_TYPE_STR:
        GLOG(("=X= %s: returning %2d - str [%s]", func, num, node->data.gstr.str));
        if (rpos > 0) {
          ret[rpos++] = ',';
          ret[rpos++] = ' ';
        }
        memcpy(ret + rpos, node->data.gstr.str, node->data.gstr.ulen - 1);
        rpos += node->data.gstr.ulen - 1;
        break;

      case SNODE_TYPE_OBJ:
        break;
      }
      ret[rpos] = '\0';
    }

    EXTEND(SP, 1);
    PUSHs(sv_2mortal(newSVpv(ret, rpos)));
    PUTBACK;
  }

  if (want == G_ARRAY) {
    GLOG(("=X= %s: returning as %d elements", func, count));
    EXTEND(SP, count);
    int num = 0;
    SIter siter;
    for (siter_reset(&siter, list);
         siter_more(&siter);
         siter_next(&siter)) {
      SNode* node = siter_fetch(&siter);
      ++num;

    /* TODO: This can probably be optimised A LOT*/
      switch (node->type) {
      case SNODE_TYPE_STR:
        GLOG(("=X= %s: returning %2d - str [%s]", func, num, node->data.gstr.str));
        PUSHs(sv_2mortal(newSVpv(node->data.gstr.str, node->data.gstr.ulen - 1)));
        break;

      case SNODE_TYPE_OBJ:
        break;
      }
    }
    PUTBACK;
  }
}


MODULE = HTTP::Headers::Fast::XS		PACKAGE = HTTP::Headers::Fast::XS
PROTOTYPES: DISABLE

BOOT:
{
    MY_CXT_INIT;
    MY_CXT.translate = hv_fetch(
        gv_stashpvn( "HTTP::Headers::Fast", 19, 0 ),
        "TRANSLATE_UNDERSCORE",
        20,
        0
    );
}

#
# Create a new HList.
#
void*
hhf_hlist_create()

  PREINIT:
    HList* h = 0;

  CODE:
    h = hlist_create();
    GLOG(("=X= HLIST_CREATE() => %p", h));
    RETVAL = (void*) h;

  OUTPUT: RETVAL


#
# Clone an existing HList.
#
void*
hhf_hlist_clone(unsigned long nh)

  PREINIT:
    HList* h = 0;
    HList* t = 0;

  CODE:
    h = (HList*) nh;
    t = hlist_clone(h);
    GLOG(("=X= HLIST_CLONE(%p|%d) => %p", h, hlist_size(h), t));
    RETVAL = t;

  OUTPUT: RETVAL



#################################################################

#
# Object's destructor, called automatically
#
void
DESTROY(SV* self, ...)
  PREINIT:
    HList* h = 0;

  CODE:
    h = fetch_hlist(aTHX_  self);
    GLOG(("=X= @@@ destroy(%p|%d)", h, hlist_size(h)));
    hlist_destroy(h);


#
# Clear object, leaving it as freshly created.
#
void
clear(SV* self, ...)
  PREINIT:
    HList* h = 0;

  CODE:
    h = fetch_hlist(aTHX_  self);
    GLOG(("=X= @@@ clear(%p|%d)", h, hlist_size(h)));
    hlist_clear(h);


#
# Get all the keys in an existing HList.
#
void
_header_keys(SV* self)
  PREINIT:
    HList* h = 0;

  PPCODE:
    h = fetch_hlist(aTHX_  self);
    GLOG(("=X= @@@ _header_keys(%p|%d), want %d",
          h, hlist_size(h), GIMME_V));

    PUTBACK;
    return_hlist(aTHX_   h, "_header_keys", GIMME_V);
    SPAGAIN;


#
# init_header
#
void
init_header(SV* self, ...)
  PREINIT:
    int argc = 0;
    HList* h = 0;
    HNode* n = 0;
    int    ctrans = 0;
    SV*    pkey;
    SV*    pval;
    STRLEN len;
    char*  ckey;

  CODE:
    argc = items - 1;
    if (argc != 2) {
      croak("init_header needs two arguments");
    }

    h = fetch_hlist(aTHX_  self);
    ctrans = fetch_translate(aTHX_ self);
    GLOG(("=X= @@@ init_header(%p|%d), %d params, want %d, trans %d",
          h, hlist_size(h), argc, GIMME_V, ctrans));

    pkey = ST(1);
    ckey = SvPV(pkey, len);
    pval = ST(2);

    n = hlist_get_header(h, ctrans, n, ckey);
    if (!n) {
      PUTBACK;
      n = set_value(aTHX_  h, n, ctrans, ckey, pval);
      SPAGAIN;
    }

#
# push_header
#
void
push_header(SV* self, ...)
  PREINIT:
    int argc = 0;
    HList* h = 0;
    HNode* n = 0;
    int    ctrans = 0;
    int    j = 0;
    SV*    pkey;
    SV*    pval;
    STRLEN len;
    char*  ckey;

  CODE:
    argc = items - 1;
    if (argc % 2 != 0) {
      croak("push_header needs an even number of arguments");
    }

    h = fetch_hlist(aTHX_  self);
    ctrans = fetch_translate(aTHX_ self);
    GLOG(("=X= @@@ push_header(%p|%d), %d params, want %d, trans %d",
          h, hlist_size(h), argc, GIMME_V, ctrans));

    for (j = 1; j <= argc; ) {
        if (j > argc) {
          break;
        }
        pkey = ST(j++);

        if (j > argc) {
          break;
        }
        pval = ST(j++);

        ckey = SvPV(pkey, len);
        PUTBACK;
        n = set_value(aTHX_  h, n, ctrans, ckey, pval);
        SPAGAIN;
    }


#
# header
#
void
header(SV* self, ...)
  PREINIT:
    int argc = 0;
    HList* h = 0;
    HNode* n = 0;
    int    ctrans = 0;
    int    j = 0;
    SV*    pkey;
    SV*    pval;
    STRLEN len;
    char*  ckey;
    HList* seen = 0;

  PPCODE:
    argc = items - 1;
    h = fetch_hlist(aTHX_  self);
    ctrans = fetch_translate(aTHX_ self);
    GLOG(("=X= @@@ header(%p|%d), %d params, want %d, trans %d",
          h, hlist_size(h), argc, GIMME_V, ctrans));

    do {
      if (argc == 0) {
        croak("init_header called with no arguments");
        break;
      }

      if (argc == 1) {
        pkey = ST(1);
        ckey = SvPV(pkey, len);
        n = hlist_get_header(h, ctrans, n, ckey);
        if (n && slist_size(n->slist) > 0) {
          PUTBACK;
          return_slist(aTHX_   n->slist, "header1", GIMME_V);
          SPAGAIN;
        }
        break;
      }

      if (argc % 2 != 0) {
        croak("init_header needs one or an even number of arguments");
        break;
      }

      seen = hlist_create();
      for (j = 1; j <= argc; ) {
          if (j > argc) {
            break;
          }
          pkey = ST(j++);

          if (j > argc) {
            break;
          }
          pval = ST(j++);

          ckey = SvPV(pkey, len);
          int clear = 0;
          if (! hlist_get_header(seen, ctrans, 0, ckey)) {
            clear = 1;
            hlist_add_header(seen, ctrans, 0, ckey, 0, 0);
          }

          n = hlist_get_header(h, ctrans, n, ckey);
          if (n) {
            if (j > argc && slist_size(n->slist) > 0) {
              /* Last value, return its current contents */
              PUTBACK;
              return_slist(aTHX_   n->slist, "header2", GIMME_V);
              SPAGAIN;
            }
            if (clear) {
              slist_clear(n->slist);
            }
          }

          PUTBACK;
          n = set_value(aTHX_  h, n, ctrans, ckey, pval);
          SPAGAIN;
          n = 0;
      }
      hlist_destroy(seen);
      break;
    } while (0);


#
# remove_header
#
void
remove_header(SV* self, ...)
  PREINIT:
    int argc = 0;
    HList* h = 0;
    HNode* n = 0;
    int    ctrans = 0;
    int    j = 0;
    SV*    pkey;
    STRLEN len;
    char*  ckey;
    int    size = 0;
    int    total = 0;

  PPCODE:
    argc = items - 1;
    h = fetch_hlist(aTHX_  self);
    ctrans = fetch_translate(aTHX_ self);
    GLOG(("=X= @@@ remove_header(%p|%d), %d params, want %d, trans %d",
          h, hlist_size(h), argc, GIMME_V, ctrans));

    for (j = 1; j <= argc; ++j) {
      pkey = ST(j);
      ckey = SvPV(pkey, len);

      n = hlist_get_header(h, ctrans, n, ckey);
      if (! n) {
        continue;
      }

      size = slist_size(n->slist);
      if (size > 0) {
        total += size;
        if (GIMME_V == G_ARRAY) {
          PUTBACK;
          return_slist(aTHX_   n->slist, "remove_header", G_ARRAY);
          SPAGAIN;
        }
      }

      n = hlist_del_header(h, ctrans, 0, ckey);
      GLOG(("=X= remove_header: deleted key [%s]", ckey));
    }

    if (GIMME_V == G_SCALAR) {
      GLOG(("=X= remove_header: returning count %d", total));
      EXTEND(SP, 1);
      PUSHs(sv_2mortal(newSViv(total)));
    }
