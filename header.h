#ifndef HEADER_H_
#define HEADER_H_

/*
 * A definition of a header, useful for:
 * 1. Storing a list of standardised headers, sorted in the "proper" order.
 * 2. Quickly determining if a header is of a given type, or a standard one.
 * 3. Adding user-defined headers, respecting the proper order.
 *
 * See static array standard_headers[] in header.c for the definition of all
 * standard headers.
 */

#define HEADER_TYPE_NONE     999 // should be greater than all other types
#define HEADER_TYPE_GENERAL  100
#define HEADER_TYPE_REQUEST  200
#define HEADER_TYPE_RESPONSE 300
#define HEADER_TYPE_ENTITY   400

typedef struct Header {
  int order;   // the order / grouping of the header
  char* name;  // the header name
} Header;

Header* header_create(const char* name);
Header* header_clone(Header* header);
void header_clear(Header* header);

int header_compare(const char* n1, const char* n2);
int header_match(const Header* h, const char* name, int type);
Header* header_lookup(const char* name, int type);
void header_dump(const Header* h, FILE* fp);

// Is this header an entity header?
int header_is_entity(const Header* h);

#endif
