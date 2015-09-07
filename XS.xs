#define PERL_NO_GET_CONTEXT     /* we want efficiency */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include <string.h>

#define MY_CXT_KEY "HTTP::Headers::Fast::XS::_guts" XS_VERSION

typedef struct {
    HV *standard_case;
    SV **translate;
} my_cxt_t;

START_MY_CXT;

void translate_underscore(pTHX_ char *field, int len) {
    dMY_CXT;
    int i;
    SV *translate = GvSV( *MY_CXT.translate );

    if (!translate || field[0] == ':')
        croak("$TRANSLATE_UNDERSCORE variable does not exist");

    if ( !SvOK(translate) || !SvTRUE(translate) )
        return;

    for ( i = 0; i < len; i++ )
        if ( field[i] == '_' )
            field[i] = '-';
}

void handle_standard_case(pTHX_ char *field, int len) {
    dMY_CXT;
    char *orig;
    bool word_boundary;
    int  i;
    SV   **standard_case_val;

    /* leading ':' means "don't standardize" */
    if ( field[0] == ':' ) {
        return;
    }

    translate_underscore(aTHX_ field, len);

    /* make a copy to represent the original one and lc the original */
    orig = (char *) alloca(len + 1);
    for ( i = 0; i < len; i++ ) {
        orig[i]  = field[i];
        field[i] = tolower( field[i] );
    }
    orig[len] = '\0';

    standard_case_val = hv_fetch(MY_CXT.standard_case, field, len, 1);
    if (standard_case_val == NULL)
        croak("hv_fetch() failed. This should not happen.");

    /* if we already have a value in the hash table, nothing to do */
    if ( SvOK(*standard_case_val) )
        return;

    /* uc first char after word boundary */
    word_boundary = true;
    for (i = 0; i < len; i++ ) {
        if (word_boundary) {
            orig[i] = toupper( orig[i] );
        }
        word_boundary = !isWORDCHAR( orig[i] );
    }

    /* save result in hash table */
    *standard_case_val = newSVpv( orig, len );
}

SV* get_header_value(pTHX_ HV *self, char *field, STRLEN len) {
    SV **h;

    /* check if field has a value */
    if ( !hv_exists(self, field, len) )
        return NULL;

    h = hv_fetch(self, field, len, 0);
    if (h == NULL)
        croak("hv_fetch() failed. This should not happen.");

    if ( SvROK(*h) )
        return *h;
    else
        return newSVsv(*h);
}

void set_header_value(pTHX_ HV *self, char *field, int len, SV *val) {
    SV **val_0;

    /* if array has a single element, then store that element instead of the array */
    if (SvROK(val) &&
        !sv_isobject(val) &&
        SvTYPE(SvRV(val)) == SVt_PVAV &&
        av_len((AV *) SvRV(val)) == 0)
    {
        val_0 = av_fetch( (AV *)SvRV(val), 0, 0 );
        if (val_0 == NULL)
            croak("av_fetch() failed. This should not happen.");

        val = *val_0;
    }
    hv_store(self, field, len, newSVsv(val), 0);
}

void push_header_value(pTHX_  HV *self, char *field, STRLEN len, SV *val) {
    AV  *array;
    SV  **h, **array_elem;
    int i, top_index;

    h = hv_fetch( self, field, len, 1 );
    if ( h == NULL )
        croak("hv_fetch() failed. This should not happen.");

    if ( ! SvOK(*h) ) {
        *h = newRV_noinc( (SV *) newAV() );
    } else if ( ! SvROK(*h) || SvTYPE(SvRV(*h)) != SVt_PVAV || sv_isobject(*h) ) {
        array = newAV();
        av_store(array, 0, *h); /* don't increment ref count */
        *h = newRV_noinc((SV *) array);
    }

    if ( SvROK(val) && SvTYPE(SvRV(val)) == SVt_PVAV && !sv_isobject(val) ) {
        array = (AV *) SvRV(val);
        top_index = av_len(array);

        for ( i = 0; i <= top_index; i++ ) {
            array_elem = av_fetch(array, i, 0);
            if (array_elem == NULL)
                croak("av_fetch() failed. This should not happen.");

            av_push( (AV *) SvRV(*h), newSVsv(*array_elem) );
        }
    } else {
        av_push( (AV *) SvRV(*h), newSVsv(val) );
    }
}

