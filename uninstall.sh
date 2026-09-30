#!/bin/sh
set -eu

DESTDIR=${DESTDIR:-}
case $DESTDIR in
    ''|/*) ;;
    *)
        printf '%s\n' 'DESTDIR deve essere assoluto.' >&2
        exit 1
        ;;
esac
bin=$DESTDIR/usr/local/bin/67
data=$DESTDIR/usr/local/share/67
rm -f -- "$bin" "$data/67.gif" "$data/prompt.zsh"
for module in ansi frames renderer editor; do
    rm -f -- "$data/prompt/$module.zsh"
done
# Preserve unrelated files if someone placed any in this directory.
if [ -d "$data/prompt" ]; then rmdir -- "$data/prompt"; fi
if [ -d "$data" ]; then rmdir -- "$data"; fi
[ ! -e "$bin" ] && [ ! -e "$data/67.gif" ] && [ ! -e "$data/prompt.zsh" ]
printf '%s\n' '67 disinstallato.'
