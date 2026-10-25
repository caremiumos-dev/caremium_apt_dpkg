# apt / dpkg for Android (Caremium, armhf, API 27)

用 `/opt/android-ndk-r21` 交叉编译，目标为 `/system` 前缀、`armhf`（armv7a, Android 8.1/API 27）。

## 目录

```
~/android-deb/
├── env.sh                 # 交叉编译环境（source 后使用）
├── cmake-android.cmake    # apt 用的 CMake toolchain
├── src/                   # 上游源码 + 补丁后的 apt/dpkg
├── build/                 # 各库构建目录（apt 在 build/apt）
├── compat/                # bionic 兼容层（glob / getservbyport_r / dn_skipname）
├── hostbin/triehash       # apt 构建所需的 triehash（Perl）
├── logs/                  # 各步骤日志
├── stage/system/          # ★ 最终要拷贝到设备 /system 的树
└── out/                   # 打包产物
```

## 版本

| 组件 | 版本 | 说明 |
|---|---|---|
| dpkg / libdpkg | 1.22.22 | 上游最新稳定；`libdpkg.a`（上游不提供 .so） |
| apt / libapt-pkg / libapt-private | 3.0.3 | Debian 13 stable；apt 3.3.x 需要 C++23，NDK r21 的 clang 9 不支持 |
| bzip2 | 1.0.8 | 静态 |
| xz / liblzma | 5.8.4 | 共享 |
| zstd / libzstd | 1.5.7 | 静态 |
| lz4 / liblz4 | 1.10.0 | 静态 |
| openssl / libcrypto / libssl | 3.0.17 | 共享（SONAME 无版本后缀，适合 Android） |
| libmd | 1.1.0 | dpkg 1.22 必需 |
| libiconv | 1.18 | apt 必需（bionic 无 iconv） |
| Berkeley DB | 5.3.28 | apt-ftparchive / apt 必需 |
| xxhash | 0.8.3 | apt 3.0 必需 |
| libc++ | NDK r21 的 `libc++_shared.so` | 随包提供 |

## 安装到设备

```sh
# 设备上 /system 可写时（或先 remount）
cp -a ~/android-deb/stage/system/. /system/
```

### 文件布局（不覆盖任何系统自带的库/命令）

| 路径 | 内容 |
|---|---|
| `/system/bin` | `apt*`、`dpkg*`（设备原本没有这些名字） |
| `/system/lib` | `libapt-pkg.so*`、`libapt-private.so*`、`libc++_shared.so`、各 `.a` |
| `/system/usr/libexec/apt` | apt 的 methods/solvers/planners |
| `/system/usr/local/openssl` | `libcrypto.so`、`libssl.so`、`include/`、`bin/openssl`（私有） |
| `/system/usr/share/dpkg` | dpkg 的 cputable/ostable 等 |
| `/system/usr/include` | `apt-pkg/`、`dpkg/` 头文件 |
| `/system/usr/var` | dpkg 数据库、apt lists/cache/log |
| `/system/etc` | `apt/`、`dpkg/` 配置 |

关键点：
- **OpenSSL 装在 `/system/usr/local/openssl/lib`**，所有需要它的 ELF 都带
  `DT_RUNPATH=/system/usr/local/openssl/lib`（bionic 支持 DT_RUNPATH），
  不会加载到系统自带的 BoringSSL。
- `liblzma/liblz4/libzstd/libbz2/libmd/libiconv/glob` 全部静态链接，
  `/system/lib` 里没有这些 `.so`。
- 与设备 system 镜像的 `/lib`、`/bin` 逐项比对：无同名冲突。
- `libc++_shared.so` 是设备上没有的 soname（设备只有 `libc++.so`），安全。

已包含的初始 dpkg 数据库（空库，可直接被 dpkg/apt 使用）：

