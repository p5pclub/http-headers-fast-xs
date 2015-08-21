#ifndef HLIST_H_
#define HLIST_H_

#define SNODE_TYPE_NONE 0
#define SNODE_TYPE_STR  1
#define SNODE_TYPE_OBJ  2
#define SNODE_TYPE_SIZE 3

/*
 * A linked list node, reference counted, holding:
 *
 * + a dynamically allocated string
 */
typedef struct DataStr {
  char* str;  // Allocated string
  short alen; // Allocated length
  short ulen; // Used length
} DataStr;
typedef struct DataObj {
  void* obj;
} DataObj;
typedef struct SNode {
  union {
    DataStr str;
    DataObj obj;
  } data;
  struct SNode* nxt;
  short refcnt;
  short type;
} SNode;

/*
 * A placeholder for a linked list of SNode*.
 */
typedef struct SList {
  struct SNode* head;
  struct SNode* tail;
  int size;
} SList;

// Create a new, empty SList.
SList* slist_create(void);

// Destroy an existing SList.
void slist_destroy(SList* slist);

// Create a clone of an SList.
SList* slist_clone(SList* slist);

// Erase all elements of an SList, leaving it as it was when just created.
// Return 1 if the SList* could also be deleted.
int slist_clear(SList* slist);

// Is this SList empty?
int slist_empty(const SList* slist);

// Get the size for this SList.
int slist_size(const SList* slist);

// Dump an SList to a FILE stream.
void slist_dump(SList* slist, FILE* fp);

// Add a str element to this SList.
void slist_add_str(SList* slist, const char* str);

// Add a obj element to this SList.
void slist_add_obj(SList* slist, void* obj);

#if 0
// Get a buffer with all elements in the list, separated with character sep.
// If buffer or length are zero, allocate just the space necessary for this.
char* slist_format(const SList* slist, char spearator, char* buffer, int length);
#endif


/*
 * A linked list node, reference counted, holding:
 *
 * + a dynamically allocated string - name
 * + a dynamically allocated string - canonical name
 * + an integer length - canonical offset
 * + a pointer to an SList holding values for this name
 */
typedef struct HNode {
  char* name;
  char* canonical_name;
  int canonical_offset;
  SList* slist;
  struct HNode* nxt;
} HNode;

/*
 * A placeholder for a linked list of HNode*.
 */
typedef struct HList {
  struct HNode* head;
  struct HNode* tail;
  int size;
} HList;




// Create a new, empty HList.
HList* hlist_create(void);

// Destroy an existing HList.
void hlist_destroy(HList* hlist);

// Create a clone of an HList.
HList* hlist_clone(HList* hlist);

// Erase all elements of an HList, leaving it as it was when just created.
// Return 1 if the HList* could also be deleted.
int hlist_clear(HList* hlist);

// Is this HList empty?
int hlist_empty(const HList* hlist);

// Get the size for this HList.
int hlist_size(const HList* hlist);

// Dump an HList to a FILE stream.
void hlist_dump(HList* hlist, FILE* fp);

// Get the SList with values for a given header name.
SList* hlist_get_header(HList* hlist, int translate_underscore,
                        const char* name);

// Add a value to the SList for a given header name.
// If header name already exists, append to its values; if not, create it.
SList* hlist_add_header(HList* hlist, int translate_underscore,
                        const char* name, const char* str, void* obj);

// Delete a given header from an HList, if that header is there.
void hlist_del_header(HList* hlist, int translate_underscore,
                      const char* name);

#endif
