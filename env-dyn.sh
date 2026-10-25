DYN=$HOME/android-deb/dyn
DYNROOT=$DYN/stage/system
DYN_LIB=$DYNROOT/usr/local/apt/lib
DYN_INC=$DYNROOT/usr/local/apt/include
OSSL=$DYNROOT/usr/local/openssl
export CPPFLAGS="-I$DYN_INC -I$OSSL/include -I$HOME/android-deb/buildinclude -I$HOME/android-deb/compat -I$DYNROOT/usr/include"
export CFLAGS="-O2 -fPIC -D__ANDROID_API__=27 -I$DYN_INC -I$OSSL/include -I$HOME/android-deb/buildinclude -I$HOME/android-deb/compat"
export CXXFLAGS="-O2 -fPIC -D__ANDROID_API__=27 -stdlib=libc++ -I$DYN_INC -I$OSSL/include -I$HOME/android-deb/buildinclude -I$HOME/android-deb/compat"
export LDFLAGS="-L$DYN_LIB -L$OSSL/lib -Wl,--enable-new-dtags,-rpath,/system/usr/local/apt/lib:/system/usr/local/openssl/lib"
export PKG_CONFIG_PATH=$DYN_LIB/pkgconfig:$OSSL/lib/pkgconfig
export PKG_CONFIG_LIBDIR=$PKG_CONFIG_PATH
