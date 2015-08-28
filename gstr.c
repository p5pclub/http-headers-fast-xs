#include "gmem.h"
#include "glog.h"
#include "gstr.h"

void gstr_init(GStr* gstr, const char* str, int len) {
  gstr->buf[0] = '\0';
  gstr->str = gstr->buf;
  gstr->alen = gstr->ulen = 0;

  if (!str) {
    return;
  }

  if (len <= 0) {
    len = strlen(str) + 1;
  }

  gstr->ulen = len;
  if (len <= GSTR_MAX_FIXED_LENGTH) {
    GLOG(("=C= copying %d bytes to fixed buffer: [%*s]",
          gstr->ulen, gstr->ulen-1, str));
  } else {
    gstr->alen = len;
    GMEM_NEW(gstr->str, char*, gstr->alen);
    GLOG(("=C= copied %d bytes to dynamic buffer: [%*s]",
          gstr->alen, gstr->alen-1, str));
  }
  memcpy(gstr->str, str, gstr->ulen);
}

void gstr_clear(GStr* gstr) {
  if (gstr->alen <= 0) {
    GLOG(("=C= 'freeing' %d bytes from fixed buffer: [%*s]",
          gstr->ulen, gstr->ulen-1, gstr->str));
    gstr->buf[0] = '\0';
  } else {
    GLOG(("=C= deleting %d bytes from dynamic buffer: [%*s]",
          gstr->alen, gstr->alen-1, gstr->str));
    GMEM_DEL(gstr->str, char*, gstr->alen);
  }
  gstr->alen = gstr->ulen = 0;
}
