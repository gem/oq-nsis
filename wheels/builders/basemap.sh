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

cd /tmp/src

curl -Lo basemap-master.tar.gz https://github.com/matplotlib/basemap/archive/master.tar.gz
tar xf basemap-master.tar.gz
cd basemap-master/geos-3.3.3
export GEOS_DIR=/usr/local
./configure --prefix=$GEOS_DIR
make -j $NPROC
make install

cd ..

get numpy pyshp pyproj matplotlib==1.5.3 pillow
build .

post