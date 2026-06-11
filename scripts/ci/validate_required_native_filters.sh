#!/usr/bin/env bash
set -euo pipefail

root="${1:-libs/native/jhdf5}"
if [[ ! -d "${root}" ]]; then
  echo "Native root does not exist: ${root}" >&2
  exit 1
fi

required_filters=(bshuf lzf zstd)
required_dirs=(
  "amd64-Linux"
  "amd64-Linux-avx2"
  "arm64-Linux"
  "amd64-Windows"
  "amd64-Windows-avx2"
  "aarch64-Mac OS X"
  "x86_64-Mac OS X"
)

missing=0
for platform in "${required_dirs[@]}"; do
  dir="${root}/${platform}"
  if [[ ! -d "${dir}" ]]; then
    echo "Missing native platform directory: ${dir}" >&2
    missing=1
    continue
  fi

  for filter in "${required_filters[@]}"; do
    case "${platform}" in
      *Windows*)
        pattern="${dir}/libh5${filter}.dll"
        ;;
      *Mac\ OS\ X*)
        pattern="${dir}/libh5${filter}.dylib"
        ;;
      *)
        pattern="${dir}/libh5${filter}.so"
        ;;
    esac
    if ! compgen -G "${pattern}" >/dev/null; then
      echo "Missing required HDF5 filter plugin ${filter} for ${platform} under ${dir}" >&2
      missing=1
    fi
  done
done

if [[ "${missing}" -ne 0 ]]; then
  echo "Required HDF5 filter plugin validation failed." >&2
  exit 1
fi

echo "Required HDF5 filter plugins are present for all packaged native platforms."
