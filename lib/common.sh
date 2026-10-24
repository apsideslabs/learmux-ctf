#!/usr/bin/env bash
# Some values here are read by the CLI and the installer rather than used in
# this file, so shellcheck cannot see the use. Challenge files are sourced by
# path at runtime. Both are expected.
# shellcheck disable=SC2034,SC1091
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
else
  C_RESET=''; C_DIM=''; C_BOLD=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_CYAN=''
fi

say()  { printf '%s\n' "$*"; }
dim()  { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }
info() { printf '%s%s%s\n' "$C_CYAN" "$*" "$C_RESET"; }
ok()   { printf '%s%s%s\n' "$C_GREEN" "$*" "$C_RESET"; }
warn() { printf '%s%s%s\n' "$C_YELLOW" "$*" "$C_RESET" >&2; }
die()  { printf '%s%s%s\n' "$C_RED" "$*" "$C_RESET" >&2; exit 1; }

rule() { printf '%s%s%s\n' "$C_DIM" "────────────────────────────────────────────────────────────" "$C_RESET"; }

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
  [ -f "$LEARMUX_SOLVED" ] && grep -c . "$LEARMUX_SOLVED" || printf '0\n'
}

# ── challenges ──────────────────────────────────────────────────────────────
# Each challenge is a directory holding a challenge.sh that sets a few
# CHALLENGE_* variables and defines challenge_briefing, challenge_files and
# challenge_setup.

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
