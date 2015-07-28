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

#define TRANSLATE_UNDERSCORE(field,len)                                   \
    STMT_START {                                                          \
        /* underscores to dashes */                                       \
        translate_underscore = GvSV( *MY_CXT.translate );                 \
                                                                          \
        if (!translate_underscore)                                        \
            croak("$translate_underscore variable does not exist");       \
                                                                          \
        if ( SvOK(translate_underscore) && SvTRUE(translate_underscore) ) \
            for ( i = 0; i < len; i++ )                                   \
                if ( field[i] == '_' )                                    \
                    field[i] = '-';                                       \
    } STMT_END;

#define HANDLE_STANDARD_CASE( field, len )                       \
    STMT_START {                                                 \
        /* make a copy to represent the original one */          \
        orig = (char *) alloca(len);                             \
        my_strlcpy( orig, field, len + 1 );                      \
                                                                 \
        /* lc */                                                 \
        for ( i = 0; i < len; i++ )                              \
            field[i] = tolower( field[i] );                      \
                                                                 \
        /* uc first char after word boundary */                  \
        standard_case_val = hv_fetch(                            \
            MY_CXT.standard_case, field, len, 1                  \
        );                                                       \
                                                                 \
        if (!standard_case_val)                                  \
            croak("hv_fetch() failed. This should not happen."); \
                                                                 \
        if ( !SvOK(*standard_case_val) ) {                       \
            word_boundary = true;                                \
                                                                 \
            for (i = 0; i < len; i++ ) {                         \
                if ( ! isWORDCHAR( orig[i] ) ) {                 \
                    word_boundary = true;                        \
                    continue;                                    \
                }                                                \
                                                                 \
                if (word_boundary) {                             \
                    orig[i] = toupper( orig[i] );                \
                    word_boundary = false;                       \
                }                                                \
            }                                                    \
                                                                 \
            *standard_case_val = newSVpv( orig, len );           \
        }                                                        \
    } STMT_END;

char *
_standardize_field_name( char *field )
    PREINIT:
        SV   *translate_underscore;
        SV   **standard_case_val;
        char *orig;
        int  i;
        int  len;
        bool word_boundary;
        dMY_CXT;
    CODE:
        len = strlen(field);
        TRANSLATE_UNDERSCORE(field, len);
        HANDLE_STANDARD_CASE(field, len);
        RETVAL = field;
    OUTPUT: RETVAL

void
push_header( SV *self, ... )
    PREINIT:
        /* variables for standardization */
        SV   *translate_underscore;
        SV   **standard_case_val;
        char *orig;
        int  i;
        int  len;
        bool word_boundary;
        dMY_CXT;

        char *field;
        SV   *val;
        SV   **h;
        SV   **a_value;
        AV   *h_copy;
        int  top_index;
    CODE:
        if ( items % 2 == 0 )
            croak("You must provide key/value pairs");

        for ( i = 1; i < items; i += 2 ) {
            field = SvPVX( ST(i) );
            val   = newSVsv( ST( i + 1 ) );
            len   = SvCUR( ST(i) );

            /* leading ':' means "don't standardize" */
            if ( field[0] != ':' ) {
                TRANSLATE_UNDERSCORE(field, len);
                HANDLE_STANDARD_CASE(field, len);
            }

            h = hv_fetch( (HV *) SvRV(self), field, len, 1 );
            if ( h == NULL )
                croak("hv_fetch() failed. This should not happen."); \

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
