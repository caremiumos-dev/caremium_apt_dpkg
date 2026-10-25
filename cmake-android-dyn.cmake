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
set(CMAKE_FIND_ROOT_PATH $ENV{DYNROOT})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

set(OPENSSL_ROOT_DIR $ENV{OSSL})
set(CMAKE_PREFIX_PATH $ENV{DYNROOT}/usr/local/apt $ENV{OSSL})

set(CMAKE_C_FLAGS_INIT   "-O2 -fPIC -DAT_EACCESS=0 -I$ENV{DYN_INC} -I$ENV{OSSL}/include -I$ENV{HOME}/android-deb/buildinclude -I$ENV{HOME}/android-deb/compat")
set(CMAKE_CXX_FLAGS_INIT "-O2 -fPIC -DAT_EACCESS=0 -include $ENV{HOME}/android-deb/compat/android-compat.h -stdlib=libc++ -I$ENV{DYN_INC} -I$ENV{OSSL}/include -I$ENV{HOME}/android-deb/buildinclude -I$ENV{HOME}/android-deb/compat")

set(DEB_RUNPATH /system/usr/local/apt/lib:/system/usr/local/openssl/lib)
set(DEB_LINK "-L$ENV{HOME}/android-deb/compat/lib -L$ENV{DYN_LIB} -L$ENV{OSSL}/lib -Wl,--enable-new-dtags,-rpath,${DEB_RUNPATH}")
set(CMAKE_EXE_LINKER_FLAGS_INIT    "${DEB_LINK}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "${DEB_LINK}")

set(CMAKE_C_STANDARD_LIBRARIES "-lglob")
set(CMAKE_CXX_STANDARD_LIBRARIES "-lglob")
