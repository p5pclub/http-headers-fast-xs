#ifndef UTIL_H_
#define UTIL_H_

#include "hlist.h"
#include "plist.h"

int string_append(char* buf, int pos, const char* str);
int string_cleanup(const char* str, char* buf, int len, const char* newl);

SV* clone_from(pTHX, SV* klass, SV* self, HList* old_list);

void set_scalar(pTHX, HList* h, const char* ckey, SV* pval);
void set_array(pTHX, HList* h, const char* ckey, AV* pval);
void set_value(pTHX, HList* h, const char* ckey, SV* pval);

int format_all(pTHX, HList* h, int sort, char* str, const char* endl);

void return_hlist(pTHX, HList* list, const char* func, int want);
void return_plist(pTHX, PList* list, const char* func, int want);

#endif
