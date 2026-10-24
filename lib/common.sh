#!/usr/bin/env bash
# Some values here are read by the CLI and the installer rather than used in
# this file, so shellcheck cannot see the use. Challenge files are sourced by
# path at runtime. Both are expected.
# shellcheck disable=SC2034,SC1091
#
# Shared helpers for the Learmux CTF.
#
# Sourced by the ctf CLI and by the installer. Not meant to be run directly.
#
# Everything the tool creates lives in one of two places:
#   $LEARMUX_HOME   the tool, your progress, and the record of what it wrote
#   $HOME           challenge files, which are recorded in the same manifest
#
# Nothing here touches the network, and nothing needs root.

# ── paths ───────────────────────────────────────────────────────────────────
# LEARMUX_HOME is set by the caller before sourcing this file.
: "${LEARMUX_HOME:=$HOME/.learmux}"

LEARMUX_LIB="$LEARMUX_HOME/lib"
LEARMUX_CHALLENGES="$LEARMUX_HOME/challenges"
LEARMUX_SEED="$LEARMUX_HOME/seed"
LEARMUX_SOLVED="$LEARMUX_HOME/solved"
LEARMUX_HINTS="$LEARMUX_HOME/hints"
LEARMUX_MANIFEST="$LEARMUX_HOME/manifest"
LEARMUX_VERSION_FILE="$LEARMUX_HOME/version"

# ── output ──────────────────────────────────────────────────────────────────
# Colour only when writing to a terminal, and never when NO_COLOR is set.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'
  C_DIM=$'\033[2m'
  C_BOLD=$'\033[1m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
  C_CYAN=$'\033[36m'
  C_INVERT=$'\033[7m'
else
  C_RESET=''; C_DIM=''; C_BOLD=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_CYAN=''; C_INVERT=''
fi

say()  { printf '%s\n' "$*"; }
dim()  { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }
info() { printf '%s%s%s\n' "$C_CYAN" "$*" "$C_RESET"; }
ok()   { printf '%s%s%s\n' "$C_GREEN" "$*" "$C_RESET"; }
warn() { printf '%s%s%s\n' "$C_YELLOW" "$*" "$C_RESET" >&2; }
die()  { printf '%s%s%s\n' "$C_RED" "$*" "$C_RESET" >&2; exit 1; }

rule() { printf '%s%s%s\n' "$C_DIM" "────────────────────────────────────────────────────────────" "$C_RESET"; }

# ── animation ───────────────────────────────────────────────────────────────
# Decided once, at source time, so nothing has to test it repeatedly. Animation
# needs an interactive terminal and a sleep that accepts fractions (the GNU
# coreutils sleep in Termux does). Piped output and NO_COLOR always get the
# plain version, which is also what the test suite exercises.
LEARMUX_ANIM=0
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${LEARMUX_NO_ANIM:-0}" != "1" ]; then
  if sleep 0.01 2>/dev/null; then LEARMUX_ANIM=1; fi
fi

animating() { [ "$LEARMUX_ANIM" = "1" ]; }

