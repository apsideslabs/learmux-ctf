#!/usr/bin/env bash
# Solution for challenge 02. Never installed, never read by the CLI.
# shellcheck disable=SC2034

challenge_solution() {
  printf '%s\n' 'ls -l "$HOME"'
  printf '%s\n' 'cat "$HOME"/private-*.key'
}
