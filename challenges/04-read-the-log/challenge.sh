#!/usr/bin/env bash
# The CHALLENGE_* values are read by the CLI through challenge_meta, so they
# look unused in this file. That is expected.
# shellcheck disable=SC2034
#
# Challenge 04 — Read the log.
#
# About searching a file instead of reading it.

CHALLENGE_ID="04"
CHALLENGE_SLUG="read-the-log"
CHALLENGE_TITLE="Read the log"
CHALLENGE_CATEGORY="Text"
CHALLENGE_DIFFICULTY="Medium"
CHALLENGE_POINTS=20
CHALLENGE_OBJECTIVE="Find the flag in a web server log, without reading every line."

challenge_briefing() {
  printf '%s\n' \
    "A web server log holds one line per request. Four fields, in order: the" \
    "address that asked, the time, the request itself, and the status code." \
    "" \
    "    address - - [time] \"GET /path HTTP/1.1\" status size" \
    "" \
    "There are dozens of lines, and reading them by hand is a waste of your" \
    "time. A search tool will find a pattern in a file and show you only the" \
    "lines that match." \
    "" \
    "One warning. More than one line contains something that looks like a" \
    "flag. Only one of them is real, and you can tell them apart by shape:" \
    "your flag holds exactly sixteen characters, and every one of them is a" \
    "digit or a letter from a to f."
}

challenge_hints() {
  cat <<'HINTS'
Search the file rather than opening it. The tool you want is grep, and
the option that prints only the matching part of a line is -o.
---
Use a pattern rather than a plain word, so the decoy cannot match. A
character class of the sixteen hex digits, repeated sixteen times, is
enough to describe the real flag and nothing else.
HINTS
}

challenge_log_file() {
  printf '%s\n' "$HOME/logs/requests.log"
}

challenge_files() {
  challenge_log_file
  printf '%s\n' "$HOME/logs"
}

# One log line, built from parts so the shape is visible.
log_line() { # <ip> <clock> <request> <status> <size>
  printf '%s - - [10/Oct/2026:%s +0000] "%s" %s %s\n' "$1" "$2" "$3" "$4" "$5"
}

challenge_setup() {
  local log flag i
  log="$(challenge_log_file)"
  flag="$(flag_for "$CHALLENGE_ID")"
  mkdir -p "$(dirname "$log")"

  {
    for i in 11 12 13 14 15 16; do
      log_line "198.51.100.$i" "09:0$i:0$i" 'GET /assets/app.js HTTP/1.1' 200 5120
    done

    # a decoy that looks like a flag but is not the right shape
    log_line '203.0.113.7' '10:14:03' \
      'GET /admin?debug=LEARMUX{decoy_do_not_use_this} HTTP/1.1' 200 812

    for i in 21 22 23 24; do
      log_line "192.0.2.$i" "10:0$i:0$i" 'POST /login HTTP/1.1' 302 0
    done

    # the real one
    log_line '192.0.2.55' '11:03:22' "GET /admin?debug=$flag HTTP/1.1" 200 1043

    for i in 31 32 33 34 35; do
      log_line "198.51.100.$i" "11:0$i:0$i" 'GET /style.css HTTP/1.1' 200 512
    done

    log_line '203.0.113.9' '12:01:00' 'GET /missing.html HTTP/1.1' 404 153

    for i in 41 42 43; do
      log_line "192.0.2.$i" "12:0$i:0$i" 'GET /index.html HTTP/1.1' 200 1043
    done
  } > "$log"

  chmod 644 "$log"
}
