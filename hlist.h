#ifndef HLIST_H_
#define HLIST_H_

/*
 * A linked list of string values.
 */
typedef struct SList {
  char* str;
  struct SList* nxt;
  int refcnt;
} SList;

// Manage reference-counted SList* elements.
SList* slist_ref(SList* slist);
SList* slist_unref(SList* slist);

// Create a new, empty SList.
SList* slist_create(void);

// Create a deep clone of an SList.
SList* slist_clone(SList* slist);

// Is this SList empty?
int slist_empty(const SList* slist);

// Get the size for this SList.
int slist_size(const SList* slist);

// Add a string element to this SList.  Accept duplicates.
void slist_add(SList* slist, const char* str);

// Get a buffer with all elements in the list, separated with character sep.
// If buffer or length are zero, allocate just the space necessary for this.
char* slist_format(const SList* slist, char spearator, char* buffer, int length);



/*
 * A linked list of headers.  Each header has a name and an SList containing
 * all the values for that header.
 */
typedef struct HList {
  char* name;
  char* canonical_name;
  int canonical_offset;
  SList* slist;
  struct HList* nxt;
  int refcnt;
} HList;


// Manage reference-counted HList* elements.
HList* hlist_ref(HList* hlist);
HList* hlist_unref(HList* hlist);

// Create a new, empty HList.
HList* hlist_create(void);

// Create a deep clone of an HList.
HList* hlist_clone(HList* hlist);

// Erase all elements of an HList; leave it as just created.
void hlist_clear(HList* hlist);

// Dump an HList to a FILE stream.
void hlist_dump(HList* hlist, FILE* fp);

// Add a value to the SList for a given header name.
// If header name already exists, append to its values; if not, create it.
SList* hlist_add_header(HList* hlist, int translate_underscore,
                        const char* name, const char* value);

// Delete a given header from an HList, if that header is there.
void hlist_del_header(HList* hlist, int translate_underscore,
                      const char* name);

// Get the SList with values for a given header name.
SList* hlist_get_header(HList* hlist, int translate_underscore,
                        const char* name);

#endif
