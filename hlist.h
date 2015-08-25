#ifndef HLIST_H_
#define HLIST_H_

#include "gstr.h"

#define SNODE_TYPE_NONE 0
#define SNODE_TYPE_STR  1
#define SNODE_TYPE_OBJ  2
#define SNODE_TYPE_SIZE 3

#define SLIST_INITIAL_SIZE 16
#define HLIST_INITIAL_SIZE 97 // 131

/*
 * A linked list node, reference counted, holding:
 *
 * + a dynamically allocated string
 */
typedef struct PObj {
  void* obj;
} PObj;
typedef struct SNode {
  union {
    GStr gstr;
    PObj pobj;
  } data;
  short refcnt;
  short type;
} SNode;

/*
 * A placeholder for a linked list of SNode*.
 */
typedef struct SList {
  SNode* data;
  int alen;
  int ulen;
} SList;

/*
 * An iterator for SLists.
 */
typedef struct SIter {
  const SList* slist;
  int pos;
} SIter;


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


// SList iterator functions.
void siter_reset(SIter* siter, const SList* slist);
int siter_more(const SIter* siter);
SNode* siter_fetch(SIter* siter);
void siter_next(SIter* siter);


/*
 * A linked list node, reference counted, holding:
 *
 * + a dynamically allocated string - name
 * + a pointer to an SList holding values for this name
 */
typedef struct HNode {
  char* name;
  SList* slist;
  struct HNode* nxt;
} HNode;

/*
 * A placeholder for a linked list of HNode*.
 */
typedef struct HList {
  HNode* data[HLIST_INITIAL_SIZE];
  int alen;
  int ulen;
} HList;

/*
 * An iterator for HLists.
 */
typedef struct HIter {
  const HList* hlist;
  int pos;
  HNode* node;
} HIter;


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
HNode* hlist_get_header(HList* hlist, int translate_underscore,
                        HNode* h, const char* name);

// Add a value to the SList for a given header name.
// If header name already exists, append to its values; if not, create it.
HNode* hlist_add_header(HList* hlist, int translate_underscore,
                        HNode* h, const char* name, const char* str, void* obj);

// Delete a given header from an HList, if that header is there.
HNode* hlist_del_header(HList* hlist, int translate_underscore,
                        HNode* h, const char* name);


// HList iterator functions.
void hiter_reset(HIter* hiter, const HList* hlist);
int hiter_more(const HIter* hiter);
HNode* hiter_fetch(HIter* hiter);
void hiter_next(HIter* hiter);

#endif
