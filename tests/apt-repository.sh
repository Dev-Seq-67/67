#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
repository=${REPOSITORY:-$root/dist/apt}
work=$(mktemp -d /tmp/67-apt-test.XXXXXX)
cp -R "$repository" "$work/repository"
mkdir -p "$work/apt/lists/partial" "$work/apt/archives/partial" "$work/downloads"
cp /var/lib/dpkg/status "$work/apt/status"
cat > "$work/67.sources" <<SOURCES
Types: deb
URIs: file:$work/repository
Suites: ./
Signed-By: $work/repository/67-archive-keyring.gpg
SOURCES
# All APT state stays in the test directory; no system source or cache changes.
apt_isolated() {
    client=$1
    shift
    "$client" -o "Dir::Etc::sourcelist=$work/67.sources" \
        -o Dir::Etc::sourceparts=- -o Dir::Etc::main=- -o Dir::Etc::parts=- \
        -o "Dir::State=$work/apt" -o "Dir::State::status=$work/apt/status" \
        -o "Dir::Cache=$work/apt" -o "APT::Sandbox::User=$(id -un)" \
        -o APT::Update::Error-Mode=any -o Acquire::Languages=none \
        "$@"
}
if ! apt_isolated apt-get update > "$work/update.log" 2>&1; then
    cat "$work/update.log" >&2
    exit 1
fi
(
    cd "$work/downloads"
    apt_isolated apt-get download 67 > "$work/download.log" 2>&1
)
version=$(sed -n 's/^Version: //p' "$root/packaging/control")
cmp "$work/downloads/67_${version}_all.deb" "$work/repository/pool/67_${version}_all.deb"
if ! apt_isolated apt --simulate install 67 > "$work/install-simulation.log" 2>&1; then
    cat "$work/install-simulation.log" >&2
    exit 1
fi
printf '%s\n' 'PASS: APT verifies the signature, finds 67, downloads it and simulates installation'

# Stage client configuration, replacing only the network download with a copy.
mkdir -p "$work/bin"
cat > "$work/bin/curl" <<'CURL'
#!/bin/sh
while [ "$#" -gt 0 ]; do
    if [ "$1" = -o ]; then cp "$MOCK_KEY" "$2"; exit; fi
    shift
done
exit 2
CURL
chmod 755 "$work/bin/curl"
PATH="$work/bin:$PATH" MOCK_KEY="$repository/67-archive-keyring.gpg" \
    DESTDIR="$work/client" sh "$repository/configure-apt.sh" https://example.org/67 \
    > "$work/configure.log"
cmp "$repository/67-archive-keyring.gpg" "$work/client/etc/apt/keyrings/67-archive-keyring.gpg"
grep -q '^URIs: https://example.org/67$' "$work/client/etc/apt/sources.list.d/67.sources"
grep -q '^Signed-By: /etc/apt/keyrings/67-archive-keyring.gpg$' "$work/client/etc/apt/sources.list.d/67.sources"
printf wrong-key > "$work/wrong-key"
if PATH="$work/bin:$PATH" MOCK_KEY="$work/wrong-key" DESTDIR="$work/rejected-client" \
    sh "$repository/configure-apt.sh" https://example.org/67 > "$work/rejected-key.log" 2>&1; then
    printf '%s\n' 'FAIL: configuration accepted the wrong public key' >&2
    exit 1
fi
[ ! -e "$work/rejected-client/etc/apt/sources.list.d/67.sources" ]
printf '%s\n' 'PASS: staged client configuration and rejection of a substituted public key'

# A valid index must not let a modified package through the download check.
printf x >> "$work/repository/pool/67_${version}_all.deb"
rm "$work/downloads/67_${version}_all.deb"
if (cd "$work/downloads" && apt_isolated apt-get download 67) > "$work/tampered-package.log" 2>&1; then
    printf '%s\n' 'FAIL: APT downloaded a tampered package' >&2
    exit 1
fi
grep -q 'Hash Sum mismatch' "$work/tampered-package.log"
printf '%s\n' 'PASS: APT rejects a tampered package'

# Remove cached indexes so the negative control must fetch the altered signature.
sed 's/Label: 67/Label: 68/' "$work/repository/InRelease" > "$work/tampered-release"
mv "$work/tampered-release" "$work/repository/InRelease"
rm -rf "$work/apt/lists"
mkdir -p "$work/apt/lists/partial"
if apt_isolated apt-get update > "$work/tampered-signature.log" 2>&1; then
    printf '%s\n' 'FAIL: APT accepted a tampered signature' >&2
    exit 1
fi
grep -Eq 'BADSIG|invalid signature|not signed' "$work/tampered-signature.log"
printf '%s\n' 'PASS: APT rejects altered signed metadata'
printf 'Evidence: %s\n' "$work"
