#!/usr/bin/env bash
# Solution for challenge 01. The installer does NOT copy this file, and the CLI
# never reads it. It exists so the test suite can prove the challenge is
# solvable without shipping the answer to the player.
#
# Prints one command per line. The test runs them and looks for the flag.

challenge_solution() {
  printf '%s\n' 'ls -a "$HOME"'
  printf '%s\n' 'cat "$HOME"/.backup-*'
}