```
/system/usr/var/lib/dpkg/{status,available,diversions,statoverride}
/system/usr/var/lib/dpkg/{info,updates,triggers,alternatives,parts}/
/system/usr/var/log/dpkg.log
/system/usr/var/lib/apt/lists/partial
/system/usr/var/cache/apt/archives/partial
/system/etc/apt/{sources.list,apt.conf.d/00-android,preferences.d,trusted.gpg.d}
```

`/system/etc/apt/apt.conf.d/00-android` 里显式写了路径（`/var/lib/dpkg/status`
在设备上经 `/var -> /system/usr/var` 指向我们的库）与 `APT::Architecture "armhf"`。

用法：

```sh
dpkg -i foo_1.0_armhf.deb
dpkg -l
apt-get update          # 需要 sources.list，且仓库必须标 [trusted=yes]
apt-get install foo
```

## 对上游源码的补丁（都在 src/ 里）

apt-3.0.3：

1. `CMake/apti18n.h.in`：去掉 `setlocale/textdomain/bindtextdomain/dgettext`
   内联声明上的 `throw()`（bionic 的同名声明没有 noexcept，否则重定义报错）。
2. `apt-pkg/contrib/fileutl.cc`：`ZSTD_inBuffer/ZSTD_outBuffer.size` 加
   `static_cast<size_t>`（32 位下 `unsigned long long` → `size_t` 收窄是硬错误）。
3. `apt-pkg/solver3.h`：新增 `fifo<T>`（基于 `std::vector`），替换
   `std::queue<Var>`。`Var` 在头文件里只有前向声明，libc++ 会在类定义时急切
   实例化 `std::deque` 的块大小而失败（libstdc++ 是惰性的）。
4. `methods/connect.cc`：`getsockopt` 的长度参数改为 `socklen_t`。
5. `apt-private/private-download.cc`：`RAMFS_MAGIC` 改名 `RAMFS_MAGIC_VALUE`
   （与 bionic `<linux/magic.h>` 的宏冲突）。
6. `apt-private/private-output.cc`、`ftparchive/apt-ftparchive.cc`：
   补 `#include <array>`（libstdc++ 会间接包含，libc++ 不会）。

dpkg：无源码补丁。configure 用 `--host=arm-linux-gnueabihf` 只是为了让
dpkg 的 `cputable/ostable` 识别出 `armhf`（编译器仍由 CC/CFLAGS 指定为 NDK clang）。

## bionic 兼容层（compat/）

- `glob.c`：bionic 在 API 28 才有 `glob()/globfree()`；这里实现最小可用版本
  （`* ? [...]`，按路径分量递归）。
- `netcompat.c`：`getservbyport_r()`（bionic 无非重入版）、`dn_skipname()`。
- `android-compat.h`：通过 `-include` 强制注入上述声明。
- `-DAT_EACCESS=0`：bionic 无此宏，`faccessat` 传 0。
- `libutil.so`/`libresolv.so` 在链接期指向 NDK 的 `libc.so`（符号都在 libc 里）。

## 已知限制

- **没有 gpgv**：`apt-get update` 只接受 `[trusted=yes]` 的仓库
  （`Acquire::AllowInsecureRepositories` 已打开）。要支持签名仓库，还需移植
  gnupg 的 gpgv（依赖 libgpg-error + libgcrypt）。
- dpkg 的 Perl 工具（`dpkg-maintscript-helper`、`dpkg-buildpackage` 等）在
  设备上没有 perl 无法运行；`dpkg -i` / `dpkg -r` / `dpkg-deb` / `apt-get`
  主流程不依赖它们。
- `libz.so` 未随包提供（设备 `/system/lib/libz.so` 已存在；NDK 里的
  `27/libz.so` 只是链接桩，不能安装）。
- 只测过 armhf；arm64/x86 需要重新用对应 NDK target 编译。

## 预置 dpkg 数据库（20 个包）

`gen-db.sh` 会按实际安装的文件生成 `/system/usr/var/lib/dpkg/{status,info/*.list}`，
所以装完直接 `dpkg -l` / `apt list --installed` 就能看到：

