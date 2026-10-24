#!/usr/bin/env bash
# Solution for challenge 04. Never installed, never read by the CLI.
# shellcheck disable=SC2034

challenge_solution() {
  printf '%s\n' 'grep -oE "LEARMUX[{][0-9a-f]{16}[}]" access.log'
}
