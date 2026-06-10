#! /bin/bash
set -e
set -u
set -o pipefail

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
REPO_ROOT="$( realpath "$SCRIPT_PATH/../.." )"
SOURCE_ARCHIVE="$SCRIPT_PATH/CMake-hdf5-1.10.11.zip"

if [[ ! -f "$SOURCE_ARCHIVE" ]]; then
  echo "Missing $SOURCE_ARCHIVE"
  echo "Download the official HDF5 CMake archive first:"
  echo "  curl -L -o '$SOURCE_ARCHIVE' https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.10/hdf5-1.10.11/src/CMake-hdf5-1.10.11.zip"
  exit 1
fi

if [[ -z "${JAVA_HOME:-}" && -z "${JVM_INCLUDE_PATH:-}" ]]; then
  if command -v javac >/dev/null 2>&1; then
    JAVAC_PATH="$(readlink -f "$(command -v javac)")"
    export JAVA_HOME="$(realpath "$(dirname "$JAVAC_PATH")/.." 2>/dev/null || true)"
    echo "[jhdf5] JAVA_HOME was not set; resolved from javac to ${JAVA_HOME}"
  fi
fi

VARIANTS=("$@")
if [[ ${#VARIANTS[@]} -eq 0 ]]; then
  VARIANTS=("generic" "avx2" "avx512")
fi

build_variant() {
  local variant="$1"
  local output_variant="$variant"
  local cflags
  local jhdf5_flags
  local cmake_preset="${CMAKE_PRESET:-hict-StdShar-GNUC-noexamples}"

  case "$variant" in
    generic)
      cflags="-O3 -fPIC -m64 -mtune=generic"
      ;;
    avx2)
      cflags="-O3 -fPIC -m64 -mavx2 -mfma -msse4.2 -mbmi -mbmi2 -mtune=generic"
      ;;
    baseline)
      output_variant="avx2"
      cflags="-O3 -fPIC -m64 -mavx2 -mfma -msse4.2 -mbmi -mbmi2 -mtune=generic"
      echo "[jhdf5] Variant 'baseline' is deprecated; building the AVX2 target as '$output_variant'."
      ;;
    avx512)
      cflags="-O3 -fPIC -m64 -mavx2 -mfma -msse4.2 -mbmi -mbmi2 -mavx512f -mavx512dq -mavx512bw -mavx512vl -mtune=generic"
      ;;
    *)
      echo "Unknown variant '$variant'. Expected: generic, avx2, baseline, or avx512."
      exit 1
      ;;
  esac

  jhdf5_flags="$cflags -Wl,-rpath,\$ORIGIN -Wl,--exclude-libs,ALL"

  echo "[jhdf5] Building Linux amd64 $output_variant variant"
  (
    cd "$SCRIPT_PATH"
    CMAKE_PRESET="$cmake_preset" POSTFIX="$output_variant" CFLAGS="$cflags" ./compile_hdf5_gcc.sh amd64 ""
    POSTFIX="$output_variant" \
      CMAKE_PRESET="$cmake_preset" \
      CFLAGS="$cflags" \
      JHDF5_ADDITIONAL_GCC_FLAGS="$jhdf5_flags" \
      JHDF5_DEPLOY_DIR="$REPO_ROOT/libs/native/jhdf5/amd64-Linux-$output_variant" \
      ./compile_linux_amd64.sh
  )

  if [[ "$output_variant" == "generic" ]]; then
    local base_deploy_dir="$REPO_ROOT/libs/native/jhdf5/amd64-Linux"
    rm -rf "$base_deploy_dir"
    mkdir -p "$base_deploy_dir"
    cp -a "$REPO_ROOT/libs/native/jhdf5/amd64-Linux-$output_variant"/. "$base_deploy_dir"/
  fi
}

for variant in "${VARIANTS[@]}"; do
  build_variant "$variant"
done

echo "[jhdf5] Finished Linux amd64 variants: ${VARIANTS[*]}"
