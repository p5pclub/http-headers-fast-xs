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

    /* make a copy to represent the original one */
    orig = (char *) alloca(len + 1);

    /* copy and lc */
    for ( i = 0; i < len; i++ ) {
        orig[i] = field[i];
        field[i] = tolower( field[i] );
    }

    orig[len] = '\0';

    /* if we already have a value in the hash table, nothing to do */
    standard_case_val = hv_fetch(
        MY_CXT.standard_case, field, len, 1
    );

    if (!standard_case_val)
        croak("hv_fetch() failed. This should not happen.");

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
    if ( !hv_exists(self, field, len) ) {
        return NULL;
    }

    h = hv_fetch(self, field, len, 0);
    if (h == NULL)
        croak("hv_fetch() failed. This should not happen.");

    return *h;
}

/* Returns if we store that field name or not */
bool put_header_value_on_perl_stack(pTHX_ SV *self, char *field, STRLEN len) {
    dSP;
    AV   *val_array;
    SV   *value, **val_array_elem;
    int  top_index, i;

    value = get_header_value(aTHX_ (HV *) SvRV(self), field, len);

    if (value == NULL)
        return false;

    if ( SvROK(value) && SvTYPE( SvRV(value) ) == SVt_PVAV ) {
        /* If the value is an array, put all the values of the array on stack.
         * This will return @$h to perl */
        val_array = (AV *) SvRV(value);
        top_index = av_len(val_array);
        EXTEND(SP, top_index);

        for (i = 0; i <= top_index; i++) {
            val_array_elem = av_fetch(val_array, i, 0);

            if (val_array_elem == NULL)
                croak("av_fetch() failed. This should not happen.");

            PUSHs(sv_2mortal(newSVsv(*val_array_elem)));
        }
    } else {
        /* If we have one value, just put it on stack. This will return ($h) to perl */
        EXTEND(SP, 1);
        PUSHs(sv_2mortal(newSVsv(value)));
    }

    /* put the local SP in THX -> SP was EXTENDED */
    PUTBACK;
    return true;
}

void __push_header(pTHX_  HV *self, char *field, STRLEN len, SV *val) {
    SV  **h;
    AV  *h_copy;
    SV  **a_value;
    int i, top_index;

    h = hv_fetch( self, field, len, 1 );
    if ( h == NULL )
        croak("hv_fetch() failed. This should not happen.");

    if ( ! SvOK(*h) ) {
        *h = newRV_noinc( (SV *) newAV() );
    } else if ( ! SvROK(*h) || SvTYPE( SvRV(*h) ) != SVt_PVAV ) {
        h_copy = av_make( 1, h );
        *h = newRV_noinc( (SV *)h_copy );
    }

    if ( SvROK(val) && SvTYPE( SvRV(val) ) == SVt_PVAV ) {
        h_copy = (AV *) SvRV(val);
        top_index = av_len(h_copy);

        for ( i = 0; i <= top_index; i++ ) {
            a_value = av_fetch( h_copy, i, 0 );
            if (a_value)
                av_push( (AV *) SvRV(*h), *a_value );
        }
    } else {
        av_push( (AV *) SvRV(*h), val );
    }
}

void set_header(pTHX_ HV *self, char *field, int len, SV *val) {
    SV **val_0;

    /* av_len == 0 here means that we have one item in av */
    if ( SvROK(val) &&
         SvTYPE( SvRV(val) ) == SVt_PVAV &&
         av_len( (AV *)SvRV(val) ) == 0 )
    {
        val_0 = av_fetch( (AV *)SvRV(val), 0, 0 );
        val = *val_0;
    }
    hv_store(self, field, len, newSVsv(val), 0);
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
        int    i;
        STRLEN len;
        char   *field;
        SV     *val;
    CODE:
        if ( items % 2 == 0 )
            croak("You must provide key/value pairs");

        for ( i = 1; i < items; i += 2 ) {
            field = SvPV(ST(i), len);
            val   = newSVsv( ST( i + 1 ) );

            handle_standard_case(aTHX_ field, len);

            __push_header(aTHX_ (HV *) SvRV(self), field, len, val);
       }


void
_header_get( SV *self, SV *field_name, ... )
    PREINIT:
        char   *field;
        STRLEN len;
        bool   skip_standardize;
    PPCODE:
        field = SvPV(field_name, len);
        skip_standardize = ( items == 3 ) && SvTRUE(ST(3));
        if (!skip_standardize)
            handle_standard_case(aTHX_ field, len);

        /* we are putting the decremented(with the number of input parameters) SP back in the THX */
        PUTBACK;

        put_header_value_on_perl_stack(aTHX_ self, field, len);

        /* we are setting the local SP variable to the value in THX(it was changed inside the previous function call) */
        SPAGAIN;


void
_header_set(SV *self, SV *field_name, SV *val)
    PREINIT:
        char   *field;
        STRLEN len;
        bool   found;
    PPCODE:
        field = SvPV(field_name, len);

        handle_standard_case(aTHX_ field, len);

        /* we are putting the decremented(with the number of input parameters) SP back in the THX */
        PUTBACK;

        found = put_header_value_on_perl_stack(aTHX_ self, field, len);

        /* we are setting the local SP variable to the value in THX */
        SPAGAIN;

        if (!SvOK(val) && found) {
            hv_delete((HV *) SvRV(self), field, len, G_DISCARD);
        } else {
            set_header(aTHX_ (HV *)SvRV(self), field, len, val);
        }

void
_header_push(SV *self, SV *field_name, SV *val)
    PREINIT:
        char   *field;
        STRLEN len;
    PPCODE:
        field = SvPV(field_name, len);

        handle_standard_case(aTHX_ field, len);

        /* we are putting the decremented (with the number of
        input parameters) SP back in the THX */
        PUTBACK;

        put_header_value_on_perl_stack(aTHX_ self, field, len);

        /* we are setting the local SP variable to the value in THX */
        SPAGAIN;

        __push_header(aTHX_ (HV *) SvRV(self), field, len, newSVsv(val));
