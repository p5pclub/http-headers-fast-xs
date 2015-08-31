#ifndef HEADER_H_
#define HEADER_H_

#define HEADER_IS_CLASS(h, v) (h->order >= v && h->order < (v+100))

#define HEADER_TYPE_NONE     999
#define HEADER_TYPE_GENERAL  100
#define HEADER_TYPE_REQUEST  200
#define HEADER_TYPE_RESPONSE 300
#define HEADER_TYPE_ENTITY   400

#define HEADER_IS_GENERAL(h)  HEADER_IS_CLASS(h, HEADER_TYPE_GENERAL)
#define HEADER_IS_REQUEST(h)  HEADER_IS_CLASS(h, HEADER_TYPE_REQUEST)
#define HEADER_IS_RESPONSE(h) HEADER_IS_CLASS(h, HEADER_TYPE_RESPONSE)
#define HEADER_IS_ENTITY(h)   HEADER_IS_CLASS(h, HEADER_TYPE_ENTITY)

typedef struct Header {
  int order;
  char* name;
} Header;

Header* header_create(const char* name);
Header* header_clone(Header* header);
void header_clear(Header* header);

int header_compare(const char* n1, const char* n2);
int header_match(const Header* h, const char* name, int type);
Header* header_lookup(const char* name, int type);
void header_dump(const Header* h, FILE* fp);

int header_is_entity(const Header* h);

#endif
