#!/usr/bin/env bash
# Solution for challenge 06. Never installed, never read by the CLI.
# shellcheck disable=SC2034

challenge_solution() {
  printf '%s\n' 'ls -l "$HOME"/backups'
  printf '%s\n' 'tar -tzf "$HOME"/backups/backup-*.tar.gz'
  printf '%s\n' 'tar -xzOf "$HOME"/backups/backup-*.tar.gz secret/flag.txt'
}
