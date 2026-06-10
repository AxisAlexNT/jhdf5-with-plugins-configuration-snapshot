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

PREPARED_DIR="CMake-hdf5-$VERSION"
if [ -n "$POSTFIX" ]; then
  PREPARED_DIR="CMake-hdf5-$VERSION-$POSTFIX"
  rm -rf "$PREPARED_DIR"
  mv CMake-hdf5-$VERSION "$PREPARED_DIR"
fi

rm -fR "$PREPARED_DIR/hdf5-$VERSION/java/src/jni"
cp -af ../jni "$PREPARED_DIR/hdf5-$VERSION/java/src/"
cp -af ../*.c "$PREPARED_DIR/hdf5-$VERSION/java/src/jni/"
cp -af ../HDF5options.cmake "$PREPARED_DIR/"

cd "$PREPARED_DIR"
#patch --ignore-whitespace --fuzz 10 -p1 < ../../cmake_set_hdf5_options.diff

cp -af ../../*.tar.gz .

cd hdf5-$VERSION
if patch --ignore-whitespace --fuzz 10 -p2 < ../../../cmake_add_sources.diff; then
  echo "Applied JNI patch"
else
  if [[ -f java/src/jni/CMakeLists.txt.rej ]]; then
    echo "JNI patch was already applied or partially applied; continuing with current jni sources."
    rm -f java/src/jni/CMakeLists.txt.rej
  else
    echo "JNI patch failed unexpectedly."
    exit 1
  fi
fi

cp -af ../../../CMakeUserPresets.json .
