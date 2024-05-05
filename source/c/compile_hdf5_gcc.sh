#! /bin/bash
set -e
set -u
set -o pipefail
set -x


source version.sh
PLATFORM="$1"
PATCHES="$2"

BUILD_HDF5=""
BUILD_HDF5_PLUGINS=""

CMAKE_HDF5="1"
HDF5_CLEAN="1"
CMAKE_PRESET="hict-StdShar-GNUC-notest"
HDF5_USE_AUTOTOOLS=""

# Should java/src/jni folder be overwritten by JHDF5 patches?
if [ -z ${REPLACE_JNI+x} ]; then  
	REPLACE_JNI="0"
 	echo "REPLACE_JNI variable was not provided in environment, default set to no (0)"
 else 
 	echo "REPLACE_JNI variable is provided and is set to $REPLACE_JNI"
 fi

export PATH="/opt/cmake/bin:/opt/cmake:$PATH"


if [ "$PLATFORM" != "i386" -a "$PLATFORM" != "x86" -a "$PLATFORM" != "amd64" -a "$PLATFORM" != "x86_64" -a "$PLATFORM" != "armv6l" -a "$PLATFORM" != "aarch64" ]; then
  echo "Syntax: compile_hdf5.sh <platform>"
  echo "where <platform> is one of i386, x86, amd64, x86_64, aarch64, or armv6l"
  exit 1
fi

if [[ ! -z $BUILD_HDF5 || ! -d "build" ]]; then
	echo "Removing existing build directory and creating new one"
	rm -fR build || true
	mkdir build
else
	echo "Not overwriting existing build directory"
fi

cd build
BUILD_ROOT=`pwd`

if [[ ! -z $BUILD_HDF5 ]]; then
	tar xvf ../hdf5-$VERSION.tar*
fi

if [[ ! -z $BUILD_HDF5_PLUGINS ]]; then
	tar xvf ../hdf5_plugins-$VERSION.tar*
fi

if [[ ! -z $CMAKE_HDF5 ]]; then
	echo "Preparing files to build HDF5 with CMake"
	if [[ -f "../CMake-hdf5-$VERSION.zip" ]]; then
		echo "Found CMake-hdf5-$VERSION.zip"
		if [[ ! -z "$HDF5_CLEAN" ]]; then
			echo "HDF5_CLEAN is set to true, removing existing sources"
			rm -rf CMake-hdf5-${VERSION}*
			rm -rf hdf5-$VERSION-$PLATFORM
			#mkdir hdf5-$VERSION-$PLATFORM
		fi
		cp "../CMake-hdf5-$VERSION.zip" .
		unzip "CMake-hdf5-$VERSION.zip"
		mv CMake-hdf5-$VERSION hdf5-$VERSION
		rm -f "CMake-hdf5-$VERSION.zip"
	else
		echo "Can not find CMake-hdf5-$VERSION.zip"
		exit 1
	fi
fi

#exit 1

if [[ -d hdfsrc ]]; then
	mv hdfsrc hdf5-$VERSION
fi

if [[ -d CMake-hdf5-$VERSION ]]; then
	mv CMake-hdf5-$VERSION hdf5-$VERSION
fi

if [ -n "$POSTFIX" ]; then
  mv hdf5-$VERSION hdf5-$VERSION-$POSTFIX
  VERSION="$VERSION-$POSTFIX"
fi

echo "Copied hdf sources"

cd hdf5-$VERSION

if [ -n "$PATCHES" ]; then
  for p in $PATCHES; do
    patch -p1 < ../../$p
  done
fi

echo "Applied patches"

cd ..


#printf "\n\n#Patch added in compile_hdf5_gcc.sh\nAC_CONFIG_SUBDIRS([LZF])\nAC_CONFIG_SUBDIRS([BSHUF])\n\n" >> build/hdf5_plugins-$VERSION/configure.ac

rm -f *.stdout.log *.stderr.log

echo "CFLAGS=$CFLAGS"
#exit 1

if [[ ! -z $BUILD_HDF5 ]]; then
	cd hdf5-$VERSION
	CFLAGS=$CFLAGS ./configure --prefix=$BUILD_ROOT/hdf5-$VERSION-$PLATFORM --enable-java --enable-tests --enable-test-express=3 --enable-tools --disable-doxygen-doc --enable-deprecated-symbols --enable-embedded-libinfo --enable-build-mode=production $ADDITIONAL > >(tee -a configure.stdout.log) 2> >(tee -a configure.stderr.log >&2)
	#CFLAGS=$CFLAGS ./configure --with-hdf5=$BUILD_ROOT/hdf5-$VERSION-$PLATFORM > >(tee -a configure_plugins.stdout.log) 2> >(tee -a configure_plugins.stderr.log >&2)

	echo "Done cofigure"

	if [ "`uname`" == "Darwin" ]; then
	   NCPU=`sysctl -n hw.ncpu`
	else
	   NCPU=`lscpu|awk '/^CPU\(s\)/ {print $2}'`
	fi
	
	echo "Number of CPUs is $NCPU" 
	
	make -j $NCPU > >(tee -a build.stdout.log) 2> >(tee -a build.stderr.log >&2)
	make install > >(tee -a install.stdout.log) 2> >(tee -a install.stderr.log >&2)
	#make -j $NCPU test > >(tee -a test.stdout.log) 2> >(tee -a test.stderr.log >&2)
