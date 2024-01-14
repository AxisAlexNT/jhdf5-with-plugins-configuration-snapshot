#! /bin/bash

source version.sh

if [ -n "$POSTFIX" ]; then
  VERSION="$VERSION-$POSTFIX"
fi

rm -fR build/jni
rm -f build/libjhdf5.so
cp -a jni build/
cp -a *.c build/jni/
cd build
cp hdf5-$VERSION/src/H5win32defs.h jni/
cp hdf5-$VERSION/src/H5private.h jni/

echo "JHDF5 building..."
gcc -shared -O3 -Wl,--exclude-libs,ALL jni/*.c -Ihdf5-${VERSION}-armv6l/include -I/usr/java/jdk1.8.0/include -I/usr/java/jdk1.8.0/include/linux hdf5-${VERSION}-armv6l/lib/libhdf5.a -o libjhdf5.so -lz &> jhdf5_build.log

if [ -f libjhdf5.so ]; then
  cp -pf libjhdf5.so ../../../libs/native/jhdf5/amd64-Linux/
  echo "Build deployed"
else
  echo "ERROR"
fi
