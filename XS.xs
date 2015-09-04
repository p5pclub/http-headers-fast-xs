#define PERL_NO_GET_CONTEXT     /* we want efficiency */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include "glog.h"
#include "util.h"
#include "header.h"

#define HLIST_KEY_STR "hlist"

static HList* fetch_hlist(pTHX, SV* self) {
  HList* h;

  h = (HList*) SvIV(*hv_fetch((HV*) SvRV(self),
                              HLIST_KEY_STR, sizeof(HLIST_KEY_STR) - 1, 0));
  return h;
}


MODULE = HTTP::Headers::Fast::XS        PACKAGE = HTTP::Headers::Fast::XS
PROTOTYPES: DISABLE


#################################################################


SV *
new( SV* klass, ... )
  PREINIT:
  PREINIT:
    SV*    self = 0;
    HList* h = 0;
    int    j;
    SV*    pkey;
    SV*    pval;
    char*  ckey;

  CODE:
    if ( ( items - 1 ) % 2 )
        croak("Expecting a hash as input to constructor");

    GLOG(("=X= @@@ new()"));
    self = clone_from(aTHX, klass, 0, 0);
    h = fetch_hlist(aTHX, self);

    /* create the initial list */
    for (j = 1; j < items; ) {
        pkey = ST(j++);

        /* did we reach the end by any chance? */
        if (j == items) {
          break;
        }

        pval = ST(j++);
        ckey = SvPV_nolen(pkey);
        GLOG(("=X= Will set [%s] to [%s]", ckey, SvPV_nolen(pval)));
        set_value(aTHX, h, ckey, pval);
    }

    RETVAL = self;

  OUTPUT: RETVAL


SV *
clone( SV* self )
  PREINIT:
    HList* h = 0;

  CODE:
    h = fetch_hlist(aTHX, self);
    GLOG(("=X= @@@ clone(%p|%d)", h, hlist_size(h)));
    RETVAL = clone_from(aTHX, 0, self, h);

  OUTPUT: RETVAL


#
# Object's destructor, called automatically
#
void
DESTROY(SV* self, ...)
  PREINIT:
    HList* h = 0;
    int    j;
    int    k;

  CODE:
    h = fetch_hlist(aTHX, self);
    GLOG(("=X= @@@ destroy(%p|%d)", h, hlist_size(h)));

    for (j = 0; j < h->ulen; ++j) {
      HNode* hn = &h->data[j];
      PList* pl = hn->values;
      for (k = 0; k < pl->ulen; ++k) {
        PNode* pn = &pl->data[k];
        sv_2mortal( (SV*) pn->ptr );
      }
    }

    hlist_destroy(h);


#
# Clear object, leaving it as freshly created.
#
void
clear(SV* self, ...)
  PREINIT:
    HList* h = 0;

  CODE:
    h = fetch_hlist(aTHX, self);
    GLOG(("=X= @@@ clear(%p|%d)", h, hlist_size(h)));
    hlist_clear(h);


#
# Get all the keys in an existing HList.
#
void
header_field_names(SV* self)
  PREINIT:
    HList* h = 0;

  PPCODE:
    h = fetch_hlist(aTHX, self);
    GLOG(("=X= @@@ header_field_names(%p|%d), want %d",
          h, hlist_size(h), GIMME_V));

    hlist_sort(h);
    PUTBACK;
    return_hlist(aTHX, h, "header_field_names", GIMME_V);
    SPAGAIN;


#
# Get all the keys in an existing HList.
#
void
_header_keys(SV* self)
  PREINIT:
    HList* h = 0;

  PPCODE:
    h = fetch_hlist(aTHX, self);
    GLOG(("=X= @@@ _header_keys(%p|%d), want %d",
          h, hlist_size(h), GIMME_V));

    PUTBACK;
    return_hlist(aTHX, h, "_header_keys", GIMME_V);
    SPAGAIN;


#
# init_header
#
void
init_header(SV* self, ...)
  PREINIT:
    int argc = 0;
    HList* h = 0;
    SV*    pkey;
    SV*    pval;
    STRLEN len;
    char*  ckey;

  CODE:
    argc = items - 1;
    if (argc != 2) {
      croak("init_header needs two arguments");
    }

    h = fetch_hlist(aTHX, self);
    GLOG(("=X= @@@ init_header(%p|%d), %d params, want %d",
          h, hlist_size(h), argc, GIMME_V));

    pkey = ST(1);
    ckey = SvPV(pkey, len);
    pval = ST(2);

    if (!hlist_get(h, ckey)) {
      set_value(aTHX, h, ckey, pval);
    }

#
# push_header
#
void
push_header(SV* self, ...)
  PREINIT:
    int argc = 0;
    HList* h = 0;
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

    h = fetch_hlist(aTHX, self);
    GLOG(("=X= @@@ push_header(%p|%d), %d params, want %d",
          h, hlist_size(h), argc, GIMME_V));

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
        set_value(aTHX, h, ckey, pval);
    }


