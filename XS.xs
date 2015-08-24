#define PERL_NO_GET_CONTEXT     /* we want efficiency */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include "glog.h"
#include "hlist.h"

/*
 * Given an HList, return all of its nodes to Perl.
 */
static int return_hlist(pTHX_   HList* list, const char* func) {

  dSP;

  int count = hlist_size(list);
  if (count <= 0) {
    GLOG(("=X= %s: hlist is empty, nothing to return", func));
    return 0;
  }

  GLOG(("=X= %s: returning %d values", func, count));
  EXTEND(SP, count);

  int num = 0;
  HIter hiter;
  for (hiter_reset(&hiter, list);
       hiter_more(&hiter);
       hiter_next(&hiter)) {
    HNode* node = hiter_fetch(&hiter);
    ++num;

    /* TODO: This can probably be optimised A LOT*/
    GLOG(("=X= %s: returning %2d - str [%s]", func, num, node->canonical_name));
    PUSHs(sv_2mortal(newSVpv(node->canonical_name, 0)));
  }

  PUTBACK;
  return count;
}

/*
 * Given an SList, return all of its nodes to Perl.
 */
static int return_slist(pTHX_   SList* list, const char* func) {

  dSP;

  int count = slist_size(list);
  if (count <= 0) {
    GLOG(("=X= %s: slist is empty, nothing to return", func));
    return 0;
  }

  GLOG(("=X= %s: returning %d values", func, count));
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
      GLOG(("=X= %s: %2d - returning data [%p]", func, num, node->data));
      // TODO: PUSHs(sv_2mortal(newSVpv(node->data.gstr.str, 0)));
      PUSHs(sv_2mortal(newSVpv("gonzo", 0)));
      break;
    }
  }

  PUTBACK;
  return count;
}


MODULE = HTTP::Headers::Fast::XS		PACKAGE = HTTP::Headers::Fast::XS
PROTOTYPES: DISABLE


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
# Destroy an existing HList.
#
void
hhf_hlist_destroy(unsigned long nh)

  PREINIT:
    HList* h = 0;

  CODE:
    h = (HList*) nh;
    GLOG(("=X= HLIST_DESTROY(%p|%d)", h, hlist_size(h)));
    hlist_destroy(h);


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


#
# Clear an existing HList, leaving it as freshly created.
#
void
hhf_hlist_clear(unsigned long nh)

  PREINIT:
    HList* h = 0;

  CODE:
    GLOG(("=X= HLIST_CLEAR(%p|%d)", h, hlist_size(h)));
    h = (HList*) nh;
    hlist_clear(h);


#
# Get all the keys in an existing HList.
#
void
hhf_hlist_header_names(unsigned long nh)

  PREINIT:
    HList* h = 0;

  PPCODE:
    h = (HList*) nh;
    GLOG(("=X= HLIST_HEADER_NAMES(%p|%d)", h, hlist_size(h)));

    PUTBACK;
    return_hlist(aTHX_   h, "header_names");
    SPAGAIN;


#
# Get all the values for a given key in an existing HList.
#
void
hhf_hlist_header_get(unsigned long nh, int translate_underscore, const char* name)

  PREINIT:
    HList* h = 0;
    SList* s = 0;

  PPCODE:
    h = (HList*) nh;
    GLOG(("=X= HLIST_HEADER_GET(%p|%d, %d, %s)",
          h, hlist_size(h), translate_underscore, name));

    s = hlist_get_header(h, translate_underscore,
                         name);

    PUTBACK;
    return_slist(aTHX_   s, "header_get");
    SPAGAIN;


#
# Add to or overwrite the values for a given key in an existing HList.
#
# new_only: fail if this key already had values
# keep_previous: keep any existing previous values for the key
# want_answer: return previously existing values
#
void
hhf_hlist_header_set(unsigned long nh, int translate_underscore, int new_only, int keep_previous, int want_answer, const char* name, SV* val)

  PREINIT:
    HList* h = 0;
    SList* s = 0;
    AV* arr = 0;
    int j;

  PPCODE:
    h = (HList*) nh;
    GLOG(("=X= HLIST_HEADER_SET(%p|%d, %d, %d, %d, %s, %p)",
          h, hlist_size(h), translate_underscore, new_only, keep_previous, name, val));

    /* We look for the current values for the header. */
    s = hlist_get_header(h, translate_underscore,
                         name);
    int count = slist_size(s);
    if (count > 0) {
      if (new_only) {
        /* header should not have existed before */
        GLOG(("=X= header_set: tried to init already-existing header, bye"));
        XSRETURN_EMPTY;
      }

      if (want_answer) {
        /* Put current values as the return for the function. */
        PUTBACK;
        return_slist(aTHX_   s, "header_set");
        SPAGAIN;
      }

      if (keep_previous) {
      } else {
        /* Make a shallow copy of the current value */
        /* GLOG(("=X= header_set: making a shallow copy")); */
        /* t = slist_clone(s); */

        /* Erase what is already there for this header */
        hlist_del_header(h, translate_underscore,
                         name);
        GLOG(("=X= header_set: deleted key [%s]", name));
      }
    }

    if (val) {

      /* Scalar? Just convert it to string. */
      if (SvIOK(val) || SvNOK(val) || SvPOK(val)) {
        STRLEN slen;
        const char* elem = SvPV(val, slen);
        hlist_add_header(h, translate_underscore,
                         name, elem, 0);
        GLOG(("=X= header_set: added single value [%s]", elem));
      }

      /* Reference? */
      if (SvROK(val)) {
       do {
        GLOG(("=X= header_set: is a ref"));
        SV* deref = SvRV(val);

        if (SvOBJECT(deref)) {
          GLOG(("=X= header_set: is an object"));
          hlist_add_header(h, translate_underscore,
                           name, 0, deref);
          GLOG(("=X= header_set: added data value [%p]", deref));
          break;
        }

        if (SvTYPE(deref) == SVt_PVAV) {
          GLOG(("=X= header_set: is an arrayref"));
          arr = (AV*) SvRV(val);

          /* Add each element in val as a value for name. */
          count = av_len(arr) + 1;
          GLOG(("=X= header_set: array has %d elementds", count));
          for (j = 0; j < count; ++j) {
            SV** svp = av_fetch(arr, j, 0);
            if (SvIOK(*svp) || SvNOK(*svp) || SvPOK(*svp)) {
              STRLEN slen;
              const char* elem = SvPV(*svp, slen);
              hlist_add_header(h, translate_underscore,
                               name, elem, 0);
              GLOG(("=X= header_set: added str value %d [%s]", j, elem));
            }
          }
          break;
        }
       } while (0);
      }
    }

#
# Remove a given key (and all its values) in an existing HList.
#
void
hhf_hlist_header_remove(unsigned long nh, int translate_underscore, const char* name)

  PREINIT:
    HList* h = 0;
    SList* s = 0;

  PPCODE:
    h = (HList*) nh;
    GLOG(("=X= HLIST_HEADER_REMOVE(%p|%d, %d, %s)",
          h, hlist_size(h), translate_underscore, name));

    /* We look for the current values for the header and keep a reference to them */
    s = hlist_get_header(h, translate_underscore,
                         name);
    int count = slist_size(s);
    if (count) {

      PUTBACK;
      return_slist(aTHX_   s, "header_remove");
      SPAGAIN;

      /* Erase what is already there for this header */
      hlist_del_header(h, translate_underscore,
                       name);
      GLOG(("=X= header_remove: deleted key [%s]", name));
    }

