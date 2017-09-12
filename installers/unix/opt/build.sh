#!/bin/bash
# -*- coding: utf-8 -*-
# vim: tabstop=4 shiftwidth=4 softtabstop=4
#
# Copyright (C) 2010-2017 GEM Foundation
#
# OpenQuake is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# OpenQuake is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with OpenQuake. If not, see <http://www.gnu.org/licenses/>.

if [ $GEM_SET_DEBUG ]; then
    set -x
fi
set -e

unset LD_LIBRARY_PATH

check_dep() {
    for i in $*; do
        command -v $i &> /dev/null || {
            echo -e "!! Please install $i first. Aborting." >&2
            exit 1
        }
    done
}

not_supported() {
    echo "!! This operating system is not unsupported. Aborting." >&2
    exit 1
}

OQ_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OQ_ROOT=/tmp/build-openquake-dist
OQ_DIST=${OQ_ROOT}/qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq
OQ_PREFIX=${OQ_DIST}/prefix
OQ_WHEEL=${OQ_DIST}/wheelhouse

if [ $GEM_SET_NPROC ]; then
    NPROC=$GEM_SET_NPROC
else
    #Everyone has at least two cores
    NPROC=2
fi
if [ $GEM_SET_BRANCH ]; then
    OQ_BRANCH=$GEM_SET_BRANCH
else
    OQ_BRANCH=master
fi

if [ $GEM_SET_BRANCH_TOOLS ]; then
    TOOLS_BRANCH=$GEM_SET_BRANCH_TOOLS
else
    TOOLS_BRANCH=$OQ_BRANCH
fi

if $(echo $OSTYPE | grep -q linux); then
    BUILD_OS='linux64'
    if [ -f /etc/redhat-release ]; then
        check_dep sudo
        sudo yum -q -y upgrade
        sudo yum -q -y groupinstall 'Development Tools'
        sudo yum -q -y install epel-release
        sudo yum -q -y install autoconf bzip2-devel curl git gzip libtool makeself readline-devel spatialindex-devel tar which xz zip zlib-devel
    else
        not_supported
    fi
elif $(echo $OSTYPE | grep -q darwin); then
    BUILD_OS='macos'
    check_dep xcode-select makeself
    sudo xcode-select --install || true
else
    not_supported
fi

rm -Rf $OQ_ROOT
mkdir -p $OQ_PREFIX $OQ_DIST/{wheelhouse,src}
cd $OQ_ROOT

curl -LO http://ftp.gnu.org/gnu/sed/sed-4.2.2.tar.gz
curl -LO https://www.openssl.org/source/openssl-1.0.2l.tar.gz
curl -LO https://www.sqlite.org/2017/sqlite-autoconf-3190200.tar.gz
curl -LO https://www.python.org/ftp/python/2.7.13/Python-2.7.13.tar.xz

cat <<EOF >> $OQ_PREFIX/env.sh
PREFIX=$OQ_PREFIX

export LD_LIBRARY_PATH=\${PREFIX}/lib
export CPATH=\${PREFIX}/include
export PATH=\${PREFIX}/bin:\${PATH}
export PS1=(openquake)\${PS1}
EOF
if [ "$BUILD_OS" == "macos" ]; then
    cat <<EOF >> $OQ_PREFIX/env.sh
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
EOF
fi

source $OQ_PREFIX/env.sh

tar xf sed-4.2.2.tar.gz
cd sed-4.2.2
./configure --prefix=$OQ_PREFIX
make -s -j $NPROC
make -s install
cd ..

tar xf openssl-1.0.2l.tar.gz
cd openssl-1.0.2l/
if [ "$BUILD_OS" == "macos" ]; then
    ./Configure darwin64-x86_64-cc shared enable-ec_nistp_64_gcc_128 no-ssl2 no-ssl3 no-comp --prefix=$OQ_PREFIX
else
    ./config shared --prefix=$OQ_PREFIX
fi
make -s -j $NPROC depend
make -s -j $NPROC
make -s install
cd ..

tar xf sqlite-autoconf-3190200.tar.gz
cd sqlite-autoconf-3190200
./configure --prefix=$OQ_PREFIX
make -s -j $NPROC
make -s install
cd ..

tar xJf Python-2.7.13.tar.xz
cd Python-2.7.13
./configure --prefix=$OQ_PREFIX --enable-unicode=ucs4 --with-ensurepip
make -s -j $NPROC
make -s install
cd ..

$OQ_PREFIX/bin/python2.7 -m pip -q install wheel

rm -Rf oq-engine
git clone -q --depth=1 -b $OQ_BRANCH https://github.com/gem/oq-engine.git

rm -Rf oq-platform*
git clone -q --depth=1 -b $OQ_BRANCH https://github.com/gem/oq-platform-standalone.git
git clone -q --depth=1 -b $OQ_BRANCH https://github.com/gem/oq-platform-ipt.git
git clone -q --depth=1 -b $OQ_BRANCH https://github.com/gem/oq-platform-taxtweb.git
git clone -q --depth=1 -b $OQ_BRANCH https://github.com/gem/oq-platform-taxonomy.git

$OQ_PREFIX/bin/python2.7 -m pip -q wheel -r oq-engine/requirements-py27-${BUILD_OS}.txt -w $OQ_WHEEL

cd oq-engine
$OQ_PREFIX/bin/python2.7 -m pip -q wheel --no-deps . -w $OQ_WHEEL
declare OQ_$(echo 'engine' | tr '[:lower:]' '[:upper:]')_DEV=$(git rev-parse --short HEAD)
cd ..

mkdir ${OQ_WHEEL}/tools
for app in oq-platform-*; do
    $OQ_PREFIX/bin/python2.7 -m pip -q wheel --no-deps ${app}/ -w ${OQ_WHEEL}/tools
done

cp -R ${OQ_ROOT}/oq-engine/{README.md,LICENSE,demos,doc} ${OQ_DIST}/src
rm -Rf ${OQ_DIST}/src/doc/sphinx

# Make a zipped copy of each demo
${OQ_ROOT}/oq-engine/helpers/zipdemos.sh ${OQ_DIST}/src/demos

## utils is not copied for now, since it does not contain anything useful here
cp ${OQ_DIR}/install.sh ${OQ_DIST}

echo "Creating installation package"
makeself -q ${OQ_DIST} ${OQ_DIR}/openquake-py27-${BUILD_OS}-${OQ_ENGINE_DEV}.run "installer for the OpenQuake Engine" ./install.sh

exit 0
