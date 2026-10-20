#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Agent Fleet
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 🛰️

# Documentation:
# @raycast.description Every agent session grouped by state, with its jump target.
# @raycast.author grepinsight

set -euo pipefail

FLEET="$HOME/.hammerspoon/claude-fleet"
[ -x "$FLEET" ] || { echo "claude-fleet not installed at $FLEET"; exit 1; }

/usr/bin/python3 "$FLEET" list --no-color
