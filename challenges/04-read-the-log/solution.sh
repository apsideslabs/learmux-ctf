#!/usr/bin/env bash
# Solution for challenge 04. Never installed, never read by the CLI.
# shellcheck disable=SC2034

challenge_solution() {
  # how many lines are there, before you go reading them
  printf '%s\n' 'wc -l "$HOME"/logs/requests.log'
  # a plain search shows both candidates
  printf '%s\n' 'grep LEARMUX "$HOME"/logs/requests.log'
  # a pattern describing the real shape picks out one
  printf '%s\n' 'grep -oE "LEARMUX[{][0-9a-f]{16}[}]" "$HOME"/logs/requests.log'
}