# Print text one character at a time. Falls back to plain output.
type_out() {
  local text="$1" i
  if ! animating; then printf '%s\n' "$text"; return 0; fi
  for (( i = 0; i < ${#text}; i++ )); do
    printf '%s' "${text:i:1}"
    sleep 0.012
  done
  printf '\n'
}

# A one-line progress bar, redrawn in place.
progress_bar() { # <done> <total> [width]
  local done="$1" total="$2" width="${3:-26}" filled=0 i bar=''
  [ "$total" -gt 0 ] || total=1
  [ "$done" -le "$total" ] || done="$total"
  filled=$(( done * width / total ))
  for (( i = 0; i < width; i++ )); do
    if [ "$i" -lt "$filled" ]; then bar="${bar}█"; else bar="${bar}░"; fi
  done
  if [ -t 1 ]; then
    printf '\r  %s%s%s  %s/%s' "$C_GREEN" "$bar" "$C_RESET" "$done" "$total"
  fi
}

# Reveal a solved flag as if it were being decrypted.
reveal() { # <text>
  local text="$1" i
  if ! animating; then printf '%s\n' "$text"; return 0; fi
  for (( i = 0; i < ${#text}; i++ )); do
    printf '%s' "${text:i:1}"
    sleep 0.02
  done
  printf '\n'
}

# ── hashing ─────────────────────────────────────────────────────────────────
# Termux ships sha256sum with coreutils. The others are fallbacks.
have_sha256() {
  command -v sha256sum >/dev/null 2>&1 ||
    command -v shasum >/dev/null 2>&1 ||
    command -v openssl >/dev/null 2>&1
}

# Read stdin, print a lowercase hex digest.
sha256_hex() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | cut -d' ' -f1
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 | sed 's/^.*= //'
  else
    return 1
  fi
}

# ── the per-device seed ─────────────────────────────────────────────────────
# A random value generated once, at install time, and never shared. Every flag
# is derived from it, so two people running the same challenge get different
# flags and a solution posted online is worthless to anyone else.
random_hex() {
  local bytes="${1:-32}"
  if [ -r /dev/urandom ]; then
    od -An -N"$bytes" -tx1 /dev/urandom | tr -d ' \n'
  elif command -v openssl >/dev/null 2>&1; then
    openssl rand -hex "$bytes"
  else
    printf '%s%s%s%s' "$(date +%s)" "$$" "${RANDOM}${RANDOM}" "$bytes" | sha256_hex
  fi
}

# Print the seed, creating it if this is the first run.
ensure_seed() {
  if [ ! -s "$LEARMUX_SEED" ]; then
    mkdir -p "$(dirname "$LEARMUX_SEED")"
    random_hex 32 > "$LEARMUX_SEED"
    chmod 600 "$LEARMUX_SEED" 2>/dev/null || true
  fi
  cat "$LEARMUX_SEED"
}

# flag_for <challenge-id> -> LEARMUX{16 hex characters}
flag_for() {
  local digest
  digest="$(printf '%s:%s' "$(ensure_seed)" "$1" | sha256_hex)" || return 1
  printf 'LEARMUX{%s}\n' "$(printf '%s' "$digest" | cut -c1-16)"
}

# derived_name <challenge-id> <purpose> [length]
# A stable but device-specific name, for hiding things under names that differ
# from machine to machine.
derived_name() {
  local digest
  digest="$(printf '%s:%s:%s' "$(ensure_seed)" "$1" "$2" | sha256_hex)" || return 1
  printf '%s\n' "$(printf '%s' "$digest" | cut -c1-"${3:-8}")"
}

# A short public name for this device, safe to show and to share. It reveals
# nothing about the seed itself.
device_id() {
  printf '%s\n' "$(printf 'device:%s' "$(ensure_seed)" | sha256_hex | cut -c1-8)"
}

# ── the manifest ────────────────────────────────────────────────────────────
# Every path this tool creates is recorded here, in creation order. That is what
# makes uninstall exact rather than a guess.
manifest_init() { [ -f "$LEARMUX_MANIFEST" ] || : > "$LEARMUX_MANIFEST"; }

manifest_record() {
  manifest_init
  grep -Fxq "$1" "$LEARMUX_MANIFEST" 2>/dev/null || printf '%s\n' "$1" >> "$LEARMUX_MANIFEST"
}

manifest_paths() { [ -f "$LEARMUX_MANIFEST" ] && cat "$LEARMUX_MANIFEST"; }

# ── progress ────────────────────────────────────────────────────────────────
is_solved() { [ -f "$LEARMUX_SOLVED" ] && grep -Fxq "$1" "$LEARMUX_SOLVED"; }

mark_solved() {
  mkdir -p "$(dirname "$LEARMUX_SOLVED")"
  touch "$LEARMUX_SOLVED"
  is_solved "$1" || printf '%s\n' "$1" >> "$LEARMUX_SOLVED"
}

solved_count() {
  if [ -f "$LEARMUX_SOLVED" ]; then grep -c . "$LEARMUX_SOLVED"; else printf '0\n'; fi
}

# ── hints ───────────────────────────────────────────────────────────────────
# A hint can run to several lines, so hints are separated by a line holding
# only three dashes. That keeps the challenge files readable while letting the
# CLI count hints rather than lines.
hints_count() { # reads stdin
  local input
  input="$(cat)"
  if [ -z "$input" ]; then printf '0\n'; return 0; fi
  printf '%s\n' "$input" | awk 'BEGIN { n = 1 } /^---$/ { n++ } END { print n }'
}

hints_nth() { # <n>, reads stdin
  awk -v want="$1" 'BEGIN { n = 1 } /^---$/ { n++; next } n == want { print }'
}

# How many hints you have asked for, per challenge. Stored so `ctf hint` gives
# you the next one rather than starting over.
hints_revealed() { # <slug>
  local f="$LEARMUX_HINTS/$1"
  if [ -f "$f" ]; then cat "$f"; else printf '0\n'; fi
}

hints_used_total() {
  [ -d "$LEARMUX_HINTS" ] || { printf '0\n'; return; }
  cat "$LEARMUX_HINTS"/* 2>/dev/null | awk '{s+=$1} END {printf "%d\n", s+0}'
}

# Everything this tool writes must be recorded in the manifest, or uninstall
# will leave it behind. That applies to the hint counters too.
bump_hints() { # <slug> <new-count>
  mkdir -p "$LEARMUX_HINTS"
  manifest_record "$LEARMUX_HINTS"
  printf '%s\n' "$2" > "$LEARMUX_HINTS/$1"
  manifest_record "$LEARMUX_HINTS/$1"
}

# ── challenges ──────────────────────────────────────────────────────────────
# Each challenge is a directory holding a challenge.sh that sets a few
# CHALLENGE_* variables and defines challenge_briefing, challenge_files,
# challenge_setup and challenge_hints.
#
# The same directory may hold a solution.sh, which the installer deliberately
# does not copy. Solutions are for the test suite.

# Read one metadata variable out of a challenge, without polluting this shell.
challenge_meta() { # <dir> <VAR_NAME>
  ( . "$1/challenge.sh" >/dev/null 2>&1; eval "printf '%s' \"\${$2:-}\"" )
}

# challenge_dir <id-or-slug> -> prints the directory, or fails
challenge_dir() {
  local want="$1" dir id slug
  [ -d "$LEARMUX_CHALLENGES" ] || return 1
  for dir in "$LEARMUX_CHALLENGES"/*/; do
    [ -f "$dir/challenge.sh" ] || continue
    id="$(challenge_meta "$dir" CHALLENGE_ID)"
    slug="$(challenge_meta "$dir" CHALLENGE_SLUG)"
    if [ "$want" = "$id" ] || [ "$want" = "$slug" ]; then
      printf '%s\n' "${dir%/}"
      return 0
    fi
  done
  return 1
}

# Every challenge directory, in id order.
challenge_dirs() {
  local dir
  [ -d "$LEARMUX_CHALLENGES" ] || return 0
  for dir in "$LEARMUX_CHALLENGES"/*/; do
    [ -f "$dir/challenge.sh" ] || continue
    printf '%s\n' "${dir%/}"
  done | sort
}

challenge_count() {
  challenge_dirs | grep -c . || printf '0\n'
}

# Total points on offer, and points captured.
points_total() {
  local dir sum=0 p
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    p="$(challenge_meta "$dir" CHALLENGE_POINTS)"
    sum=$(( sum + ${p:-0} ))
  done <<< "$(challenge_dirs)"
  printf '%s\n' "$sum"
}

points_earned() {
  local dir slug sum=0 p
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    slug="$(challenge_meta "$dir" CHALLENGE_SLUG)"
    if is_solved "$slug"; then
      p="$(challenge_meta "$dir" CHALLENGE_POINTS)"
      sum=$(( sum + ${p:-0} ))
    fi
  done <<< "$(challenge_dirs)"
  printf '%s\n' "$sum"
}

# ── json ────────────────────────────────────────────────────────────────────
# Enough JSON writing for the export command, with no dependency.
json_escape() {
  printf '%s' "$1" |
    sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' -e 's/\r/\\r/g' |
    awk '{ printf "%s%s", (NR > 1 ? "\\n" : ""), $0 }'
}