int put_array_values_on_perl_stack(pTHX_ AV *array) {
    dSP;
    int i, count;
    SV  **array_elem;

    count = av_len(array) + 1;
    EXTEND(SP, count);

    for (i = 0; i < count; i++) {
        array_elem = av_fetch(array, i, 0);
        if (array_elem == NULL)
            croak("av_fetch() failed. This should not happen.");

        PUSHs(sv_2mortal(newSVsv(*array_elem)));
    }
    return count;
}

/* Returns if we store that field name or not */
int put_header_value_on_perl_stack(pTHX_ SV *self, char *field, STRLEN len) {
    dSP;
    int count;
    SV  *value;

    value = get_header_value(aTHX_ (HV *) SvRV(self), field, len);

    if (value == NULL)
        return 0;

    if (SvROK(value) && (SvTYPE(SvRV(value)) == SVt_PVAV) && !sv_isobject(value)) {
        /* If the value is an array, put all the values of the array on stack.
         * This will return @$h to perl */
        count = put_array_values_on_perl_stack((AV *) SvRV(value));
    } else {
        /* If we have one value, just put it on stack. This will return ($h) to perl */
        PUSHs(sv_2mortal(newSVsv(value)));
        count = 1;
    }
    return count;
}

SV * join(pTHX_ AV *values) {
    int    i, top_index;
    char   *str;
    SV     **element, *joined;

    top_index = av_len(values);
    joined    = newSVpv("", 0);

    for (i = 0; i <= top_index; i++) {
        element = av_fetch(values, i, 0);
        if (element == NULL)
            croak("av_fetch() failed. This should not happen.");

        str = SvPV_nolen(*element);
        if (i == 0)
            sv_catpv(joined, str);
        else
            sv_catpvf(joined, ", %s", str);
    }
    return joined;
}

MODULE = HTTP::Headers::Fast::XS		PACKAGE = HTTP::Headers::Fast::XS
PROTOTYPES: DISABLE

BOOT:
{
    MY_CXT_INIT;
    MY_CXT.standard_case = get_hv( "HTTP::Headers::Fast::standard_case", 0 );
    MY_CXT.translate     = hv_fetch(
        gv_stashpvn( "HTTP::Headers::Fast", 19, 0 ),
        "TRANSLATE_UNDERSCORE",
        20,
        0
    );
}

char *
_standardize_field_name(SV *field)
    PREINIT:
        char   *field_name;
        STRLEN len;
    CODE:
        field_name = SvPV(field, len);
        handle_standard_case(aTHX_ field_name, len);
        RETVAL = field_name;
    OUTPUT: RETVAL

void
push_header( SV *self, ... )
    PREINIT:
        char   *field;
        int    i;
        STRLEN len;
    CODE:
        if ( items % 2 == 0 )
            croak("You must provide key/value pairs");

        for ( i = 1; i < items; i += 2 ) {
            field = SvPV(ST(i), len);
            handle_standard_case(aTHX_ field, len);
            push_header_value(aTHX_ (HV *) SvRV(self), field, len, ST(i + 1));
       }

