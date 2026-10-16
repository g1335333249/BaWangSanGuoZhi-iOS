#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
core=third_party/segagenesisrecomp/external/m68k-recomp-core
apply_one() {
  repo=$1
  patch=$2
  if git -C "$repo" apply --reverse --check "$(pwd)/$patch" 2>/dev/null; then
    echo "$patch already applied"
  elif git -C "$repo" apply --check "$(pwd)/$patch"; then
    git -C "$repo" apply "$(pwd)/$patch"
    echo "$patch applied"
  else
    echo "Cannot apply $patch to this upstream commit" >&2
    exit 1
  fi
}
apply_one "$core" scripts/patches/m68k-rtr-return.patch
apply_one "$core" scripts/patches/m68k-m2-codegen.patch
apply_one third_party/segagenesisrecomp scripts/patches/m2-runtime-cosim.patch
apply_one third_party/segagenesisrecomp scripts/patches/m2-cosim-input-script.patch
