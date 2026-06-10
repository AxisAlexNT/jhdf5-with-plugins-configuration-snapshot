#! /bin/bash
set -euo pipefail

normalize_preset() {
  local preset="${CMAKE_PRESET:-ci-StdShar-Clang}"
  while [[ "$preset" == *-notest* ]]; do
    preset="${preset/-notest/}"
  done
  while [[ "$preset" == *-noexamples* ]]; do
    preset="${preset/-noexamples/}"
  done
  preset="${preset%%-}"
  if [[ "$preset" == hict-* ]]; then
    preset="ci-${preset#hict-}"
  fi
  echo "$preset"
}

CMAKE_PRESET="$(normalize_preset)"
export CMAKE_PRESET
CFLAGS='-Wno-error=implicit-function-declaration -m64 -mmacosx-version-min=10.11' ./compile_hdf5_gcc.sh aarch64
