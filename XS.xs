#define PERL_NO_GET_CONTEXT     /* we want efficiency */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include <string.h>

#define MY_CXT_KEY "HTTP::Headers::Fast::XS::_guts" XS_VERSION

typedef struct {
    HV *cache;
    HV *standard_case;
    SV **translate;
} my_cxt_t;

START_MY_CXT;

MODULE = HTTP::Headers::Fast::XS		PACKAGE = HTTP::Headers::Fast::XS
PROTOTYPES: DISABLE

BOOT:
{
    MY_CXT_INIT;
    MY_CXT.cache         = newHV();
    MY_CXT.standard_case = get_hv( "HTTP::Headers::Fast::standard_case", 0 );
    MY_CXT.translate     = hv_fetch(
        gv_stashpvn( "HTTP::Headers::Fast", 19, 0 ),
        "TRANSLATE_UNDERSCORE",
        20,
        0
    );
}

char *
_standardize_field_name( char *field )
    PREINIT:
        SV   **cache_field;
        SV   *TRANSLATE_UNDERSCORE;
        SV   **standard_case_val;
        char *orig;
        int  i;
        int  len;
        bool word_boundary;
        dMY_CXT;
    CODE:
        /* underscores to dashes */
        TRANSLATE_UNDERSCORE = GvSV( *MY_CXT.translate );

        if (!TRANSLATE_UNDERSCORE)
            croak("$TRANSLATE_UNDERSCORE variable does not exist");

        len = strlen(field);
        if ( SvOK(TRANSLATE_UNDERSCORE) && SvTRUE(TRANSLATE_UNDERSCORE) )
            for ( i = 0; i < len; i++ )
                if ( field[i] == '_' )
                    field[i] = '-';

        /* check the cache */
        cache_field = hv_fetch( MY_CXT.cache, field, len, 0 );
        if ( cache_field && SvOK(*cache_field) ) {
            XSRETURN_PV( SvPV_nolen(*cache_field) );
            return;
        }

        /* make a copy to represent the original one */
        orig = (char *) malloc(len);
        my_strlcpy( orig, field, len + 1 );

        /* lc */
        for ( i = 0; i < len; i++ )
            field[i] = tolower( field[i] );

        /* uc first char after word boundary */
        standard_case_val = hv_fetch(
            MY_CXT.standard_case, field, len, 1
        );

        if (!standard_case_val)
            croak("hv_fetch() failed. This should not happen.");

        if ( !SvOK(*standard_case_val) ) {
            word_boundary = true;

            for (i = 0; i < len; i++ ) {
                if ( ! isWORDCHAR( orig[i] ) ) {
                    word_boundary = true;
                    continue;
                }

                if (word_boundary) {
                    orig[i] = toupper( orig[i] );
                    word_boundary = false;
                }
            }

            *standard_case_val = newSVpv( orig, len );
        }

        hv_store( MY_CXT.cache, orig, len, newSVpv(field,len), 0 );
        free(orig);
        RETVAL = field;
    OUTPUT: RETVAL
