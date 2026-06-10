#! /bin/bash
set -euo pipefail

if [ -z "${CFLAGS+x}" ]; then
  CFLAGS="-O3 -fPIC"
fi
export CFLAGS

./compile_hdf5_gcc.sh aarch64 ""
