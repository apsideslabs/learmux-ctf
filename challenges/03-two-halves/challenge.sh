#!/usr/bin/env bash
# The CHALLENGE_* values are read by the CLI through challenge_meta, so they
# look unused in this file. That is expected.
# shellcheck disable=SC2034
#
# Challenge 03 — Two halves.
#
# About walking a directory tree, and joining two pieces of text.

CHALLENGE_ID="03"
CHALLENGE_SLUG="two-halves"
CHALLENGE_TITLE="Two halves"
CHALLENGE_CATEGORY="Filesystem"
CHALLENGE_DIFFICULTY="Medium"
CHALLENGE_POINTS=20
CHALLENGE_OBJECTIVE="Join the two halves of the flag, which sit in different directories."

challenge_briefing() {
  printf '%s\n' \
    "A flag was split down the middle. The first half is in one file, the" \
    "second half is in another, and they are not in the same directory." \
    "" \
    "The awkward part is that each half is on its own line. Put them together" \
    "and you get a line break in the middle of the flag, which is not what you" \
    "want." \
    "" \
    "Two commands are worth knowing here. Listing a tree shows you what is" \
    "under a directory without walking into each one by hand. And tr can" \
    "delete characters, including the newline character, if you name it." \
    "" \
    "Everything is under your home directory. Start there."
}

challenge_hints() {
  cat <<'HINTS'
There is a command whose whole job is showing you a directory tree.
Once you have it, you can see both halves at once.
---
Concatenate the two files with cat, then remove the line break with tr.
The name for a newline inside quotes is a backslash followed by a lower
case n.
HINTS
}

challenge_part_a() {
  printf '%s\n' "$HOME/work/part-a.txt"
}

challenge_part_b() {
  printf '%s\n' "$HOME/work/archive/part-b.txt"
}

challenge_files() {
  challenge_part_a
  challenge_part_b
  printf '%s\n' "$HOME/work/archive"
  printf '%s\n' "$HOME/work"
}

challenge_setup() {
  local a b flag first second
  a="$(challenge_part_a)"
  b="$(challenge_part_b)"
  flag="$(flag_for "$CHALLENGE_ID")"

  # split the inner sixteen characters down the middle
  first="$(printf '%s' "$flag" | cut -c1-16)"
  second="$(printf '%s' "$flag" | cut -c17-)"

  mkdir -p "$(dirname "$b")"
  printf '%s\n' "$first" > "$a"
  printf '%s\n' "$second" > "$b"

  chmod 644 "$a"
  chmod 644 "$b"
}
