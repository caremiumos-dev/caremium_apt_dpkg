#!/bin/bash
# Generate the pre-seeded dpkg database for the Caremium apt/dpkg bundle.
# Run: bash ~/android-deb/gen-db.sh
set -euo pipefail

ROOT="${ROOT:-$HOME/android-deb/stage/system}"
DB="$ROOT/usr/var/lib/dpkg"
MAINT="CaremiumOS Developers <caremium-os@googlegroups.com>"
ARCH=armhf

rm -rf "$DB/info" "$DB/updates" "$DB/triggers" "$DB/alternatives" "$DB/parts"
mkdir -p "$DB/info" "$DB/updates" "$DB/triggers" "$DB/alternatives" "$DB/parts"
: > "$DB/status"
: > "$DB/available"
: > "$DB/diversions"
: > "$DB/statoverride"

# Collect files under ROOT for the given globs (directories are recursive).
collect() {
    local pat f sub
    for pat in "$@"; do
        for f in "$ROOT"/$pat; do
            [ -e "$f" ] || [ -L "$f" ] || continue
            if [ -d "$f" ]; then
                while IFS= read -r sub; do
                    printf '%s\n' "${sub#"$ROOT"}"
                done < <(find "$f" \( -type f -o -type l \) | sort)
            else
                printf '%s\n' "${f#"$ROOT"}"
            fi
        done
    done | sort -u | sed '/^$/d'
}

write_pkg() {
    local name=$1 ver=$2 section=$3 prio=$4 depends=$5 desc=$6 size=$7
    shift 7
    {
        echo "Package: $name"
        echo "Status: install ok installed"
        echo "Priority: $prio"
        echo "Section: $section"
        echo "Installed-Size: $size"
        echo "Maintainer: $MAINT"
        echo "Architecture: $ARCH"
        echo "Version: $ver"
        [ -n "$depends" ] && echo "Depends: $depends"
        echo "Description: $desc"
        echo " Pre-seeded package of the Caremium apt/dpkg port for Android."
        echo
    } >> "$DB/status"
    printf '%s\n' "$@" > "$DB/info/$name.list"
}

# add <name> <ver> <section> <prio> <depends> <desc> <globs...>
add() {
    local name=$1 ver=$2 section=$3 prio=$4 depends=$5 desc=$6
    shift 6
    local files size=0 f kb
    files=$(collect "$@")
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        size=$(( size + $(stat -c %s "$ROOT$f") ))
    done <<< "$files"
    kb=$(( size / 1024 + 1 ))
    local list=()
    while IFS= read -r f; do
        [ -n "$f" ] && list+=("/system$f")
    done <<< "$files"
    write_pkg "$name" "$ver" "$section" "$prio" "$depends" "$desc" "$kb" "${list[@]}"
}

# add_sys <name> <ver> <section> <prio> <depends> <desc> <paths under /system>
# For libraries that already exist on the device (bionic, zlib).
add_sys() {
    local name=$1 ver=$2 section=$3 prio=$4 depends=$5 desc=$6
    shift 6
    local list=() p
    for p in "$@"; do list+=("/system$p"); done
    write_pkg "$name" "$ver" "$section" "$prio" "$depends" "$desc" 1 "${list[@]}"
}

add_sys bionic 8.1.0 libs required "" \
    "Android C library (bionic: libc, libm, libdl)" \
    /lib/libc.so /lib/libm.so /lib/libdl.so

add_sys zlib1g 1.2.11 libs required "bionic" \
    "zlib compression library" \
    /lib/libz.so

add libc++ 9.0.8 libs optional "bionic" \
    "LLVM libc++ runtime (NDK r21)" \
    lib/libc++_shared.so

add libssl3 3.0.17 libs optional "bionic" \
    "OpenSSL 3 runtime libraries (private copy)" \
    usr/local/openssl/lib/libcrypto.so usr/local/openssl/lib/libssl.so

