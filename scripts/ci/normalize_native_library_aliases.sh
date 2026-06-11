#!/usr/bin/env bash
set -euo pipefail

root="${1:-libs/native/jhdf5}"

if [[ ! -d "${root}" ]]; then
  echo "Native payload root does not exist: ${root}" >&2
  exit 1
fi

sha256_file() {
  sha256sum "$1" | awk '{print $1}'
}

replace_with_symlink_if_identical() {
  local alias="$1"
  local target="$2"

  [[ -f "${alias}" && -f "${target}" ]] || return 0
  [[ ! -L "${alias}" ]] || return 0

  local alias_hash
  local target_hash
  alias_hash="$(sha256_file "${alias}")"
  target_hash="$(sha256_file "${target}")"
  if [[ "${alias_hash}" != "${target_hash}" ]]; then
    echo "Keeping non-identical native alias ${alias} and ${target}" >&2
    return 0
  fi

  local target_name
  target_name="$(basename "${target}")"
  rm -f "${alias}"
  ln -s "${target_name}" "${alias}"
  echo "Linked duplicate native alias ${alias} -> ${target_name}"
}

normalize_linux_soname_family() {
  local directory="$1"
  local unversioned="$2"

  [[ -f "${unversioned}" || -L "${unversioned}" ]] || return 0
  local library_name
  library_name="$(basename "${unversioned}")"

  local versioned=()
  while IFS= read -r -d '' candidate; do
    [[ "${candidate}" != "${unversioned}" ]] || continue
    versioned+=("${candidate}")
  done < <(find "${directory}" -maxdepth 1 \( -type f -o -type l \) -name "${library_name}.*" -print0 | sort -z)

  [[ ${#versioned[@]} -gt 0 ]] || return 0

  local canonical="${versioned[-1]}"
  replace_with_symlink_if_identical "${unversioned}" "${canonical}"

  local alias
  for alias in "${versioned[@]}"; do
    [[ "${alias}" != "${canonical}" ]] || continue
    replace_with_symlink_if_identical "${alias}" "${canonical}"
  done
}

while IFS= read -r -d '' platform_dir; do
  while IFS= read -r -d '' unversioned; do
    normalize_linux_soname_family "${platform_dir}" "${unversioned}"
  done < <(find "${platform_dir}" -maxdepth 1 \( -type f -o -type l \) -name '*.so' -print0 | sort -z)
done < <(find "${root}" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
