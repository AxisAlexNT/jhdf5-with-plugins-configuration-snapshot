#! /bin/bash
set -e
set -u
set -o pipefail
set -x

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

source version.sh
SOURCE_VERSION="$VERSION"

# Add optimization arguments for JHDF5 build
if [ -z ${JHDF5_ADDITIONAL_GCC_FLAGS+x} ]; then	
	JHDF5_ADDITIONAL_GCC_FLAGS='-O3 -m64 -mavx2 -mfma -msse4.2 -mbmi -mbmi2 -mtune=generic -Wl,-rpath,$ORIGIN -Wl,--exclude-libs,ALL'
 	echo "JHDF5_ADDITIONAL_GCC_FLAGS variable was not provided in environment, default set to ${JHDF5_ADDITIONAL_GCC_FLAGS}"
 else 
 	echo "JHDF5_ADDITIONAL_GCC_FLAGS variable is provided and is set to ${JHDF5_ADDITIONAL_GCC_FLAGS}"
 fi

resolve_jvm_include_path() {
	local candidate_include="${1:-}"

	if [[ -n "$candidate_include" && -d "$candidate_include" && -d "$candidate_include/linux" ]]; then
		printf '%s\n' "$candidate_include"
		return 0
	fi

	if command -v javac >/dev/null 2>&1; then
		local javac_path
		javac_path="$(readlink -f "$(command -v javac)")"
		candidate_include="$(realpath "$(dirname "$javac_path")/../include" 2>/dev/null || true)"
		if [[ -n "$candidate_include" && -d "$candidate_include" && -d "$candidate_include/linux" ]]; then
			printf '%s\n' "$candidate_include"
			return 0
		fi
	fi

	return 1
}

if [ -z ${JVM_INCLUDE_PATH+x} ]; then
	if JVM_INCLUDE_PATH="$(resolve_jvm_include_path "${JAVA_HOME:-}/include")"; then
		echo "JVM_INCLUDE_PATH variable was not provided in environment, resolved to ${JVM_INCLUDE_PATH}"
	else
		echo "::error file=${SCRIPT_PATH}/compile_linux_amd64.sh,line=30::Could not find JNI headers. Set JAVA_HOME to a full JDK or set JVM_INCLUDE_PATH to a directory containing jni.h and linux/jni_md.h."
		exit 1
	fi
else
	echo "JVM_INCLUDE_PATH variable is provided and is set to ${JVM_INCLUDE_PATH}"
fi

if [[ ! -d "${JVM_INCLUDE_PATH}" || ! -d "${JVM_INCLUDE_PATH}/linux" ]]; then
	echo "::error file=${SCRIPT_PATH}/compile_linux_amd64.sh,line=30::JVM include directory (${JVM_INCLUDE_PATH}) or its linux subdirectory does not exist."
	exit 1
fi

if [ -z ${JHDF5_DEPLOY_DIR+x} ]; then
	JHDF5_DEPLOY_DIR="$SCRIPT_PATH/../../libs/native/jhdf5/amd64-Linux"
	echo "JHDF5_DEPLOY_DIR variable was not provided in environment, default set to ${JHDF5_DEPLOY_DIR}"
else
	echo "JHDF5_DEPLOY_DIR variable is provided and is set to ${JHDF5_DEPLOY_DIR}"
fi

if [ -n "${POSTFIX:-}" ]; then
  VERSION="$SOURCE_VERSION-$POSTFIX"
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

SRCDIR=$(realpath build/hdf5-$VERSION/hdf5-$SOURCE_VERSION/)
BUILDDIR=$(realpath build)

rm -rf $BUILDDIR/jni
rm -f $BUILDDIR/libjhdf5.so
cp -a jni $BUILDDIR/
cp -a *.c $BUILDDIR/jni/
cd $BUILDDIR
cp $SRCDIR/src/H5win32defs.h $BUILDDIR/jni/
cp $SRCDIR/src/H5private.h $BUILDDIR/jni/

HDF5_CMAKE_PRESET="${CMAKE_PRESET:-hict-StdShar-GNUC-notest-noexamples}"
HDF5_CMAKE_PRESET="${HDF5_CMAKE_PRESET/#hict-/ci-}"
HDF5_PACKAGE_PRESET="${HDF5_CMAKE_PRESET/-notest/}"
PDIR="$BUILDDIR/hdf5-$VERSION/build110/$HDF5_PACKAGE_PRESET/_CPack_Packages/Linux/TGZ/HDF5-1.10.11-Linux/HDF_Group/HDF5/1.10.11/"
BDIR="$BUILDDIR/hdf5-$VERSION/build110/$HDF5_PACKAGE_PRESET/"
HDF5_PUBLIC_INCLUDE="$PDIR/include"
if [[ ! -d "$HDF5_PUBLIC_INCLUDE" ]]; then
	HDF5_PUBLIC_INCLUDE="$BDIR/src"
	echo "Packaged HDF5 include directory was not found; using generated build include directory ${HDF5_PUBLIC_INCLUDE}"
fi

