#!/bin/bash
# Build Debian-style .deb packages for the dynamic apt/dpkg bundle.
#   bash ~/android-deb/mkdebs-dyn.sh
set -euo pipefail

R="${R:-$HOME/android-deb/dyn/stage/system}"
DEBOUT="${DEBOUT:-$HOME/android-deb/out/dyn}"
MAINT="CaremiumOS Developers <caremium-os@googlegroups.com>"
ARCH=armhf
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$DEBOUT"

mkdeb() {
    local name=$1 ver=$2 section=$3 prio=$4 depends=$5 desc=$6
    shift 6
    local root="$WORK/$name" f size=0
    rm -rf "$root"
    mkdir -p "$root/DEBIAN"
    for pat in "$@"; do
        for f in "$R"/$pat; do
            [ -e "$f" ] || [ -L "$f" ] || continue
            mkdir -p "$root/system/$(dirname "${f#"$R/"}")"
            cp -a "$f" "$root/system/${f#"$R/"}"
        done
    done
    size=$(du -sk "$root" | cut -f1)
    {
        echo "Package: $name"
        echo "Version: $ver"
        echo "Architecture: $ARCH"
        echo "Maintainer: $MAINT"
        echo "Installed-Size: $size"
        echo "Section: $section"
        echo "Priority: $prio"
        [ -n "$depends" ] && echo "Depends: $depends"
        [ -n "${EXTRA_FIELDS:-}" ] && printf "%b\n" "$EXTRA_FIELDS"
        echo "Description: $desc"
        echo " Built from the Android platform source tree for Caremium."
    } > "$root/DEBIAN/control"

    ( cd "$root" && echo 2.0 > "$WORK/debian-binary" \
        && tar --owner=0 --group=0 --numeric-owner -czf "$WORK/control.tar.gz" -C DEBIAN . \
        && tar --owner=0 --group=0 --numeric-owner -czf "$WORK/data.tar.gz" -C . ./system )
    rm -f "$DEBOUT/${name}_${ver}_${ARCH}.deb"
    ar rc "$DEBOUT/${name}_${ver}_${ARCH}.deb" "$WORK/debian-binary" "$WORK/control.tar.gz" "$WORK/data.tar.gz"
    echo "  $name $ver"
}

# runtime libraries (no conflict with the device) -> /system/lib
mkdeb libbz2-1.0   1.0.8  libs required "bionic" "bzip2 runtime library"            lib/libbz2.so*
mkdeb libzstd1     1.5.7  libs required "bionic" "zstd runtime library"             lib/libzstd.so*
mkdeb libmd0       1.1.0  libs required "bionic" "message digest library"           lib/libmd.so
mkdeb libiconv1    1.18   libs required "bionic" "iconv/charset conversion library" lib/libiconv.so lib/libcharset.so
mkdeb libdb5.3     5.3.28 libs optional "bionic" "Berkeley DB runtime library"      lib/libdb-5.3.so lib/libdb.so lib/libdb-5.so
mkdeb libxxhash0   0.8.3  libs required "bionic" "xxHash runtime library"           lib/libxxhash.so*
mkdeb libglob0     1.0    libs required "bionic" "glob(3) compatibility library"    lib/libglob.so
EXTRA_FIELDS="Replaces: libc++ (<< 9.0.8)\nBreaks: libc++ (<< 9.0.8)\nProvides: libc++"
mkdeb libc++1      9.0.8  libs required "bionic" "LLVM libc++ runtime"              lib/libc++_shared.so
EXTRA_FIELDS=""
mkdeb libapt-pkg7.0 3.0.3 libs important "libbz2-1.0, liblzma5, liblz4-1, libzstd1, libiconv1, libxxhash0, libglob0, libc++1, libssl3, zlib1g, bionic" \
      "APT package management library" lib/libapt-pkg.so*

# conflicting libraries -> private per-library directories
mkdeb liblzma5     5.8.4  libs required "bionic" "xz/liblzma runtime (private copy)" usr/local/liblzma/lib/liblzma.so
mkdeb liblz4-1     1.10.0 libs optional "bionic" "lz4 runtime (private copy)"        usr/local/liblz4/lib/liblz4.so*
mkdeb libssl3      3.0.17 libs required "bionic" "OpenSSL 3 runtime (private copy)"  usr/local/openssl/lib/libcrypto.so usr/local/openssl/lib/libssl.so

mkdeb openssl      3.0.17 utils optional "libssl3 (= 3.0.17), bionic" \
      "OpenSSL 3 tools and headers (private copy)" \
      usr/local/openssl/bin usr/local/openssl/include usr/local/openssl/lib/engines-3 usr/local/openssl/lib/ossl-modules

mkdeb apt          3.0.3  admin important "libapt-pkg7.0 (= 3.0.3), dpkg (>= 1.22.22), libc++1, libglob0, libssl3" \
      "commandline package manager" \
      bin/apt bin/apt-cache bin/apt-cdrom bin/apt-config bin/apt-ftparchive bin/apt-get bin/apt-mark bin/apt-sortpkgs \
      lib/libapt-private.so* usr/libexec/apt etc/apt

mkdeb dpkg         1.22.22 admin required "tar (>= 1.35), libbz2-1.0, liblzma5, libzstd1, libmd0, zlib1g, bionic" \
      "Debian package management system" \
      bin/dpkg bin/dpkg-architecture bin/dpkg-buildapi bin/dpkg-buildflags bin/dpkg-buildpackage \
      bin/dpkg-buildtree bin/dpkg-checkbuilddeps bin/dpkg-deb bin/dpkg-distaddfile bin/dpkg-divert \
      bin/dpkg-genbuildinfo bin/dpkg-genchanges bin/dpkg-gencontrol bin/dpkg-gensymbols \
      bin/dpkg-maintscript-helper bin/dpkg-mergechangelogs bin/dpkg-name bin/dpkg-parsechangelog \
      bin/dpkg-query bin/dpkg-realpath bin/dpkg-scanpackages bin/dpkg-scansources bin/dpkg-shlibdeps \
      bin/dpkg-source bin/dpkg-split bin/dpkg-statoverride bin/dpkg-trigger bin/dpkg-vendor \
      bin/update-alternatives etc/dpkg etc/alternatives usr/share/dpkg usr/share/perl5 usr/libexec/dpkg

mkdeb tar          1.35   utils required "bionic" "GNU tar (replaces toybox tar; used by dpkg-deb)" bin/tar

echo "debs: $(ls "$DEBOUT"/*.deb | wc -l) in $DEBOUT"
