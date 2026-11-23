#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title   DND Status
# @raycast.mode    compact

# Optional parameters:
# @raycast.icon    🔔

# Documentation:
# @raycast.author  Albert Lee

osascript -e '
  tell application "System Events"
    tell application process "ControlCenter"
      set descs to {}
      repeat with mi in (every menu bar item of menu bar 1)
        try
          set end of descs to description of mi
        end try
      end repeat
      if descs contains "Focus" then
        return "DND: ON"
      else
        return "DND: OFF"
      end if
    end tell
  end tell'
