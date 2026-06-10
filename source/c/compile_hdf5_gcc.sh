#! /bin/bash
set -e
set -u
set -o pipefail
set -x


source version.sh
SOURCE_VERSION="$VERSION"
PLATFORM="$1"
PATCHES="${2:-}"
POSTFIX="${POSTFIX:-}"

if [ -z "${CFLAGS+x}" ]; then
  CFLAGS="-O3 -fPIC"
fi

BUILD_HDF5=""
BUILD_HDF5_PLUGINS=""

CMAKE_HDF5="1"
HDF5_CLEAN="1"
if [ -z "${CMAKE_PRESET+x}" ]; then
	case "$(uname -s)" in
		Darwin) CMAKE_PRESET="hict-StdShar-Clang-noexamples" ;;
		*) CMAKE_PRESET="hict-StdShar-GNUC-notest-noexamples" ;;
	esac
fi

normalize_preset() {
	local preset="$1"
	preset="${preset%%-}"
	echo "$preset"
}

CMAKE_PRESET="$(normalize_preset "${CMAKE_PRESET}")"
HDF5_USE_AUTOTOOLS=""
BUILD_WITH_WORKFLOW=1

resolve_workflow_preset() {
	local requested="$1"
	local source_dir="$2"
	local available_presets=""
	local cmake_presets
	BUILD_WITH_WORKFLOW=1
	if ! cmake_presets="$(cmake -S "$source_dir" --list-presets 2>&1)"; then
		echo "Warning: cmake --list-presets returned non-zero status for $source_dir. Falling back to preset-guessing mode." >&2
		echo "$cmake_presets" >&2
	fi

	available_presets="$(printf '%s\n' "$cmake_presets" | awk '
		/^Available workflow presets:/{in_section=1; next}
		in_section && $0 ~ /^[[:space:]]*"[^"]+"/ {
			gsub(/^[[:space:]]*"/, "", $0);
			gsub(/"[[:space:]]*$/, "", $0);
			print $0
		}
		in_section && $0 !~ /^[[:space:]]*"/ {in_section=0}
	')"

	if [[ -z "${available_presets}" ]]; then
		BUILD_WITH_WORKFLOW=0
		available_presets="$(printf '%s\n' "$cmake_presets" | awk '
		/^Available configure presets:/{in_section=1; next}
		in_section && $0 ~ /^[[:space:]]*"[^"]+"/ {
			gsub(/^[[:space:]]*"/, "", $0);
			gsub(/"[[:space:]]*$/, "", $0);
			print $0
		}
		in_section && $0 !~ /^[[:space:]]*"/ {in_section=0}
	')"
	else
		BUILD_WITH_WORKFLOW=1
	fi

	local candidates=(
		"$requested"
		"${requested/#hict-/ci-}"
		"${requested/#ci-/hict-}"
		"${requested/-notest-noexamples/}"
		"${requested/-notest/}"
		"${requested/-noexamples/}"
	)
	local candidate
	local line
	local fallback=""
	for candidate in "${candidates[@]}"; do
		candidate="$(normalize_preset "$candidate")"
		[[ -z "$candidate" ]] && continue
		if [[ -z "$fallback" ]]; then
			fallback="$candidate"
		fi
		while IFS= read -r line; do
			if [[ "$candidate" == "$line" ]]; then
				echo "$candidate"
				return 0
			fi
		done <<<"${available_presets}"
	done

	if [[ -n "$fallback" ]]; then
		echo "Could not validate CMake preset '$requested' against discovered presets; attempting compatibility fallback." >&2
		local fallback_compat=(
			"${requested}"
			"${requested/-notest-noexamples/}"
			"${requested/-notest/}"
			"${requested/-noexamples/}"
			"${requested/-notest-noexamples/-noexamples}"
			"${requested/-notest-noexamples/-notest}"
			"${requested/^hict-/ci-}"
			"${requested/^ci-/hict-}"
		)
		for candidate in "${fallback_compat[@]}"; do
			candidate="$(normalize_preset "$candidate")"
			[[ -z "$candidate" ]] && continue
			while IFS= read -r line; do
				if [[ "$candidate" == "$line" ]]; then
					echo "Using compatible fallback preset '$candidate'." >&2
					echo "$candidate"
					return 0
				fi
			done <<<"${available_presets}"
		done
		echo "$fallback" >&2
		return 0
	fi

	echo "Could not resolve CMake preset '$requested' to any available preset." >&2
	if [[ "$BUILD_WITH_WORKFLOW" -eq 1 ]]; then
		echo "Available workflow presets:" >&2
	else
		echo "Available configure presets:" >&2
	fi
	if [[ -n "${available_presets}" ]]; then
		while IFS= read -r line; do
			printf '  %s\n' "$line" >&2
		done <<<"${available_presets}"
	else
		echo "  (none available or cmake --list-presets parsing failed)" >&2
	fi
	return 1
}

