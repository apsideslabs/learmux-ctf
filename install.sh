#!/usr/bin/env bash
# Learmux CTF installer.
#
# Writes the tool into ~/.learmux, installs the `ctf` command, and generates a
# random value for this device that every flag is derived from.
#
# It prints exactly what it is about to write, and asks before writing it.
# Nothing here touches the network, and nothing needs root.
#
#   ./install.sh            normal install
#   ./install.sh --yes      skip the confirmation
#   ./install.sh --force    carry on even if Termux is not detected

set -euo pipefail

VERSION="0.1.0"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LEARMUX_HOME="${LEARMUX_HOME:-$HOME/.learmux}"
ASSUME_YES=0
FORCE=0

# ── arguments ───────────────────────────────────────────────────────────────
while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes)   ASSUME_YES=1 ;;
    -f|--force) FORCE=1 ;;
    -h|--help)
      cat <<'USAGE'
Learmux CTF installer

  ./install.sh [--yes] [--force]

  --yes, -y      do not ask for confirmation
  --force, -f    install even if this does not look like Termux
  --help, -h     show this message

Environment:
  LEARMUX_HOME   where to install (default: ~/.learmux)
USAGE
      exit 0 ;;
    *) printf 'install.sh: unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

# ── output, before the library is in place ──────────────────────────────────
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

