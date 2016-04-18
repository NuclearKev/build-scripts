#!/bin/sh
# Copyright (C) 2014  Mateus Rodrigues <mprodrigues@openmailbox.org>
#
# Based on scripts written by Matias A. Fonzo <selk@dragora.org> 
# and Lucas Sköldqvist <frusen@gungre.ch>
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
P=Python
V=2.7.11
B=1

# Define target architecture:
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
DCFLAGS=${DCFLAGS:=-O2 ${FLAGS}}

# Jobs:
JOBS=$(nproc)

PKG=${TMP}/package-${P}

rm -rf $PKG
mkdir -p $PKG $OUT

rm -rf ${TMP}/${P}-${V}
echo "Uncompressing the tarball..."
tar -xf ${CWD}/${P}-${V}.tar.xz -C $TMP

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

CXX=g++ \
OPT="$DCFLAGS" \
./configure \
 --prefix=/usr \
 --mandir=/usr/man \
 --enable-shared \
 --enable-ipv6 \
 --build=${ARCH}-dragora-linux-gnu

SHORT_VER=2.7

make -j$JOBS
make install DESTDIR=$PKG

# Make python soft link:
# ( cd ${PKG}/usr/bin
#   mv python python${SHORT_VER}
#   ln -s python${SHORT_VER} python
# )

# Strip commentaries and notes:
( cd $PKG
  find . -type f | xargs file | awk '/ELF/ && /executable/ || /shared object/' | \
   cut -f 1 -d : | xargs strip --remove-section=.comment --remove-section=.note 2> /dev/null
)

# Includes the Python tools under site-packages:
( cd Tools
  # No overwrite the README file in site-packages directory:
  if [[ -r README ]]; then
    mv README README.Tools
  fi
  cp -rPp * ${PKG}/usr/lib/python${SHORT_VER}/site-packages
)

# Make some symlinks (just in case):
TOOL_DIR=/usr/lib/python${SHORT_VER}/site-packages
( cd ${PKG}/usr/bin
  ln -sf ${TOOL_DIR}/i18n/msgfmt.py msgfmt.py
  ln -sf ${TOOL_DIR}/i18n/pygettext.py pygettext.py 
  ln -sf ${TOOL_DIR}/modulator/modulator.py modulator
  ln -sf ${TOOL_DIR}/pynche/pynche pynche
)
CXX=g++ \
OPT="$DCFLAGS" \
./configure \
 --prefix=/usr \
 --mandir=/usr/man \
 --enable-shared \
 --with-threads \
 --enable-ipv6 \
 --build=${ARCH}-dragora-linux-gnu

make -j$JOBS
make install DESTDIR=$PKG

# Make python soft link:
# ( cd ${PKG}/usr/bin
#   mv python python${SHORT_VER}
#   ln -s python${SHORT_VER} python
# )

# Strip commentaries and notes:
( cd $PKG
  find . -type f | xargs file | awk '/ELF/ && /executable/ || /shared object/' | \
   cut -f 1 -d : | xargs strip --remove-section=.comment --remove-section=.note 2> /dev/null
)

# Includes the Python tools under site-packages:
( cd Tools
  # No overwrite the README file in site-packages directory:
  if [[ -r README ]]; then
    mv README README.Tools
  fi
  cp -rPp * ${PKG}/usr/lib/python${SHORT_VER}/site-packages
)

# Make some symlinks (just in case):
TOOL_DIR=/usr/lib/python${SHORT_VER}/site-packages
( cd ${PKG}/usr/bin
  ln -sf ${TOOL_DIR}/i18n/msgfmt.py msgfmt.py
  ln -sf ${TOOL_DIR}/i18n/pygettext.py pygettext.py 
  ln -sf ${TOOL_DIR}/modulator/modulator.py modulator
  ln -sf ${TOOL_DIR}/pynche/pynche pynche
)

# Compress and link manual pages (if needed)
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
# mkdir -p ${PKG}/usr/doc/${P}-${V}
# cp -a \
#  LICENSE README \
#  ${PKG}/usr/doc/${P}-${V}

# Copy the description files:
# mkdir -p ${PKG}/description
# cp ${CWD}/description/?? ${PKG}/description/

# Build the package:
cd $PKG
makepkg -l ${OUT}/${P}-${V}-${ARCH}-${B}.tlz
