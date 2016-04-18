#!/bin/bash
# Copyright (C) 2013-2016  Lucas Sköldqvist <frusen@gungre.ch>
#
# Based on scripts written by Matias A. Fonzo <selk@dragora.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -e

CWD=$(pwd)

TMP=${TMP:-/tmp/sources}
OUT=${OUT:-/tmp/packages}

# Basic information about the package:
P=sbcl
V=1.3.4
B=1

case "$(uname -m)" in
  i?86) export ARCH=i486
        FLAGS="-march=i486 -mtune=i686"
  ;;
  x86_64) export ARCH=x86_64
          FLAGS="-mtune=generic"
          SUFARCH=64
  ;;
  *) export ARCH=$(uname -m)
esac

# Flags for the compiler:
DCFLAGS=${DCFLAGS:=-O2 ${FLAGS} -D_GNU_SOURCE -fno-omit-frame-pointer -DSBCL_HOME=/usr/lib$SUFARCH/sbcl}

# Jobs:
JOBS=$(nproc)

PKG=${TMP}/package-${P}

rm -rf $PKG
mkdir -p $PKG $OUT

rm -rf ${TMP}/${P}-${V}
echo "Uncompressing the tarball..."
tar -xvf ${CWD}/${P}-${V}-source.tar.bz2 -C $TMP

cd ${TMP}/${P}-${V}

# Set sane ownerships and permissions:
chown -R 0:0 .
find . \
 \( -perm 2777 -o \
    -perm 777  -o \
    -perm 775  -o \
    -perm 711  -o \
    -perm 555  -o \
    -perm 511     \
 \) -exec chmod 755 {} + \
  -o \
 \( -perm 666 -o \
    -perm 664 -o \
    -perm 600 -o \
    -perm 444 -o \
    -perm 440 -o \
    -perm 400    \
 \) -exec chmod 644 {} +

export CFLAGS="$DCFLAGS"
export GNUMAKE="make"
export LINKFLAGS="$LDFLAGS"
unset LDFLAGS
unset MAKEFLAGS

# Make a multi-threaded SBCL and disable LARGEFILE:
cat >customize-target-features.lisp <<EOF
(lambda (features)
  (flet ((enable (x) (pushnew x features))
         (disable (x) (setf features (remove x features))))
  (enable :sb-thread)
  (enable :sb-core-compression)
  (disable :largefile)))
EOF

sh make.sh sbcl --prefix=/usr
make -C doc/manual info
SBCL_HOME="" INSTALL_ROOT="$PKG/usr" sh install.sh

# Remove unwanted files:
find "$PKG" \( -name Makefile -o -name .cvsignore \) -delete

mv $PKG/usr/share/man $PKG/usr/man
mv $PKG/usr/share/info $PKG/usr/info

# Strip binaries & libraries:
( cd $PKG
  find . -type f | xargs file | awk '/ELF/ && /executable/ || /shared object/' | \
   cut -f 1 -d : | xargs strip --strip-unneeded 2> /dev/null
)

# Compress info documents (if needed):
if [ -d ${PKG}/usr/info ] ; then \
  rm -f ${PKG}/usr/info/dir && \
  gzip -9 ${PKG}/usr/info/* ; \
fi

# Compress and link manual pages (if needed):
if [ -d ${PKG}/usr/man ] ; then \
  ( cd ${PKG}/usr/man && \
    find . -type f -exec gzip -9 '{}' ';' && \
    find . -type l | while read file ; do \
      ln -sf $(readlink ${file}).gz ${file}.gz && \
      rm ${file} ; \
    done ; \
  ) ; \
fi

# Copy the documentation:
mkdir -p ${PKG}/usr/doc/${P}-${V}
cp -a \
 COPYING \
 ${PKG}/usr/doc/${P}-${V}

# Copy the description files:
# mkdir -p ${PKG}/description
# cp ${CWD}/description/?? ${PKG}/description/

# Build the package:
cd $PKG
makepkg -l ${OUT}/${P}-${V}-${ARCH}-${B}.tlz