```
bionic 8.1.0            zlib1g 1.2.11          libc++ 9.0.8
libssl3 3.0.17          openssl 3.0.17         libapt-pkg7.0 3.0.3
libapt-pkg-dev 3.0.3    apt 3.0.3              dpkg 1.22.22
libdpkg-dev 1.22.22     tar 1.35               libbz2-dev 1.0.8
liblzma-dev 5.8.4       liblz4-dev 1.10.0      libzstd-dev 1.5.7
libmd-dev 1.1.0         libiconv-dev 1.18      libdb-dev 5.3.28
libxxhash-dev 0.8.3     libglob-dev 1.0
```

依赖链是完整的（`apt → libapt-pkg7.0 → libc++/libssl3/bionic`，
`dpkg → tar → bionic`），apt 不会报缺依赖。

## GNU tar 替换 toybox tar

`tar 1.35` 直接装在 **`/system/bin/tar`**（覆盖原来的 toybox tar 符号链接）。
GNU tar 兼容 toybox tar 的常用参数，并且 dpkg-deb 需要的
`--warning=no-timestamp`、`--clamp-mtime`、`--owner root:0` 等只有 GNU tar 支持。
dpkg 编译时 `TAR` 已固定为 `/system/bin/tar`。

## 从源码重建（简要）

```sh
# 1. 依赖库（静态链入，装在 stage/ 里）
#    bzip2 1.0.8 / xz 5.8.4 / zstd 1.5.7 / lz4 1.10.0 / openssl 3.0.17
#    libmd 1.1.0 / libiconv 1.18 / db 5.3.28 / xxhash 0.8.3 / tar 1.35
#    全部用 NDK r21、--prefix=/system/usr（openssl 用 /system/usr/local/openssl）
source env.sh
# 各库 ./configure --host=$HOST ... && make && make install DESTDIR=$STAGE

# 2. dpkg 1.22.22
cd dpkg-1.22.22
TAR=/usr/bin/tar ./configure --host=arm-linux-gnueabihf \
  --prefix=/system/usr --libdir=/system/lib --bindir=/system/bin \
  --sbindir=/system/bin --libexecdir=/system/usr/libexec \
  --sysconfdir=/system/etc --localstatedir=/system/usr/var \
  --sharedstatedir=/system/usr/var/lib \
  --with-liblzma --with-libbz2 --with-libzstd --without-libselinux \
  --disable-dselect --disable-nls --disable-start-stop-daemon
# configure 的 TAR 探测要执行 host 二进制，因此编完把 config.h 改成设备路径：
sed -i 's|#define TAR "/usr/bin/tar"|#define TAR "/system/bin/tar"|' config.h
make -j8 && make install DESTDIR=$STAGE

# 3. apt 3.0.3（先打补丁）
cd apt-3.0.3 && patch -p1 < ../patches/apt-3.0.3-android.patch
cmake -DCMAKE_TOOLCHAIN_FILE=$HOME/android-deb/cmake-android.cmake \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DTRIEHASH_EXECUTABLE=$HOME/android-deb/hostbin/triehash \
  -DDPKG_DATADIR=/system/usr/share/dpkg -DCOMMON_ARCH=armhf \
  -DCMAKE_INSTALL_PREFIX=/system -DCMAKE_INSTALL_BINDIR=bin -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_INSTALL_LIBEXECDIR=usr/libexec -DCMAKE_INSTALL_DATADIR=usr/share \
  -DCMAKE_INSTALL_SYSCONFDIR=etc -DCMAKE_INSTALL_LOCALSTATEDIR=usr/var \
  -DWITH_DOC=OFF -DWITH_TESTS=OFF -DUSE_NLS=OFF -DCMAKE_BUILD_TYPE=Release
make -j8 && make install DESTDIR=$STAGE

# 4. 生成预置 dpkg 数据库
bash gen-db.sh

# 5. 打包
tar --owner=0 --group=0 --numeric-owner -czf caremium-apt-dpkg-armhf.tar.gz -C stage system
```

