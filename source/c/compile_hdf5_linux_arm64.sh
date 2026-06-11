#! /bin/bash
set -euo pipefail

if [ -z "${CFLAGS+x}" ]; then
  CFLAGS="-O3 -fPIC -std=gnu99"
fi
export CFLAGS

./compile_hdf5_gcc.sh aarch64 ""
