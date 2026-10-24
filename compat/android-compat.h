/* Force-included compatibility declarations for bionic < API 28. */
#ifndef ANDROID_DEB_COMPAT_H
#define ANDROID_DEB_COMPAT_H

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

#endif
