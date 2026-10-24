#!/usr/bin/env bash
# Solution for challenge 03. Never installed, never read by the CLI.
# shellcheck disable=SC2034

challenge_solution() {
  printf '%s\n' 'tree "$HOME"'
  printf '%s\n' 'cat "$HOME"/work/part-a.txt "$HOME"/work/archive/part-b.txt | tr -d "\n"'
}
