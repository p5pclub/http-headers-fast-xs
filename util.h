#ifndef UTIL_H_
#define UTIL_H_

/*
 * Utility functions called from our XSUB.
 */

#include "hlist.h"
#include "plist.h"

// Clone an object, either from its class or from an existing object; put a
// clone of old_list (if any) as the initial values for the cloned object.
SV* clone_from(pTHX, SV* klass, SV* self, HList* old_list);

// Set the value for a given header; call recursively into set_scalar and
// set_array, depending of whether pval is a scalar or an array.
void set_value(pTHX, HList* h, const char* ckey, SV* pval);
void set_scalar(pTHX, HList* h, const char* ckey, SV* pval);
void set_array(pTHX, HList* h, const char* ckey, AV* pval);

// Return to Perl all values in an object.
void return_hlist(pTHX, HList* list, const char* func, int want);

// Return to Perl all values for a given key.
void return_plist(pTHX, PList* list, const char* func, int want);

// Format all values in a given object, as a string, into str, using endl as
// end of line separator; if sort is true, sort key names before.
char* format_all(pTHX, HList* h, int sort, const char* endl, int* size);

#endif
