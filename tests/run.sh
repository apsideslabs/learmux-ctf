#!/usr/bin/env bash
# Challenge and solution files are sourced by path at runtime, so shellcheck
# cannot follow them. That is expected.
# shellcheck disable=SC1091
# End-to-end test for the Learmux CTF.
#
# Installs into a throwaway HOME and PREFIX, plays every challenge the way a
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

# Read one CHALLENGE_* value out of a challenge in the repository.
challenge_field() { # <dir> <VAR>
  ( . "$1/challenge.sh"; eval "printf '%s' \"\${$2:-}\"" )
}

# The flag this device should produce for a challenge.
expected_flag() { # <id>
  ( LEARMUX_HOME="$LEAR" . "$LEAR/lib/common.sh"; flag_for "$1" )
}

# Run the commands a challenge's solution.sh prints, and return everything they
# produced. This is how a challenge is proved solvable without shipping the
# answer to the player.
solve() { # <repo-challenge-dir>
  local dir="$1" line out=''
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    out="${out}$(eval "$line" 2>&1)"$'\n'
  done <<< "$( . "$dir/solution.sh"; challenge_solution )"
  printf '%s' "$out"
}

# ── the installer refuses outside Termux ────────────────────────────────────
printf '\n── the installer refuses outside Termux ──\n'
out="$( bash "$REPO/install.sh" --yes 2>&1 )"; code=$?
check_true "refuses without --force when Termux is not detected" "$([ "$code" -ne 0 ] && echo 0 || echo 1 )"
check_true "and writes nothing" "$([ ! -d "$LEAR" ] && echo 0 || echo 1 )"

# ── install ─────────────────────────────────────────────────────────────────
printf '\n── install ──\n'
out="$( bash "$REPO/install.sh" --yes --force 2>&1 )"; code=$?
check "install exits 0" "$code" "0"
check_true "the tool directory exists" "$([ -d "$LEAR" ] && echo 0 || echo 1 )"
check_true "a seed was written" "$([ -s "$LEAR/seed" ] && echo 0 || echo 1 )"
check "the seed is 64 hex characters" "$(tr -d '\n' < "$LEAR/seed" | wc -c | tr -d ' ')" "64"
check "the seed is hex" "$(grep -c '^[0-9a-f]\{64\}$' "$LEAR/seed" || true)" "1"
check_true "a manifest was written" "$([ -s "$LEAR/manifest" ] && echo 0 || echo 1 )"
check_true "the ctf command was installed" "$([ -x "$CTF" ] && echo 0 || echo 1 )"
check_true "the library was copied" "$([ -f "$LEAR/lib/common.sh" ] && echo 0 || echo 1 )"
check "the version is recorded" "$(cat "$LEAR/version")" "0.2.0"
check_true "the installer did not claim PREFIX/bin" "$(grep -qx "$PREFIX/bin" "$LEAR/manifest" && echo 1 || echo 0 )"
check "the manifest has no /. entries" "$(grep -c '/\.$' "$LEAR/manifest")" "0"
seed_before="$(tr -d '\n' < "$LEAR/seed")"