void
header(SV *self, ...)
    PREINIT:
        char   *field;
        int    arg, count;
        STRLEN len;
        SV     *args[items], *value;
        HV     *seen, *self_hash;
    PPCODE:
        if (items <= 1)
            croak("Usage: $h->header($field, ...)");

        /* check if we can skip preparing the results */
        self_hash = (HV *) SvRV(self);

        if (items == 2) {
            /* @old = $self->_header_get(@_) */
            field = SvPV(ST(1), len);
            handle_standard_case(aTHX_ field, len);
            value = get_header_value(aTHX_ self_hash, field, len);
        } else if (items == 3) {
            /* @old = $self->_header_set(@_) */
            field = SvPV(ST(1), len);
            handle_standard_case(aTHX_ field, len);
            value = get_header_value(aTHX_ self_hash, field, len);

            if ( SvOK(ST(2)) )
                set_header_value(aTHX_ self_hash, field, len, ST(2));
            else if (value != NULL)
                /* delete only if there is something to delete */
                hv_delete(self_hash, field, len, G_DISCARD);

        } else {
            /* save the args from the stack since _header_push()
             * might overwrite them with results */
            for (arg = 1; arg < items; arg++)
                args[arg] = ST(arg);

            seen = newHV();
            for (arg = 1; arg < items; arg += 2) {
                field = SvPV(args[arg], len);
                handle_standard_case(aTHX_ field, len); /* lc $field */

                if ( !hv_exists(seen, field, len) ) {
                    hv_store(seen, field, len, newSViv(1), 0);

                    /* @old = $self->_header_set($field, shift) */
                    value = get_header_value(aTHX_ self_hash, field, len);
                    if ( SvOK(args[arg + 1]) )
                        set_header_value(aTHX_ self_hash, field, len, args[arg + 1]);
                    else if (value != NULL)
                        /* delete only if there is something to delete */
                        hv_delete(self_hash, field, len, G_DISCARD);

                } else {
                    /* @old = $self->_header_push($field, shift) */
                    value = get_header_value(aTHX_ self_hash, field, len);
                    push_header_value(aTHX_ self_hash, field, len, args[arg + 1]);
                }
            }
        }

        if (GIMME_V == G_VOID)
            XSRETURN_EMPTY;

        if (value == NULL) {
            /* return wantarray ? () : undef */
            if (GIMME_V == G_ARRAY)
                XSRETURN_EMPTY;
            else
                XSRETURN_UNDEF;
        }

        if (SvROK(value) && (SvTYPE(SvRV(value)) == SVt_PVAV) && !sv_isobject(value)) {
            if (GIMME_V == G_ARRAY) {
                /* return @old */
                PUTBACK;
                count = put_array_values_on_perl_stack((AV *) SvRV(value));
                SPAGAIN;

                XSRETURN(count);
            } else {
                /* return join( ', ', @old ) */
                value = join(aTHX_ (AV *) SvRV(value));
                PUSHs(sv_2mortal(value));
                XSRETURN(1);
            }
        } else {
            /* return $old[0] */
            PUSHs(sv_2mortal(newSVsv(value)));
            XSRETURN(1);
        }

void
_header_get( SV *self, SV *field_name, ... )
    PREINIT:
        bool   skip_standardize;
        char   *field;
        STRLEN len;
    PPCODE:
        field = SvPV(field_name, len);

        skip_standardize = (items == 3) && SvTRUE(ST(3));
        if (!skip_standardize)
            handle_standard_case(aTHX_ field, len);

        /* we are putting the decremented(with the number of input parameters) SP back in the THX */
        PUTBACK;

        XSRETURN( put_header_value_on_perl_stack(aTHX_ self, field, len) );

void
_header_set(SV *self, SV *field_name, SV *val)
    PREINIT:
        char   *field;
        int    count;
        STRLEN len;
    PPCODE:
        field = SvPV(field_name, len);

        handle_standard_case(aTHX_ field, len);

        /* we are putting the decremented(with the number of input parameters) SP back in the THX */
        PUTBACK;

        count = put_header_value_on_perl_stack(aTHX_ self, field, len);

        /* we are setting the local SP variable to the value in THX */
        SPAGAIN;

        if ( SvOK(val) )
            set_header_value(aTHX_ (HV *)SvRV(self), field, len, val);
        else if (count)
            /* delete only if there is something to delete */
            hv_delete((HV *) SvRV(self), field, len, G_DISCARD);

        XSRETURN(count);
