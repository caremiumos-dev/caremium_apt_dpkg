#!/bin/bash
set -euo pipefail
S="$HOME/android-deb/stage-bash/system"
OUT="$HOME/android-deb/out/bash"
V=5.2.37
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
Maintainer: GNU Bash Maintainers <bug-bash@gnu.org>
Installed-Size: @SIZE@
Section: $2
Priority: $3
Depends: $4
Provides: bash
Homepage: https://www.gnu.org/software/bash/
Description: $5
 Bash is the GNU Project's shell: a sh-compatible command language
 interpreter that executes commands read from the standard input or
 from a file.  Bash also incorporates useful features from the Korn and
 C shells (ksh and csh).
 .
 Bash is ultimately intended to be a conformant implementation of the
 IEEE POSIX Shell and Tools specification (IEEE Working Group 1003.2).
 .
 This build is the upstream GNU Bash 5.2.37 release for Android 8.1
 (API 27, armhf), with a bundled readline and Android default paths.
EOF
}

root="$W/bash"; mkdir -p "$root/DEBIAN" "$root/system"
cp -a "$S/bin" "$S/etc" "$S/usr" "$root/system/"
control bash shells required "bionic" "GNU Bourne-Again SHell"
mk bash

echo "done: $OUT"
