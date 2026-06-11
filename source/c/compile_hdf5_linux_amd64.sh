#! /bin/bash
set -e
set -u
set -o pipefail

if [ -z "${CFLAGS+x}" ]; then
  CFLAGS="-O3 -fPIC -m64 -mavx2 -mfma -msse4.2 -mbmi -mbmi2 -mtune=generic -std=gnu99"
fi
export CFLAGS

./compile_hdf5_gcc.sh amd64 ""