#
# header
#
void
header(SV* self, ...)
  PREINIT:
    int argc = 0;
    HList* h = 0;
    int    j = 0;
    SV*    pkey;
    SV*    pval;
    STRLEN len;
    char*  ckey;
    HList* seen = 0;

  PPCODE:
    argc = items - 1;
    h = fetch_hlist(aTHX, self);
    GLOG(("=X= @@@ header(%p|%d), %d params, want %d",
          h, hlist_size(h), argc, GIMME_V));

    do {
      if (argc == 0) {
        croak("header called with no arguments");
        break;
      }

      if (argc == 1) {
        pkey = ST(1);
        ckey = SvPV(pkey, len);
        HNode* n = hlist_get(h, ckey);
        if (n && plist_size(n->values) > 0) {
          PUTBACK;
          return_plist(aTHX, n->values, "header1", GIMME_V);
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
          if (! hlist_get(seen, ckey)) {
            clear = 1;
            hlist_add(seen, ckey, 0);
          }

          HNode* n = hlist_get(h, ckey);
          if (n) {
            if (j > argc && plist_size(n->values) > 0) {
              /* Last value, return its current contents */
              PUTBACK;
              return_plist(aTHX, n->values, "header2", GIMME_V);
              SPAGAIN;
            }
            if (clear) {
              plist_clear(n->values);
            }
          }

          set_value(aTHX, h, ckey, pval);
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
    int    j = 0;
    SV*    pkey;
    STRLEN len;
    char*  ckey;
    int    size = 0;
    int    total = 0;

  PPCODE:
    argc = items - 1;
    h = fetch_hlist(aTHX, self);
    GLOG(("=X= @@@ remove_header(%p|%d), %d params, want %d",
          h, hlist_size(h), argc, GIMME_V));

    for (j = 1; j <= argc; ++j) {
      pkey = ST(j);
      ckey = SvPV(pkey, len);

      HNode* n = hlist_get(h, ckey);
      if (!n) {
        continue;
      }

      size = plist_size(n->values);
      if (size > 0) {
        total += size;
        if (GIMME_V == G_ARRAY) {
          PUTBACK;
          return_plist(aTHX, n->values, "remove_header", G_ARRAY);
          SPAGAIN;
        }
      }

      hlist_del(h, ckey);
      GLOG(("=X= remove_header: deleted key [%s]", ckey));
    }

    if (GIMME_V == G_SCALAR) {
      GLOG(("=X= remove_header: returning count %d", total));
      EXTEND(SP, 1);
      PUSHs(sv_2mortal(newSViv(total)));
    }


#
# remove_content_headers
#
SV*
remove_content_headers(SV* self, ...)
  PREINIT:
    HList* h = 0;
    SV*    extra = 0;
    HList* to = 0;
    int    j = 0;
    HNode* n = 0;

  CODE:
    h = fetch_hlist(aTHX, self);
    GLOG(("=X= @@@ remove_content_headers(%p|%d)",
          h, hlist_size(h)));

    extra = clone_from(aTHX, 0, self, 0);
    to = fetch_hlist(aTHX, extra);
    for (j = 0; j < h->ulen; ) {
      n = &h->data[j];
      if (! header_is_entity(n->header)) {
        ++j;
        continue;
      }
      hlist_transfer_header(h, j, to);
    }

    RETVAL = extra;

  OUTPUT: RETVAL


const char*
as_string(SV* self, ...)
  PREINIT:
    HList* h = 0;

  CODE:
    h = fetch_hlist(aTHX, self);
    GLOG(("=X= @@@ as_string(%p|%d) %d", h, hlist_size(h), items));

    const char* cendl = "\n";
    if ( items > 1 ) {
      SV* pendl = ST(1);
      cendl = SvPV_nolen(pendl);
    }
    char str[10240]; // TODO
    format_all(aTHX, h, 1, str, cendl);
    RETVAL = str;

  OUTPUT: RETVAL


const char*
as_string_without_sort(SV* self, ...)
  PREINIT:
    HList* h = 0;

  CODE:
    h = fetch_hlist(aTHX, self);
    GLOG(("=X= @@@ as_string_without_sort(%p|%d) %d", h, hlist_size(h), items));

    const char* cendl = "\n";
    if ( items > 1 ) {
      SV* pendl = ST(1);
      cendl = SvPV_nolen(pendl);
    }
    char str[10240]; // TODO
    format_all(aTHX, h, 0, str, cendl);
    RETVAL = str;

  OUTPUT: RETVAL


void
scan(SV* self, SV* sub)
  PREINIT:
    HList* h = 0;
    int    j;
    int    k;

  CODE:
    h = fetch_hlist(aTHX, self);
    GLOG(("=X= @@@ scan(%p|%d)", h, hlist_size(h)));

    hlist_sort(h);
    for (j = 0; j < h->ulen; ++j) {
      HNode* hn = &h->data[j];
      const char* header = hn->header->name;
      SV* pheader = newSVpv(header, 0);
      PList* pl = hn->values;
      for (k = 0; k < pl->ulen; ++k) {
        PNode* pn = &pl->data[k];
        SV* value = (SV*) pn->ptr;

        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        PUSHs( pheader );
        PUSHs( value );
        PUTBACK;
        call_sv( sub, G_DISCARD );

        FREETMPS;
        LEAVE;
      }
    }
