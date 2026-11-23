#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Agents Waiting
# @raycast.mode inline
# @raycast.refreshTime 30s

# Optional parameters:
# @raycast.icon 🛰️

# Documentation:
# @raycast.description Count of agent sessions blocked on a human, shown in the Raycast root.
# @raycast.author grepinsight

set -euo pipefail

FLEET="$HOME/.hammerspoon/claude-fleet"
[ -x "$FLEET" ] || { echo "claude-fleet not installed"; exit 0; }

# Inline mode renders one line in the root search, so this stays a count and
# never the whole list.
/usr/bin/python3 "$FLEET" list --needs-input --json 2>/dev/null | /usr/bin/python3 -c '
import json, sys
try:
    rows = json.load(sys.stdin)
except Exception:
    print("agents: unavailable")
    raise SystemExit
if not rows:
    print("agents: all clear")
else:
    first = rows[0]
    mins = first["minutes"]
    name = first["name"][:34]
    age = "%dm" % mins if mins < 60 else "%dh%02dm" % (mins // 60, mins % 60)
    print("%d waiting - oldest: %s (%s)" % (len(rows), name, age))
'