fi

echo $CFLAGS
#exit 1

if [[ ! -z $BUILD_HDF5_PLUGINS ]]; then
	cd ../hdf5_plugins-$VERSION
	printf "\n\n#Patch added in compile_hdf5_gcc.sh\nAC_CONFIG_SUBDIRS([LZF])\nAC_CONFIG_SUBDIRS([BSHUF])\n\n" >> build/hdf5_plugins-$VERSION/configure.ac
	autoreconf -vfi
	CFLAGS=$CFLAGS ./configure --with-hdf5=$BUILD_ROOT/hdf5-$VERSION-$PLATFORM/include --with-hdf5-plugin-dir=$BUILD_ROOT/../hdf5-$VERSION-$PLATFORM/plugin --with-bz2lib=/usr/lib64 > >(tee -a configure_plugins.stdout.log) 2> >(tee -a configure_plugins.stderr.log >&2)
	make -j $NCPU
	make check
	make install
fi

if [[ ! -z "$HDF5_USE_AUTOTOOLS" && "$HDF5_USE_AUTOTOOLS" -ne "0" && "$HDF5_USE_AUTOTOOLS" -ne "no" && "$HDF5_USE_AUTOTOOLS" -ne "n" ]]; then
	SRCDIR=$(realpath hdf5-$VERSION/hdf5-$VERSION/)
	INSDIR=$(realpath hdf5-$VERSION-$PLATFORM/)
	OPTS=("-DHDF5_BUILD_FORTRAN:BOOL=OFF")
	OPTS+=("-DHDF5_BUILD_CPP_LIB:BOOL=OFF")
	OPTS+=("-DHDF5_ALLOW_EXTERNAL_SUPPORT:STRING=TGZ")
	OPTS+=("-DPLUGIN_TGZ_NAME:STRING=$SRCDIR/hdf5_plugins.tar.gz")
	OPTS+=("-DCMAKE_BUILD_TYPE:STRING=Release")
	OPTS+=("-DHDF5_ENABLE_SZIP_SUPPORT:BOOL=OFF")
	OPTS+=("-DHDF5_ENABLE_Z_LIB_SUPPORT:BOOL=ON")
	OPTS+=("-DBUILD_SHARED_LIBS:BOOL=ON")
	OPTS+=("-DHDF5_BUILD_JAVA:BOOL=ON")
	OPTS+=("-DINSTALL_PREFIX:STRING=$INSDIR")
	OPTS+=("-DHDF5_GENERATE_HEADERS:BOOL=ON")
	OPTS+=("-DHDF5_ENABLE_PLUGIN_SUPPORT:BOOL=ON")
	OARG="${OPTS[*]}"
	autoreconf -vfi
	#echo "OARG are $OARG"
	#exit 1
	#cmake -C ${SRCDIR}/config/cmake/cacheinit.cmake -G "Unix Makefile" $OARG $SRCDIR
	cmake -S "${SRCDIR}" --list-presets
	#cmake -S "${SRCDIR}" --workflow --preset=hict-StdShar-GNUC --fresh
	#cd $SRCDIR
	#cd ..
	#unzip -f hdf5_plugins-master.zip
	#tar cfz hdf5_plugins.tar.gz hdf5_plugins-master
	#unzip -f hdf5-examples-master.zip
	#tar cfz hdf5-examples.tar.gz hdf5-examples-master
fi


# Currently, only this way of building HDF5 is supported, using CMake workflow mode:
if [[ ! -z $CMAKE_HDF5 ]]; then
	SRCDIR=$(realpath hdf5-$VERSION/hdf5-$VERSION/)
	cp -af ../CMakeUserPresets.json $SRCDIR/CMakeUserPresets.json
	if [[ ! -z "$REPLACE_JNI" && "$REPLACE_JNI" -ne "0" && "$REPLACE_JNI" -ne "no" && "$REPLACE_JNI" -ne "1" ]]; then
		cp -arf ../jni $SRCDIR/java/src/
		cp -arf ../*.c $SRCDIR/java/src/jni/
	fi
	cp -af ../*tar.gz "$SRCDIR/../"
	echo "HDF5 Source DIR is $SRCDIR"
	cd $SRCDIR
	echo "Available CMake presets:"
	cmake -S "${SRCDIR}" --list-presets
	if [[ ! -z "$REPLACE_JNI" && "$REPLACE_JNI" -ne "0" && "$REPLACE_JNI" -ne "no" && "$REPLACE_JNI" -ne "1" ]]; then
		echo "Applying JNI path"
		patch --ignore-whitespace --fuzz 10 -p2 < ../../../cmake_add_sources.diff
	else
		echo "Not applying JNI patch as set by parameters in script"
	fi
	rm -f cmake.std*.log
	cmake --workflow --preset="$CMAKE_PRESET" --fresh > >(tee -a cmake.stdout.log) 2> >(tee -a cmake.stderr.log >&2)
	cd ..
fi
