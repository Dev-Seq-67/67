#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
if ! command -v dpkg-deb >/dev/null 2>&1; then
    printf '%s\n' 'Manca dpkg-deb: sudo apt install dpkg' >&2
    exit 127
fi
stage=$(mktemp -d)
chmod 755 "$stage"
trap 'rm -rf -- "$stage"' 0
trap 'exit 130' INT
trap 'exit 143' TERM
install -d -m 755 "$stage/DEBIAN" "$stage/usr/bin" \
    "$stage/usr/share/67/prompt" "$stage/usr/share/doc/67/docs"
install -m 644 "$root/packaging/control" "$stage/DEBIAN/control"
install -m 755 "$root/src/67" "$stage/usr/bin/67"
install -m 644 "$root/assets/67.gif" "$stage/usr/share/67/67.gif"
install -m 644 "$root/src/prompt.zsh" "$stage/usr/share/67/prompt.zsh"
for source in "$root"/src/prompt/*.zsh; do
    install -m 644 "$source" "$stage/usr/share/67/prompt/${source##*/}"
done
install -m 644 "$root/LICENSE" "$stage/usr/share/doc/67/copyright"
install -m 644 "$root/README.md" "$stage/usr/share/doc/67/README.md"
install -m 644 "$root/docs/architecture.md" "$stage/usr/share/doc/67/docs/architecture.md"
install -m 644 "$root/docs/apt-repository.md" "$stage/usr/share/doc/67/docs/apt-repository.md"
size=$(du -sk "$stage/usr" | cut -f1)
printf 'Installed-Size: %s\n' "$size" >> "$stage/DEBIAN/control"
mkdir -p "$root/dist"
version=$(sed -n 's/^Version: //p' "$root/packaging/control")
dpkg-deb --root-owner-group --build "$stage" "$root/dist/67_${version}_all.deb"
