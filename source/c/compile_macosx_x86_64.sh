#! /bin/bash

source version.sh

if [ -n "$POSTFIX" ]; then
  VERSION="$VERSION-$POSTFIX"
fi

rm -fR build/jni
rm -f build/libjhdf5.jnilib
cp -a jni build/
cp -a *.c build/jni/
cd build
cp hdf5-$VERSION/src/H5win32defs.h jni/
cp hdf5-$VERSION/src/H5private.h jni/

echo "JHDF5 building..."
gcc -m64 -mmacosx-version-min=10.11 -dynamiclib -O3 jni/*.c -Ihdf5-${VERSION}-x86_64/include -I/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/JavaVM.framework/Versions/Current/Headers hdf5-${VERSION}-x86_64/lib/libhdf5.a -o libjhdf5.jnilib -lz &> jhdf5_build.log

if [ -f libjhdf5.jnilib ]; then
  cp -pf libjhdf5.jnilib "../../../libs/native/jhdf5/x86_64-Mac OS X"
  echo "Build deployed"
else
  echo "ERROR"
fi

