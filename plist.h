#ifndef PLIST_H_
#define PLIST_H_

#define PLIST_INITIAL_SIZE 2 // 16

typedef struct PNode {
  const void* ptr;
} PNode;

typedef struct PList {
  PNode* data;
  unsigned short alen;
  unsigned short ulen;
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
