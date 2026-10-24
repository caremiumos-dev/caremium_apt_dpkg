/*
 * Minimal glob(3) for Android/bionic < API 28.
 *
 * Only what apt needs: *, ?, [...] per path component (fnmatch), no brace
 * expansion, no GLOB_MARK/DOOOFFS/APPEND/NOCHECK semantics beyond the basics.
 */

#include <glob.h>

#include <dirent.h>
#include <errno.h>
#include <fnmatch.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

static int glob_add(glob_t *g, const char *path)
{
    char **v = realloc(g->gl_pathv, (g->gl_pathc + 2) * sizeof(char *));
    if (v == NULL)
        return GLOB_NOSPACE;
    g->gl_pathv = v;
    v[g->gl_pathc] = strdup(path);
    if (v[g->gl_pathc] == NULL)
        return GLOB_NOSPACE;
    g->gl_pathc++;
    v[g->gl_pathc] = NULL;
    return 0;
}

static int has_magic(const char *s)
{
    return strpbrk(s, "*?[") != NULL;
}

static int cmp_str(const void *a, const void *b)
{
    return strcmp(*(const char *const *)a, *(const char *const *)b);
}

static int glob_walk(const char *base, const char *pattern, int flags, glob_t *g)
{
    char path[PATH_MAX];
    const char *slash, *rest;
    size_t comp_len;

    while (*pattern == '/')
        pattern++;
    if (*pattern == '\0') {
        if (base[0] != '\0')
            return glob_add(g, base);
        return 0;
    }

    slash = strchr(pattern, '/');
    comp_len = slash ? (size_t)(slash - pattern) : strlen(pattern);
    rest = slash ? slash + 1 : pattern + comp_len;
    if (comp_len >= sizeof(path))
        return GLOB_NOSPACE;

    if (!has_magic(pattern)) {
        if (base[0] == '\0')
            snprintf(path, sizeof(path), "%.*s", (int)comp_len, pattern);
        else
            snprintf(path, sizeof(path), "%s/%.*s", base, (int)comp_len, pattern);

        if (*rest == '\0') {
            struct stat st;
            if (stat(path, &st) == 0)
                return glob_add(g, path);
            if (flags & GLOB_ERR)
                return GLOB_ABORTED;
            return 0;
        }
        return glob_walk(path, rest, flags, g);
    }

    {
        const char *dirpath = base[0] ? base : ".";
        DIR *d = opendir(dirpath);
        struct dirent *de;
        char comp[PATH_MAX];
        int rc = 0;

        if (d == NULL)
            return (flags & GLOB_ERR) ? GLOB_ABORTED : 0;

        snprintf(comp, sizeof(comp), "%.*s", (int)comp_len, pattern);
        while ((de = readdir(d)) != NULL) {
            if (de->d_name[0] == '.' &&
                !(comp[0] == '.' && (comp[1] == '\0' || comp[1] == '.')))
                continue;
            if (fnmatch(comp, de->d_name, 0) != 0)
                continue;

            if (base[0] == '\0')
                snprintf(path, sizeof(path), "%s", de->d_name);
            else
                snprintf(path, sizeof(path), "%s/%s", base, de->d_name);

            if (*rest == '\0')
                rc = glob_add(g, path);
            else
                rc = glob_walk(path, rest, flags, g);
            if (rc != 0)
                break;
        }
        closedir(d);
        return rc;
    }
}

int glob(const char *pattern, int flags,
         int (*errfunc)(const char *epath, int eerrno), glob_t *pglob)
{
    int rc;

    (void)errfunc;

    pglob->gl_pathc = 0;
    pglob->gl_pathv = NULL;
    pglob->gl_offs = 0;

    if (pattern == NULL)
        return GLOB_NOMATCH;

    if (pattern[0] == '/')
        rc = glob_walk("", pattern, flags, pglob);
    else
        rc = glob_walk("", pattern, flags, pglob);

    if (rc != 0) {
        globfree(pglob);
        return rc;
    }
    if (pglob->gl_pathc == 0)
        return GLOB_NOMATCH;

    if (!(flags & GLOB_NOSORT) && pglob->gl_pathc > 1)
        qsort(pglob->gl_pathv, pglob->gl_pathc, sizeof(char *), cmp_str);

    return 0;
}

void globfree(glob_t *pglob)
{
    size_t i;

    if (pglob == NULL || pglob->gl_pathv == NULL)
        return;
    for (i = 0; i < pglob->gl_pathc; i++)
        free(pglob->gl_pathv[i]);
    free(pglob->gl_pathv);
    pglob->gl_pathv = NULL;
    pglob->gl_pathc = 0;
}