# ── every challenge is installed, and no solution is ────────────────────────
printf '\n── what got installed ──\n'
repo_challenges=$(find "$REPO/challenges" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
check "challenges in the repository" "$repo_challenges" "6"
check "challenges installed" "$(find "$LEAR/challenges" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" "6"
check "solution files installed" "$(find "$LEAR/challenges" -name 'solution.sh' | wc -l | tr -d ' ')" "0"
check_true "the repository still holds the solutions" "$([ "$(find "$REPO/challenges" -name 'solution.sh' | wc -l | tr -d ' ')" = "6" ] && echo 0 || echo 1 )"

# ── ctf list ────────────────────────────────────────────────────────────────
printf '\n── ctf list ──\n'
out="$( "$CTF" list 2>&1 )"; code=$?
check "list exits 0" "$code" "0"
check_true "lists the challenges" "$([ "$(printf '%s' "$out" | grep -c 'pts')" = "6" ] && echo 0 || echo 1 )"
check_true "shows the points total" "$(printf '%s' "$out" | grep -q '120 points' && echo 0 || echo 1 )"
check_true "shows them all as open" "$([ "$(printf '%s' "$out" | grep -c 'open')" = "6" ] && echo 0 || echo 1 )"

# ── play every challenge, exactly as documented ─────────────────────────────
for cdir in "$REPO"/challenges/*/; do
  [ -f "$cdir/challenge.sh" ] || continue
  id="$(challenge_field "$cdir" CHALLENGE_ID)"
  slug="$(challenge_field "$cdir" CHALLENGE_SLUG)"
  title="$(challenge_field "$cdir" CHALLENGE_TITLE)"
  want="$(expected_flag "$id")"

  printf '\n── %s  %s (%s) ──\n' "$id" "$title" "$slug"

  out="$( "$CTF" start "$id" 2>&1 )"; code=$?
  check "$slug: start exits 0" "$code" "0"
  check_true "$slug: does not reveal the file names" "$([ "$(printf '%s' "$out" | grep -cE '\.backup-|\.cache-|private-|part-a|access\.log|payload\.txt|backup-')" = "0" ] && echo 0 || echo 1 )"

  out="$(solve "$cdir")"
  check_true "$slug: the documented solution finds the flag" "$(printf '%s' "$out" | grep -qF "$want" && echo 0 || echo 1 )"

  if "$CTF" check "$id" "$want" >/dev/null 2>&1; then code=0; else code=1; fi
  check_true "$slug: the flag is accepted" "$code"

  if "$CTF" check "$id" 'LEARMUX{0000000000000000}' >/dev/null 2>&1; then code=0; else code=1; fi
  check_true "$slug: a wrong flag is rejected" "$([ "$code" -ne 0 ] && echo 0 || echo 1 )"

  if "$CTF" reset "$id" >/dev/null 2>&1; then code=0; else code=1; fi
  check_true "$slug: reset works" "$code"
  check_true "$slug: the flag survives a reset" "$(solve "$cdir" | grep -qF "$want" && echo 0 || echo 1 )"
done

# ── progress ────────────────────────────────────────────────────────────────
printf '\n── progress ──\n'
out="$( "$CTF" list 2>&1 )"
check_true "everything now reads as captured" "$([ "$(printf '%s' "$out" | grep 'pts' | grep -c 'captured')" = "6" ] && echo 0 || echo 1 )"
check_true "and the points are counted" "$(printf '%s' "$out" | grep -q '6 of 6 captured, 120 of 120 points' && echo 0 || echo 1 )"

# ── hints ───────────────────────────────────────────────────────────────────
printf '\n── hints ──\n'
out="$( "$CTF" hint 01 2>&1 )"
check_true "the first hint is the first one" "$(printf '%s' "$out" | grep -q 'Hint 1 of 2' && echo 0 || echo 1 )"
out="$( "$CTF" hint 01 2>&1 )"
check_true "the next call gives the next hint" "$(printf '%s' "$out" | grep -q 'Hint 2 of 2' && echo 0 || echo 1 )"
out="$( "$CTF" hint 01 2>&1 )"
check_true "past the last one it says so" "$(printf '%s' "$out" | grep -qi 'last hint' && echo 0 || echo 1 )"
out="$( "$CTF" hint 01 2>&1 )"
check_true "and keeps saying so" "$(printf '%s' "$out" | grep -qi 'last hint' && echo 0 || echo 1 )"

# ── export ──────────────────────────────────────────────────────────────────
printf '\n── export ──\n'
out="$( "$CTF" export 2>&1 )"
check_true "export mentions the device" "$(printf '%s' "$out" | grep -q '"device"' && echo 0 || echo 1 )"
check_true "export counts the captures" "$(printf '%s' "$out" | grep -q '"solved": 6' && echo 0 || echo 1 )"
check_true "export counts the points" "$(printf '%s' "$out" | grep -q '"points": 120' && echo 0 || echo 1 )"
if command -v python3 >/dev/null 2>&1; then
  json=1
  if printf '%s' "$out" | python3 -c 'import json,sys; json.load(sys.stdin)' >/dev/null 2>&1; then json=0; fi
  check_true "the export is valid JSON" "$json"
fi

out="$( "$CTF" export --challenges 2>&1 )"
check_true "the challenge manifest lists all six" "$([ "$(printf '%s' "$out" | grep -c '"slug"')" = "6" ] && echo 0 || echo 1 )"
check_true "the challenge manifest carries the briefing" "$(printf '%s' "$out" | grep -q '"briefing"' && echo 0 || echo 1 )"
check_true "the challenge manifest carries no real flag" "$(printf '%s' "$out" | grep -qF "$(expected_flag 01)" && echo 1 || echo 0 )"
if command -v python3 >/dev/null 2>&1; then
  json=1
  if printf '%s' "$out" | python3 -c 'import json,sys; json.load(sys.stdin)' >/dev/null 2>&1; then json=0; fi
  check_true "the challenge manifest is valid JSON" "$json"
fi

# ── doctor ──────────────────────────────────────────────────────────────────
printf '\n── doctor ──\n'
out="$( "$CTF" doctor 2>&1 )"; code=$?
check "doctor exits 0" "$code" "0"
check_true "doctor reports the seed" "$(printf '%s' "$out" | grep -q '64 hex characters' && echo 0 || echo 1 )"
check_true "doctor reports the challenges" "$(printf '%s' "$out" | grep -q '6 installed' && echo 0 || echo 1 )"
check_true "doctor says everything is right" "$(printf '%s' "$out" | grep -q 'Everything looks right' && echo 0 || echo 1 )"

# ── no arguments, no terminal ───────────────────────────────────────────────
printf '\n── piped, with no arguments ──\n'
out="$( "$CTF" 2>&1 )"; code=$?
check "exits 0" "$code" "0"
check_true "prints the how-to-play text rather than a menu" "$(printf '%s' "$out" | grep -q 'HOW TO PLAY' && echo 0 || echo 1 )"

# ── reset and reinstall ─────────────────────────────────────────────────────
printf '\n── reset, and re-installing ──\n'
rm -f "$HOME"/.backup-*
out="$( "$CTF" reset 01 2>&1 )"
check_true "reset puts the files back" "$([ -n "$(find_hidden "$HOME" ".backup-")" ] && echo 0 || echo 1 )"
out="$( bash "$REPO/install.sh" --yes --force 2>&1 )"; code=$?
check "re-install exits 0" "$code" "0"
check "the seed is not regenerated" "$(tr -d '\n' < "$LEAR/seed")" "$seed_before"
out="$( "$CTF" list 2>&1 )"
check_true "and your progress survives" "$(printf '%s' "$out" | grep -q 'captured' && echo 0 || echo 1 )"

# ── a second device gets its own flags ──────────────────────────────────────
printf '\n── a second device gets its own flags ──\n'
export HOME="$TMP/home2"
mkdir -p "$HOME"
bash "$REPO/install.sh" --yes --force >/dev/null 2>&1
"$PREFIX/bin/ctf" start 01 >/dev/null 2>&1
f2="$(find_hidden "$HOME" ".backup-")"
flag_b="$(grep -o 'LEARMUX{[^}]*}' "$HOME/$f2" | head -n1)"
check_true "a different seed" "$([ "$(tr -d '\n' < "$HOME/.learmux/seed")" != "$seed_before" ] && echo 0 || echo 1 )"
check_true "a different flag" "$([ -n "$flag_b" ] && [ "$flag_b" != "$(expected_flag 01)" ] && echo 0 || echo 1 )"
check_true "a different file name" "$([ -n "$f2" ] && echo 0 || echo 1 )"

# ── uninstall ───────────────────────────────────────────────────────────────
printf '\n── uninstall ──\n'
export HOME="$TMP/home"
out="$( bash "$REPO/uninstall.sh" --yes 2>&1 )"; code=$?
check "uninstall exits 0" "$code" "0"
check_true "the tool directory is gone" "$([ ! -d "$LEAR" ] && echo 0 || echo 1 )"
check_true "the ctf command is gone" "$([ ! -e "$CTF" ] && echo 0 || echo 1 )"
check_true "the challenge files are gone" "$([ -z "$(find_hidden "$HOME" ".backup-")" ] && echo 0 || echo 1 )"
check "no challenge directories remain" "$(find "$HOME" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" "0"
check_true "PREFIX/bin was left alone" "$([ -d "$PREFIX/bin" ] && echo 0 || echo 1 )"
check_true "the home directory itself is untouched" "$([ -d "$HOME" ] && echo 0 || echo 1 )"
check_true "uninstall reports a clean removal" "$(printf '%s' "$out" | grep -q 'Removed' && printf '%s' "$out" | grep -q 'not empty' && echo 1 || echo 0 )"
check_true "and lists no leftovers" "$(printf '%s' "$out" | grep -q 'left alone' && echo 1 || echo 0 )"

printf '\n── uninstalling again is harmless ──\n'
out="$( bash "$REPO/uninstall.sh" --yes 2>&1 )"; code=$?
check "a second uninstall exits 0" "$code" "0"

printf '\n────────────────────────────────────────────────────────────\n'
printf '%s passed, %s failed\n\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
