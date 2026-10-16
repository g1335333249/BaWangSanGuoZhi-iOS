#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
upstream=third_party/segagenesisrecomp
commit=f875aa8eac5e0749ce42c3f1cec601b6317c6b51
fresh=0
if [ ! -d "$upstream/.git" ]; then
  mkdir -p third_party
  git clone --recursive https://github.com/mstan/segagenesisrecomp.git "$upstream"
  fresh=1
fi
if [ "$fresh" -eq 1 ]; then
  git -C "$upstream" checkout "$commit"
fi
actual=$(git -C "$upstream" rev-parse HEAD)
if [ "$actual" != "$commit" ]; then
  echo "Expected upstream $commit; found $actual. Use a clean checkout of the pinned revision." >&2
  exit 1
fi
git -C "$upstream" submodule update --init --recursive
sh scripts/apply_upstream_patches.sh
