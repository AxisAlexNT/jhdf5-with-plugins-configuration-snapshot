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
CMAKE_PRESET_EXTRA_ARGS='-DCMAKE_C_FLAGS=-Dfdopen=fdopen'
CMAKE_PRESET_EXTRA_ARGS="$CMAKE_PRESET_EXTRA_ARGS -DCMAKE_CXX_FLAGS=-Dfdopen=fdopen"
CMAKE_PRESET_EXTRA_ARGS="$CMAKE_PRESET_EXTRA_ARGS -DCMAKE_REQUIRED_DEFINITIONS=-Dfdopen=fdopen"
export CMAKE_PRESET CMAKE_PRESET_EXTRA_ARGS
CFLAGS='-Wno-error=implicit-function-declaration -m64 -mmacosx-version-min=10.11' ./compile_hdf5_gcc.sh x86_64
