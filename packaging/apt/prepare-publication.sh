#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
"$root/packaging/apt/build-repository.sh"
REPOSITORY="$root/dist/apt" "$root/tests/apt-repository.sh"
mkdir -p "$root/apt"
cp -R "$root/dist/apt/." "$root/apt/"
printf '%s\n' 'File pubblici pronti in apt/. Pubblica il commit su main per avviare GitHub Pages.'
