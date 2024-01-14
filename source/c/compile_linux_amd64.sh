#! /bin/bash

source version.sh

JVM_INCLUDE_PATH="/usr/lib/jvm/java-1.8.0/include/"
JVM_INCLUDE_PATH="/usr/lib/jvm/java-8-openjdk-amd64/include/"

if [ -n "$POSTFIX" ]; then
  VERSION="$VERSION-$POSTFIX"
fi

if [[ ! -z "" ]]; then
	rm -fR build/jni
	rm -f build/libjhdf5.so
	cp -a jni build/
	cp -a *.c build/jni/
	cd build
	cp hdf5-$VERSION/src/H5win32defs.h jni/
	cp hdf5-$VERSION/src/H5private.h jni/

	echo "JHDF5 building..."
	gcc -shared -O3 -mtune=corei7 -fPIC -Wl,--exclude-libs,ALL jni/*.c -Ihdf5-${VERSION}-amd64/include -I/usr/lib/jvm/java-1.8.0/include -I/usr/lib/jvm/java-1.8.0/include/linux hdf5-${VERSION}-amd64/lib/libhdf5.a -o libjhdf5.so -lz &> jhdf5_build.log

	if [ -f libjhdf5.so ]; then
	  cp -pf libjhdf5.so ../../../libs/native/jhdf5/amd64-Linux/
	  echo "Build deployed"
	else
	  echo "ERROR"
	fi
fi

#cd build

SRCDIR=$(realpath build/hdf5-$VERSION/hdf5-$VERSION/)
BUILDDIR=$(realpath build)

rm -rf $BUILDDIR/jni
rm -f $BUILDDIR/libjhdf5.so
cp -a jni $BUILDDIR/
cp -a *.c $BUILDDIR/jni/
cd $BUILDDIR
cp $SRCDIR/src/H5win32defs.h $BUILDDIR/jni/
cp $SRCDIR/src/H5private.h $BUILDDIR/jni/

PDIR="$BUILDDIR/hdf5-$VERSION/build110/hict-StdShar-GNUC/_CPack_Packages/Linux/TGZ/HDF5-1.10.11-Linux/HDF_Group/HDF5/1.10.11/"
BDIR="$BUILDDIR/hdf5-$VERSION/build110/hict-StdShar-GNUC/"



rm -rf jhdf5*.std*.log jhdf5*.so
echo "JHDF5 building..."
if [[ ! -z "" ]]; then
	gcc \
		-shared -O3 -march=native -mtune=znver3 -fPIC \
		-Wl,--exclude-libs,ALL \
		$BUILDDIR/jni/*.c \
		-I"$PDIR/include" \
		-I$BDIR/src \
		-I$SRCDIR/src \
		-I$JVM_INCLUDE_PATH \
		-I$JVM_INCLUDE_PATH/linux \
		"$BDIR/bin/libhdf5.a" \
		$(find $BDIR -type f -name "*.a" | xargs -n1 realpath) \
		-o libjhdf5.so -lz \
			> >(tee -a jhdf5.stdout.log) 2> >(tee -a jhdf5.stderr.log >&2)
			
	gcc \
		-shared -O3 -march=native -mtune=znver3 -fPIC \
		$BUILDDIR/jni/*.c \
		-I"$PDIR/include" \
		-I$BDIR/src \
		-I$SRCDIR/src \
		-I$JVM_INCLUDE_PATH \
		-I$JVM_INCLUDE_PATH/linux \
		"$BDIR/bin/libhdf5.a" \
		$(find $BDIR -type f -name "*.a" | xargs -n1 realpath) \
		-o libjhdf5_export.so -lz \
			> >(tee -a jhdf5_export.stdout.log) 2> >(tee -a jhdf5_export.stderr.log >&2)
fi
		
gcc \
	-shared -O3 -march=native -mtune=znver3 -fPIC \
	$BUILDDIR/jni/*.c  \
	-I"$PDIR/include" \
	-I$BDIR/src \
	-I$SRCDIR/src \
	-I$JVM_INCLUDE_PATH \
	-I$JVM_INCLUDE_PATH/linux \
	-L"$BDIR/bin" -l:libhdf5.so \
	$(find $BDIR -type f -name "*.a" | xargs -n1 realpath) \
	-o libjhdf5_export_sharedlink.so -lz \
		> >(tee -a jhdf5_export_sharedlink.stdout.log) 2> >(tee -a jhdf5_export_sharedlink.stderr.log >&2)


if [ -f libjhdf5.so ]; then
  #cp -pf libjhdf5.so ../../../libs/native/jhdf5/amd64-Linux/
  echo "Build OK"
else
  echo "ERROR"
fi
