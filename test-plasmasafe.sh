#!/usr/bin/env bash
set -euo pipefail

FAKE_HOME="/tmp/plasmasafe-test-home"
EXPORT_FILE="/tmp/plasmasafe-export-test.tar.gz"
IMPORT_HOME="/tmp/plasmasafe-import-home"

echo "== PlasmaSafe test suite =="

fail() {
  echo
  echo "FAILED: $1"
  exit 1
}

pass() {
  echo "OK: $1"
}

run_ps() {
  PLASMASAFE_HOME="$FAKE_HOME" cabal run plasmasafe -- "$@"
}

run_ps_import_home() {
  PLASMASAFE_HOME="$IMPORT_HOME" cabal run plasmasafe -- "$@"
}

echo
echo "== Cleaning old test data =="
rm -rf "$FAKE_HOME" "$IMPORT_HOME" "$EXPORT_FILE"

echo
echo "== Creating fake home =="
./make-fake-home.sh "$FAKE_HOME" >/dev/null
test -f "$FAKE_HOME/.config/kwinrc" || fail "fake kwinrc was not created"
pass "fake home created"

echo
echo "== Building project =="
cabal build
pass "build completed"

echo
echo "== Testing doctor =="
run_ps doctor >/tmp/plasmasafe-doctor.out
grep -q "PlasmaSafe Doctor" /tmp/plasmasafe-doctor.out || fail "doctor output missing header"
pass "doctor works"

echo
echo "== Testing profiles =="
run_ps profiles >/tmp/plasmasafe-profiles.out
grep -q "Profile: minimal" /tmp/plasmasafe-profiles.out || fail "minimal profile missing"
grep -q "Profile: desktop" /tmp/plasmasafe-profiles.out || fail "desktop profile missing"
grep -q "Profile: full" /tmp/plasmasafe-profiles.out || fail "full profile missing"
pass "profiles works"

echo
echo "== Testing save/list/show =="
run_ps save base --profile desktop >/tmp/plasmasafe-save-base.out
run_ps list >/tmp/plasmasafe-list.out
grep -q "base" /tmp/plasmasafe-list.out || fail "saved snapshot not listed"

run_ps show base >/tmp/plasmasafe-show.out
grep -q "Name:          base" /tmp/plasmasafe-show.out || fail "show output missing snapshot name"
grep -q "Profile:       desktop" /tmp/plasmasafe-show.out || fail "show output missing profile"
pass "save/list/show work"

echo
echo "== Testing show --json =="
run_ps show base --json >/tmp/plasmasafe-show-json.out
grep -q '"snapshotName": "base"' /tmp/plasmasafe-show-json.out || fail "show --json missing snapshotName"
grep -q '"profileName": "desktop"' /tmp/plasmasafe-show-json.out || fail "show --json missing profileName"
pass "show --json works"

echo
echo "== Testing list --json =="
run_ps list --json >/tmp/plasmasafe-list-json.out
grep -q '"snapshotName": "base"' /tmp/plasmasafe-list-json.out || fail "list --json missing snapshot"
pass "list --json works"

echo
echo "== Testing verify success =="
run_ps verify base >/tmp/plasmasafe-verify.out
grep -q "OK: snapshot passed verification." /tmp/plasmasafe-verify.out || fail "verify did not pass valid snapshot"
pass "verify success works"

echo
echo "== Testing verify --json success =="
run_ps verify base --json >/tmp/plasmasafe-verify-json.out
grep -q '"verificationOk": true' /tmp/plasmasafe-verify-json.out || fail "verify --json did not report true"
pass "verify --json success works"

echo
echo "== Testing diff =="
echo "BROKEN CHANGE" >> "$FAKE_HOME/.config/kwinrc"
run_ps save changed --profile desktop >/tmp/plasmasafe-save-changed.out
run_ps diff base changed >/tmp/plasmasafe-diff.out
grep -q "BROKEN CHANGE" /tmp/plasmasafe-diff.out || fail "diff did not show changed content"
pass "diff works"

