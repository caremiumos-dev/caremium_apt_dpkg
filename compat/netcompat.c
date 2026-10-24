/*
 * Small Android/bionic compatibility shims used by apt:
 *   - getservbyport_r(): bionic has no reentrant variant
 *   - dn_skipname():     bionic libc does not export it
 *
 * These are linked into libglob (our compat shim library).
 */

#include <errno.h>
#include <netdb.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

int getservbyport_r(int port, const char *proto, struct servent *result,
                    char *buf, size_t buflen, struct servent **res)
{
    struct servent *s;
    char *p;
    char **aliases;
    size_t naliases = 0, strings, ptrs, need, i;

    s = getservbyport(port, proto);
    if (s == NULL) {
        if (res)
            *res = NULL;
        return ENOENT;
    }

    strings = strlen(s->s_name) + 1 + strlen(s->s_proto) + 1;
    for (i = 0; s->s_aliases && s->s_aliases[i]; i++)
        strings += strlen(s->s_aliases[i]) + 1;
    naliases = i;
    ptrs = (naliases + 1) * sizeof(char *);
    need = ((strings + sizeof(char *) - 1) & ~(sizeof(char *) - 1)) + ptrs;

    if (buflen < need)
        return ERANGE;

    /* strings first */
    p = buf;
    result->s_name = p;
    strcpy(p, s->s_name);
    p += strlen(s->s_name) + 1;

    for (i = 0; i < naliases; i++) {
        /* store alias strings contiguously; pointers are fixed up below */
        strcpy(p, s->s_aliases[i]);
        p += strlen(s->s_aliases[i]) + 1;
    }

    result->s_proto = p;
    strcpy(p, s->s_proto);

    /* pointer array at the (aligned) end */
    aliases = (char **)(void *)(uintptr_t)(buf + ((strings + sizeof(char *) - 1) & ~(sizeof(char *) - 1)));
    p = buf + strlen(s->s_name) + 1;
    for (i = 0; i < naliases; i++) {
        aliases[i] = p;
        p += strlen(s->s_aliases[i]) + 1;
    }
    aliases[naliases] = NULL;
    result->s_aliases = aliases;

    result->s_port = s->s_port;
    if (res)
        *res = result;
    return 0;
}

int dn_skipname(const unsigned char *comp_dn, const unsigned char *eom)
{
    const unsigned char *cp = comp_dn;

    while (cp < eom) {
        int n = *cp++;

        if (n == 0)
            return (int)(cp - comp_dn);
        if ((n & 0xC0) == 0xC0) {
            if (cp >= eom)
                return -1;
            return (int)(cp + 1 - comp_dn);
        }
        if (n & 0xC0)
            return -1;
        cp += n;
        if (cp > eom)
            return -1;
    }
    return -1;
}
