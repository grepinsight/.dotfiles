#!/bin/bash
# Cycle tab background color through Catppuccin Mocha palette + reset
# Usage: toggle-tab-color.sh [tab_index]
#   No args = current tab (uses KITTY_WINDOW_ID for background launches)
#   With arg = target specific tab (0-based)

colors=("#f38ba8" "#a6e3a1" "#f9e2af" "#89b4fa" "#cba6f7" "none")
fg=(    "#11111b" "#11111b" "#11111b" "#11111b" "#11111b" "none")
labels=("red" "green" "yellow" "blue" "mauve" "reset")

# Find the kitty socket
KITTY_SOCK=$(find "$TMPDIR" -maxdepth 1 -name 'kitty*' -type s 2>/dev/null | head -1)
if [ -z "$KITTY_SOCK" ] && [ -n "$KITTY_LISTEN_ON" ]; then
    KITTY_SOCK="${KITTY_LISTEN_ON#unix:}"
fi

TO_FLAG=""
if [ -n "$KITTY_SOCK" ]; then
    TO_FLAG="--to unix:$KITTY_SOCK"
fi

idx_file="/tmp/kitty-tab-color-idx"
idx=$(cat "$idx_file" 2>/dev/null || echo 0)

color="${colors[$idx]}"
fgcolor="${fg[$idx]}"
label="${labels[$idx]}"

# Build match flag: explicit tab index, or KITTY_WINDOW_ID, or omit (current)
if [ -n "$1" ]; then
    MATCH="-m index:$1"
elif [ -n "$KITTY_WINDOW_ID" ]; then
    MATCH="-m id:$KITTY_WINDOW_ID"
else
    MATCH=""
fi

kitty @ $TO_FLAG set-tab-color $MATCH \
    active_bg="$color" active_fg="$fgcolor" \
    inactive_bg="$color" inactive_fg="$fgcolor"

next=$(( (idx + 1) % ${#colors[@]} ))
echo "$next" > "$idx_file"

printf "Tab color: %s (%s)\n" "$label" "$color" >&2
