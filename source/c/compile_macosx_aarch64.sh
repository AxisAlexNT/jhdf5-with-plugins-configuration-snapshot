#! /bin/bash
set -euo pipefail

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

source version.sh
SOURCE_VERSION="$VERSION"

if [ -n "${POSTFIX:-}" ]; then
  VERSION="$VERSION-$POSTFIX"
fi

if [ -z "${JAVA_HOME:-}" ]; then
  JAVA_HOME="$(/usr/libexec/java_home 2>/dev/null || true)"
fi
if [[ -z "${JAVA_HOME:-}" || ! -d "${JAVA_HOME}/include" || ! -d "${JAVA_HOME}/include/darwin" ]]; then
  echo "::error file=${SCRIPT_PATH}/compile_macosx_aarch64.sh,line=15::Could not find JNI headers. Set JAVA_HOME to a full macOS JDK." >&2
  exit 1
fi

resolve_build_preset() {
  local requested="$1"
  local base_dir="$2"
  local candidates=(
    "$requested"
    "${requested/-notest-noexamples/}"
    "${requested/-notest/}"
    "${requested/-noexamples/}"
    "${requested/hict-/ci-}"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -d "$base_dir/$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

BUILDDIR="$(realpath build)"
SRCDIR="$(realpath "build/hdf5-${VERSION}/hdf5-${SOURCE_VERSION}")"
HDF5_CMAKE_PRESET="${CMAKE_PRESET:-hict-StdShar-Clang-noexamples}"
HDF5_PACKAGE_PRESET="$(resolve_build_preset "${HDF5_CMAKE_PRESET}" "${BUILDDIR}/hdf5-${VERSION}/build110")"
if [[ -z "${HDF5_PACKAGE_PRESET}" ]]; then
  echo "::error file=${SCRIPT_PATH}/compile_macosx_aarch64.sh,line=38::No matching HDF5 build preset directory found for ${HDF5_CMAKE_PRESET} under ${BUILDDIR}/hdf5-${VERSION}/build110" >&2
  exit 1
fi
BDIR="${BUILDDIR}/hdf5-${VERSION}/build110/${HDF5_PACKAGE_PRESET}"
HDF5_PUBLIC_INCLUDE="${BDIR}/src"
HDF5_LINK_LIB="$(find "${BDIR}/bin" -maxdepth 1 \( -type f -o -type l \) \( -name "libhdf5.dylib" -o -name "libhdf5.*.dylib" \) -print | sort | head -n 1)"
if [[ -z "${HDF5_LINK_LIB}" ]]; then
  echo "::error file=${SCRIPT_PATH}/compile_macosx_aarch64.sh,line=46::Could not find a CMake-built libhdf5 dylib under ${BDIR}/bin" >&2
  exit 1
fi

rm -rf "${BUILDDIR}/jni"
rm -f "${BUILDDIR}/libjhdf5.jnilib"
cp -a jni "${BUILDDIR}/"
cp -a *.c "${BUILDDIR}/jni/"
cd "${BUILDDIR}"
cp "${SRCDIR}/src/H5win32defs.h" jni/
cp "${SRCDIR}/src/H5private.h" jni/

echo "JHDF5 building..."
gcc \
  -Wno-error=implicit-function-declaration \
  -m64 \
  -mmacosx-version-min=10.11 \
  -dynamiclib \
  -O3 \
  -Wl,-rpath,@loader_path \
  jni/*.c \
  -I"${HDF5_PUBLIC_INCLUDE}" \
  -I"${SRCDIR}/src" \
  -I"${JAVA_HOME}/include" \
  -I"${JAVA_HOME}/include/darwin" \
  "${HDF5_LINK_LIB}" \
  -o libjhdf5.jnilib \
  -lz \
    > >(tee -a jhdf5.stdout.log) 2> >(tee -a jhdf5.stderr.log >&2)

DEPLOY_DIR="../../../libs/native/jhdf5/aarch64-Mac OS X"
rm -rf "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"

find "$BDIR" \( -type f -o -type l \) \
  \( -name "libhdf5.dylib" -o -name "libhdf5.[0-9]*.dylib" -o -name "libhdf5_java*.dylib" -o -name "libh5*.dylib" -o -name "libblosc*.dylib" \) \
  -exec cp -Ppf {} "$DEPLOY_DIR/" \;
while IFS= read -r plugin_lib; do
  cp -Ppf "$plugin_lib" "$DEPLOY_DIR/$(basename "${plugin_lib%.so}.dylib")"
done < <(find "$BDIR" -type f \( -name "libh5*.so" -o -name "libblosc*.so" \) -print | sort -u)

if [ -f libjhdf5.jnilib ]; then
  cp -pf libjhdf5.jnilib "$DEPLOY_DIR"
  echo "Build deployed"
else
  echo "ERROR" >&2
  exit 1
fi
