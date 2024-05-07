#! /bin/bash
set -e
set -u
set -o pipefail
set -x


source version.sh

#rm -fR build
if [[ ! -d build ]]; then
	echo "Creating build directory"
	mkdir build
fi

cd build
BUILD_ROOT=`pwd`

rm -rf CMake-hdf5-$VERSION

unzip ../CMake-hdf5-$VERSION.zip

if [ -n "$POSTFIX" ]; then
  mv CMake-hdf5-$VERSION CMake-hdf5-$VERSION-$POSTFIX
fi

rm -fR CMake-hdf5-$VERSION/hdf5-$VERSION/java/src/jni
cp -af ../jni CMake-hdf5-$VERSION/hdf5-$VERSION/java/src/
cp -af ../*.c CMake-hdf5-$VERSION/hdf5-$VERSION/java/src/jni/
cp -af ../HDF5options.cmake CMake-hdf5-$VERSION/

cd CMake-hdf5-$VERSION
#patch --ignore-whitespace --fuzz 10 -p1 < ../../cmake_set_hdf5_options.diff

cp -af ../../*.tar.gz .

cd hdf5-$VERSION
patch --ignore-whitespace --fuzz 10 -p2 --force --verbose < ../../../cmake_add_sources.diff

cp -af ../../../CMakeUserPresets.json .
