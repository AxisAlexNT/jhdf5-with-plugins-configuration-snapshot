#! /bin/bash
set -euo pipefail

normalize_preset() {
  local preset="${CMAKE_PRESET:-ci-StdShar-Clang}"
  preset="${preset%%-}"
  echo "$preset"
}

if [ -z "${CMAKE_PRESET:-}" ]; then
  CMAKE_PRESET="hict-StdShar-Clang-noexamples"
fi
CMAKE_PRESET="$(normalize_preset)"
export CMAKE_PRESET
CFLAGS='-Wno-error=implicit-function-declaration -m64 -mmacosx-version-min=10.11' ./compile_hdf5_gcc.sh x86_64
