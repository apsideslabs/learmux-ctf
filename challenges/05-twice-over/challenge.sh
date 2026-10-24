#!/usr/bin/env bash
# The CHALLENGE_* values are read by the CLI through challenge_meta, so they
# look unused in this file. That is expected.
# shellcheck disable=SC2034
#
# Challenge 05 — Twice over.
#
# Two encoding layers, neither of which is encryption.

CHALLENGE_ID="05"
CHALLENGE_SLUG="twice-over"
CHALLENGE_TITLE="Twice over"
CHALLENGE_CATEGORY="Encoding"
CHALLENGE_DIFFICULTY="Hard"
CHALLENGE_POINTS=30
CHALLENGE_OBJECTIVE="Undo two layers of encoding to get the flag back."

challenge_briefing() {
  printf '%s\n' \
    "Encoding is not encryption. Encryption needs a key, and without the key" \
    "there is nothing to do. Encoding is just a different way of writing the" \
    "same thing, and anyone who knows the scheme can reverse it." \
    "" \
    "Two schemes were used here, one after the other." \
    "" \
    "The first turns three bytes into four printable characters, so that" \
    "binary data can travel through systems that only carry text. You can spot" \
    "it by the alphabet it uses: capitals, lower case, digits, and often one or" \
    "two equals signs at the end as padding." \
    "" \
    "The second is older and simpler. It shifts every letter thirteen places" \
    "along the alphabet, wrapping around at the end. Because there are" \
    "twenty-six letters, running it again undoes it." \
    "" \
    "Undo them in the reverse order to the one they were applied in."
}

challenge_hints() {
  cat <<'HINTS'
The payload is the last line of the file, and it is the first scheme.
The tool that decodes it is the same one that encoded it, with -d.
---
After decoding you will have readable text with the letters shifted.
Shift them back with tr, mapping the upper and lower case alphabets onto
themselves rotated by thirteen. The rotation is its own inverse, so the
same command both applies and removes it.
HINTS
}

challenge_payload_file() {
  printf '%s\n' "$HOME/notes/payload.txt"
}

challenge_files() {
  challenge_payload_file
  printf '%s\n' "$HOME/notes"
}

challenge_setup() {
  local f flag shifted
  f="$(challenge_payload_file)"
  flag="$(flag_for "$CHALLENGE_ID")"
  mkdir -p "$(dirname "$f")"

  # rot13 first, then base64, so the solver undoes base64 then rot13
  shifted="$(printf '%s' "$flag" | tr 'A-Za-z' 'N-ZA-Mn-za-m')"

  {
    printf '%s\n' "# payload for the staging build"
    printf '%s\n' "# encoded twice, do not edit by hand"
    printf '%s\n' "$shifted" | base64
  } > "$f"

  chmod 644 "$f"
}