echo
echo "== Testing restore --dry-run =="
run_ps restore base --dry-run >/tmp/plasmasafe-restore-dry-run.out
grep -q "Restore dry-run only" /tmp/plasmasafe-restore-dry-run.out || fail "dry-run missing header"
grep -q "Nothing was changed" /tmp/plasmasafe-restore-dry-run.out || fail "dry-run missing no-change message"
pass "restore --dry-run works"

echo
echo "== Testing restore --force =="
run_ps restore base --force >/tmp/plasmasafe-restore-force.out
grep -q "Restore completed." /tmp/plasmasafe-restore-force.out || fail "restore force did not complete"

if grep -q "BROKEN CHANGE" "$FAKE_HOME/.config/kwinrc"; then
  fail "restore did not remove BROKEN CHANGE"
fi

run_ps list >/tmp/plasmasafe-list-after-restore.out
grep -q "auto-before-restore-base" /tmp/plasmasafe-list-after-restore.out || fail "auto safety snapshot not created"
pass "restore --force works"

echo
echo "== Testing export =="
run_ps export base "$EXPORT_FILE" >/tmp/plasmasafe-export.out
test -f "$EXPORT_FILE" || fail "export archive was not created"
tar -tzf "$EXPORT_FILE" | grep -q "manifest.json" || fail "export archive missing manifest"
pass "export works"

echo
echo "== Testing import =="
./make-fake-home.sh "$IMPORT_HOME" >/dev/null
rm -rf "$IMPORT_HOME/.local/state/plasmasafe"

run_ps_import_home import "$EXPORT_FILE" >/tmp/plasmasafe-import.out
grep -q "Import completed" /tmp/plasmasafe-import.out || fail "import did not complete"

run_ps_import_home list >/tmp/plasmasafe-import-list.out
grep -q "base" /tmp/plasmasafe-import-list.out || fail "imported snapshot not listed"

run_ps_import_home verify base >/tmp/plasmasafe-import-verify.out
grep -q "OK: snapshot passed verification." /tmp/plasmasafe-import-verify.out || fail "imported snapshot failed verification"
pass "import works"

echo
echo "== Testing delete preview =="
run_ps delete changed >/tmp/plasmasafe-delete-preview.out
grep -q "Delete preview only" /tmp/plasmasafe-delete-preview.out || fail "delete preview missing safety message"
run_ps list >/tmp/plasmasafe-list-before-delete.out
grep -q "changed" /tmp/plasmasafe-list-before-delete.out || fail "delete preview should not delete snapshot"
pass "delete preview works"

echo
echo "== Testing delete --force =="
run_ps delete changed --force >/tmp/plasmasafe-delete-force.out
grep -q "Deleted snapshot" /tmp/plasmasafe-delete-force.out || fail "delete --force missing deleted message"

run_ps list >/tmp/plasmasafe-list-after-delete.out
if grep -q "changed" /tmp/plasmasafe-list-after-delete.out; then
  fail "delete --force did not delete snapshot"
fi
pass "delete --force works"

echo
echo "== Testing verify failure exit code =="
SNAPSHOT_DIR="$(find "$FAKE_HOME/.local/state/plasmasafe/snapshots" -maxdepth 1 -type d -name '*_base' | head -n 1)"
rm -f "$SNAPSHOT_DIR/files/.config/kwinrc"

set +e
run_ps verify base >/tmp/plasmasafe-verify-fail.out 2>&1
VERIFY_CODE=$?
set -e

if [ "$VERIFY_CODE" -eq 0 ]; then
  fail "verify returned exit code 0 for broken snapshot"
fi

grep -q "FAILED" /tmp/plasmasafe-verify-fail.out || fail "verify failure output did not contain FAILED"
pass "verify failure exit code works"

echo
echo "== Testing verify --json failure exit code =="
set +e
run_ps verify base --json >/tmp/plasmasafe-verify-json-fail.out 2>&1
VERIFY_JSON_CODE=$?
set -e

if [ "$VERIFY_JSON_CODE" -eq 0 ]; then
  fail "verify --json returned exit code 0 for broken snapshot"
fi

grep -q '"verificationOk": false' /tmp/plasmasafe-verify-json-fail.out || fail "verify --json did not report false"
pass "verify --json failure exit code works"

echo
echo "== All tests passed =="