# Should java/src/jni folder be overwritten by JHDF5 patches?
if [ -z ${REPLACE_JNI+x} ]; then
	REPLACE_JNI="0"
	echo "REPLACE_JNI variable was not provided in environment, default set to no (0)"
else
	echo "REPLACE_JNI variable is provided and is set to $REPLACE_JNI"
fi

export CMAKE_POLICY_VERSION_MINIMUM="${CMAKE_POLICY_VERSION_MINIMUM:-3.5}"
export CC="${CC:-gcc}"
export CXX="${CXX:-g++}"


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
			if [ -n "$POSTFIX" ]; then
				rm -rf hdf5-$VERSION-$POSTFIX
			fi
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
  mv hdf5-$SOURCE_VERSION hdf5-$SOURCE_VERSION-$POSTFIX
  VERSION="$SOURCE_VERSION-$POSTFIX"
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
	   NCPU=`getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || lscpu|awk '/^CPU\(s\)/ {print $2}'`
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
	SRCDIR=$(realpath hdf5-$VERSION/hdf5-$SOURCE_VERSION/)
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
	SRCDIR=$(realpath hdf5-$VERSION/hdf5-$SOURCE_VERSION/)
	cp -af ../CMakeUserPresets.json $SRCDIR/CMakeUserPresets.json
	if [[ "$REPLACE_JNI" == "1" || "$REPLACE_JNI" == "yes" || "$REPLACE_JNI" == "true" ]]; then
		cp -arf ../jni $SRCDIR/java/src/
		cp -arf ../*.c $SRCDIR/java/src/jni/
	fi
	cp -af ../*tar.gz "$SRCDIR/../"
	PLUGIN_TMPDIR="$(mktemp -d)"
	if [[ -f "../hdf5_plugins-release-1_10_11.zip" ]]; then
		unzip -q "../hdf5_plugins-release-1_10_11.zip" -d "$PLUGIN_TMPDIR"
		tar -C "$PLUGIN_TMPDIR" -czf "$SRCDIR/../hdf5_plugins.tar.gz" hdf5_plugins-release-1_10_11
	elif [[ -f "$SRCDIR/../hdf5_plugins-master.zip" ]]; then
		unzip -q "$SRCDIR/../hdf5_plugins-master.zip" -d "$PLUGIN_TMPDIR"
		tar -C "$PLUGIN_TMPDIR" -czf "$SRCDIR/../hdf5_plugins.tar.gz" hdf5_plugins-master
	else
		rm -rf "$PLUGIN_TMPDIR"
		echo "::error::No HDF5 plugin source archive was found." >&2
		exit 1
	fi
	rm -rf "$PLUGIN_TMPDIR"
	echo "HDF5 Source DIR is $SRCDIR"
	cd $SRCDIR
	echo "Available CMake presets:"
	cmake -S "${SRCDIR}" --list-presets
	if [[ "$REPLACE_JNI" == "1" || "$REPLACE_JNI" == "yes" || "$REPLACE_JNI" == "true" ]]; then
		echo "Applying JNI path"
		if patch --ignore-whitespace --fuzz 10 -p2 < ../../../cmake_add_sources.diff; then
			echo "Applied JNI patch"
		else
			if [[ -f java/src/jni/CMakeLists.txt.rej ]]; then
				echo "JNI patch appears to be already applied or partially applied; continuing with current jni sources."
				rm -f java/src/jni/CMakeLists.txt.rej
			else
				echo "JNI patch failed to apply and produced no reject file."
				exit 1
			fi
		fi
	else
		echo "Not applying JNI patch as set by parameters in script"
	fi
	rm -f cmake.std*.log
	CMAKE_PRESET="$(resolve_workflow_preset "$CMAKE_PRESET" "$SRCDIR")"
	if [[ "$BUILD_WITH_WORKFLOW" -eq 1 ]]; then
		cmake_args=(--workflow --preset="$CMAKE_PRESET" --fresh)
		if ! cmake "${cmake_args[@]}" > >(tee -a cmake.stdout.log) 2> >(tee -a cmake.stderr.log >&2); then
			echo "Workflow preset execution failed for '$CMAKE_PRESET'; retrying with configure/build preset sequence." >&2
			BUILD_WITH_WORKFLOW=0
			cmake_args=(--preset="$CMAKE_PRESET" --fresh)
			cmake "${cmake_args[@]}" > >(tee -a cmake.stdout.log) 2> >(tee -a cmake.stderr.log >&2)
			cmake --build --preset="$CMAKE_PRESET" > >(tee -a cmake.stdout.log) 2> >(tee -a cmake.stderr.log >&2)
		fi
	else
		cmake_args=(--preset="$CMAKE_PRESET" --fresh)
		cmake "${cmake_args[@]}" > >(tee -a cmake.stdout.log) 2> >(tee -a cmake.stderr.log >&2)
		cmake --build --preset="$CMAKE_PRESET" > >(tee -a cmake.stdout.log) 2> >(tee -a cmake.stderr.log >&2)
	fi
	cd ..
fi
