#! /bin/bash

source version.sh

if [ -n "$POSTFIX" ]; then
  VERSION="$VERSION-$POSTFIX"
fi

if [ -z "$JAVA_HOME" ]; then
  JAVA_HOME=`java -XshowSettings:properties -version 2>&1 | grep "java.home" | cut -d"=" -f2`
fi

rm -fR build/jni
rm -f build/libjhdf5.jnilib
cp -a jni build/
cp -a *.c build/jni/
cd build
cp hdf5-$VERSION/src/H5win32defs.h jni/
cp hdf5-$VERSION/src/H5private.h jni/

echo "JHDF5 building..."
pwd
gcc -Wno-error=implicit-function-declaration -m64 -mmacosx-version-min=10.11 -dynamiclib -O3 jni/*.c -Ihdf5-${VERSION}-aarch64/include -I${JAVA_HOME}/include hdf5-${VERSION}-aarch64/lib/libhdf5.a -o libjhdf5.jnilib -lz &> jhdf5_build.log

if [ -f libjhdf5.jnilib ]; then
  cp -pf libjhdf5.jnilib "../../../libs/native/jhdf5/aarch64-Mac OS X"
  echo "Build deployed"
else
  echo "ERROR"
fi

