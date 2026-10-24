# Cross-build environment for apt/dpkg on Android (NDK r21, API 27, armv7a).
#   source ~/android-deb/env.sh
export NDK=/opt/android-ndk-r21
export TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64
export API=27
export TARGET=armv7a-linux-androideabi
export HOST=arm-linux-androideabi

export CC=$TOOLCHAIN/bin/${TARGET}${API}-clang
export CXX=$TOOLCHAIN/bin/${TARGET}${API}-clang++
export AR=$TOOLCHAIN/bin/llvm-ar
export RANLIB=$TOOLCHAIN/bin/llvm-ranlib
export NM=$TOOLCHAIN/bin/llvm-nm
export STRIP=$TOOLCHAIN/bin/llvm-strip
export READELF=$TOOLCHAIN/bin/llvm-readelf
export SYSROOT=$TOOLCHAIN/sysroot

# Final install prefix on device and the staging root used while building.
export PREFIX=/system
export STAGE=$HOME/android-deb/stage
export WORK=$HOME/android-deb/build
export SRC=$HOME/android-deb/src
export OUT=$HOME/android-deb/out
export LOGS=$HOME/android-deb/logs

export CFLAGS="-O2 -fPIC -D__ANDROID_API__=$API -I$HOME/android-deb/buildinclude -I$HOME/android-deb/compat -I$STAGE/system/usr/include"
export CXXFLAGS="-O2 -fPIC -D__ANDROID_API__=$API -stdlib=libc++ -I$STAGE/system/usr/include"
export CPPFLAGS="-I$HOME/android-deb/buildinclude -I$HOME/android-deb/compat -I$STAGE/system/usr/include -I$STAGE/system/usr/local/openssl/include"
export LDFLAGS="-L$STAGE/system/lib"
export PKG_CONFIG_PATH=$STAGE/system/lib/pkgconfig:$STAGE/system/usr/lib/pkgconfig
export PKG_CONFIG_LIBDIR=$PKG_CONFIG_PATH

mkdir -p "$STAGE" "$WORK" "$OUT" "$LOGS"
