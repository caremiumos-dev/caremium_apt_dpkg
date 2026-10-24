/* Minimal <glob.h> for Android/bionic < API 28 (bionic added glob() in API 28). */
#ifndef _GLOB_H_
#define _GLOB_H_

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define GLOB_ERR      1
#define GLOB_MARK     2
#define GLOB_NOSORT   4
#define GLOB_DOOFFS   8
#define GLOB_NOCHECK  16
#define GLOB_APPEND   32
#define GLOB_NOESCAPE 64

#define GLOB_NOSPACE  1
#define GLOB_ABORTED  2
#define GLOB_NOMATCH  3

typedef struct {
    size_t gl_pathc;
    char **gl_pathv;
    size_t gl_offs;
} glob_t;

int glob(const char *pattern, int flags,
         int (*errfunc)(const char *epath, int eerrno), glob_t *pglob);
void globfree(glob_t *pglob);

#ifdef __cplusplus
}
#endif

#endif
