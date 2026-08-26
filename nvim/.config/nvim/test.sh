#!/usr/bin/env bash
#
# Run the Lua test suite with plenary.busted.
#
# plenary.nvim is already installed as a telescope.nvim dependency, so this needs no
# extra plugin. Uses --clean so the real config (and anything in it that spawns external
# processes) stays out of the test run; see lua/util/headless.lua.
#
# Usage:
#   ./test.sh                 # everything under tests/
#   ./test.sh tests/annotate  # one directory
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PLENARY_DIR="${PLENARY_DIR:-$HOME/.local/share/nvim/lazy/plenary.nvim}"
export PLENARY_DIR

if [ ! -d "$PLENARY_DIR" ]; then
  echo "plenary.nvim not found at $PLENARY_DIR" >&2
  echo "install it, or set PLENARY_DIR to its location" >&2
  exit 1
fi

TARGET="${1:-tests}"

exec nvim --clean --headless \
  --cmd "set runtimepath+=$PLENARY_DIR" \
  --cmd "set runtimepath+=$PWD" \
  -c "runtime plugin/plenary.vim" \
  -c "PlenaryBustedDirectory $TARGET { minimal_init = 'tests/minimal_init.lua' }"
