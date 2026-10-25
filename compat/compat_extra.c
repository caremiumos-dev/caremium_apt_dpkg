/*
 * Extra bionic compatibility shims used by busybox:
 *   getusershell()/setusershell()/endusershell()
 *   getrandom()
 *   ether_hostton()
 *   sigisemptyset()
 */

#include <errno.h>
#include <net/ethernet.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
#include <unistd.h>

/* ---- getusershell family ------------------------------------------------ */

static FILE *shells_fp;
static char *shells_line;
static size_t shells_cap;

static char *next_shell(void)
{
    if (shells_fp == NULL)
        shells_fp = fopen("/etc/shells", "re");
    if (shells_fp == NULL)
        return NULL;

    while (getline(&shells_line, &shells_cap, shells_fp) > 0) {
        char *p = shells_line;
        while (*p == ' ' || *p == '\t')
            p++;
        if (*p == '#' || *p == '\n' || *p == '\0')
            continue;
        p[strcspn(p, "\r\n")] = '\0';
        return p;
    }
    return NULL;
}

__attribute__((weak)) char *getusershell(void)
{
    return next_shell();
}

__attribute__((weak)) void setusershell(void)
{
    if (shells_fp == NULL)
        shells_fp = fopen("/etc/shells", "re");
    else
        rewind(shells_fp);
}

__attribute__((weak)) void endusershell(void)
{
    if (shells_fp != NULL) {
        fclose(shells_fp);
        shells_fp = NULL;
    }
    free(shells_line);
    shells_line = NULL;
    shells_cap = 0;
}

/* ---- getrandom ---------------------------------------------------------- */

__attribute__((weak)) ssize_t getrandom(void *buf, size_t buflen, unsigned int flags)
{
    return (ssize_t)syscall(__NR_getrandom, buf, buflen, flags);
}

/* ---- ether_hostton ------------------------------------------------------ */

__attribute__((weak)) int ether_hostton(const char *hostname, struct ether_addr *addr)
{
    FILE *fp;
    char *line = NULL;
    size_t cap = 0;
    int rc = -1;

    fp = fopen("/etc/ethers", "re");
    if (fp == NULL)
        return -1;

    while (getline(&line, &cap, fp) > 0) {
        char mac[64], name[256];
        if (sscanf(line, "%63s %255s", mac, name) != 2)
            continue;
        if (strcmp(name, hostname) != 0)
            continue;
        unsigned int b0, b1, b2, b3, b4, b5;
        if (sscanf(mac, "%x:%x:%x:%x:%x:%x", &b0, &b1, &b2, &b3, &b4, &b5) == 6) {
            addr->ether_addr_octet[0] = (unsigned char)b0;
            addr->ether_addr_octet[1] = (unsigned char)b1;
            addr->ether_addr_octet[2] = (unsigned char)b2;
            addr->ether_addr_octet[3] = (unsigned char)b3;
            addr->ether_addr_octet[4] = (unsigned char)b4;
            addr->ether_addr_octet[5] = (unsigned char)b5;
            rc = 0;
            break;
        }
    }
    free(line);
    fclose(fp);
    return rc;
}

/* ---- sigisemptyset ------------------------------------------------------ */

__attribute__((weak)) int sigisemptyset(const sigset_t *set)
{
    int i;
    for (i = 1; i < NSIG; i++) {
        if (sigismember(set, i) == 1)
            return 0;
    }
    return 1;
}

/* ---- gethostid / getlogin_r / syncfs ------------------------------------ */

#include <pwd.h>

__attribute__((weak)) long gethostid(void)
{
    char host[256];
    unsigned long h = 5381;
    char *p;

    if (gethostname(host, sizeof(host)) != 0)
        return 0;
    for (p = host; *p != '\0'; p++)
        h = h * 33 + (unsigned char)*p;
    return (long)(h & 0xffffffffUL);
}

__attribute__((weak)) int getlogin_r(char *buf, size_t len)
{
    struct passwd *pw = getpwuid(getuid());
    if (pw == NULL)
        return ENXIO;
    if (strlen(pw->pw_name) + 1 > len)
        return ERANGE;
    strcpy(buf, pw->pw_name);
    return 0;
}

__attribute__((weak)) int syncfs(int fd)
{
    return (int)syscall(__NR_syncfs, fd);
}
