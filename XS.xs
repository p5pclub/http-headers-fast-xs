#define PERL_NO_GET_CONTEXT     /* we want efficiency */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include "hlist.h"

MODULE = HTTP::Headers::Fast::XS		PACKAGE = HTTP::Headers::Fast::XS
PROTOTYPES: DISABLE


void*
hhf_hlist_create()

  PREINIT:
    HList* h = 0;

  CODE:
    h = hlist_create();
    fprintf(stderr, "=C= created hlist %p\n", h);
    RETVAL = (void*) h;

  OUTPUT: RETVAL


void
hhf_hlist_destroy(unsigned long nh)

  PREINIT:
    HList* h = 0;

  CODE:
    h = (HList*) nh;
    fprintf(stderr, "=C= destroying hlist %p\n", h);
    hlist_unref(h);


void
hhf_hlist_clear(unsigned long nh)

  PREINIT:
    HList* h = 0;

  CODE:
    fprintf(stderr, "=C= clearing hlist %p\n", h);
    h = (HList*) nh;
    hlist_clear(h);


void
hhf_header_get(unsigned long nh, const char* name)

  PREINIT:
    HList* h = 0;
    SList* s = 0;

  PPCODE:
    h = (HList*) nh;
    fprintf(stderr, "=C= header_get hlist %p\n", h);

    fprintf(stderr, "=C= header_get: name=[%s]\n", name);
    s = hlist_get_header(h, name);
    int count = s ? slist_size(s) : 0;
    if (count <= 0) {
      fprintf(stderr, "=C= header_get: empty values\n");
      return;
    }
    fprintf(stderr, "=C= header_get: returning %d values\n", count);
    EXTEND(SP, count);
    for (; s != 0; s = s->nxt) {
      if (!s->str) {
        continue;
      }

      /* TODO: This can probably be optimised A LOT*/
      fprintf(stderr, "=C= header_get: returning [%s]\n", s->str);
      PUSHs(sv_2mortal(newSVpv(s->str, 0)));
    }


void
hhf_header_set(unsigned long nh, int new_only, int keep_previous, const char* name, SV* val)

  PREINIT:
    HList* h = 0;
    SList* s = 0;
    SList* t = 0;
    AV* arr = 0;
    int count = 0;

  PPCODE:
    h = (HList*) nh;
    fprintf(stderr, "=C= HEADER_SET(%p, %d, %d, %s, %p)\n", h, new_only, keep_previous, name, val);

    fprintf(stderr, "=C= header_set: name=[%s]\n", name);
    /* We look for the current values for the header and keep a reference to them */
    s = hlist_get_header(h, name);
    count = s ? slist_size(s) : 0;
    fprintf(stderr, "=C= header_set: will later return %d values\n", count);
    if (s) {
      if (new_only) {
        /* header should not have existed before */
        fprintf(stderr, "=C= header_set: tried to init already-existing header, bye\n");
        return;
      }

      if (keep_previous) {
        /* Make a deep copy of the current value */
        fprintf(stderr, "=C= header_set: making a deep copy\n");
        t = slist_clone(s);
      } else {
        /* Make a shallow copy of the current value */
        fprintf(stderr, "=C= header_set: making a shallow copy\n");
        t = slist_ref(s);

        /* Erase what is already there for this header */
        hlist_del_header(h, name);
        fprintf(stderr, "=C= header_set: deleted key [%s]\n", name);
      }
    }

    /* hlist_new_header(h, name, 0); */
    /* fprintf(stderr, "=C= header_set: added key [%s]\n", name); */

    if (val) {

      /* Scalar? Just convert it to string. */
      if (SvIOK(val) || SvNOK(val) || SvPOK(val)) {
        STRLEN slen;
        const char* elem = SvPV(val, slen);
        hlist_add_header(h, name, elem);
        fprintf(stderr, "=C= header_set: added single value [%s]\n", elem);
      }

      /* Reference? */
      if (SvROK(val)) {
        fprintf(stderr, "=C= header_set: is a ref\n");
        SV* deref = (SV*) SvRV(val);
        if (SvTYPE(deref) == SVt_PVAV) {
          fprintf(stderr, "=C= header_set: is an arrayref\n");
          arr = (AV*) SvRV(val);

          /* Add each element in val as a value for name. */
          count = av_len(arr) + 1;
          fprintf(stderr, "=C= header_set: array has %d elementds\n", count);
          for (int j = 0; j < count; ++j) {
            SV** svp = av_fetch(arr, j, 0);
            if (SvIOK(*svp) || SvNOK(*svp) || SvPOK(*svp)) {
              STRLEN slen;
              const char* elem = SvPV(*svp, slen);
              hlist_add_header(h, name, elem);
              fprintf(stderr, "=C= header_set: added value %d [%s]\n", j, elem);
            }
          }
        }
      }
    }

    /* We now can put in the return stack all the original values */
    count = t ? slist_size(t) : 0;
    fprintf(stderr, "=C= header_set: returning %d values\n", count);
    EXTEND(SP, count);
    for (s = t; s != 0; s = s->nxt) {
      if (!s->str) {
        continue;
      }

      /* TODO: This can probably be optimised A LOT*/
      fprintf(stderr, "=C= header_set: returning [%s]\n", s->str);
      PUSHs(sv_2mortal(newSVpv(s->str, 0)));
    }

    fprintf(stderr, "=C= header_set: now erasing the %d values for %p\n", count, t);
    slist_unref(t);
    fprintf(stderr, "=C= header_set: finished erasing the %d values\n", count);


