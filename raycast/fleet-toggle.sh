#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Fleet Toggle
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🛰️

# Documentation:
# @raycast.description Turn the agent panel on or off. Off also stops its polling.
# @raycast.author grepinsight

set -euo pipefail
open -g "hammerspoon://fleet?action=toggle"
