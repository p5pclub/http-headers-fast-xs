#ifndef GMEM_H_
#define GMEM_H_

#include <stdlib.h>
#include <string.h>

#ifndef GMEM_CHECK

#define GMEM_NEW(var, type, size) do { var = (type) malloc(size); } while (0)
#define GMEM_DEL(var, type, size) do { free(var); var = 0; } while (0)

#else

#define GMEM_NEW(var, type, size) \
  do { \
    var = (type) malloc(size); \
    gmem_new_called(__FILE__, __LINE__, var, size);  \
  } while (0)
#define GMEM_DEL(var, type, size) \
  do { \
    gmem_del_called(__FILE__, __LINE__, var, size);  \
    free(var); \
    var = 0; \
  } while (0)

extern long gmem_new;
extern long gmem_del;

void gmem_new_called(const char* file, int line, void* var, long size);
void gmem_del_called(const char* file, int line, void* var, long size);

#endif

#endif
