#!/usr/bin/env bash
# End-to-end test for the Learmux CTF.
#
# Installs into a throwaway HOME and PREFIX, plays challenge 01 the way a
# learner would, and uninstalls. Nothing touches the real home directory.
#
#   ./tests/run.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# A HOME and a PREFIX of our own, so the default paths are exercised rather
# than overridden. LEARMUX_HOME is deliberately left unset: the CLI has to
# find the install on its own.
export HOME="$TMP/home"
export PREFIX="$TMP/prefix"
export NO_COLOR=1
unset LEARMUX_HOME
mkdir -p "$HOME" "$PREFIX/bin"

CTF="$PREFIX/bin/ctf"
LEAR="$HOME/.learmux"
seed_before=""

pass=0
fail=0
check() { # <name> <actual> <expected>
  if [ "$2" = "$3" ]; then
    printf 'OK   %s\n' "$1"; pass=$((pass + 1))
  else
    printf 'FAIL %s\n       expected: [%s]\n       actual:   [%s]\n' "$1" "$3" "$2"
    fail=$((fail + 1))
  fi
}
check_true() { # <name> <0-or-1>
  if [ "$2" = "0" ]; then
    printf 'OK   %s\n' "$1"; pass=$((pass + 1))
  else
    printf 'FAIL %s\n' "$1"; fail=$((fail + 1))
  fi
}
# First file in a directory matching a prefix, as a bare name.
find_hidden() { # <dir> <prefix>
  local f
  for f in "$1"/"$2"*; do
    [ -e "$f" ] || continue
    printf '%s\n' "${f##*/}"
    return 0
  done
}

printf '\n── the installer refuses outside Termux ──\n'
out="$( bash "$REPO/install.sh" --yes 2>&1 )"; code=$?
check_true "refuses without --force when Termux is not detected" "$([ "$code" -ne 0 ] && echo 0 || echo 1 )"
check_true "and writes nothing" "$([ ! -d "$LEAR" ] && echo 0 || echo 1 )"

printf '\n── install ──\n'
out="$( bash "$REPO/install.sh" --yes --force 2>&1 )"; code=$?
check "install exits 0" "$code" "0"
check_true "the tool directory exists" "$([ -d "$LEAR" ] && echo 0 || echo 1 )"
check_true "a seed was written" "$([ -s "$LEAR/seed" ] && echo 0 || echo 1 )"
check "the seed is 64 hex characters" "$(tr -d '\n' < "$LEAR/seed" | wc -c | tr -d ' ')" "64"
check "the seed is hex" "$(grep -c '^[0-9a-f]\{64\}$' "$LEAR/seed" || true)" "1"
check_true "a manifest was written" "$([ -s "$LEAR/manifest" ] && echo 0 || echo 1 )"
check_true "the ctf command was installed" "$([ -x "$CTF" ] && echo 0 || echo 1 )"
check_true "the challenge was copied" "$([ -f "$LEAR/challenges/01-hidden-file/challenge.sh" ] && echo 0 || echo 1 )"
check_true "the library was copied" "$([ -f "$LEAR/lib/common.sh" ] && echo 0 || echo 1 )"
check_true "the installer did not claim PREFIX/bin" "$(grep -qx "$PREFIX/bin" "$LEAR/manifest" && echo 1 || echo 0 )"
check "the manifest has no /. entries" "$(grep -c '/\.$' "$LEAR/manifest")" "0"
seed_before="$(tr -d '\n' < "$LEAR/seed")"

printf '\n── ctf list ──\n'
out="$( "$CTF" list 2>&1 )"; code=$?
check "list exits 0" "$code" "0"
check_true "lists the challenge by slug" "$(printf '%s' "$out" | grep -q 'hidden-file' && echo 0 || echo 1 )"
check_true "shows it as open" "$(printf '%s' "$out" | grep -q 'open' && echo 0 || echo 1 )"
check_true "shows the points total" "$(printf '%s' "$out" | grep -q '10 points' && echo 0 || echo 1 )"

printf '\n── ctf start 01 ──\n'
out="$( "$CTF" start 01 2>&1 )"; code=$?
check "start exits 0" "$code" "0"
check_true "prints the briefing" "$(printf '%s' "$out" | grep -qi 'home directory' && echo 0 || echo 1 )"
check_true "does not reveal the file names" "$(printf '%s' "$out" | grep -q '\.backup-\|\.cache-' && echo 1 || echo 0 )"

flagfile="$(find_hidden "$HOME" ".backup-")"
decoy="$(find_hidden "$HOME" ".cache-")"
check_true "a hidden flag file was created" "$([ -n "$flagfile" ] && echo 0 || echo 1 )"
check_true "a decoy file was created" "$([ -n "$decoy" ] && echo 0 || echo 1 )"
check "the flag file is mode 600" "$(stat -c '%a' "$HOME/$flagfile" 2>/dev/null)" "600"
check "a plain listing shows nothing" "$(ls "$HOME")" ""

