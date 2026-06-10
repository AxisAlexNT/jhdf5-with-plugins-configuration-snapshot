#! /bin/bash
set -euo pipefail

CMAKE_PRESET="${CMAKE_PRESET:-ci-StdShar-Clang}"
export CMAKE_PRESET
CFLAGS='-m64 -mmacosx-version-min=10.11' ./compile_hdf5_gcc.sh x86_64