void
hhf_header_remove(unsigned long nh, const char* name)

  PREINIT:
    HList* h = 0;
    SList* s = 0;
    SList* t = 0;
    int count = 0;

  PPCODE:
    h = (HList*) nh;
    fprintf(stderr, "=C= HEADER_REMOVE(%p, %s)\n", h, name);

    /* We look for the current values for the header and keep a reference to them */
    s = hlist_get_header(h, name);
    count = s ? slist_size(s) : 0;
    fprintf(stderr, "=C= header_remove: will later return %d values\n", count);
    if (s) {
        fprintf(stderr, "=C= header_remove: making a shallow copy\n");
        t = slist_ref(s);

        /* Erase what is already there for this header */
        hlist_del_header(h, name);
        fprintf(stderr, "=C= header_remove: deleted key [%s]\n", name);
    }

    /* We now can put in the return stack all the original values */
    count = t ? slist_size(t) : 0;
    fprintf(stderr, "=C= header_remove: returning %d values\n", count);
    EXTEND(SP, count);
    for (s = t; s != 0; s = s->nxt) {
      if (!s->str) {
        continue;
      }

      /* TODO: This can probably be optimised A LOT*/
      fprintf(stderr, "=C= header_remove: returning [%s]\n", s->str);
      PUSHs(sv_2mortal(newSVpv(s->str, 0)));
    }

    fprintf(stderr, "=C= header_remove: now erasing the %d values for %p\n", count, t);
    slist_unref(t);
    fprintf(stderr, "=C= header_remove: finished erasing the %d values\n", count);


void
hhf_header_names(unsigned long nh)

  PREINIT:
    HList* h = 0;
    HList* t = 0;

  PPCODE:
    h = (HList*) nh;
    fprintf(stderr, "=C= HEADER_NAMES(%p)\n", h);

    for (t = h; t != 0; t = t->nxt) {
      if (!t->name) {
        continue;
      }

      EXTEND(SP, 1);

      /* TODO: This can probably be optimised A LOT*/
      fprintf(stderr, "=C= header_names: returning [%s]\n", t->canonical_name);
      PUSHs(sv_2mortal(newSVpv(t->canonical_name, 0)));
    }
