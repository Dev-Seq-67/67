#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
work=$(mktemp -d /tmp/67-regression.XXXXXX)
mkdir -p "$work/broken/src" "$work/broken/assets"
cp "$root/src/67" "$work/broken/src/67"
cp "$root/src/prompt.zsh" "$work/broken/src/prompt.zsh"
cp -R "$root/src/prompt" "$work/broken/src/prompt"
cp "$root/assets/67.gif" "$work/broken/assets/67.gif"
# Negative control: restore precisely the missing cleanup from the review.
sed '/^_67_finish() {/,/^}/ { /region_highlight=()/d; }' \
    "$root/src/prompt/editor.zsh" > "$work/broken/src/prompt/editor.zsh"
if PROGRAM="$work/broken/src/67" REGRESSION_ONLY=1 \
    "$root/tests/integration.sh" > "$work/negative-control.log" 2>&1; then
    printf '%s\n' 'FAIL: regression test accepted the deliberately broken code' >&2
    exit 1
fi
grep -q 'Sprite colors leaked onto accepted command' "$work/negative-control.log"
printf '%s\n' 'PASS: negative control reproduces and detects the reviewed bug'
REGRESSION_ONLY=1 "$root/tests/integration.sh"
printf 'Regression evidence: %s\n' "$work"