add openssl 3.0.17 utils optional "libssl3 (= 3.0.17), bionic" \
    "OpenSSL 3 tools and headers (private copy)" \
    usr/local/openssl/bin usr/local/openssl/include usr/local/openssl/lib/engines-3 \
    usr/local/openssl/lib/ossl-modules usr/local/openssl/lib/pkgconfig \
    usr/local/openssl/lib/libcrypto.a usr/local/openssl/lib/libssl.a

add libapt-pkg7.0 3.0.3 libs important "bionic, libc++, libssl3" \
    "APT package management library" \
    lib/libapt-pkg.so.7.0 lib/libapt-pkg.so.7.0.0

add libapt-pkg-dev 3.0.3 libdevel optional "libapt-pkg7.0 (= 3.0.3)" \
    "APT library development files" \
    lib/libapt-pkg.so usr/include/apt-pkg

add apt 3.0.3 admin important "libapt-pkg7.0 (= 3.0.3), dpkg (>= 1.22.22), libc++, libssl3" \
    "commandline package manager" \
    bin/apt bin/apt-cache bin/apt-cdrom bin/apt-config bin/apt-ftparchive \
    bin/apt-get bin/apt-mark bin/apt-sortpkgs \
    lib/libapt-private.so.0.0 lib/libapt-private.so.0.0.0 \
    usr/libexec/apt etc/apt

add dpkg 1.22.22 admin required "bionic, tar (>= 1.35)" \
    "Debian package management system" \
    bin/dpkg bin/dpkg-architecture bin/dpkg-buildapi bin/dpkg-buildflags \
    bin/dpkg-buildpackage bin/dpkg-buildtree bin/dpkg-checkbuilddeps bin/dpkg-deb \
    bin/dpkg-distaddfile bin/dpkg-divert bin/dpkg-genbuildinfo bin/dpkg-genchanges \
    bin/dpkg-gencontrol bin/dpkg-gensymbols bin/dpkg-maintscript-helper \
    bin/dpkg-mergechangelogs bin/dpkg-name bin/dpkg-parsechangelog bin/dpkg-query \
    bin/dpkg-realpath bin/dpkg-scanpackages bin/dpkg-scansources bin/dpkg-shlibdeps \
    bin/dpkg-source bin/dpkg-split bin/dpkg-statoverride bin/dpkg-trigger \
    bin/dpkg-vendor bin/update-alternatives \
    etc/dpkg etc/alternatives usr/share/dpkg usr/share/perl5 usr/libexec/dpkg

add libdpkg-dev 1.22.22 libdevel optional "dpkg (= 1.22.22)" \
    "libdpkg static library and headers" \
    lib/libdpkg.a usr/include/dpkg

add tar 1.35 utils required "bionic" \
    "GNU tar (replaces toybox tar; used by dpkg-deb)" \
    bin/tar

add libbz2-dev 1.0.8 libdevel optional "bionic" \
    "bzip2 static library" lib/libbz2.a
add liblzma-dev 5.8.4 libdevel optional "bionic" \
    "xz/liblzma static library" lib/liblzma.a
add liblz4-dev 1.10.0 libdevel optional "bionic" \
    "lz4 static library" lib/liblz4.a
add libzstd-dev 1.5.7 libdevel optional "bionic" \
    "zstd static library" lib/libzstd.a
add libmd-dev 1.1.0 libdevel optional "bionic" \
    "libmd message digest static library" lib/libmd.a
add libiconv-dev 1.18 libdevel optional "bionic" \
    "libiconv static library" lib/libiconv.a lib/libcharset.a
add libdb-dev 5.3.28 libdevel optional "bionic" \
    "Berkeley DB static library" lib/libdb.a lib/libdb-5.3.a
add libxxhash-dev 0.8.3 libdevel optional "bionic" \
    "xxHash static library" lib/libxxhash.a
add libglob-dev 1.0 libdevel optional "bionic" \
    "glob(3) compatibility shim (static)" lib/libglob.a

echo "packages: $(grep -c '^Package:' "$DB/status")"
echo "files owned: $(cat "$DB"/info/*.list | wc -l)"
