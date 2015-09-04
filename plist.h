#ifndef PLIST_H_
#define PLIST_H_

/*
 * A list of values (PNodes), each of which has just a pointer, since we are
 * storing Perl SVs in here.
 */

// when we first allocate a chunk of values, this is the size we use
#define PLIST_INITIAL_SIZE 2 // 16

typedef struct PNode {
  const void* ptr;        // the pointer we are storing; we claim NO OWNERSHIP on it
} PNode;

typedef struct PList {
  PNode* data;            // a chunk of values
  unsigned short alen;    // allocated size of chunk
  unsigned short ulen;    // actual used size in chunk
} PList;

PList* plist_create(void);
void plist_destroy(PList* plist);
PList* plist_clone(PList* plist);

void plist_init(PList* plist);
void plist_clear(PList* plist);

int plist_size(const PList* plist);

PNode* plist_add(PList* plist, const void* obj);

void plist_dump(const PList* plist, FILE* fp);

#endif
