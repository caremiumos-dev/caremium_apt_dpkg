#!/bin/bash
# Pre-seeded dpkg database for the *dynamic* apt/dpkg bundle.
#   bash ~/android-deb/gen-db-dyn.sh
set -euo pipefail

ROOT="${ROOT:-$HOME/android-deb/dyn/stage/system}"
DB="$ROOT/usr/var/lib/dpkg"
MAINT="CaremiumOS Developers <caremium-os@googlegroups.com>"
ARCH=armhf

rm -rf "$DB/info" "$DB/updates" "$DB/triggers" "$DB/alternatives" "$DB/parts"
mkdir -p "$DB/info" "$DB/updates" "$DB/triggers" "$DB/alternatives" "$DB/parts"
: > "$DB/status"; : > "$DB/available"; : > "$DB/diversions"; : > "$DB/statoverride"

collect() {
    local pat f sub
    for pat in "$@"; do
        for f in "$ROOT"/$pat; do
            [ -e "$f" ] || [ -L "$f" ] || continue
            if [ -d "$f" ]; then
                while IFS= read -r sub; do printf '%s\n' "${sub#"$ROOT"}"; done \
                    < <(find "$f" \( -type f -o -type l \) | sort)
            else
                printf '%s\n' "${f#"$ROOT"}"
            fi
        done
    done | sort -u | sed '/^$/d'
}

write_pkg() {
    local name=$1 ver=$2 section=$3 prio=$4 depends=$5 desc=$6 size=$7 extra=$8
    shift 8
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
        [ -n "$extra" ] && printf '%b\n' "$extra"
        echo "Description: $desc"
        echo " Pre-seeded package of the Caremium apt/dpkg port for Android."
        echo
    } >> "$DB/status"
    printf '%s\n' "$@" > "$DB/info/$name.list"
}

add() {
    local name=$1 ver=$2 section=$3 prio=$4 depends=$5 desc=$6 extra=$7
    shift 7
    local files size=0 f kb list=()
    files=$(collect "$@")
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        size=$(( size + $(stat -c %s "$ROOT$f") ))
    done <<< "$files"
    kb=$(( size / 1024 + 1 ))
    while IFS= read -r f; do [ -n "$f" ] && list+=("/system$f"); done <<< "$files"
    write_pkg "$name" "$ver" "$section" "$prio" "$depends" "$desc" "$kb" "$extra" "${list[@]}"
}

add_sys() {
    local name=$1 ver=$2 section=$3 prio=$4 depends=$5 desc=$6
    shift 6
    local list=() p
    for p in "$@"; do list+=("/system$p"); done
    write_pkg "$name" "$ver" "$section" "$prio" "$depends" "$desc" 1 "" "${list[@]}"
}

mkdir -p "$ROOT/usr/var/lib/apt/lists/partial" "$ROOT/usr/var/cache/apt/archives/partial" \
         "$ROOT/usr/var/log/apt" "$ROOT/etc/apt/apt.conf.d" "$ROOT/etc/apt/sources.list.d" \
         "$ROOT/etc/apt/preferences.d" "$ROOT/etc/apt/trusted.gpg.d"
: > "$ROOT/usr/var/log/dpkg.log"
cat > "$ROOT/etc/apt/apt.conf.d/00-android" <<'EOF'
Dir "/system";
Dir::State "usr/var/lib/apt/";
Dir::State::status "/var/lib/dpkg/status";
Dir::Cache "usr/var/cache/apt/";
Dir::Log "usr/var/log/apt/";
Dir::Etc "/system/etc/apt/";
Dir::Bin::dpkg "/system/bin/dpkg";
Dir::Bin::methods "/system/usr/libexec/apt/methods";
Dir::Bin::solvers "/system/usr/libexec/apt/solvers";
Dir::Bin::planners "/system/usr/libexec/apt/planners";
APT::Architecture "armhf";
APT::Architectures { "armhf"; };
Acquire::AllowInsecureRepositories "true";
EOF
: > "$ROOT/etc/apt/sources.list"

add_sys bionic 8.1.0 libs required "" "Android C library (bionic: libc, libm, libdl)" \
    /lib/libc.so /lib/libm.so /lib/libdl.so
