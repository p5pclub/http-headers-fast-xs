#define PERL_NO_GET_CONTEXT     /* we want efficiency */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include "glog.h"
#include "hlist.h"

MODULE = HTTP::Headers::Fast::XS		PACKAGE = HTTP::Headers::Fast::XS
PROTOTYPES: DISABLE


void*
hhf_hlist_create()

  PREINIT:
    HList* h = 0;

  CODE:
    h = hlist_create();
    GLOG(("=X= created hlist %p", h));
    RETVAL = (void*) h;

  OUTPUT: RETVAL


void
hhf_hlist_destroy(unsigned long nh)

  PREINIT:
    HList* h = 0;

  CODE:
    h = (HList*) nh;
    GLOG(("=X= destroying hlist %p", h));
    hlist_destroy(h);


void
hhf_hlist_clear(unsigned long nh)

  PREINIT:
    HList* h = 0;

  CODE:
    GLOG(("=X= clearing hlist %p", h));
    h = (HList*) nh;
    hlist_clear(h);


void
hhf_hlist_header_get(unsigned long nh, int translate_underscore, const char* name)

  PREINIT:
    HList* h = 0;
    SList* s = 0;
    SNode* n = 0;

  PPCODE:
    h = (HList*) nh;
    GLOG(("=X= HEADER_GET(%p, %d, %s)", h, translate_underscore, name));
    s = hlist_get_header(h, translate_underscore,
                         name);
    int count = slist_size(s);
    if (count <= 0) {
      GLOG(("=X= header_get: empty values"));
      XSRETURN_EMPTY;
    }
    GLOG(("=X= header_get: returning %d values", count));
    EXTEND(SP, count);
    n = s->head;
    while (n) {
      int last = n == s->tail;
      /* TODO: This can probably be optimised A LOT*/
      GLOG(("=X= header_get: returning [%s]", n->str));
      PUSHs(sv_2mortal(newSVpv(n->str, 0)));
      if (last) {
        n = 0;
        break;
      }
      n = n->nxt;
    }


void
hhf_hlist_header_set(unsigned long nh, int translate_underscore, int new_only, int keep_previous, int want_answer, const char* name, SV* val)

  PREINIT:
    HList* h = 0;
    SList* s = 0;
    SList* t = 0;
    SNode* n = 0;
    AV* arr = 0;

  PPCODE:
    h = (HList*) nh;
    GLOG(("=X= HEADER_SET(%p, %d, %d, %d, %s, %p)",
          h, translate_underscore, new_only, keep_previous, name, val));

    /* We look for the current values for the header and keep a reference to them */
    s = hlist_get_header(h, translate_underscore,
                         name);
    int count = slist_size(s);
    GLOG(("=X= header_set: will later return %d values", count));
    if (count > 0) {
      if (new_only) {
        /* header should not have existed before */
        GLOG(("=X= header_set: tried to init already-existing header, bye"));
        XSRETURN_EMPTY;
      }

      if (keep_previous) {
        if (want_answer) {
          /* Make a deep copy of the current value */
          GLOG(("=X= header_set: making a deep copy"));
          /* GONZO: this is still EXPENSIVE! */
          t = slist_clone(s);
        }
      } else {
        /* Make a shallow copy of the current value */
        GLOG(("=X= header_set: making a shallow copy"));
        t = slist_clone(s);

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
                         name, elem);
        GLOG(("=X= header_set: added single value [%s]", elem));
      }

      /* Reference? */
      if (SvROK(val)) {
        GLOG(("=X= header_set: is a ref"));
        SV* deref = (SV*) SvRV(val);
        if (SvTYPE(deref) == SVt_PVAV) {
          GLOG(("=X= header_set: is an arrayref"));
          arr = (AV*) SvRV(val);

          /* Add each element in val as a value for name. */
          count = av_len(arr) + 1;
          GLOG(("=X= header_set: array has %d elementds", count));
          for (int j = 0; j < count; ++j) {
            SV** svp = av_fetch(arr, j, 0);
            if (SvIOK(*svp) || SvNOK(*svp) || SvPOK(*svp)) {
              STRLEN slen;
              const char* elem = SvPV(*svp, slen);
              hlist_add_header(h, translate_underscore,
                               name, elem);
              GLOG(("=X= header_set: added value %d [%s]", j, elem));
            }
          }
        }
      }
    }

    /* We now can put in the return stack all the original values */
    count = slist_size(t);
    if (count <= 0) {
      GLOG(("=X= header_set: empty values"));
      XSRETURN_EMPTY;
    }

    GLOG(("=X= header_set: returning %d values", count));
    EXTEND(SP, count);
    n = t->head;
    while (n) {
      int last = n == t->tail;
      /* TODO: This can probably be optimised A LOT*/
      GLOG(("=X= header_set: returning [%s]", n->str));
      PUSHs(sv_2mortal(newSVpv(n->str, 0)));
      if (last) {
        n = 0;
        break;
      }
      n = n->nxt;
    }

    GLOG(("=X= header_set: now erasing the %d values for %p", count, t));
    slist_destroy(t);
    GLOG(("=X= header_set: finished erasing the %d values", count));

