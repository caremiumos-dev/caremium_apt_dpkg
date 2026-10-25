/*
 * bionic-compat: small ABI shims for bionic < API 28.
 *
 *   glob()/globfree()      - bionic only has them since API 28
 *   getservbyport_r()      - bionic has no reentrant variant
 *   dn_skipname()          - bionic libc does not export it
 */
#ifndef BIONIC_COMPAT_H
#define BIONIC_COMPAT_H

#include <glob.h>
#include <netdb.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

int getservbyport_r(int port, const char *proto, struct servent *result,
                    char *buf, size_t buflen, struct servent **res);
int dn_skipname(const unsigned char *comp_dn, const unsigned char *eom);

#ifdef __cplusplus
}
#endif

#endif /* BIONIC_COMPAT_H */
