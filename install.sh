#!/bin/sh
set -eu

# DESTDIR stages installation for verification without touching the system.
DESTDIR=${DESTDIR:-}
case $DESTDIR in
    ''|/*) ;;
    *)
        printf '%s\n' 'DESTDIR deve essere assoluto.' >&2
        exit 1
        ;;
esac
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
bin=$DESTDIR/usr/local/bin/67
gif=$DESTDIR/usr/local/share/67/67.gif
prompt=$DESTDIR/usr/local/share/67/prompt.zsh
modules=$DESTDIR/usr/local/share/67/prompt

install -d -m 755 "$DESTDIR/usr/local/bin" "$modules"
install -m 755 "$root/src/67" "$bin"
install -m 644 "$root/assets/67.gif" "$gif"
install -m 644 "$root/src/prompt.zsh" "$prompt"

[ -x "$bin" ] && [ -r "$gif" ] && [ -r "$prompt" ]
cmp "$root/src/67" "$bin"
cmp "$root/assets/67.gif" "$gif"
cmp "$root/src/prompt.zsh" "$prompt"
for source in "$root"/src/prompt/*.zsh; do
    target=$modules/${source##*/}
    install -m 644 "$source" "$target"
    cmp "$source" "$target"
done
printf '%s\n' "Installazione verificata: $bin"
if ! command -v chafa >/dev/null 2>&1 || ! command -v zsh >/dev/null 2>&1; then
    printf '%s\n' 'Installa le dipendenze: sudo apt install chafa zsh'
fi