confirm() { # <prompt>
  if [ "$ASSUME_YES" -eq 1 ]; then return 0; fi
  printf '%s ' "$1"
  local reply=''
  read -r reply || true
  case "$reply" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

# ── environment checks ──────────────────────────────────────────────────────
is_termux() {
  [ -n "${TERMUX_VERSION:-}" ] || [ -d /data/data/com.termux/files/usr ]
}

missing=''
for tool in cut grep sed awk mktemp; do
  command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
done

rule
printf '%s  Learmux CTF installer%s  %s%s%s\n' "$C_BOLD" "$C_RESET" "$C_DIM" "$VERSION" "$C_RESET"
rule
say ''

if is_termux; then
  ok '  Termux detected.'
else
  warn '  This does not look like Termux.'
  dim  '  The tool works on any Linux, but the challenges are written for Termux.'
  if [ "$FORCE" -ne 1 ]; then
    say ''
    dim  '  Re-run with --force to install anyway.'
    exit 1
  fi
fi

if ! ( command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || command -v openssl >/dev/null 2>&1 ); then
  die '  No SHA-256 tool found. In Termux: pkg install coreutils'
fi

if [ -n "$missing" ]; then
  die "  Missing required tools:$missing    In Termux: pkg install coreutils"
fi

# Where the `ctf` command goes. $PREFIX/bin is on PATH in Termux and is owned by
# the user, so it is the natural home. Otherwise fall back to ~/.local/bin.
BIN_DIR=''
if [ -n "${PREFIX:-}" ] && [ -d "$PREFIX/bin" ] && [ -w "$PREFIX/bin" ]; then
  BIN_DIR="$PREFIX/bin"
elif [ -d "$HOME/.local/bin" ] && [ -w "$HOME/.local/bin" ]; then
  BIN_DIR="$HOME/.local/bin"
else
  BIN_DIR="$HOME/.local/bin"
fi

say ''
dim '  Required tools found.'
say ''

# ── the plan ────────────────────────────────────────────────────────────────
lib_count=$(find "$REPO_DIR/lib" -type f 2>/dev/null | wc -l | tr -d ' ')
chal_count=$(find "$REPO_DIR/challenges" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')

rule
printf '%s  This will write%s\n' "$C_BOLD" "$C_RESET"
rule
printf '    %-42s %s\n' "$LEARMUX_HOME/" 'the tool and your progress'
printf '    %-42s %s\n' "$LEARMUX_HOME/seed" 'a random value for this device (mode 600)'
printf '    %-42s %s\n' "$LEARMUX_HOME/solved" 'the challenges you have captured'
printf '    %-42s %s\n' "$LEARMUX_HOME/manifest" 'every path below, so it can all be removed'
printf '    %-42s %s\n' "$LEARMUX_HOME/lib/" "$lib_count file(s)"
printf '    %-42s %s\n' "$LEARMUX_HOME/challenges/" "$chal_count challenge(s)"
printf '    %-42s %s\n' "$BIN_DIR/ctf" 'the command you run'
say ''
dim '  Challenges write their own files into your home directory when you run'
dim "  'ctf start'. Those paths go into the same manifest."
say ''
dim '  Nothing here uses the network. Nothing runs as root.'
dim '  Remove all of it later with ./uninstall.sh'
say ''
rule
say ''

if ! confirm 'Install? [y/N]'; then
  dim 'Nothing was written.'
  exit 1
fi

say ''

# ── the library, so the manifest helpers are available ──────────────────────
mkdir -p "$LEARMUX_HOME/lib"
# shellcheck source=/dev/null
. "$REPO_DIR/lib/common.sh"

manifest_init
manifest_record "$LEARMUX_HOME"
manifest_record "$LEARMUX_HOME/lib"
manifest_record "$LEARMUX_HOME/challenges"
manifest_record "$LEARMUX_MANIFEST"

# ── copy the tool ───────────────────────────────────────────────────────────
copy_tree() { # <src-dir> <dest-dir>
  local src="$1" dest="$2" rel file dir
  mkdir -p "$dest"
  manifest_record "$dest"
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    rel="${rel#./}"
    file="$src/$rel"
    # dirname is '.' for a file at the top of the tree, which would record
    # "$dest/." alongside "$dest". Record only real subdirectories.
    sub="$(dirname "$rel")"
    if [ "$sub" = "." ]; then
      dir="$dest"
    else
      dir="$dest/$sub"
      mkdir -p "$dir"
      manifest_record "$dir"
    fi
    cp "$file" "$dest/$rel"
    manifest_record "$dest/$rel"
  done <<< "$( cd "$src" && find . -type f -print )"
}

copy_tree "$REPO_DIR/lib" "$LEARMUX_HOME/lib"
copy_tree "$REPO_DIR/challenges" "$LEARMUX_HOME/challenges"

# ── the seed, and the files beside it ───────────────────────────────────────
ensure_seed >/dev/null
manifest_record "$LEARMUX_SEED"
printf '%s\n' "$VERSION" > "$LEARMUX_VERSION_FILE"
manifest_record "$LEARMUX_VERSION_FILE"
: > "$LEARMUX_SOLVED"
manifest_record "$LEARMUX_SOLVED"

# ── the command ─────────────────────────────────────────────────────────────
# Only claim the directory if we created it. $PREFIX/bin already exists on a
# normal Termux install, and uninstall must never touch it.
if [ -d "$BIN_DIR" ]; then
  :
else
  mkdir -p "$BIN_DIR"
  manifest_record "$BIN_DIR"
fi
awk -v home="$LEARMUX_HOME" '
  /^LEARMUX_DEFAULT_HOME=/ { print "LEARMUX_DEFAULT_HOME=\"" home "\""; next }
  { print }
' "$REPO_DIR/bin/ctf" > "$BIN_DIR/ctf"
chmod 755 "$BIN_DIR/ctf"
manifest_record "$BIN_DIR/ctf"

# ── done ────────────────────────────────────────────────────────────────────
ok '  Installed.'
say ''
rule
printf '%s  Next%s\n' "$C_BOLD" "$C_RESET"
rule
say ''
if ! command -v ctf >/dev/null 2>&1; then
  warn "  $BIN_DIR is not on your PATH."
  dim  "  Add this to ~/.bashrc, then open a new session:"
  dim  "    export PATH=\"$BIN_DIR:\$PATH\""
  say ''
fi
say '    ctf list'
say '    ctf start 01'
say ''
dim "  Your seed is at $LEARMUX_SEED"
dim '  Every flag is derived from it, so your flags are unique to this device.'
say ''
