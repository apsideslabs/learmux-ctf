#!/usr/bin/env bash
# The CHALLENGE_* values are read by the CLI through challenge_meta, so they
# look unused in this file. That is expected.
# shellcheck disable=SC2034
#
# Challenge 06 — Inside the archive.
#
# About looking into a compressed archive without unpacking it everywhere.

CHALLENGE_ID="06"
CHALLENGE_SLUG="inside-the-archive"
CHALLENGE_TITLE="Inside the archive"
CHALLENGE_CATEGORY="Archives"
CHALLENGE_DIFFICULTY="Medium"
CHALLENGE_POINTS=25
CHALLENGE_OBJECTIVE="Read a file out of a compressed backup without unpacking it."

challenge_briefing() {
  printf '%s\n' \
    "A backup was taken of a directory and stored as a single compressed file." \
    "It sits under a backups directory in your home." \
    "" \
    "You could unpack the whole thing, but that scatters files everywhere and" \
    "you only want one of them. The archiving tool can list what is inside" \
    "without extracting anything, and it can print a single member straight to" \
    "your terminal." \
    "" \
    "Two options do that. One lists, one writes to standard output, which is" \
    "the same thing as printing it."
}

challenge_hints() {
  cat <<'HINTS'
Ask the archive what it holds before you touch it. The tar option for
listing is -t, and for a gzipped archive you also need -z and -f.
---
Once you know the member's name, ask tar to write it to standard output
with -O, alongside -x for extract and -z for gzip.
HINTS
}

challenge_archive_file() {
  printf '%s\n' "$HOME/backups/backup-$(derived_name "$CHALLENGE_ID" archive 8).tar.gz"
}

challenge_build_dir() {
  printf '%s\n' "$HOME/.learmux-build-$(derived_name "$CHALLENGE_ID" build 8)"
}

challenge_files() {
  challenge_archive_file
  challenge_build_dir
  printf '%s\n' "$HOME/backups"
}

challenge_setup() {
  local build archive flag
  build="$(challenge_build_dir)"
  archive="$(challenge_archive_file)"
  flag="$(flag_for "$CHALLENGE_ID")"

  # the staging directory is removed again below, so a stale one from an
  # interrupted run cannot affect the result
  rm -rf "$build"
  mkdir -p "$build/secret" "$(dirname "$archive")"

  {
    printf '%s\n' "device backup"
    printf '%s\n' "taken by the nightly job"
    printf '%s\n' "flag: $flag"
  } > "$build/secret/flag.txt"

  printf '%s\n' "nothing to see in here" > "$build/secret/readme.txt"

  tar -czf "$archive" -C "$build" secret
  rm -rf "$build"
  chmod 644 "$archive"
}
