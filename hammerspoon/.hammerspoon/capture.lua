-- Quick capture, the Hammerspoon doors.
--
--   cmd+shift+alt+N   capture a thought, stay where you are
--   cmd+ctrl+alt+N    capture a thought and jump to it in Obsidian
--   cmd+alt+N         open the Captures base (all unfiled captures, newest first)
--
-- The writer is ~/bin/capture (see ~/.dotfiles/capture); nothing here knows the
-- file format or builds the Obsidian URI. The URI comes back from
-- `capture --json`, so there is exactly one definition of it and it is
-- unit-tested rather than assembled by string concatenation in three places.
--
-- Capture shells out through `/bin/zsh -c`, not through hs.execute's
-- with_user_env option, and that difference is the whole history of this file.
--
-- Hammerspoon is started by launchd and never sources the dotfiles, so
-- $OBSIDIAN_VAULT is not in this process's environment. hs.execute(cmd, true)
-- solves that by running an INTERACTIVE login shell -- which worked, and cost
-- ~990ms per capture while printing 13 lines of startup chatter (`zle`
-- warnings, `... loaded` notices) ahead of the output. That chatter broke the
-- JSON parse, so the deeplink silently went missing and the toast said only
-- "Captured".
--
-- Fixed at the source instead: the vault exports moved to
-- bash/local/bash_vault_env, which ~/.zshenv sources, so every zsh has them.
-- `/bin/zsh -c` now measures ~27ms with zero extra output. lastJSONLine below
-- is kept regardless -- it costs nothing, and it is what made that failure
-- legible in the first place.

local CAPTURE = os.getenv("HOME") .. "/bin/capture"

-- Flip to true to make the plain capture hotkey jump to Obsidian as well.
--
-- Left false deliberately. The hotkey exists so a thought can be saved without
-- leaving what you are doing, and switching apps on every capture is precisely
-- the interruption it was built to avoid: you would be pulled out of the
-- browser or the meeting you were in when the thought arrived. cmd+ctrl+alt+N
-- asks for the jump explicitly, on the occasions you want it.
local OPEN_AFTER_CAPTURE = false

-- The read-side view. A base file rather than a deeplink to the folder, because
-- obsidian:// can open a *file* but has no "show me this folder, sorted newest
-- first" verb, and a .base file is a file. Fallback if a future Obsidian stops
-- opening .base by URI:  obsidian://search?vault=Thoughts&query=path:00-Capture
local CAPTURES_URI = "obsidian://open?vault=Thoughts&file=00-Capture%2FCaptures.base"

---Single-quote a string so the shell treats it as one literal argument.
---Needed for the URIs too: they carry `&`, which the shell would otherwise read
---as "run this in the background".
local function shquote(text)
  return "'" .. text:gsub("'", "'\\''") .. "'"
end

---Last line of `text` that looks like a JSON object.
---
---The writer prints exactly one line of JSON, last. Everything before it is the
---interactive shell's startup chatter (see the header note), so parsing the
---whole output fails -- which is how this silently degraded the first time: the
---decode failed, the link went nil, and the alert quietly lost its suffix.
local function lastJSONLine(text)
  local found = nil
  for line in text:gmatch("[^\r\n]+") do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed:sub(1, 1) == "{" and trimmed:sub(-1) == "}" then
      found = trimmed
    end
  end
  return found
end

---Last `count` lines of `text`, so an error alert shows the message and not
---thirteen lines of shell chatter above it.
local function tailLines(text, count)
  local lines = {}
  for line in text:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  local start = math.max(1, #lines - count + 1)
  return table.concat(lines, "\n", start, #lines)
end

---`open` rather than hs.urlevent.openURL: boring, and certain with a custom scheme.
local function openURI(uri)
  local output, ok = hs.execute("/usr/bin/open " .. shquote(uri))
  if not ok then
    hs.alert.show("Could not open Obsidian:\n" .. ((output or ""):gsub("%s+$", "")), 4)
  end
end

---@param opts table|nil { open = boolean } jump to the note after writing it
local function captureThought(opts)
  opts = opts or {}

  local button, text = hs.dialog.textPrompt("Capture a thought", "", "", "Save", "Cancel")
  if button ~= "Save" then
    return
  end

  if text == nil or text:match("^%s*$") then
    hs.alert.show("Nothing captured")
    return
  end

  -- `--` so a thought that happens to start with a hyphen is text, not a flag.
  -- `2>&1` inside the inner command so the writer's own error text reaches us.
  local inner = shquote(CAPTURE) .. " --json --source hammerspoon -- " .. shquote(text) .. " 2>&1"
  local output, ok = hs.execute("/bin/zsh -c " .. shquote(inner))
  output = (output or ""):gsub("%s+$", "")

  if not ok then
    -- Tail only: the real message is last, under the shell chatter. The two
    -- likely causes (vault unset, ~/bin/capture not linked) are both named in it.
    hs.alert.show("Capture failed:\n" .. (output ~= "" and tailLines(output, 3) or "unknown error"), 5)
    return
  end

  local payload = lastJSONLine(output)
  local decoded = nil
  if payload then
    local parsed, result = pcall(hs.json.decode, payload)
    if parsed and type(result) == "table" then
      decoded = result
    end
  end

  -- The thought is already on disk by now, so this is not a failure -- but it is
  -- not a success either, and it must say so. Staying quiet here is exactly the
  -- bug that shipped: the alert said "Captured" and nothing revealed that the
  -- clipboard and the notification had both been skipped.
  if not decoded or not decoded.deeplink then
    hs.alert.show("Captured, but could not read the link:\n" .. tailLines(output, 2), 5)
    return
  end

  local link = decoded.deeplink
  local filename = (decoded.path or ""):match("([^/]+)$") or "(unknown)"

  hs.pasteboard.setContents(link)

  -- The alert is the guaranteed feedback: Hammerspoon draws it itself, so it
  -- appears even when notifications are muted or were never granted. It cannot
  -- be clicked, which is why the link goes to the clipboard and to a
  -- notification rather than into this string.
  hs.alert.show("Captured  →  link copied", 1.2)

  hs.notify
    .new(function()
      openURI(link)
    end, {
      title = "Captured",
      subTitle = filename,
      informativeText = text,
      hasActionButton = true,
      actionButtonTitle = "Open",
      withdrawAfter = 20,
    })
    :send()

  if opts.open then
    openURI(link)
  end
end

hs.hotkey.bind({ "cmd", "shift", "alt" }, "N", function()
  captureThought({ open = OPEN_AFTER_CAPTURE })
end)

hs.hotkey.bind({ "cmd", "ctrl", "alt" }, "N", function()
  captureThought({ open = true })
end)

hs.hotkey.bind({ "cmd", "alt" }, "N", function()
  openURI(CAPTURES_URI)
end)
