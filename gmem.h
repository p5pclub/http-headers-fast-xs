#ifndef GMEM_H_
#define GMEM_H_

#include <stdlib.h>
#include <string.h>

#ifndef GMEM_CHECK

#define GMEM_NEW(scalar, type, size) \
  do { \
    scalar = (type) malloc(size); \
  } while (0)
#define GMEM_NEWARR(array, type, count, size)  \
  do { \
    array = (type) calloc(count, size); \
  } while (0)
#define GMEM_DEL(scalar, type, size) \
  do { \
    free(scalar); \
    scalar = 0; \
} while (0)
#define GMEM_DELARR(array, type, count, size) \
  do { \
    free(array); \
    array = 0; \
} while (0)
#define GMEM_STRNEW(tgt, src, len, ret) \
  do { \
    tgt = 0; \
    if (!src) { \
      ret = 0; \
      break; \
    } \
    int l = len <=0 ? strlen(src) + 1 : len; \
    GMEM_NEW(tgt, char*, l); \
    memcpy(tgt, src, l); \
    ret = l; \
  } while (0)
#define GMEM_STRDEL(str, len) \
  do { \
    if (!src) break; \
    int l = len <=0 ? strlen(src) + 1 : len; \
    GMEM_DEL(str, char*, l); \
    str = 0; \
  } while (0)

#else

#define GMEM_NEW(scalar, type, size) \
  do { \
    scalar = (type) malloc(size); \
    gmem_new_called(__FILE__, __LINE__, scalar, size, 1); \
  } while (0)
#define GMEM_NEWARR(array, type, count, size) \
  do { \
    array = (type) calloc(count, size); \
    gmem_new_called(__FILE__, __LINE__, array, size, count); \
  } while (0)
#define GMEM_DEL(scalar, type, size) \
  do { \
    gmem_del_called(__FILE__, __LINE__, scalar, size, 1); \
    free(scalar); \
    scalar = 0; \
  } while (0)
#define GMEM_DELARR(array, type, count, size)   \
  do { \
    gmem_del_called(__FILE__, __LINE__, array, size, count); \
    free(array); \
    array = 0; \
  } while (0)
#define GMEM_STRNEW(tgt, src, len, ret) \
  do { \
    ret = gmem_strnew(&tgt, src, len); \
  } while (0)
#define GMEM_STRDEL(str, len) \
  do { \
    gmem_strdel(&str, len); \
  } while (0)


extern long gmem_new;
extern long gmem_del;

int gmem_new_called(const char* file,
                    int line,
                    void* var,
                    long size,
                    int count);
int gmem_del_called(const char* file,
                    int line,
                    void* var,
                    long size,
                    int count);

int gmem_strnew(char** tgt,
                const char* src,
                int len);
int gmem_strdel(char** str,
                int len);

#endif // #ifndef GMEM_CHECK

#endif
