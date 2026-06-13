#!/usr/bin/env bash
set -euo pipefail

# PlasmaSafe AUR submitter.
# This script creates/updates an AUR package repository containing only:
#   - PKGBUILD
#   - .SRCINFO
# It does NOT copy your project source code into the AUR repository.

# -----------------------------
# Edit these values per release
# -----------------------------
PKGNAME="plasmasafe"
PKGVER="0.1.0.0"
PKGREL="1"
SHA256SUM="0dd8593c4c62bd753d53e02486c7ed006cd6acfe4ad08d912eae06941b399721"

# Local AUR checkout path. Override at runtime if you want:
#   AUR_DIR=/path/to/plasmasafe-aur ./aur.sh
AUR_DIR="${AUR_DIR:-$HOME/aur/${PKGNAME}}"

# Default is to push to AUR. To test without pushing:
#   ./aur.sh --no-push
PUSH_TO_AUR=1

case "${1:-}" in
    "") ;;
    --push) PUSH_TO_AUR=1 ;;
    --no-push) PUSH_TO_AUR=0 ;;
    -h|--help)
        cat <<HELP
Usage: ./aur.sh [--push|--no-push]

Edit PKGVER and SHA256SUM near the top first.
Run checksum-helper.sh to get SHA256SUM.

Environment:
  AUR_DIR=/custom/path ./aur.sh --no-push
HELP
        exit 0
        ;;
    *)
        echo "error: unknown argument: $1" >&2
        echo "usage: ./aur.sh [--push|--no-push]" >&2
        exit 1
        ;;
esac

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "error: required command not found: $1" >&2
        exit 1
    }
}

need_cmd git
need_cmd makepkg
need_cmd awk

if [[ "$SHA256SUM" == "PUT_SHA256_HERE" || -z "$SHA256SUM" ]]; then
    echo "error: edit aur.sh and replace SHA256SUM with the value from checksum-helper.sh" >&2
    exit 1
fi

if [[ ! "$SHA256SUM" =~ ^[a-fA-F0-9]{64}$ ]]; then
    echo "error: SHA256SUM must be a 64-character hex string" >&2
    exit 1
fi

AUR_REMOTE="ssh://aur@aur.archlinux.org/${PKGNAME}.git"
SRC_URL="https://github.com/yousefvand/${PKGNAME}/archive/refs/tags/v${PKGVER}.tar.gz"

mkdir -p "$(dirname "$AUR_DIR")"

if [[ ! -d "$AUR_DIR/.git" ]]; then
    echo "==> Creating local AUR checkout: $AUR_DIR"
    if git clone "$AUR_REMOTE" "$AUR_DIR" 2>/dev/null; then
        :
    else
        echo "==> git clone failed. Creating a new local repo instead."
        echo "    This is normal for a brand-new AUR package, as long as your AUR SSH key is configured."
        mkdir -p "$AUR_DIR"
        git -C "$AUR_DIR" init
        git -C "$AUR_DIR" checkout -B master
        git -C "$AUR_DIR" remote add origin "$AUR_REMOTE"
    fi
fi

cd "$AUR_DIR"

git checkout -B master >/dev/null

# Keep the AUR repository clean: only PKGBUILD and .SRCINFO are generated.
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +

cat > PKGBUILD <<PKGBUILD_EOF
# Maintainer: Remisa Phillips <remisa.yousefvand@gmail.com>

pkgname=${PKGNAME}
pkgver=${PKGVER}
pkgrel=${PKGREL}
pkgdesc='KDE Plasma configuration backup and restore command-line tool'
arch=('x86_64')
url='https://github.com/yousefvand/plasmasafe'
license=('MIT')
depends=('ghc-libs' 'haskell-aeson' 'haskell-aeson-pretty' 'haskell-optparse-applicative')
makedepends=('ghc')
source=("\${pkgname}-\${pkgver}.tar.gz::${SRC_URL}")
sha256sums=('${SHA256SUM}')

_find_srcdir() {
    local d

    d="\${srcdir}/\${pkgname}-\${pkgver}"
    if [[ -d "\$d" ]]; then
        printf '%s\n' "\$d"
        return 0
    fi

    d="\${srcdir}/\${pkgname}-v\${pkgver}"
    if [[ -d "\$d" ]]; then
        printf '%s\n' "\$d"
        return 0
    fi

    find "\${srcdir}" -mindepth 1 -maxdepth 1 -type d -name "\${pkgname}-*" | head -n 1
}

prepare() {
    cd "\$(_find_srcdir)"

    # The project uses Cabal Simple build-type, but the release tree may not
    # include Setup.hs. Generate it locally inside the makepkg build directory.
    cat > Setup.hs <<'SETUP_EOF'
import Distribution.Simple
main = defaultMain
SETUP_EOF
}

build() {
    cd "\$(_find_srcdir)"

    runhaskell Setup.hs configure \
        --prefix=/usr \
        --docdir="/usr/share/doc/\${pkgname}" \
        --enable-executable-dynamic \
        --enable-shared \
        --enable-optimization=2

    runhaskell Setup.hs build
}

package() {
    cd "\$(_find_srcdir)"

    runhaskell Setup.hs copy --destdir="\${pkgdir}"

    install -Dm644 LICENSE "\${pkgdir}/usr/share/licenses/\${pkgname}/LICENSE"
    install -Dm644 README.md "\${pkgdir}/usr/share/doc/\${pkgname}/README.md"
}
PKGBUILD_EOF

makepkg --printsrcinfo > .SRCINFO

echo "==> Generated AUR files in: $AUR_DIR"
echo "==> Files:"
ls -la PKGBUILD .SRCINFO

git add PKGBUILD .SRCINFO

if git diff --cached --quiet; then
    echo "==> No changes to commit."
else
    git commit -m "Add/update ${PKGNAME} ${PKGVER}-${PKGREL}"
fi

if [[ "$PUSH_TO_AUR" -eq 1 ]]; then
    echo "==> Pushing to AUR: $AUR_REMOTE"
    git push -u origin master
    echo "==> Done. AUR package submitted/updated: ${PKGNAME}"
else
    echo "==> --no-push selected. Nothing was pushed."
    echo "To submit later:"
    echo "  cd '$AUR_DIR'"
    echo "  git push -u origin master"
fi
