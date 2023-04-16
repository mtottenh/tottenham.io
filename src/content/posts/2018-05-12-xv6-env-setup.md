---
type: blog
date: "2018-05-12T00:00:00Z"
order: 0
subtitle: Cross compiling with GCC for fun and profit!
title: Kernel Programming (xv6) - Step 0, Build Environments
---

Today we'll go through setting up the development environment for
[XV6](https://pdos.csail.mit.edu/6.828/2016/xv6.html). XV6 is a small Unix
clone developed by MIT to aid in their [6.828 Operating System
Engineering](https://pdos.csail.mit.edu/6.828/2016/) course.  I'm going to be
loosely following along with the course material, but we'll take some extended
detours into topics that I find interesting.  Accompanying the MIT course
material there is also a small book for XV6 that goes through much of the
theory. I'd highly recommend reading it, but it's by no means required if you
just want to follow along with this blog.


This week I'll go through setting up a development environment for either OSX or GNU/Linux. At a minimum we will need:
 
- binutils (One that can create ELF binaries)
- gcc
- qemu (To test our xv6 kernel)
- git

The first thing we need to do is get a copies of gcc/binutils. For GNU/Linux, distro packages for both of these should be adequate.

{{< toc >}}

## Linux build instructions

Linux builds are very easy. You can either use your distro packages, or
you can compile more recent versions from source. The distro packages are going
to be by far the easiest and quickest way to get a functional system.

### Ubuntu
```bash
    $ sudo apt-get install git binutils gcc qemu
```

### Arch
```bash
    $ pacman install git binutils gcc qemu
 ```   
### Fedora
```bash
    $ yum install git binutils gcc qemu
```
## OSX build instructions

Building on OSX is a pain in the ass, In order to run XV6 we will need a
toolchain that is capable of producing ELF executables. OSX uses a different
binary format (Mach-O), and so the default compiler/linker will not be
sufficient (There are also other reasons, for example OSX's libc implementation
won't work with the linux kernel etc.). My initial attempt to build a
cross-compiler for xv6 got pretty far, but for some reason the kernel crashed
qemu when it tried to turn on paging in entry.S

In the end the approach that worked the best was to use crosstools-ng to create
a functional toolchain. That said it wasn't without it's trials and
tribulations, I'm going to detail the steps I took here and hopefully it will
be reproducible:


1. Install [homebrew](https://brew.sh/).
2. Install crosstools-ng pre-requisites.
3. Install crosstools-ng from homebrew, and add some OSX specific patches to linux-4.3 and gcc-7.1.0
4. Create a case sensitive disk image for cross tools-ng to build in (HFS by default is case insensitive and that can screw up the build process).
5. Configure for x86_64-unknown-linux-musl
6. Disable STATIC= , we don't need a statically built toolchain and OSX can't create static binaries
7. run ct-ng build
8. Wait for about an hour to 1:30
9. See if the build failed....


### 1. Install Homebrew

Homebrew should be a familiar tool to Mac/OSX developers, we'll use it to
manage the dependencies for crosstool-ng. You can run the following command
below to install Homebrew directly.

~~~bash
$ /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
~~~
 
### 2. Install Crosstools-ng Pre-requisites.

Crosstools-ng requires GNU Grep (It has a problem with the grep provided by
OSX), and a native version of GCC (by default, gcc on OSX is a symlink to
clang/llvm which doesn't seem to work well with crosstools-ng).
~~~bash
$ brew install grep --default-names
$ brew link grep

$ brew install gcc
$ ln -s /usr/local/bin/gcc-7 /usr/local/bin/gcc
$ ln -s /usr/local/bin/g++-7 /usr/local/bin/g++
~~~

You will also need to ensure that `/usr/local/bin` is in your path:
~~~bash
$ export PATH=/usr/local/bin:$PATH
$ gcc --version
gcc (Homebrew GCC 7.1.0) 7.1.0
Copyright (C) 2017 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

$ grep --version
grep (GNU grep) 3.1
Packaged by Homebrew
Copyright (C) 2017 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by Mike Haertel and others, see <http://git.sv.gnu.org/cgit/grep.git/tree/AUTHORS>. 
~~~
Now that we have the relevant pre-requisites, lets get started with crosstools-ng.

### 2. Crosstools-ng install

Crosstools-ng is available via Homebrew. If you'd like a detailed explanation
about how cross-compilation toolchains are built I'd recommend reading
[this](http://crosstool-ng.github.io/docs/toolchain-construction/) which is a
great overview of the high level steps required.
~~~bash
$ brew install crosstool-ng
$ ct-ng version
This is crosstool-NG version crosstool-ng-1.22.0

Copyright (C) 2008  Yann E. MORIN <yann.morin.1998@free.fr>
This is free software; see the source for copying conditions.
There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.
~~~
Additionally, we need to ensure that crosstools-ng actually uses gnu-grep (the
one in /usr/local/bin), instead of the system grep. To do that we need to edit
the following file `$ sed -i '' 's/=".*\/grep"/="\/usr\/local\/bin\/grep"/'
/usr/local/Cellar/crosstool-ng/1.22.0_1/lib/crosstool-ng-1.22.0/paths.sh`

#### Patch the kernel headers
Now that we have crosstools-ng installed, we need to add two patches. The first
fixes the `__headers:` make target for linux-4.3. The linux kernel headers are
required to build the cross libc implementation, and unfortunately by default
the `__headers:` target in the kernel makefile has a circular dependency, which
can lead to an error like this:
~~~c
....
.../.../relocs.h:12:10: fatal error: 'elf.h' file not found 
#include <elf.h>
         ^ 
~~~
Thankfully the fix is simple enough, I've provided a copy
[here](https://tottenham.io/assets/xv6/patches/0001-fix-kernel-headers-target.patch).
It turns out all we need to do is remove the 'archscripts' dependency from the
kernel Makefile's  `__headers:` target.
~~~git
diff --git a/Makefile b/Makefile
index d5b3739..3762c53 10944
--- a/Makefile
+++ b/Makefile
@@ -1045,7 +1045,7 @@ PHONY += archscripts
 archscripts:
 
 PHONY += __headers
-__headers: $(version_h) scripts_basic asm-generic archheaders archscripts FORCE
+__headers: $(version_h) scripts_basic asm-generic archheaders FORCE
    $(Q)$(MAKE) $(build)=scripts build_unifdef
 
 PHONY += headers_install_all
-- 
2.11.0
~~~

All you need to do is copy that patch into the relevant patches subdirectory for crosstools-ng, note that the linux/4.3 subdir might not exist:
~~~bash
mkdir -p /usr/local/Cellar/crosstool-ng/1.22.0_1/lib/crosstool-ng-1.22.0/patches/linux/4.3
cp ./0001-fix-kernel-headers-target.patch /usr/local/Cellar/crosstool-ng/1.22.0_1/lib/crosstool-ng-1.22.0/patches/linux/4.3/
~~~

#### Patch GCC 7.1.0
The second patch we need is to fix one of GCC's header files. The symptom is an
error like `cfns.gperf:101:1:error: 'const char* libc_name_p(const char*,
unsigned int)' redeclared inline with 'gnu_inline' attribute`. The problem is
that one of the generated source files for GCC 7.1.0 seems to declare a
function as inline whereas the header containing the declaration does not. It
turns out that the patch is relatively simple, it's availalbe
[here](https://tottenham.io/assets/xv6/patches/910-fix-cfns.h.patch):
~~~git
diff --git a/gcc/cp/cfns.gperf b/gcc/cp/cfns.gperf
index 68acd3d..953262f 100644
--- a/gcc/cp/cfns.gperf
+++ b/gcc/cp/cfns.gperf
@@ -22,6 +22,9 @@ __inline
 static unsigned int hash (const char *, unsigned int);
 #ifdef __GNUC__
 __inline
+#ifdef __GNUC_STDC_INLINE__
+__attribute__ ((__gnu_inline__))
+#endif
 #endif
 const char * libc_name_p (const char *, unsigned int);
 %}
diff --git a/gcc/cp/cfns.h b/gcc/cp/cfns.h
index 1c6665d..6d00c0e 100644
--- a/gcc/cp/cfns.h
+++ b/gcc/cp/cfns.h
@@ -53,6 +53,9 @@ __inline
 static unsigned int hash (const char *, unsigned int);
 #ifdef __GNUC__
 __inline
+#ifdef __GNUC_STDC_INLINE__
+__attribute__ ((__gnu_inline__))
+#endif
 #endif
 const char * libc_name_p (const char *, unsigned int);
 /* maximum key range = 391, duplicates = 0 */
-- 
2.11.0
~~~

Similar to the above patch, we just need to copy it into place in the
crosstools-ng patches directory:
~~~bash
mkdir -p /usr/local/Cellar/crosstool-ng/1.22.0_1/lib/crosstool-ng-1.22.0/patches/gcc/7.1.0/
cp ./910-fix-cfns.h.patch /usr/local/Cellar/crosstool-ng/1.22.0_1/lib/crosstool-ng-1.22.0/patches/gcc/7.1.0/
~~~

### 4. Make a case sensitive filesystem image.

Crosstools-ng requires a case-sesnitive filesystem for it's build. By default
OSX uses HFS+ which is case insensitive (irritating), however we can use
hdiutil to create a disk image for us:
~~~bash
$ hdiutil create ~/Desktop/crosstools.dmg -volname "crosstools" -size 10g -fs "Case-sensitive HFS+"
$ hdiutil mount ~/Desktop/crosstools.dmg
~~~
Now we are ready to start configuring crosstools-ng and building our toolchain!


### 5. Configuring Crosstools-ng

The next step is to configure crosstools-ng to build or toolchain. By default
(using the version I have anyway), crosstools-ng doesn't list a x86 target with
musl. Instead I had to run `ct-ng menuconfig` in order for it to show up. I'd
advise against selecting other libc implementations, they take longer to
compile and I couldn't get them to work properly.

~~~bash
$ mkdir -p /Volumes/crosstools/config
$ cd /Volumes/crosstools/config
$ ct-ng list-samples
~~~
If `x86_64-unknown-linux-musl` is among the samples listed then you are in luck! you can go ahead and pick it:
~~~bash
$ ct-ng x86_64-unknown-linux-musl
$ ct-ng show-tuple
x86_64-unknown-linux-musl
~~~

If it's not quite there yet then the following should work:
~~~bash
$ ct-ng menuconfig

# Select x86 as our target
Target options  --->
    Target Architecture (x86)  --->
    Bitness: (64-bit)  --->

# Select Linux as the target OS.
Operating System --->
    Target OS (linux) --->

# Select musl as the C library
C-library --->
    C library (musl) --->

# Disable static linking.
C compiler --->
    [ ] Link libstdc++ statically into the gcc binary (NEW)

# Save
< Exit >
~~~

If all goes well `ct-ng show-tuple` should output `x86_64-unknown-linux-musl`.
Double check to ensure that static linking is not set (or binutils will
complain later):

~~~bash
$ grep 'STATIC' .config
# CT_STATIC_TOOLCHAIN is not set
# CT_CC_GCC_STATIC_LIBSTDCXX is not set
~~~
One final thing to do is to edit the resulting `.config` to ensure that the
tools are built and installed within the filesystem image we created earlier.
Addtionally it would be nice to run a few make jobs in parrallel to speed
things up a bit. The following should do the trick:

~~~bash
sed -i '' 's/CT_PARALLEL_JOBS=.*/CT_PARALLEL_JOBS=4/' .config
sed -i '' 's/CT_WORK_DIR=.*/CT_WORK_DIR="\/Volumes\/crosstools\/.build"/' .config
sed -i '' 's/CT_PREFIX_DIR=.*/CT_PREFIX_DIR="\/Volumes\/crosstools\/xtools\/${CT_TARGET}"/' .config
~~~

Now you are ready to fire off a build using `ct-ng build`.


## Build qemu-system

The final step is in setting up our toolchain is to get a copy of qemu. Qemu is
the emulator we will run the XV6 kernel under. You could probably manage with
installing a copy from Homebrew, but I prefer to compile my copy from source,
I've listed the commands I've used to compile and install qemu below:


~~~bash
$ cd ${TOOL_DIR}/src
$ git clone https://github.com/qemu/qemu.git
$ git checkout v2.9.0
$ ./configure --target-list=x86_64-softmmu  --prefix=~/tools
Install prefix    ~/tools
BIOS directory    ~/tools/share/qemu
binary directory  ~/tools/bin
library directory ~/tools/lib
module directory  ~/tools/lib/qemu
libexec directory ~/tools/libexec
include directory ~/tools/include
config directory  ~/tools/etc
local state directory   ~/tools/var
Manual directory  ~/tools/share/man
ELF interp prefix /usr/gnemul/qemu-%M
Source path       /Users/mtottenh/tools/src/qemu
C compiler        cc
Host C compiler   cc
C++ compiler      c++
Objective-C compiler clang
ARFLAGS           rv
CFLAGS            -O2 -g 
QEMU_CFLAGS       -I/usr/local/Cellar/pixman/0.34.0_1/include/pixman-1  -D_REENTRANT -I/usr/local/Cellar/glib/2.52.3/include/glib-2.0 -I/usr/local/Cellar/glib/2.52.3/lib/glib-2.0/include -I/usr/local/opt/gettext/include -I/usr/local/Cellar/pcre/8.41/include -m64 -mcx16 -DOS_OBJECT_USE_OBJC=0 -arch x86_64 -D_GNU_SOURCE -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -Wstrict-prototypes -Wredundant-decls -Wall -Wundef -Wwrite-strings -Wmissing-prototypes -fno-strict-aliasing -fno-common -fwrapv  -Wno-string-plus-int -Wno-initializer-overrides -Wendif-labels -Wno-shift-negative-value -Wno-missing-include-dirs -Wempty-body -Wnested-externs -Wformat-security -Wformat-y2k -Winit-self -Wignored-qualifiers -Wold-style-definition -Wtype-limits -fstack-protector-strong -I/usr/local/Cellar/gnutls/3.5.16/include -I/usr/local/Cellar/nettle/3.4/include -I/usr/local/Cellar/libtasn1/4.12/include -I/usr/local/Cellar/p11-kit/0.23.9/include/p11-kit-1 -I/usr/local/Cellar/nettle/3.4/include   -I/usr/local/Cellar/libpng/1.6.34/include/libpng16 -I/usr/local/Cellar/libusb/1.0.21/include/libusb-1.0
LDFLAGS           -m64 -framework CoreFoundation -framework IOKit -arch x86_64 -g 
make              make
install           install
python            python -B
smbd              /usr/sbin/smbd
module support    no
host CPU          x86_64
host big endian   no
target list       x86_64-softmmu
tcg debug enabled no
gprof enabled     no
sparse enabled    no
strip binaries    yes
profiler          no
static build      no
Cocoa support     yes
pixman            system
SDL support       no 
GTK support       no 
GTK GL support    no
VTE support       no 
TLS priority      NORMAL
GNUTLS support    yes
GNUTLS rnd        yes
libgcrypt         no
libgcrypt kdf     no
nettle            yes (3.4)
nettle kdf        yes
libtasn1          yes
curses support    no
virgl support     no
curl support      yes
mingw32 support   no
Audio drivers     coreaudio
Block whitelist (rw) 
Block whitelist (ro) 
VirtFS support    no
VNC support       yes
VNC SASL support  yes
VNC JPEG support  yes
VNC PNG support   yes
xen support       no
brlapi support    no
bluez  support    no
Documentation     yes
PIE               no
vde support       no
netmap support    no
Linux AIO support no
ATTR/XATTR support no
Install blobs     yes
KVM support       no
HAX support       yes
RDMA support      no
TCG interpreter   no
fdt support       no
preadv support    no
fdatasync         no
madvise           yes
posix_madvise     yes
libcap-ng support no
vhost-net support no
vhost-scsi support no
vhost-vsock support no
Trace backends    log
spice support     no 
rbd support       no
xfsctl support    no
smartcard support no
libusb            yes
usb net redir     no
OpenGL support    no
OpenGL dmabufs    no
libiscsi support  no
libnfs support    no
build guest agent yes
QGA VSS support   no
QGA w32 disk info no
QGA MSI support   no
seccomp support   no
coroutine backend sigaltstack
coroutine pool    yes
debug stack usage no
GlusterFS support no
gcov              gcov
gcov enabled      no
TPM support       yes
libssh2 support   no
TPM passthrough   no
QOM debugging     yes
lzo support       no
snappy support    no
bzip2 support     yes
NUMA host support no
tcmalloc support  no
jemalloc support  no
avx2 optimization no
replication support yes
$ make -j 4
...
$ make install
...
$ qemu-system-x86_64 --version
QEMU emulator version 2.8.0 (v2.8.0)
Copyright (c) 2003-2016 Fabrice Bellard and the QEMU Project developers
~~~

## Obtaining the XV6 sources

I've forked a copy of the XV6 source tree at `https://github.com/mtottenh/xv6`. If you'd
like to follow along feel free, otherwise you can get access to the upstream
source
```bash
# Upstream source
git clone git://github.com/mit-pdos/xv6-public.git

# OR My Clone.
git clone https://github.com/mtottenh/xv6.git
cd xv6
git checkout week_0
```


Now we just need to add our toolchain to $PATH `export
PATH=$PATH:/Volumes/crosstools/xtools/x86_64-unknown-linux-musl/bin`, and set
$TOOLPREFIX, before running make.

~~~bash
$ export PATH=$PATH:/Volumes/crosstools/xtools/x86_64-unknown-linux-musl/bin
$ TOOLPREFIX=x86_64-unknown-linux-musl- make
~~~

Next, run make qemu and you should be dropped into an xv6 shell! it will look
something like this:

~~~bash
TOOLPREFIX=x86_64-unknown-linux-musl- make qemu
qemu-system-i386 -serial mon:stdio -hdb fs.img xv6.img -smp 2 -m 512 
WARNING: Image format was not specified for 'fs.img' and probing guessed raw.
         Automatically detecting the format is dangerous for raw images, write operations on block 0 will be restricted.
         Specify the 'raw' format explicitly to remove the restrictions.
WARNING: Image format was not specified for 'xv6.img' and probing guessed raw.
         Automatically detecting the format is dangerous for raw images, write operations on block 0 will be restricted.
         Specify the 'raw' format explicitly to remove the restrictions.
xv6...
cpu1: starting
cpu0: starting
sb: size 1000 nblocks 941 ninodes 200 nlog 30 logstart 2 inodestart 32 bmap start 58
init: starting sh
$ 
$ ls
.              1 1 512
..             1 1 512
README         2 2 1973
cat            2 3 13060
echo           2 4 12280
forktest       2 5 8000
grep           2 6 14696
init           2 7 12828
kill           2 8 12356
ln             2 9 12248
ls             2 10 14472
mkdir          2 11 12400
rm             2 12 12376
sh             2 13 23196
stressfs       2 14 12976
usertests      2 15 58192
wc             2 16 13576
zombie         2 17 12056
console        3 18 0
test           1 19 32
$ 
~~~


Next time we are going to step through the boot process, for those who are
interested the files we are going to be peeking at are `Makfile`, `bootmain.c`,
and `bootasm.S`.
