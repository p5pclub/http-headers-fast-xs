#ifndef GSTR_H_
#define GSTR_H_

#define GSTR_MAX_FIXED_LENGTH 32

typedef struct GStr {
  char  buf[GSTR_MAX_FIXED_LENGTH];
  char* str;
  short alen;
  short ulen;
} GStr;

void gstr_init(GStr* gstr, const char* str, int len);
void gstr_clear(GStr* gstr);

#endif
