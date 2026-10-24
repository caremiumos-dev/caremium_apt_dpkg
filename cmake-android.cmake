set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(NDK /opt/android-ndk-r21)
set(TOOLCHAIN ${NDK}/toolchains/llvm/prebuilt/linux-x86_64)
set(API 27)
set(TRIPLE armv7a-linux-androideabi)

set(CMAKE_C_COMPILER   ${TOOLCHAIN}/bin/${TRIPLE}${API}-clang)
set(CMAKE_CXX_COMPILER ${TOOLCHAIN}/bin/${TRIPLE}${API}-clang++)
set(CMAKE_AR           ${TOOLCHAIN}/bin/llvm-ar)
set(CMAKE_RANLIB       ${TOOLCHAIN}/bin/llvm-ranlib)
set(CMAKE_STRIP        ${TOOLCHAIN}/bin/llvm-strip)
set(CMAKE_NM           ${TOOLCHAIN}/bin/llvm-nm)

set(CMAKE_SYSROOT ${TOOLCHAIN}/sysroot)
set(CMAKE_FIND_ROOT_PATH $ENV{STAGE}/system)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

set(OPENSSL_ROOT_DIR $ENV{STAGE}/system/usr/local/openssl)

set(CMAKE_C_FLAGS_INIT   "-O2 -fPIC -DAT_EACCESS=0 -I$ENV{HOME}/android-deb/compat -I$ENV{STAGE}/system/usr/include -I$ENV{STAGE}/system/usr/local/openssl/include")
set(CMAKE_CXX_FLAGS_INIT "-O2 -fPIC -DAT_EACCESS=0 -include $ENV{HOME}/android-deb/compat/android-compat.h -stdlib=libc++ -I$ENV{HOME}/android-deb/compat -I$ENV{STAGE}/system/usr/include -I$ENV{STAGE}/system/usr/local/openssl/include")

set(DEB_PRIVATE_LIB /system/usr/local/openssl/lib)
set(CMAKE_EXE_LINKER_FLAGS_INIT    "-L$ENV{HOME}/android-deb/compat/lib -L$ENV{STAGE}/system/lib -L$ENV{STAGE}/system/usr/local/openssl/lib -Wl,--enable-new-dtags,-rpath,${DEB_PRIVATE_LIB}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "-L$ENV{HOME}/android-deb/compat/lib -L$ENV{STAGE}/system/lib -L$ENV{STAGE}/system/usr/local/openssl/lib -Wl,--enable-new-dtags,-rpath,${DEB_PRIVATE_LIB}")

# Append after objects so the static compat lib is pulled in.
set(CMAKE_C_STANDARD_LIBRARIES "-lglob")
set(CMAKE_CXX_STANDARD_LIBRARIES "-lglob")
