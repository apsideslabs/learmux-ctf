#!/usr/bin/env bash
# The CHALLENGE_* values are read by the CLI through challenge_meta, so they
# look unused in this file. That is expected.
# shellcheck disable=SC2034
#
# Challenge 02 — Owner only.
#
# About permission bits, and about reading a long listing.

CHALLENGE_ID="02"
CHALLENGE_SLUG="owner-only"
CHALLENGE_TITLE="Owner only"
CHALLENGE_CATEGORY="Permissions"
CHALLENGE_DIFFICULTY="Easy"
CHALLENGE_POINTS=15
CHALLENGE_OBJECTIVE="Read the file that only your account is allowed to open."

challenge_briefing() {
  printf '%s\n' \
    "Every file carries a permission string, and a long listing prints it in" \
    "the first column. Nine characters, in three groups of three:" \
    "" \
    "    rwx   rwx   rwx" \
    "    you   group other" \
    "" \
    "A dash means that permission is not granted. So -rw-r--r-- is readable by" \
    "everyone, and -rw------- is readable by you alone." \
    "" \
    "Three files were written into your home directory. One of them is yours" \
    "alone. Find it and read it."
}

challenge_hints() {
  cat <<'HINTS'
A long listing shows the permissions for every file at once. That is the
long flag with a lower case L, not a one.
---
Look for the file whose group and other permissions are all dashes. The
name of that file starts with the word private.
HINTS
}

challenge_key_file() {
  printf '%s\n' "$HOME/private-$(derived_name "$CHALLENGE_ID" key 8).key"
}

challenge_notes_file() {
  printf '%s\n' "$HOME/notes.txt"
}

challenge_report_file() {
  printf '%s\n' "$HOME/report.txt"
}

challenge_files() {
  challenge_key_file
  challenge_notes_file
  challenge_report_file
}

challenge_setup() {
  local key notes report flag
  key="$(challenge_key_file)"
  notes="$(challenge_notes_file)"
  report="$(challenge_report_file)"
  flag="$(flag_for "$CHALLENGE_ID")"

  {
    printf '%s\n' "# device signing key"
    printf '%s\n' "# readable by this account only"
    printf '%s\n' "flag: $flag"
  } > "$key"
  chmod 600 "$key"

  printf '%s\n' "Shopping list." "Coffee." "Rice." > "$notes"
  chmod 644 "$notes"

  printf '%s\n' "Quarterly report." "Nothing unusual to report." > "$report"
  chmod 644 "$report"
}
