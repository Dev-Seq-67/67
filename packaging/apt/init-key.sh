#!/bin/sh
set -eu

# Keep repository signing material separate from the user's GPG keyring.
key_home=${APT_SIGNING_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/67-apt/gnupg}
case $key_home in
    /*) ;;
    *) printf '%s\n' 'APT_SIGNING_HOME deve essere assoluto.' >&2; exit 1 ;;
esac
command -v gpg >/dev/null 2>&1 || { printf '%s\n' 'Manca gpg.' >&2; exit 127; }
umask 077
mkdir -p "$key_home"
chmod 700 "$key_home"
if [ ! -f "$key_home/67-fingerprint" ]; then
    # A dedicated unattended signing key; never copy this directory to hosting.
    gpg --homedir "$key_home" --batch --pinentry-mode loopback --passphrase '' \
        --quick-generate-key '67 APT repository' ed25519 sign 2y >&2
    gpg --homedir "$key_home" --batch --with-colons --list-secret-keys \
        '67 APT repository' | awk -F: '$1 == "fpr" {print $10; exit}' \
        > "$key_home/67-fingerprint"
fi
fingerprint=$(cat "$key_home/67-fingerprint")
[ -n "$fingerprint" ]
gpg --homedir "$key_home" --batch --list-secret-keys "$fingerprint" >/dev/null
printf '%s\n' "$fingerprint"
