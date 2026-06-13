#!/usr/bin/env bash
set -euo pipefail

AUR_DIR="${AUR_DIR:-../plasmasafe-aur}"
PKGNAME="${PKGNAME:-plasmasafe}"

# Set AUR package version here.
PKGVER="${PKGVER:-0.1.0.0}"
PKGREL="${PKGREL:-1}"

PROJECT_DIR="$(pwd)"

echo "== PlasmaSafe AUR publish script =="
echo "Project dir: $PROJECT_DIR"
echo "AUR dir:     $AUR_DIR"
echo "Package:     $PKGNAME"
echo "Version:     $PKGVER-$PKGREL"
echo

fail() {
  echo
  echo "FAILED: $1"
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

need_cmd git
need_cmd makepkg
need_cmd updpkgsums
need_cmd sed

if ! command -v namcap >/dev/null 2>&1; then
  echo "WARN: namcap not found. Install with: sudo pacman -S namcap"
fi

echo "== Checking project files =="
test -f "$PROJECT_DIR/plasmasafe.cabal" || fail "plasmasafe.cabal not found"
test -f "$PROJECT_DIR/README.md" || fail "README.md not found"
test -f "$PROJECT_DIR/CHANGELOG.md" || fail "CHANGELOG.md not found"
test -f "$PROJECT_DIR/test-plasmasafe.sh" || fail "test-plasmasafe.sh not found"

echo "== Running project tests =="
cabal build
./test-plasmasafe.sh

echo
echo "== Checking AUR repository =="
if [ ! -d "$AUR_DIR/.git" ]; then
  fail "AUR repo not found at $AUR_DIR

Create it first with:

  git clone ssh://aur@aur.archlinux.org/${PKGNAME}.git $AUR_DIR"
fi

cd "$AUR_DIR"

REMOTE_URL="$(git remote get-url origin || true)"
echo "AUR remote: $REMOTE_URL"

case "$REMOTE_URL" in
  *aur.archlinux.org*) ;;
  *)
    fail "This does not look like an AUR remote: $REMOTE_URL"
    ;;
esac

echo
echo "== Syncing AUR repository =="
git pull --rebase

echo
echo "== Checking required AUR files =="
test -f PKGBUILD || fail "PKGBUILD missing in AUR repo"

echo
echo "== Updating PKGBUILD version =="
sed -i "s/^pkgver=.*/pkgver=${PKGVER}/" PKGBUILD
sed -i "s/^pkgrel=.*/pkgrel=${PKGREL}/" PKGBUILD

grep -q "^pkgver=${PKGVER}$" PKGBUILD || fail "pkgver was not updated correctly"
grep -q "^pkgrel=${PKGREL}$" PKGBUILD || fail "pkgrel was not updated correctly"

echo "PKGBUILD version set to: ${PKGVER}-${PKGREL}"

echo
echo "== Updating checksums =="
updpkgsums

echo
echo "== Generating .SRCINFO =="
makepkg --printsrcinfo > .SRCINFO

echo
echo "== Building package =="
makepkg --clean --syncdeps --noconfirm

if command -v namcap >/dev/null 2>&1; then
  echo
  echo "== Running namcap =="
  namcap PKGBUILD || true

  PACKAGE_FILE="$(find . -maxdepth 1 -type f -name "${PKGNAME}-*.pkg.tar.*" | head -n 1 || true)"
  if [ -n "$PACKAGE_FILE" ]; then
    namcap "$PACKAGE_FILE" || true
  fi
fi

echo
echo "== Git status =="
git status --short

if git diff --quiet && git diff --cached --quiet; then
  echo "No AUR changes to push."
  exit 0
fi

echo
echo "Files changed:"
git status --short

echo
read -r -p "Commit and push these AUR changes? [y/N] " answer

case "$answer" in
  y|Y|yes|YES)
    ;;
  *)
    echo "Aborted before commit."
    exit 0
    ;;
esac

git add PKGBUILD .SRCINFO

if git diff --cached --quiet; then
  echo "Nothing staged."
  exit 0
fi

git commit -m "Update ${PKGNAME} to ${PKGVER}-${PKGREL}"
git push

echo
echo "AUR push completed."
