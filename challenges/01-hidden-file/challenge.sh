#!/usr/bin/env bash
# The CHALLENGE_* values are read by the CLI through challenge_meta, so they
# look unused in this file. That is expected.
# shellcheck disable=SC2034
# Challenge 01 — Hidden in plain sight.
#
# Sourced by the ctf CLI. The CLI reads the CHALLENGE_* variables, then calls
# challenge_briefing, challenge_files and challenge_setup.
#
# The names of the files below are derived from this device's seed, so they are
# different on every machine, and the flag inside is derived the same way.

CHALLENGE_ID="01"
CHALLENGE_SLUG="hidden-file"
CHALLENGE_TITLE="Hidden in plain sight"
CHALLENGE_CATEGORY="Filesystem"
CHALLENGE_DIFFICULTY="Easy"
CHALLENGE_POINTS=10
CHALLENGE_OBJECTIVE="Find the file in your home directory that holds the flag, and read it."

challenge_briefing() {
  printf '%s\n' \
    "Two files were written into your home directory before you started." \
    "" \
    "Both have names that begin with a dot. A plain listing leaves those out," \
    "which is why a directory can look emptier than it is." \
    "" \
    "One of the two holds your flag. The other is noise." \
    "" \
    "Your home directory is $HOME."
}

# The two files this challenge writes. Kept in one place so the CLI, the
# manifest and the reset path all agree.
challenge_flag_file() {
  printf '%s\n' "$HOME/.backup-$(derived_name "$CHALLENGE_ID" manifest 8)"
}

challenge_decoy_file() {
  printf '%s\n' "$HOME/.cache-$(derived_name "$CHALLENGE_ID" cache 8)"
}

# Every path this challenge creates. The CLI records these in the manifest, so
# uninstall can remove them exactly.
challenge_files() {
  challenge_flag_file
  challenge_decoy_file
}

challenge_setup() {
  local flag_file decoy_file flag
  flag_file="$(challenge_flag_file)"
  decoy_file="$(challenge_decoy_file)"
  flag="$(flag_for "$CHALLENGE_ID")"

  {
    printf '%s\n' "# learmux device manifest"
    printf '%s\n' "# written at install time, do not edit"
    printf '%s\n' "host: $(hostname 2>/dev/null || printf 'termux')"
    printf '%s\n' "flag: $flag"
  } > "$flag_file"
  chmod 600 "$flag_file"

  {
    printf '%s\n' "# cache index"
    printf '%s\n' "entries: 3"
    printf '%s\n' "note: nothing to see here"
  } > "$decoy_file"
  chmod 600 "$decoy_file"
}
