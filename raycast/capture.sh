#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Capture
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🧠
# @raycast.argument1 { "type": "text", "placeholder": "a thought" }

# Documentation:
# @raycast.description Save a thought to the vault's 00-Capture folder. No model, no network.
# @raycast.author grepinsight

# Raycast runs script commands with a minimal environment, so $OBSIDIAN_VAULT is
# not set here -- the older scripts in this directory work around the same gap
# by hardcoding an absolute vault path, which puts a second definition of the
# vault path in the repo. Borrow the login shell's environment instead.
#
# A plain `zsh -c` suffices, but only since the vault exports moved to
# bash/local/bash_vault_env, which ~/.zshenv sources. Before that they lived in
# bash_settings_local, which only an INTERACTIVE zsh reads, so this script's
# original `zsh -lc` had no vault at all and would have failed under Raycast
# with "nowhere safe to write". It looked correct only because it was tested
# from a shell that already had the variable exported. The interactive
# workaround cost ~990ms and 13 lines of startup chatter; `zsh -c` is ~27ms and
# silent. The path is still selected out of the output rather than taken whole,
# which costs nothing and would survive that regressing.
#
# The thought is passed as a positional argument to zsh ($1 inside the quoted
# script), never interpolated into the command string, so quotes, $, backticks
# and CJK in the text are all inert.
set -uo pipefail

out=$(zsh -c 'exec "$HOME/bin/capture" --source raycast -- "$1"' capture "$1" 2>&1) || {
  printf 'Capture failed:\n%s\n' "$(printf '%s\n' "$out" | tail -n 3)"
  exit 1
}

# capture prints one absolute path; the shell's chatter never starts with `/`.
path=$(printf '%s\n' "$out" | grep '^/' | tail -n 1)

if [ -z "$path" ]; then
  printf 'Captured, but could not read the path:\n%s\n' "$(printf '%s\n' "$out" | tail -n 3)"
  exit 1
fi

printf 'Captured → %s\n' "${path##*/}"
