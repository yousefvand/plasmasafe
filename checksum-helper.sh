#!/usr/bin/env bash
set -euo pipefail

# Edit this version when you make a new GitHub release tag.
PKGNAME="plasmasafe"
PKGVER="0.1.0.0"
TAG="v${PKGVER}"
URL="https://github.com/yousefvand/${PKGNAME}/archive/refs/tags/${TAG}.tar.gz"
OUT="/tmp/${PKGNAME}-${TAG}.tar.gz"

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "error: required command not found: $1" >&2
        exit 1
    }
}

need_cmd curl
need_cmd sha256sum
need_cmd tar
need_cmd awk

printf '==> Downloading release tarball to /tmp\n'
printf 'Package: %s\n' "$PKGNAME"
printf 'Version: %s\n' "$PKGVER"
printf 'Tag:     %s\n' "$TAG"
printf 'URL:     %s\n' "$URL"
printf 'Output:  %s\n\n' "$OUT"

rm -f "${OUT}.tmp"
curl --fail --location --show-error --retry 3 --connect-timeout 20 \
    --output "${OUT}.tmp" \
    "$URL"
mv "${OUT}.tmp" "$OUT"

SHA256="$(sha256sum "$OUT" | awk '{print $1}')"
DETECTED_VERSION="$({ tar -xOf "$OUT" "*/${PKGNAME}.cabal" 2>/dev/null || true; } \
    | awk 'tolower($1) == "version:" { print $2; exit }')"

printf '\n==> Result\n'
printf 'Downloaded file: %s\n' "$OUT"
printf 'Configured version: %s\n' "$PKGVER"
if [[ -n "$DETECTED_VERSION" ]]; then
    printf 'Version inside tarball: %s\n' "$DETECTED_VERSION"
else
    printf 'Version inside tarball: not detected\n'
fi
printf 'sha256: %s\n\n' "$SHA256"

printf 'Copy this into aur.sh:\n'
printf 'SHA256SUM="%s"\n' "$SHA256"
printf '\nOr into PKGBUILD directly:\n'
printf "sha256sums=('%s')\n" "$SHA256"