STATIC_LIBS=()
if [[ -d "$BDIR" ]]; then
	while IFS= read -r lib_path; do
		STATIC_LIBS+=("$lib_path")
	done < <(find "$BDIR" -type f -name "*.a" -print)
else
	echo "::error file=${SCRIPT_PATH}/compile_linux_amd64.sh,line=86::Expected HDF5 build directory was not found: ${BDIR} (workflow preset ${HDF5_CMAKE_PRESET} maps to package preset ${HDF5_PACKAGE_PRESET})"
	exit 1
fi


rm -rf jhdf5*.std*.log jhdf5*.so
echo "JHDF5 building..."
if [[ ! -z "" ]]; then

	# Bad: links JHDF5 statically to HDF5, not suitable for plugins
	gcc \
		-shared -O3 -march=native -mtune=znver3 -fPIC \
		-Wl,--exclude-libs,ALL \
		$BUILDDIR/jni/*.c \
		-I"$HDF5_PUBLIC_INCLUDE" \
		-I$BDIR/src \
		-I$SRCDIR/src \
		-I$JVM_INCLUDE_PATH \
		-I$JVM_INCLUDE_PATH/linux \
		"$BDIR/bin/libhdf5.a" \
		"${STATIC_LIBS[@]}" \
		-o libjhdf5.so -lz \
			> >(tee -a jhdf5.stdout.log) 2> >(tee -a jhdf5.stderr.log >&2)

	# Even worse: links JHDF5 statically to HDF5 and exports all symbols
	gcc \
		-shared -O3 -march=native -mtune=znver3 -fPIC \
		$BUILDDIR/jni/*.c \
		-I"$HDF5_PUBLIC_INCLUDE" \
		-I$BDIR/src \
		-I$SRCDIR/src \
		-I$JVM_INCLUDE_PATH \
		-I$JVM_INCLUDE_PATH/linux \
		"$BDIR/bin/libhdf5.a" \
		"${STATIC_LIBS[@]}" \
		-o libjhdf5_export.so -lz \
			> >(tee -a jhdf5_export.stdout.log) 2> >(tee -a jhdf5_export.stderr.log >&2)
fi


# Links JHDF5 dynamically to HDF5 (still exports all symbols, which seems to be ok?)
gcc \
	-shared \
 	-fPIC \
	$JHDF5_ADDITIONAL_GCC_FLAGS \
	$BUILDDIR/jni/*.c  \
	-I"$HDF5_PUBLIC_INCLUDE" \
	-I$BDIR/src \
	-I$SRCDIR/src \
	-I$JVM_INCLUDE_PATH \
	-I$JVM_INCLUDE_PATH/linux \
	-L"$BDIR/bin" -l:libhdf5.so \
	"${STATIC_LIBS[@]}" \
	-o libjhdf5_export_sharedlink.so -lz \
		> >(tee -a jhdf5_export_sharedlink.stdout.log) 2> >(tee -a jhdf5_export_sharedlink.stderr.log >&2)

cp -avf libjhdf5_export_sharedlink.so libjhdf5.so

if [ -f libjhdf5.so ]; then
  mkdir -p "$JHDF5_DEPLOY_DIR"
  find "$BDIR/bin" -maxdepth 1 \( -type f -o -type l \) \
    \( -name "libhdf5*.so*" -o -name "libhdf5*.so" \) \
    -exec cp -Ppf {} "$JHDF5_DEPLOY_DIR/" \;

  BUILT_PLUGIN_COUNT=0
  for PLUGIN_OUTPUT_DIR in "$BDIR/plugins" "$BDIR/bin"; do
    if [[ -d "$PLUGIN_OUTPUT_DIR" ]]; then
      while IFS= read -r PLUGIN_LIB; do
        cp -Ppf "$PLUGIN_LIB" "$JHDF5_DEPLOY_DIR/"
        BUILT_PLUGIN_COUNT=$((BUILT_PLUGIN_COUNT + 1))
      done < <(find "$PLUGIN_OUTPUT_DIR" -maxdepth 1 \( -type f -o -type l \) \
        \( -name "libh5*.so*" -o -name "libblosc*.so*" \) -print)
    fi
  done

  LEGACY_PLUGIN_DIR="$SCRIPT_PATH/../../libs/native/jhdf5/amd64-Linux"
  if [[ "$BUILT_PLUGIN_COUNT" -eq 0 && -d "$LEGACY_PLUGIN_DIR" ]]; then
    echo "Built HDF5 compression plugins were not found; using legacy plugin copies from ${LEGACY_PLUGIN_DIR}"
    find "$LEGACY_PLUGIN_DIR" -maxdepth 1 -type f \
      \( -name "libh5*.so" -o -name "libh5*.so.*" -o -name "libblosc*.so*" \) \
      -exec cp -pf {} "$JHDF5_DEPLOY_DIR/" \;
  else
    echo "Deployed ${BUILT_PLUGIN_COUNT} freshly built HDF5 compression plugin files to ${JHDF5_DEPLOY_DIR}"
  fi

  cp -pf "$BUILDDIR/libjhdf5.so" "$JHDF5_DEPLOY_DIR/"
  echo "Build OK"
else
  echo "ERROR"
fi