add_sys zlib1g 1.2.11 libs required "bionic" "zlib compression library" /lib/libz.so

add libbz2-1.0 1.0.8 libs required "bionic" "bzip2 runtime library" "" lib/libbz2.so*
add libzstd1 1.5.7 libs required "bionic" "zstd runtime library" "" lib/libzstd.so*
add libmd0 1.1.0 libs required "bionic" "message digest library" "" lib/libmd.so
add libiconv1 1.18 libs required "bionic" "iconv/charset conversion library" "" lib/libiconv.so lib/libcharset.so
add libdb5.3 5.3.28 libs optional "bionic" "Berkeley DB runtime library" "" lib/libdb-5.3.so lib/libdb.so lib/libdb-5.so
add libxxhash0 0.8.3 libs required "bionic" "xxHash runtime library" "" lib/libxxhash.so*
add libglob0 1.0 libs required "bionic" "glob(3) compatibility library" "" lib/libglob.so
add libc++1 9.0.8 libs required "bionic" "LLVM libc++ runtime" \
    "Replaces: libc++ (<< 9.0.8)\nBreaks: libc++ (<< 9.0.8)\nProvides: libc++" lib/libc++_shared.so
add libapt-pkg7.0 3.0.3 libs important \
    "libbz2-1.0, liblzma5, liblz4-1, libzstd1, libiconv1, libxxhash0, libglob0, libc++1, libssl3, zlib1g, bionic" \
    "APT package management library" "" lib/libapt-pkg.so*

add liblzma5 5.8.4 libs required "bionic" "xz/liblzma runtime (private copy)" "" usr/local/liblzma/lib/liblzma.so
add liblz4-1 1.10.0 libs optional "bionic" "lz4 runtime (private copy)" "" usr/local/liblz4/lib/liblz4.so*
add libssl3 3.0.17 libs required "bionic" "OpenSSL 3 runtime (private copy)" "" \
    usr/local/openssl/lib/libcrypto.so usr/local/openssl/lib/libssl.so
add openssl 3.0.17 utils optional "libssl3 (= 3.0.17), bionic" "OpenSSL 3 tools and headers (private copy)" "" \
    usr/local/openssl/bin usr/local/openssl/include usr/local/openssl/lib/engines-3 usr/local/openssl/lib/ossl-modules

add apt 3.0.3 admin important "libapt-pkg7.0 (= 3.0.3), dpkg (>= 1.22.22), libc++1, libglob0, libssl3" \
    "commandline package manager" "" \
    bin/apt bin/apt-cache bin/apt-cdrom bin/apt-config bin/apt-ftparchive bin/apt-get bin/apt-mark bin/apt-sortpkgs \
    lib/libapt-private.so* usr/libexec/apt etc/apt

add dpkg 1.22.22 admin required "tar (>= 1.35), libbz2-1.0, liblzma5, libzstd1, libmd0, zlib1g, bionic" \
    "Debian package management system" "" \
    bin/dpkg bin/dpkg-architecture bin/dpkg-buildapi bin/dpkg-buildflags bin/dpkg-buildpackage \
    bin/dpkg-buildtree bin/dpkg-checkbuilddeps bin/dpkg-deb bin/dpkg-distaddfile bin/dpkg-divert \
    bin/dpkg-genbuildinfo bin/dpkg-genchanges bin/dpkg-gencontrol bin/dpkg-gensymbols \
    bin/dpkg-maintscript-helper bin/dpkg-mergechangelogs bin/dpkg-name bin/dpkg-parsechangelog \
    bin/dpkg-query bin/dpkg-realpath bin/dpkg-scanpackages bin/dpkg-scansources bin/dpkg-shlibdeps \
    bin/dpkg-source bin/dpkg-split bin/dpkg-statoverride bin/dpkg-trigger bin/dpkg-vendor \
    bin/update-alternatives etc/dpkg etc/alternatives usr/share/dpkg usr/share/perl5 usr/libexec/dpkg

add tar 1.35 utils required "bionic" "GNU tar (replaces toybox tar; used by dpkg-deb)" "" bin/tar

echo "packages: $(grep -c '^Package:' "$DB/status")"
echo "files owned: $(cat "$DB"/info/*.list | wc -l)"
