#!/bin/bash
set -euo pipefail
C="$HOME/android-deb/compat"
OUT="$HOME/android-deb/out/compat"
V=1.0
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

control() { # control <pkg> <section> <depends> <desc>
    cat > "$W/$1.control" <<EOF
Package: $1
Version: $V
Architecture: armhf
Maintainer: CaremiumOS Developers <caremium-os@googlegroups.com>
Installed-Size: @SIZE@
Section: $2
Priority: optional
Depends: $3
Description: $4
 bionic ABI compatibility shims (glob, getservbyport_r, dn_skipname).
EOF
}

# bionic-compat: runtime .so
root="$W/bionic-compat"; mkdir -p "$root/DEBIAN" "$root/system/lib"
cp -a "$C/libbionic-compat.so" "$root/system/lib/"
control bionic-compat libs "bionic" "bionic ABI compatibility shims (runtime)"
mk bionic-compat

# bionic-compat-dev: headers
root="$W/bionic-compat-dev"; mkdir -p "$root/DEBIAN" "$root/system/usr/include"
cp -a "$C/glob.h" "$C/bionic-compat.h" "$root/system/usr/include/"
control bionic-compat-dev libdevel "bionic-compat (= $V)" "bionic ABI compatibility shims (development files)"
mk bionic-compat-dev

# bionic-compat-static: .a
root="$W/bionic-compat-static"; mkdir -p "$root/DEBIAN" "$root/system/lib"
cp -a "$C/libbionic-compat.a" "$root/system/lib/"
control bionic-compat-static libdevel "bionic-compat-dev (= $V)" "bionic ABI compatibility shims (static archive)"
mk bionic-compat-static

echo "done: $OUT"
