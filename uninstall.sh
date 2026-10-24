#!/usr/bin/env bash
# Learmux CTF uninstaller.
#
# Removes exactly what install.sh and `ctf start` created, by reading the
# manifest those wrote. It does not guess, and it does not go looking for
# anything it did not make.
#
#   ./uninstall.sh          show the plan, then ask
#   ./uninstall.sh --yes    do not ask

set -euo pipefail

LEARMUX_HOME="${LEARMUX_HOME:-$HOME/.learmux}"
MANIFEST="$LEARMUX_HOME/manifest"
ASSUME_YES=0

while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes) ASSUME_YES=1 ;;
    -h|--help)
      cat <<'USAGE'
Learmux CTF uninstaller

  ./uninstall.sh [--yes]

  --yes, -y      do not ask for confirmation
  --help, -h     show this message

Environment:
  LEARMUX_HOME   where the tool was installed (default: ~/.learmux)
USAGE
      exit 0 ;;
    *) printf 'uninstall.sh: unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'
  C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'
else
  C_RESET=''; C_DIM=''; C_BOLD=''; C_GREEN=''; C_YELLOW=''; C_RED=''
fi
say()  { printf '%s\n' "$*"; }
dim()  { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }
ok()   { printf '%s%s%s\n' "$C_GREEN" "$*" "$C_RESET"; }
warn() { printf '%s%s%s\n' "$C_YELLOW" "$*" "$C_RESET" >&2; }
die()  { printf '%s%s%s\n' "$C_RED" "$*" "$C_RESET" >&2; exit 1; }
rule() { printf '%s%s%s\n' "$C_DIM" "────────────────────────────────────────────────────────────" "$C_RESET"; }

if [ ! -f "$MANIFEST" ]; then
  if [ -d "$LEARMUX_HOME" ]; then
    warn "  Found $LEARMUX_HOME but no manifest inside it."
    dim  '  Nothing was recorded there, so there is nothing this script can safely remove.'
    dim  '  Delete the directory by hand if you are sure it is ours.'
    exit 1
  fi
  dim '  The Learmux CTF is not installed here.'
  exit 0
fi

# Everything the manifest lists, in the order it was created. Reading it into an
# array up front means the file can be removed as part of the cleanup.
paths=()
while IFS= read -r line; do
  [ -n "$line" ] || continue
  paths+=("$line")
done < "$MANIFEST"

files=()
dirs=()
declare -A dir_seen=()
for p in "${paths[@]}"; do
  # a trailing "/." means the same directory as without it, so collapse it
  p="${p%/.}"
  if [ -d "$p" ]; then
    [ -n "${dir_seen[$p]:-}" ] && continue
    dir_seen[$p]=1
    dirs+=("$p")
  elif [ -e "$p" ]; then
    files+=("$p")
  fi
done

rule
printf '%s  Learmux CTF uninstaller%s\n' "$C_BOLD" "$C_RESET"
rule
say ''
printf '  This will remove %s file(s) and %s directory(ies):\n' "${#files[@]}" "${#dirs[@]}"
say ''
for f in "${files[@]}"; do printf '    %s\n' "$f"; done
for d in "${dirs[@]}"; do printf '    %s/\n' "$d"; done
say ''
dim '  Directories are removed only if they end up empty, so anything you put'
dim '  in them yourself stays where it is.'
say ''
rule
say ''

if [ "$ASSUME_YES" -ne 1 ]; then
  printf 'Remove all of it? [y/N] '
  reply=''
  read -r reply || true
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) dim 'Nothing was removed.'; exit 1 ;;
  esac
fi

say ''

# ── files first ─────────────────────────────────────────────────────────────
removed=0
for f in "${files[@]}"; do
  if [ -e "$f" ]; then
    rm -f "$f" && removed=$((removed + 1))
  fi
done

# ── then directories, children before parents ───────────────────────────────
# The manifest records parents before children, so walking it backwards means
# each directory is empty by the time we reach it.
leftover=0
for (( i=${#dirs[@]}-1; i>=0; i-- )); do
  d="${dirs[$i]}"
  [ -d "$d" ] || continue
  rmdir "$d" 2>/dev/null || leftover=$((leftover + 1))
done

say ''
if [ "$leftover" -eq 0 ]; then
  ok "  Removed. $removed file(s) deleted."
  dim '  Your challenge files are gone and the ctf command is gone with them.'
else
  warn "  Removed $removed file(s), but $leftover directory(ies) were not empty."
  dim  '  They held something this tool did not create, so they were left alone:'
  for d in "${dirs[@]}"; do
    [ -d "$d" ] && printf '    %s\n' "$d"
  done
fi
say ''
