#!/usr/bin/env bash
# Solution for challenge 05. Never installed, never read by the CLI.
# shellcheck disable=SC2034

challenge_solution() {
  printf '%s\n' 'tail -n 1 "$HOME"/notes/payload.txt'
  printf '%s\n' 'tail -n 1 "$HOME"/notes/payload.txt | base64 -d'
  printf '%s\n' 'tail -n 1 "$HOME"/notes/payload.txt | base64 -d | tr "A-Za-z" "N-ZA-Mn-za-m"'
}
