#!/bin/bash
set -euo pipefail
S="$HOME/android-deb/stage-coreutils/system"
OUT="$HOME/android-deb/out/coreutils"
V=9.12
STRIP=/opt/android-ndk-r21/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
mkdir -p "$OUT"

mk() { # mk <pkg> <control-file> ; files already staged in $W/<pkg>/system
    local pkg=$1
    local root="$W/$pkg"
    local size; size=$(du -sk "$root" | cut -f1)
    sed "s/@SIZE@/$size/" "$W/$pkg.control" > "$root/DEBIAN/control"
    ( cd "$root" && echo 2.0 > "$W/debian-binary" \
      && tar --owner=0 --group=0 --numeric-owner -czf "$W/control.tar.gz" -C DEBIAN . \
      && tar --owner=0 --group=0 --numeric-owner -czf "$W/data.tar.gz" -C . ./system )
    rm -f "$OUT/${pkg}_${V}_armhf.deb"
    ar rc "$OUT/${pkg}_${V}_armhf.deb" "$W/debian-binary" "$W/control.tar.gz" "$W/data.tar.gz"
    echo "  $pkg"
}

control() { # control <pkg> <section> <priority> <depends> <desc>
    cat > "$W/$1.control" <<EOF
Package: $1
Version: $V
Architecture: armhf
Maintainer: GNU Coreutils Maintainers <bug-coreutils@gnu.org>
Installed-Size: @SIZE@
Section: $2
Priority: $3
Depends: $4
Provides: coreutils
Homepage: https://www.gnu.org/software/coreutils/
Description: $5
 The GNU Core Utilities are the basic file, shell and text manipulation
 utilities of the GNU operating system.  These are the core utilities
 which are expected to exist on every operating system.
 .
 This build is the upstream GNU Coreutils 9.12 release for Android 8.1
 (API 27, armhf), configured with --enable-single-binary.  Only the
 multicall binary is installed; there are no per-applet symlinks.
 Invoke an applet explicitly, for example:
 .
   coreutils --coreutils-prog=ls -l /system
 .
 (Note: the install applet is spelled 'ginstall' in this mode.)
EOF
}

root="$W/coreutils"; mkdir -p "$root/DEBIAN" "$root/system/bin" "$root/system/usr/share"
cp -a "$S/bin/coreutils" "$root/system/bin/"
"$STRIP" --strip-all "$root/system/bin/coreutils"
cp -a "$S/usr/share/man" "$root/system/usr/share/"
control coreutils utils required "bionic" "GNU core utilities (single multicall binary)"
mk coreutils

echo "done: $OUT"