`compat/` 里的 `glob.c`/`netcompat.c` 编译成 `libglob.a` 并静态链入 apt（bionic
在 API 28 之前没有 `glob()`，也没有 `getservbyport_r()`/`dn_skipname()`）。

## 动态链接版（mkdebs-dyn.sh）

apt/dpkg 不再静态链接第三方库，依赖按 Debian 方式拆成独立 deb：

```sh
source env.sh && source dyn/env-dyn.sh
# 依赖库用 --host=arm-linux-androideabi、--enable-shared --disable-static 构建
cmake -DCMAKE_TOOLCHAIN_FILE=dyn/cmake-android-dyn.cmake ...   # apt
bash mkdebs-dyn.sh                                             # 生成 16 个 deb
```

库的安装位置：

| 情况 | 位置 |
|---|---|
| 与系统库无冲突 | `/system/lib`（libbz2/libzstd/libmd/libiconv/libdb/libxxhash/libglob/libc++/libapt-pkg） |
| 与系统库冲突 | 各自的 `/system/usr/local/<name>/lib`（`liblzma`、`liblz4`、`openssl`） |

所有 ELF 都带 `DT_RUNPATH=/system/usr/local/liblzma/lib:/system/usr/local/liblz4/lib:/system/usr/local/openssl/lib`。

dpkg 支持 `--host=arm-linux-androideabi`：补丁 `patches/dpkg-1.22.22-androideabi.patch`
在 `data/ostable` 增加 `linux-androideabi`、`data/tupletable` 映射到 `armhf/arm64`
（config.sub 本身已接受该三元组），因此不再需要用 `gnueabihf` 冒充。

生成的 deb：`libbz2-1.0 libzstd1 libmd0 libiconv1 libdb5.3 libxxhash0 libglob0
libc++1 liblzma5 liblz4-1 libssl3 openssl libapt-pkg7.0 apt dpkg tar`

## bionic-compat 包

`bionic-compat` / `bionic-compat-dev` / `bionic-compat-static` 把 bionic < API 28
缺的符号做成独立库（`mkdebs-compat.sh`）：

- `glob()`/`globfree()`（bionic API 28 才有）
- `getservbyport_r()`、`dn_skipname()`
- busybox 额外用到的 `getusershell()` 家族、`getrandom()`、`ether_hostton()`、
  `sigisemptyset()`、`gethostid()`、`getlogin_r()`、`syncfs()`（全部 weak，
  避免和 bionic 静态库重复定义）

库名 `libbionic-compat.so`/`.a`，头文件 `glob.h`/`bionic-compat.h`。

## fastfetch 2.66.0

`patches/fastfetch-2.66.0-android.patch`（2.67+ 需要 C23，NDK r21 的 clang 9 不支持）：

- `library.h` 去掉 `__VA_OPT__`
- Android 下关闭自动 EGL 检测（无 `GL/gl.h`）
- `users_linux.c` 补 `endutxent -> endutent`
- `codec_android.c` 换成 stub（依赖 API 29 的 `AMediaCodec_getName`）
- Android 跳过 `utmpx.h` 检测

依赖 `bionic-compat`；安装到 `/system/bin/fastfetch`。

## busybox 1.36.1

基于上游 `configs/android_ndk_defconfig`，`CONFIG_EXTRA_LDLIBS="bionic-compat"`，
`patches/busybox-1.36.1-android.patch` 处理 `struct in6_ifreq` 重复定义与
`setbit/clrbit` 宏。

- `busybox`：动态链接，仅装 `/system/bin/busybox`（不建 applet 符号链接）
- `busybox-static`：静态链接，仅装 `/system/bin/busybox`
- 两者 `Conflicts/Replaces` 互斥
