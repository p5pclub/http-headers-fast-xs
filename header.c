#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "glog.h"
#include "gmem.h"
#include "header.h"

static Header standard_headers[] = {
  // general headers
  { 100, "Cache-Control"       },
  { 101, "Connection"          },
  { 102, "Date"                },
  { 103, "Pragma"              },
  { 104, "Trailer"             },
  { 105, "Transfer-Encoding"   },
  { 106, "Upgrade"             },
  { 107, "Via"                 },
  { 108, "Warning"             },

  // request headers
  { 200, "Accept"              },
  { 201, "Accept-Charset"      },
  { 202, "Accept-Encoding"     },
  { 203, "Accept-Language"     },
  { 204, "Authorization"       },
  { 205, "Expect"              },
  { 206, "From"                },
  { 207, "Host"                },
  { 208, "If-Match"            },
  { 209, "If-Modified-Since"   },
  { 210, "If-None-Match"       },
  { 211, "If-Range"            },
  { 212, "If-Unmodified-Since" },
  { 213, "Max-Forwards"        },
  { 214, "Proxy-Authorization" },
  { 215, "Range"               },
  { 216, "Referer"             },
  { 217, "TE"                  },
  { 218, "User-Agent"          },

  // response headers
  { 300, "Accept-Ranges"       },
  { 301, "Age"                 },
  { 302, "ETag"                },
  { 303, "Location"            },
  { 304, "Proxy-Authenticate"  },
  { 305, "Retry-After"         },
  { 306, "Server"              },
  { 307, "Vary"                },
  { 308, "WWW-Authenticate"    },

  // entity headers
  { 400, "Allow"               },
  { 401, "Content-Encoding"    },
  { 402, "Content-Language"    },
  { 403, "Content-Length"      },
  { 404, "Content-Location"    },
  { 405, "Content-MD5"         },
  { 406, "Content-Range"       },
  { 407, "Content-Type"        },
  { 408, "Expires"             },
  { 409, "Last-Modified"       },
};
static int standard_headers_size = sizeof(standard_headers) / sizeof(standard_headers[0]);

Header* header_create(const char* name) {
  Header* h = 0;
  GMEM_NEW(h, Header*, sizeof(Header));
  h->order = HEADER_TYPE_NONE;
  int l = strlen(name) + 1;
  GMEM_NEW(h->name, char*, l);
  int word = 0;
  int j = 0;
  for (j = 0; name[j] != '\0'; ++j) {
    if (isalpha(name[j])) {
      if (word) {
        h->name[j] = tolower(name[j]);
      } else {
        h->name[j] = toupper(name[j]);
        word = 1;
      }
    } else {
      h->name[j] = name[j] == '_' ? '-' : name[j];
      word = 0;
    }
  }
  h->name[j] = '\0';
  GLOG(("=C= Created header [%s] => [%s]", name, h->name));
  return h;
}

Header* header_clone(Header* header) {
  if (header->order != HEADER_TYPE_NONE) {
    return header;
  }

  Header* h = header_create(header->name);
  return h;
}

void header_clear(Header* header) {
  if (header->order != HEADER_TYPE_NONE) {
    return;
  }
  GMEM_DELSTR(header->name, -1);
  GMEM_DEL(header, Header*, sizeof(Header));
}

#define CONVERT(c) c == '_' ? '-' : isupper(c) ? tolower(c) : c

int header_compare(const char* n1, const char* n2) {
  int p = 0;
  while (1) {
    if (n1[p] == '\0' || n2[p] == '\0') {
      break;
    }
    char c1 = CONVERT(n1[p]);
    char c2 = CONVERT(n2[p]);
    if (c1 < c2) {
      return -1;
    }
    if (c1 > c2) {
      return +1;
    }
    ++p;
  }
  if (n1[p] == '\0' && n2[p] != '\0') {
    return -1;
  }
  if (n1[p] != '\0' && n2[p] == '\0') {
    return +1;
  }
  return 0;
}

int header_match(const Header* h, const char* name, int type) {
  if (type != HEADER_TYPE_NONE && !HEADER_IS_CLASS(h, type)) {
    return 0;
  }
  int cmp = header_compare(name, h->name);
  // GLOG(("=C= compare [%s] & [%s] => %d", name, h->name, cmp));
  return cmp == 0;
}

Header* header_lookup(const char* name, int type) {
  int j = 0;
  Header* h = 0;
  for (j = 0; j < standard_headers_size; ++j) {
    h = &standard_headers[j];
    if (header_match(h, name, type)) {
      return h;
    }
  }

  return 0;
}

void header_dump(const Header* h, FILE* fp) {
  fprintf(fp, "[%p", h);
  if (h) {
    fprintf(fp, "|%3d|%s", h->order, h->name);
  }
  fprintf(fp, "]\n");
  fflush(fp);
}

int header_is_entity(const Header* h) {
  if (HEADER_IS_ENTITY(h)) {
    GLOG(("=C= header [%s] is entity (QUICK)", h->name));
    return 1;
  }

  if (HEADER_IS_GENERAL(h) ||
      HEADER_IS_REQUEST(h) ||
      HEADER_IS_RESPONSE(h)) {
    GLOG(("=C= header [%s] is not entity (QUICK)", h->name));
    return 0;
  }

  const char* start = "content-";
  int j;
  for (j = 0; start[j] != 0; ++j) {
    if (h->name[j] == '\0') {
      GLOG(("=C= header [%s] is not entity (EOS)", h->name));
      return 0;
    }
    if (tolower(h->name[j]) != start[j]) {
      GLOG(("=C= header [%s] is not entity (DIFF)", h->name));
      return 0;
    }
  }

  GLOG(("=C= header [%s] is entity (CMP)", h->name));
  return 1;
}
