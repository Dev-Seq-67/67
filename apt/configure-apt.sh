#!/bin/sh
KEY_SHA256='1f2fdc49cb00969cd1be8826e0cea585c2a638cdd3c37e74679a040e252ed94a'
set -eu
# KEY_SHA256 is inserted by build-repository.sh and pins the downloaded key.

if [ "$#" -ne 1 ]; then
    printf '%s\n' 'Uso: sudo sh configure-apt.sh https://indirizzo/repository' >&2
    exit 2
fi
repository=${1%/}
case $repository in
    https://?*) ;;
    *) printf '%s\n' 'Serve un indirizzo HTTPS.' >&2; exit 2 ;;
esac
# URIs is a deb822 field: reject whitespace and fragments, not just newlines.
case $repository in
    *[[:space:]]*|*\#*|*\?*) printf '%s\n' 'Indirizzo repository non valido.' >&2; exit 2 ;;
esac
DESTDIR=${DESTDIR:-}
case $DESTDIR in
    ''|/*) ;;
    *) printf '%s\n' 'DESTDIR deve essere assoluto.' >&2; exit 2 ;;
esac
if [ -z "$DESTDIR" ] && [ "$(id -u)" -ne 0 ]; then
    printf '%s\n' 'Esegui questo script con sudo.' >&2
    exit 1
fi
for dependency in curl sha256sum install; do
    command -v "$dependency" >/dev/null 2>&1 || {
        printf 'Manca %s.\n' "$dependency" >&2
        exit 127
    }
done
work=$(mktemp -d)
trap 'rm -rf -- "$work"' 0
trap 'exit 130' INT
trap 'exit 143' TERM
curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
    "$repository/67-archive-keyring.gpg" -o "$work/key.gpg"
printf '%s  %s\n' "$KEY_SHA256" "$work/key.gpg" | sha256sum -c - >/dev/null
cat > "$work/67.sources" <<SOURCES
Types: deb
URIs: $repository
Suites: ./
Signed-By: /etc/apt/keyrings/67-archive-keyring.gpg
SOURCES
install -d -m 755 "$DESTDIR/etc/apt/keyrings" "$DESTDIR/etc/apt/sources.list.d"
install -m 644 "$work/key.gpg" "$DESTDIR/etc/apt/keyrings/67-archive-keyring.gpg"
install -m 644 "$work/67.sources" "$DESTDIR/etc/apt/sources.list.d/67.sources"
printf '%s\n' 'Repository configurato. Ora esegui:' 'sudo apt update' 'sudo apt install 67'