flag="$(grep -o 'LEARMUX{[^}]*}' "$HOME/$flagfile" | head -n1)"
check_true "the flag file holds a flag" "$([ -n "$flag" ] && echo 0 || echo 1 )"
check "the flag is the right shape" "$(printf '%s' "$flag" | grep -c '^LEARMUX{[0-9a-f]\{16\}}$' || true)" "1"
# grep -c prints 0 and exits 1 when there is no match, so do not add a fallback
check "the decoy holds no flag" "$(grep -c 'LEARMUX{' "$HOME/$decoy" 2>/dev/null)" "0"
check_true "the flag file is in the manifest" "$(grep -q "$HOME/$flagfile" "$LEAR/manifest" && echo 0 || echo 1 )"
check_true "the decoy is in the manifest" "$(grep -q "$HOME/$decoy" "$LEAR/manifest" && echo 0 || echo 1 )"

printf '\n── ctf check ──\n'
out="$( "$CTF" check 01 'LEARMUX{deadbeefdeadbeef}' 2>&1 )"; code=$?
check_true "a wrong flag is rejected" "$([ "$code" -ne 0 ] && echo 0 || echo 1 )"
check_true "and says so" "$(printf '%s' "$out" | grep -qi 'not the right' && echo 0 || echo 1 )"

out="$( "$CTF" check 01 "$flag" 2>&1 )"; code=$?
check "the right flag is accepted" "$code" "0"
check_true "and reports the capture" "$(printf '%s' "$out" | grep -qi 'correct' && echo 0 || echo 1 )"

out="$( "$CTF" list 2>&1 )"
check_true "list now shows it captured" "$(printf '%s' "$out" | grep -q 'captured' && echo 0 || echo 1 )"
check_true "and counts the points" "$(printf '%s' "$out" | grep -q '1 of 1 captured, 10 of 10 points' && echo 0 || echo 1 )"

printf '\n── ctf reset ──\n'
rm -f "$HOME/$flagfile"
out="$( "$CTF" reset 01 2>&1 )"; code=$?
check "reset exits 0" "$code" "0"
check_true "the file is back" "$([ -f "$HOME/$flagfile" ] && echo 0 || echo 1 )"
check "the flag is unchanged by a reset" "$(grep -o 'LEARMUX{[^}]*}' "$HOME/$flagfile" | head -n1)" "$flag"
out="$( "$CTF" list 2>&1 )"
check_true "a reset keeps your capture" "$(printf '%s' "$out" | grep -q 'captured' && echo 0 || echo 1 )"

printf '\n── re-installing ──\n'
out="$( bash "$REPO/install.sh" --yes --force 2>&1 )"; code=$?
check "re-install exits 0" "$code" "0"
check "the seed is not regenerated" "$(tr -d '\n' < "$LEAR/seed")" "$seed_before"
out="$( "$CTF" list 2>&1 )"
check_true "and your progress survives" "$(printf '%s' "$out" | grep -q 'captured' && echo 0 || echo 1 )"

printf '\n── a second device gets its own flags ──\n'
export HOME="$TMP/home2"
mkdir -p "$HOME"
bash "$REPO/install.sh" --yes --force >/dev/null 2>&1
"$PREFIX/bin/ctf" start 01 >/dev/null 2>&1
f2="$(find_hidden "$HOME" ".backup-")"
flag_b="$(grep -o 'LEARMUX{[^}]*}' "$HOME/$f2" | head -n1)"
check_true "a different seed" "$([ "$(tr -d '\n' < "$HOME/.learmux/seed")" != "$(tr -d '\n' < "$LEAR/seed")" ] && echo 0 || echo 1 )"
check_true "a different flag" "$([ -n "$flag_b" ] && [ "$flag_b" != "$flag" ] && echo 0 || echo 1 )"
check_true "a different file name" "$([ -n "$f2" ] && [ "$f2" != "$flagfile" ] && echo 0 || echo 1 )"

printf '\n── uninstall ──\n'
export HOME="$TMP/home"
out="$( bash "$REPO/uninstall.sh" --yes 2>&1 )"; code=$?
check "uninstall exits 0" "$code" "0"
check_true "the tool directory is gone" "$([ ! -d "$LEAR" ] && echo 0 || echo 1 )"
check_true "the ctf command is gone" "$([ ! -e "$CTF" ] && echo 0 || echo 1 )"
check_true "the flag file is gone" "$([ ! -e "$HOME/$flagfile" ] && echo 0 || echo 1 )"
check_true "the decoy is gone" "$([ ! -e "$HOME/$decoy" ] && echo 0 || echo 1 )"
check_true "PREFIX/bin was left alone" "$([ -d "$PREFIX/bin" ] && echo 0 || echo 1 )"
check_true "uninstall reports a clean removal" "$(printf '%s' "$out" | grep -q 'Removed' && printf '%s' "$out" | grep -q 'not empty' && echo 1 || echo 0 )"
check_true "and lists no leftovers" "$(printf '%s' "$out" | grep -q 'left alone' && echo 1 || echo 0 )"
check_true "the home directory itself is untouched" "$([ -d "$HOME" ] && echo 0 || echo 1 )"

printf '\n── uninstalling again is harmless ──\n'
out="$( bash "$REPO/uninstall.sh" --yes 2>&1 )"; code=$?
check "a second uninstall exits 0" "$code" "0"

printf '\n────────────────────────────────────────────────────────────\n'
printf '%s passed, %s failed\n\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
