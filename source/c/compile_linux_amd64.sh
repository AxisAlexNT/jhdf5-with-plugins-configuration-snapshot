#! /bin/bash
set -e
set -u
set -o pipefail
set -x

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

source version.sh

# Add optimization arguments for JHDF5 build
if [ -z ${JHDF5_ADDITIONAL_GCC_FLAGS+x} ]; then	
	JHDF5_ADDITIONAL_GCC_FLAGS="-O3 -march=haswell -mtune=znver3 -Wl,--exclude-libs,ALL"
 	echo "JHDF5_ADDITIONAL_GCC_FLAGS variable was not provided in environment, default set to ${JHDF5_ADDITIONAL_GCC_FLAGS}"
else 
 	echo "JHDF5_ADDITIONAL_GCC_FLAGS variable is provided and is set to ${JHDF5_ADDITIONAL_GCC_FLAGS}"
fi

if [ -z ${JVM_INCLUDE_PATH+x} ]; then	
	JVM_INCLUDE_PATH="/usr/lib/jvm/java-8-openjdk-amd64/include/"
 	echo "JVM_INCLUDE_PATH variable was not provided in environment, default set to ${JVM_INCLUDE_PATH}"
else 
 	echo "JVM_INCLUDE_PATH variable is provided and is set to ${JVM_INCLUDE_PATH}"
fi

if [[ ! -d "${SCRIPT_PATH}" ]]; then
	"::error file=${SCRIPT_PATH},line=28::JVM Include directory (${SCRIPT_PATH}) does not exist, build will fail."
 	exit 1
fi

if [ -z ${CMAKE_PRESET+x} ]; then  
	CMAKE_PRESET="hict-StdShar-GNUC"
	echo "::warning ::CMAKE_PRESET variable was not provided in environment, default set to ${CMAKE_PRESET}"
else 
	echo "::notice ::CMAKE_PRESET variable is provided and is set to ${CMAKE_PRESET}"
fi

if [ -n "$POSTFIX" ]; then
  VERSION="$VERSION-$POSTFIX"
fi

# An old way for autotools build tree
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


BUILDDIR=$(realpath build)

rm -rf $BUILDDIR/jni
rm -f $BUILDDIR/libjhdf5.so
cp -a jni $BUILDDIR/
cp -a *.c $BUILDDIR/jni/
cd $BUILDDIR


EDIR=$(ls "${BUILDDIR}" | grep -E '^hdf5-([0-9.]+)$')
if [[ ! -d "${EDIR}" ]]; then
	echo "::error title=Cannot find build directory ::Cannot find build directory (detected ${EDIR}) for HDF5 version out of $(ls)"
fi
RDIR=$(ls "${BUILDDIR}/${EDIR}" | grep -E '^build([0-9]+)$')
if [[ ! -d "${BUILDDIR}/${EDIR}/${RDIR}" ]]; then
	echo "::error title=Cannot find build subdirectory ::Cannot find build subdirectory (detected ${RDIR}) for HDF5 version out of $(ls)"
fi
PDIR="${CMAKE_WORKFLOW_PRESET}"
if [[ ! -d "${BUILDDIR}/${EDIR}/${RDIR}/${PDIR}" ]]; then
	CDIR=$(ls "${BUILDDIR}/${EDIR}/${RDIR}" | head -n 1)
	OLD_PDIR="${PDIR}"
	PDIR="${CDIR}/"
	echo "::warning title=Cannot find workflow subdirectory ::Cannot find directory ${OLD_PDIR}, changed to ${PDIR}"
fi
if [[ ! -d "${BUILDDIR}/${EDIR}/${RDIR}/${PDIR}" ]]; then
	echo "::error title=Directory heuristic failed ::Still cannot find workflow build directory ${PDIR}"
fi

# PDIR="$BUILDDIR/hdf5-$VERSION/build110/${CMAKE_PRESET}/_CPack_Packages/Linux/TGZ/HDF5-1.10.11-Linux/HDF_Group/HDF5/1.10.11/"
# BDIR="$BUILDDIR/hdf5-$VERSION/build110/${CMAKE_PRESET}/"
PDIR="${BUILDDIR}/${EDIR}/${RDIR}/${PDIR}/_CPack_Packages/Linux/TGZ/HDF5-${VERSION}-Linux/HDF_Group/HDF5/${VERSION}/"
BDIR="${BUILDDIR}/${EDIR}/${RDIR}/${PDIR}"

SRCDIR=$(realpath "${BUILDDIR}/${EDIR}/${EDIR}/")
cp $SRCDIR/src/H5win32defs.h $BUILDDIR/jni/
cp $SRCDIR/src/H5private.h $BUILDDIR/jni/


rm -rf jhdf5*.std*.log jhdf5*.so
echo "JHDF5 building..."
if [[ ! -z "" ]]; then

	# Bad: links JHDF5 statically to HDF5, not suitable for plugins
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

	# Even worse: links JHDF5 statically to HDF5 and exports all symbols
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


# Links JHDF5 dynamically to HDF5 (still exports all symbols, which seems to be ok?)
gcc \
	-shared \
 	-fPIC \
 	$JHDF5_ADDITIONAL_GCC_FLAGS \
	$BUILDDIR/jni/*.c \
	-I"$PDIR/include" \
	-I$BDIR/src \
	-I$SRCDIR/src \
	-I$JVM_INCLUDE_PATH \
	-I$JVM_INCLUDE_PATH/linux \
	-L"$BDIR/bin" -L. -l:libhdf5.so \
	$(find $BDIR -type f -name "*.a" | xargs -n1 realpath) \
	-o libjhdf5_export_sharedlink.so -lz \
		> >(tee -a jhdf5_export_sharedlink.stdout.log) 2> >(tee -a jhdf5_export_sharedlink.stderr.log >&2)

cp -avf libjhdf5_export_sharedlink.so libjhdf5.so

if [ -f libjhdf5.so ]; then
  cp -af $BUILDDIR/libjhdf5.so $BUILDDIR/../../../libs/native/jhdf5/amd64-Linux/
  echo "Build OK"
else
  echo "ERROR"
fi
