#! /usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
REPO_ROOT="$( realpath "$SCRIPT_PATH/../.." )"

ARCH="${1:-}"
shift || true
VARIANTS=("$@")

case "$ARCH" in
  amd64|x86_64)
    IMAGE="${JHDF5_MANYLINUX_IMAGE_X86_64:-quay.io/pypa/manylinux2014_x86_64:latest}"
    DEFAULT_VARIANTS=("generic" "avx2" "avx512")
    ;;
  arm64|aarch64)
    IMAGE="${JHDF5_MANYLINUX_IMAGE_AARCH64:-quay.io/pypa/manylinux2014_aarch64:latest}"
    DEFAULT_VARIANTS=()
    ;;
  *)
    echo "Usage: $0 <amd64|arm64> [variants...]" >&2
    exit 1
    ;;
esac

if [[ ${#VARIANTS[@]} -eq 0 && ${#DEFAULT_VARIANTS[@]} -gt 0 ]]; then
  VARIANTS=("${DEFAULT_VARIANTS[@]}")
fi

if [[ -z "${JAVA_HOME:-}" || ! -d "${JAVA_HOME}" ]]; then
  echo "JAVA_HOME must point to a mounted JDK before invoking the manylinux build wrapper." >&2
  exit 1
fi

if [[ ! -f "$SCRIPT_PATH/CMake-hdf5-1.10.11.zip" ]]; then
  echo "Missing $SCRIPT_PATH/CMake-hdf5-1.10.11.zip" >&2
  exit 1
fi

VARIANT_ARGS="${VARIANTS[*]}"
CMAKE_VERSION="${JHDF5_CMAKE_VERSION:-3.29.6}"

docker run --rm -i \
  -v "${REPO_ROOT}:${REPO_ROOT}" \
  -v "${JAVA_HOME}:${JAVA_HOME}:ro" \
  -w "${REPO_ROOT}" \
  -e GITHUB_WORKSPACE="${REPO_ROOT}" \
  -e JHDF5_ARCH="${ARCH}" \
  -e JHDF5_VARIANTS="${VARIANT_ARGS}" \
  -e CMAKE_VERSION="${CMAKE_VERSION}" \
  -e JAVA_HOME="${JAVA_HOME}" \
  -e PATH="${JAVA_HOME}/bin:/usr/local/bin:/usr/bin:/bin" \
  -e HDF5_CMAKE_ARCHIVE_URL="${HDF5_CMAKE_ARCHIVE_URL:-}" \
  -e HDF5_CMAKE_ARCHIVE_NAME="${HDF5_CMAKE_ARCHIVE_NAME:-}" \
  -e HOST_UID="$(id -u)" \
  -e HOST_GID="$(id -g)" \
  "${IMAGE}" \
  bash -lc '
    set -euo pipefail

    yum install -y \
      autoconf automake binutils bzip2 bzip2-devel ca-certificates curl diffutils file findutils \
      gcc gcc-c++ gcc-gfortran gzip libtool m4 make patch perl-core perl-IPC-Cmd pkgconfig \
      tar unzip which xz xz-devel zip zlib-devel

    find_manylinux_python() {
      local candidate=""
      for candidate in \
        /opt/python/cp313-cp313/bin/python3 /opt/python/cp313-cp313/bin/python \
        /opt/python/cp312-cp312/bin/python3 /opt/python/cp312-cp312/bin/python \
        /opt/python/cp311-cp311/bin/python3 /opt/python/cp311-cp311/bin/python \
        /opt/python/cp310-cp310/bin/python3 /opt/python/cp310-cp310/bin/python \
        /opt/python/cp39-cp39/bin/python3 /opt/python/cp39-cp39/bin/python \
        /opt/python/cp38-cp38/bin/python3 /opt/python/cp38-cp38/bin/python; do
        if [[ -e "${candidate}" ]]; then
          printf "%s\n" "${candidate}"
          return 0
        fi
      done
      find /opt/python -maxdepth 4 \( -name python3 -o -name python \) -print 2>/dev/null | sort -V | tail -n 1
    }

    PYBIN="$(find_manylinux_python || true)"
    if [[ -z "${PYBIN}" || ! -e "${PYBIN}" ]]; then
      echo "Unable to find a manylinux Python under /opt/python." >&2
      find /opt/python -maxdepth 3 -print 2>/dev/null | sort >&2 || true
      exit 1
    fi
    ln -sfn "${PYBIN}" /usr/local/bin/python3

    python3 -m ensurepip --upgrade >/dev/null 2>&1 || true
    python3 -m pip install --upgrade pip >/dev/null
    python3 -m pip install --upgrade "cmake==${CMAKE_VERSION}" ninja >/dev/null

    export PATH="$(dirname "${PYBIN}"):/usr/local/bin:${PATH}"
    export CC="${CC:-gcc}"
    export CXX="${CXX:-g++}"
    python3 --version
    gcc --version | head -n 1
    g++ --version | head -n 1

    cd source/c
    if [[ "${JHDF5_ARCH}" == "amd64" || "${JHDF5_ARCH}" == "x86_64" ]]; then
      read -r -a variant_args <<< "${JHDF5_VARIANTS}"
      ./build_linux_amd64_variants.sh "${variant_args[@]}"
    else
      ./compile_hdf5_linux_arm64.sh
      ./compile_linux_arm64.sh
    fi

    chown -R "${HOST_UID}:${HOST_GID}" libs/native/jhdf5 build 2>/dev/null || true
  '
