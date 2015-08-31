#ifndef HLIST_H_
#define HLIST_H_

/*
 * TODO
 *
 * Forget about ':foo'. Fuck that.
 *
 * Add two flags per HList: comparison is case sensitive (default 0), consider
 * '_' and '-' as distinct (default 0).
 *
 * Add a sorted flag, set it to zero when adding, to 1 when sorting.
 *
 * Add a last HNode, update it when getting and adding, try it first when searching.
 *
 * Add a total_length???
 */
#define HLIST_INITIAL_SIZE   4 // 16

#define HLIST_FLAGS_SORTED    0x01
#define HLIST_FLAGS_SENSITIVE 0x02  // Still unused
#define HLIST_FLAGS_U_EQ_D    0x04  // Still unused

#define HLIST_FLAG_GET(h, f) (h->flags &   f)
#define HLIST_FLAG_SET(h, f)  h->flags |=  f
#define HLIST_FLAG_CLR(h, f)  h->flags &= ~f

struct Header;
struct PList;

typedef struct HNode {
  struct Header* header;
  struct PList* values;
} HNode;

typedef struct HList {
  HNode* data;
  unsigned short alen;
  unsigned short ulen;
  unsigned long flags;
} HList;

HList* hlist_create();
void hlist_destroy(HList* hlist);
HList* hlist_clone(HList* hlist);

void hlist_init(HList* hlist);
void hlist_clear(HList* hlist);

int hlist_size(const HList* hlist);

HNode* hlist_get(HList* hlist, const char* name);
HNode* hlist_add(HList* hlist, const char* name, const void* obj);
void hlist_del(HList* hlist, const char* name);

void hlist_sort(HList* hlist);

void hlist_dump(const HList* hlist, FILE* fp);

void hlist_transfer_header(HList* from, int pos, HList* to);

#endif
