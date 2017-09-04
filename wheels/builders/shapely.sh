#!/bin/bash
# -*- coding: utf-8 -*-
# vim: tabstop=4 shiftwidth=4 softtabstop=4
#
# Copyright (C) 2016-2017 GEM Foundation
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

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ -z $OQ_ENV_SET ]; then source $MYDIR/../build-common.sh; fi


yum install -y autoconf curl gzip tar
build_libtool

build_dep geos

cd /tmp/src

# Shapely 1.5 needs a patch to be able to use libgeos included by auditwheel.
# This patch has been included in the 1.6 release tree.
curl -Lo Shapely-1.5.13.tar.gz https://github.com/Toblerity/Shapely/archive/1.5.13.tar.gz
tar xf Shapely-1.5.13.tar.gz
cd Shapely-1.5.13
patch -p1 < $MYDIR/shapely/libgeos_wheel.patch
build .

post
