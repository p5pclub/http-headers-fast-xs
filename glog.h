#ifndef GLOG_H_
#define GLOG_H_

#include <stdio.h>

#ifndef GLOG_SHOW

#define GLOG(args)

#else

#define GLOG(args) glog args

#endif

void glog(const char* fmt, ...);

#endif