void
hhf_hlist_header_remove(unsigned long nh, int translate_underscore, const char* name)

  PREINIT:
    HList* h = 0;
    SList* s = 0;
    SList* t = 0;
    SNode* n = 0;

  PPCODE:
    h = (HList*) nh;
    GLOG(("=X= HEADER_REMOVE(%p, %d, %s)", h, translate_underscore, name));

    /* We look for the current values for the header and keep a reference to them */
    s = hlist_get_header(h, translate_underscore,
                         name);
    int count = slist_size(s);
    GLOG(("=X= header_remove: will later return %d values", count));
    if (count) {
        GLOG(("=X= header_remove: making a copy of current values"));
        t = slist_clone(s);

        /* Erase what is already there for this header */
        hlist_del_header(h, translate_underscore,
                         name);
        GLOG(("=X= header_remove: deleted key [%s]", name));
    }

    /* We now can put in the return stack all the original values */
    count = slist_size(t);
    if (count <= 0) {
      GLOG(("=X= header_set: empty values"));
      XSRETURN_EMPTY;
    }

    GLOG(("=X= header_remove: returning %d values", count));
    EXTEND(SP, count);
    n = t->head;
    while (n) {
      int last = n == t->tail;
      /* TODO: This can probably be optimised A LOT*/
      GLOG(("=X= header_remove: returning [%s]", n->str));
      PUSHs(sv_2mortal(newSVpv(n->str, 0)));
      if (last) {
        n = 0;
        break;
      }
      n = n->nxt;
    }

    GLOG(("=X= header_remove: now erasing the %d values for %p", count, t));
    slist_destroy(t);
    GLOG(("=X= header_remove: finished erasing the %d values", count));


void
hhf_hlist_header_names(unsigned long nh)

  PREINIT:
    HList* h = 0;
    HNode* n = 0;

  PPCODE:
    h = (HList*) nh;
    GLOG(("=X= HEADER_NAMES(%p)", h));

    int count = hlist_size(h);
    if (count <= 0) {
      GLOG(("=X= header_names: empty values"));
      XSRETURN_EMPTY;
    }

    GLOG(("=X= header_names: returning %d values", count));
    EXTEND(SP, count);
    n = h->head;
    while (n) {
      int last = n == h->tail;
      /* TODO: This can probably be optimised A LOT*/
      GLOG(("=X= header_names: returning [%s]", n->canonical_name));
      PUSHs(sv_2mortal(newSVpv(n->canonical_name, 0)));
      if (last) {
        n = 0;
        break;
      }
      n = n->nxt;
    }


void*
hhf_hlist_clone(unsigned long nh)

  PREINIT:
    HList* h = 0;
    HList* t = 0;

  CODE:
    h = (HList*) nh;
    GLOG(("=X= CLONE(%p)", h));

    t = hlist_clone(h);
    GLOG(("=X= CLONE(%p) => %p", h, t));

    RETVAL = t;

  OUTPUT: RETVAL
