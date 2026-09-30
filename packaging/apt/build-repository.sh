#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
key_home=${APT_SIGNING_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/67-apt/gnupg}
case $key_home in
    /*) ;;
    *) printf '%s\n' 'APT_SIGNING_HOME deve essere assoluto.' >&2; exit 1 ;;
esac
for dependency in gpg gpgv apt-ftparchive gzip sha256sum dpkg-deb; do
    command -v "$dependency" >/dev/null 2>&1 || {
        printf 'Manca %s. Installa gnupg e apt-utils.\n' "$dependency" >&2
        exit 127
    }
done
if [ ! -r "$key_home/67-fingerprint" ]; then
    printf '%s\n' 'Prima esegui packaging/apt/init-key.sh.' >&2
    exit 1
fi
fingerprint=$(cat "$key_home/67-fingerprint")
"$root/packaging/build-deb.sh"
version=$(sed -n 's/^Version: //p' "$root/packaging/control")
output=$root/dist/apt
work=$(mktemp -d "$root/dist/.apt-repository.XXXXXX")
cleanup() {
    # Restore the previous complete repository if the final rename failed.
    if [ -d "$work/previous" ] && [ ! -e "$output" ]; then
        mv "$work/previous" "$output"
    fi
    rm -rf -- "$work"
}
trap cleanup 0
trap 'exit 130' INT
trap 'exit 143' TERM
repository=$work/repository
mkdir -p "$repository/pool"
# Retain published package URLs while clients may still hold older indexes.
if [ -d "$output/pool" ]; then cp -R "$output/pool/." "$repository/pool/"; fi
install -m 644 "$root/dist/67_${version}_all.deb" "$repository/pool/"
gpg --homedir "$key_home" --batch --export-options export-minimal \
    --export "$fingerprint" > "$repository/67-archive-keyring.gpg"
[ -s "$repository/67-archive-keyring.gpg" ]
printf '%s\n' "$fingerprint" > "$repository/67-archive-keyring.fingerprint"
(
    cd "$repository"
    apt-ftparchive packages pool > Packages
    gzip -n -9 -c Packages > Packages.gz
    apt-ftparchive -o APT::FTPArchive::Release::Origin=67 \
        -o APT::FTPArchive::Release::Label=67 release . > "$work/Release"
)
install -m 644 "$work/Release" "$repository/Release"
gpg --homedir "$key_home" --batch --yes --local-user "$fingerprint" \
    --digest-algo SHA256 --clearsign --output "$repository/InRelease" "$repository/Release"
gpg --homedir "$key_home" --batch --yes --local-user "$fingerprint" \
    --digest-algo SHA256 --armor --detach-sign --output "$repository/Release.gpg" "$repository/Release"
gpgv --keyring "$repository/67-archive-keyring.gpg" "$repository/InRelease"
# The public setup script downloads only this key, with repository-scoped trust.
key_hash=$(sha256sum "$repository/67-archive-keyring.gpg" | cut -d ' ' -f1)
{
    printf '%s\n' '#!/bin/sh' "KEY_SHA256='$key_hash'"
    sed '1d' "$root/packaging/apt/configure-apt.sh.in"
} > "$repository/configure-apt.sh"
chmod 755 "$repository/configure-apt.sh"
# Hosts such as GitHub Pages must serve these files as plain static assets.
: > "$repository/.nojekyll"
if [ -e "$output" ]; then mv "$output" "$work/previous"; fi
mv "$repository" "$output"
printf 'Repository firmato pronto da pubblicare: %s\n' "$output"
