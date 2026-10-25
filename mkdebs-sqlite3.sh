#!/bin/bash
set -euo pipefail
S="$HOME/android-deb/stage-sqlite3/system"
OUT="$HOME/android-deb/out/sqlite3"
V=3.54.1
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

control() { # control <pkg> <section> <priority> <depends> <desc> <body>
    cat > "$W/$1.control" <<EOF
Package: $1
Version: $V
Architecture: armhf
Maintainer: SQLite Development Team <sqlite-users@mailinglists.sqlite.org>
Installed-Size: @SIZE@
Section: $2
Priority: $3
Depends: $4
Homepage: https://sqlite.org/
Description: $5
$6
EOF
}

# runtime library
root="$W/libsqlite3-0"; mkdir -p "$root/DEBIAN" "$root/system/lib"
cp -a "$S/lib/libsqlite3.so.$V" "$root/system/lib/"
"$STRIP" --strip-unneeded "$root/system/lib/libsqlite3.so.$V"
ln -s "libsqlite3.so.$V" "$root/system/lib/libsqlite3.so.0"
control libsqlite3-0 libs optional "bionic" "SQLite 3 shared library" \
" SQLite is a C library that implements an SQL database engine.  Programs
 that link with it can access SQLite databases through a simple API.
 .
 This package contains the shared runtime library (SONAME libsqlite3.so.0)."
mk libsqlite3-0

# development files
root="$W/libsqlite3-dev"; mkdir -p "$root/DEBIAN" "$root/system/lib" "$root/system/usr/include"
cp -a "$S/lib/libsqlite3.a" "$root/system/lib/"
"$STRIP" --strip-debug "$root/system/lib/libsqlite3.a"
ln -s "libsqlite3.so.$V" "$root/system/lib/libsqlite3.so"
cp -a "$S/usr/include/sqlite3.h" "$S/usr/include/sqlite3ext.h" "$root/system/usr/include/"
if [ -f "$S/lib/pkgconfig/sqlite3.pc" ]; then
    mkdir -p "$root/system/lib/pkgconfig"
    cp -a "$S/lib/pkgconfig/sqlite3.pc" "$root/system/lib/pkgconfig/"
fi
control libsqlite3-dev libdevel optional "libsqlite3-0 (= $V)" "SQLite 3 development files" \
" SQLite is a C library that implements an SQL database engine.
 .
 This package contains the headers, static library and pkg-config file
 needed to build programs against SQLite."
mk libsqlite3-dev

# command-line shell (statically linked against the amalgamation)
root="$W/sqlite3"; mkdir -p "$root/DEBIAN" "$root/system/bin" "$root/system/usr/share/man/man1"
cp -a "$S/bin/sqlite3" "$root/system/bin/"
"$STRIP" --strip-all "$root/system/bin/sqlite3"
cp -a "$S/usr/share/man/man1/sqlite3.1" "$root/system/usr/share/man/man1/"
control sqlite3 database optional "bionic" "SQLite 3 command-line shell" \
" SQLite is a C library that implements an SQL database engine.
 .
 This package contains the sqlite3 command-line shell.  The shell is
 statically linked against the SQLite amalgamation, so it does not need
 the shared library at run time.
 .
 RUNPATH is set to /system/lib plus the private OpenSSL/xz/lz4 directories
 (/system/usr/local/openssl/lib, /system/usr/local/liblzma/lib,
 /system/usr/local/liblz4/lib) for extensions linked against those copies."
mk sqlite3

echo "done: $OUT"
