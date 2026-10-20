-- fleet.lua -- an always-on-top panel listing Claude Code sessions, grouped by state.
--
-- The built-in agent view renders background agents only, so an interactive
-- terminal session that is blocked on a question never appears in it. This polls
-- the JSON feed instead, groups sessions under section headings, and focuses
-- that session's terminal window when you click its row.
--
-- Mouse:    drag the header      move the panel
--           click a section      fold or unfold that group
--           click `o`            cycle opacity: full, faded, ghost
--           click `_`            minimize to a pill
--           click `x`            hide until the hotkey brings it back
--           click a row          focus that session's terminal window
--           click a row's `x`    arm it, click again to confirm. A live session
--                                stops; one that already finished is DELETED.
--
-- Hotkeys:  cmd+shift+alt+F      turn fleet on or off (stops polling when off)
--           cmd+shift+alt+G      refresh now
--           cmd+shift+alt+D      cycle opacity
--           cmd+shift+alt+=      bigger font
--           cmd+shift+alt+-      smaller font
--           cmd+shift+alt+H      reset position, opacity, and size
--
-- URLs:     hammerspoon://fleet?action=toggle   also: on, off, refresh,
--           dim, minimize, bigger, smaller, reset, and
--           font&size=16&name=Menlo. Lets Raycast, a Stream Deck, or any
--           `open -g` caller drive the panel without a CLI.
--
-- Stopping is reversible: a background agent goes through `claude stop` and
-- reopens with `claude attach`, an interactive session gets SIGTERM and reopens
-- with `claude --resume`. A row that has already finished has nothing to stop,
-- so its `x` runs `claude rm` instead, which deletes the session and its
-- worktree and is NOT reversible. The armed label says which one you are about
-- to get, and `claude-fleet` decides the verb per row so the two cannot drift.
--
-- Position, fold state, minimized state, and on/off persist across reloads in
-- ~/.cache/claude-fleet/ui.json. Dragging needs Hammerspoon to hold
-- Accessibility permission, the same permission the hotkeys above need.

local M = {}

local PYTHON = "/usr/bin/python3"
local SCRIPT = hs.configdir .. "/claude-fleet"
local CACHE_DIR = (os.getenv("HOME") or "") .. "/.cache/claude-fleet"
local UI_STATE = CACHE_DIR .. "/ui.json"
local HEARTBEAT = CACHE_DIR .. "/heartbeat.json"

local POLL_SECONDS = 3
-- Font size drives every dimension. Hardcoding both a size and a row height is
-- how text ends up clipped the first time the size changes, so heights, widths
-- and column positions are all computed from FONT below.
local DEFAULT_FONT_SIZE = 15
local DEFAULT_FONT_NAME = "Menlo"
local MIN_FONT_SIZE, MAX_FONT_SIZE = 9, 28

local WIDTH, PILL_WIDTH, ROW_HEIGHT, SECTION_HEIGHT, HEADER_HEIGHT
local FONT, FONT_BOLD, FONT_SIZE, SMALL_SIZE, TEXT_H
local GUTTER = 12
local MARGIN = 12
local PAD = 6
local ROWS_PER_GROUP = 5
local CLEAR_LINGER_SECONDS = 4
local DRAG_SLOP = 2 -- pixels of movement before a click counts as a drag
local ARM_SECONDS = 4 -- how long a kill stays armed before it disarms itself

-- Opacity steps the `o` button cycles through. Never reaches 0: an invisible
-- panel that still swallows clicks is worse than a visible one.
local ALPHA_STEPS = { 1.0, 0.65, 0.35 }

-- Render order, and the groups that keep the panel on screen. `Idle` is
-- deliberately absent: a session doing nothing is not news.
local GROUP_ORDER = { "Needs input", "Working", "Completed", "Stopped" }
local KEEPS_PANEL_OPEN = { ["Needs input"] = true, ["Working"] = true }

local COLORS = {
  panel = { red = 0.07, green = 0.08, blue = 0.11, alpha = 0.94 },
  header = { red = 0.11, green = 0.12, blue = 0.16, alpha = 0.97 },
  hover = { red = 0.18, green = 0.20, blue = 0.26, alpha = 1.0 },
  section = { white = 0.62, alpha = 1.0 },
  text = { white = 0.93, alpha = 1.0 },
  dim = { white = 0.48, alpha = 1.0 },
  clear = { red = 0.42, green = 0.82, blue = 0.51, alpha = 1.0 },
  armed = { red = 0.34, green = 0.10, blue = 0.12, alpha = 1.0 },
  danger = { red = 0.96, green = 0.42, blue = 0.42, alpha = 1.0 },
}

local GLYPH_COLORS = {
  ["!"] = { red = 0.93, green = 0.33, blue = 0.33, alpha = 1.0 },
  ["?"] = { red = 0.96, green = 0.75, blue = 0.31, alpha = 1.0 },
  [">"] = { red = 0.40, green = 0.78, blue = 0.90, alpha = 1.0 },
  ["v"] = { red = 0.42, green = 0.82, blue = 0.51, alpha = 1.0 },
  ["-"] = { white = 0.45, alpha = 1.0 },
}

local canvas = nil
local timer = nil
local clearTimer = nil
local grouped = {}
local counts = {}
local clickables = {} -- canvas element id -> { action = ..., ... }
local hidden = false
local lastError = nil
-- Armed kills are keyed by their kill target, never by the canvas element id.
-- A poll every three seconds can reorder rows between the arming click and the
-- confirming one, and `row3` would then point at a different session.
local armed = nil
local armTimer = nil

local ui = {
  x = nil,
  y = nil,
  minimized = false,
  collapsed = {},
  alpha = 1.0,
  enabled = true,
  fontSize = DEFAULT_FONT_SIZE,
  fontName = DEFAULT_FONT_NAME,
}

local function percentDecode(text)
  if type(text) ~= "string" then
    return text
  end
  return (text:gsub("+", " "):gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

local fontLookup = nil
local function fontExists(name)
  if not name or name == "" then
    return false
  end
  if not fontLookup then
    fontLookup = {}
    for _, list in ipairs({ hs.styledtext.fontNames() or {}, hs.styledtext.fontFamilies() or {} }) do
      for _, found in ipairs(list) do
        fontLookup[found] = true
      end
    end
  end
  return fontLookup[name] == true
end

-- Recomputed whenever the font changes. Every frame in the renderers reads
-- these, so there is exactly one place that decides how big anything is.
local function applyMetrics()
  FONT_SIZE = math.max(MIN_FONT_SIZE, math.min(ui.fontSize or DEFAULT_FONT_SIZE, MAX_FONT_SIZE))
  ui.fontSize = FONT_SIZE
  FONT = ui.fontName or DEFAULT_FONT_NAME
  local bold = FONT .. "-Bold"
  FONT_BOLD = fontExists(bold) and bold or FONT
  SMALL_SIZE = math.max(MIN_FONT_SIZE - 1, FONT_SIZE - 1)
  TEXT_H = FONT_SIZE + 6
  ROW_HEIGHT = FONT_SIZE + 12
  SECTION_HEIGHT = FONT_SIZE + 10
  HEADER_HEIGHT = FONT_SIZE + 14
  WIDTH = math.max(360, math.floor(FONT_SIZE * 30))
  PILL_WIDTH = math.max(120, math.floor(FONT_SIZE * 11))
end

applyMetrics()

local dragState = nil
local dragTap = nil
local suppressClickUntil = 0

-- ---------------------------------------------------------------- persistence

local function ensureCacheDir()
  hs.fs.mkdir((os.getenv("HOME") or "") .. "/.cache")
  hs.fs.mkdir(CACHE_DIR)
end

local function loadUI()
  local file = io.open(UI_STATE, "r")
  if not file then
    return
  end
  local body = file:read("*a")
  file:close()
  local ok, saved = pcall(hs.json.decode, body)
  if ok and type(saved) == "table" then
    ui.x = tonumber(saved.x)
    ui.y = tonumber(saved.y)
    ui.minimized = saved.minimized == true
    ui.collapsed = type(saved.collapsed) == "table" and saved.collapsed or {}
    ui.alpha = tonumber(saved.alpha) or 1.0
    ui.enabled = saved.enabled ~= false
    ui.fontSize = tonumber(saved.fontSize) or DEFAULT_FONT_SIZE
    ui.fontName = type(saved.fontName) == "string" and saved.fontName or DEFAULT_FONT_NAME
  end
  applyMetrics()
end

local function saveUI()
  ensureCacheDir()
  local file = io.open(UI_STATE, "w")
  if not file then
    return
  end
  file:write(hs.json.encode(ui))
  file:close()
end

-- ---------------------------------------------------------------- formatting

-- "4h20m" reads faster than "260 minutes" when the number is the whole point.
local function duration(minutes)
  if minutes < 60 then
    return string.format("%dm", minutes)
  elseif minutes < 1440 then
    return string.format("%dh%02dm", minutes // 60, minutes % 60)
  end
  return string.format("%dd%dh", minutes // 1440, (minutes % 1440) // 60)
end

local function visibleGroups()
  local out = {}
  for _, name in ipairs(GROUP_ORDER) do
    local rows = grouped[name]
    if rows and #rows > 0 then
      out[#out + 1] = { name = name, rows = rows, collapsed = ui.collapsed[name] == true }
    end
  end
  return out
end

local function shouldShow()
  for name in pairs(KEEPS_PANEL_OPEN) do
    if grouped[name] and #grouped[name] > 0 then
      return true
    end
  end
  return false
end

local function summaryLine()
  local parts = {}
  for _, name in ipairs(GROUP_ORDER) do
    if counts[name] and counts[name] > 0 then
      parts[#parts + 1] = string.format("%d %s", counts[name], name:lower())
    end
  end
  return table.concat(parts, "  ·  ")
end

local function pillLine()
  local needs = counts["Needs input"] or 0
  local working = counts["Working"] or 0
  return string.format("! %d   > %d", needs, working)
end

-- ---------------------------------------------------------------- geometry

local function contentHeight(groups)
  local height = HEADER_HEIGHT + PAD
  for _, group in ipairs(groups) do
    height = height + SECTION_HEIGHT
    if not group.collapsed then
      local shown = math.min(#group.rows, ROWS_PER_GROUP)
      height = height + (shown * ROW_HEIGHT)
      if #group.rows > shown then
        height = height + ROW_HEIGHT
      end
    end
  end
  return height
end

-- The panel keeps whatever corner the user dragged it to and grows downward
-- from there, so a new row never yanks it back to the default position.
local function panelFrame(width, height)
  local screen = hs.screen.primaryScreen():frame()
  local x = ui.x or (screen.x + screen.w - width - MARGIN)
  local y = ui.y or (screen.y + MARGIN)
  x = math.max(screen.x, math.min(x, screen.x + screen.w - width))
  y = math.max(screen.y, math.min(y, screen.y + screen.h - HEADER_HEIGHT))
  return { x = x, y = y, w = width, h = height }
end

-- ---------------------------------------------------------------- dragging

local function endDrag(moved)
  dragState = nil
  if dragTap then
    dragTap:stop()
    dragTap = nil
  end
  if moved then
    -- The canvas fires its own mouseUp too, and the order is not guaranteed,
    -- so a moved drag briefly suppresses click actions rather than trying to
    -- reason about which event arrives first.
    suppressClickUntil = hs.timer.secondsSinceEpoch() + 0.3
    saveUI()
  end
end

local function beginDrag()
  if not canvas then
    return
  end
  local mouse = hs.mouse.absolutePosition()
  local frame = canvas:frame()
  dragState = { mouseX = mouse.x, mouseY = mouse.y, panelX = frame.x, panelY = frame.y, moved = false }

  if dragTap then
    dragTap:stop()
  end
  dragTap = hs.eventtap.new({
    hs.eventtap.event.types.leftMouseDragged,
    hs.eventtap.event.types.leftMouseUp,
  }, function(event)
    if not dragState or not canvas then
      endDrag(false)
      return false
    end
    if event:getType() == hs.eventtap.event.types.leftMouseDragged then
      local cursor = hs.mouse.absolutePosition()
      local dx, dy = cursor.x - dragState.mouseX, cursor.y - dragState.mouseY
      if math.abs(dx) > DRAG_SLOP or math.abs(dy) > DRAG_SLOP then
        dragState.moved = true
      end
      ui.x, ui.y = dragState.panelX + dx, dragState.panelY + dy
      canvas:topLeft({ x = ui.x, y = ui.y })
    else
      endDrag(dragState.moved)
    end
    return false
  end)
  dragTap:start()
end

-- ---------------------------------------------------------------- interaction

local jumpTask, killTask -- forward declarations, defined with the other tasks below

local function onMouse(_, message, elementId)
  if type(elementId) ~= "string" then
    return
  end
  local target = clickables[elementId]
  if not target then
    return
  end

  if message == "mouseDown" then
    -- The pill is one element doing two jobs, so it opts into dragging with a
    -- flag rather than by being a dedicated drag handle.
    if target.action == "drag" or target.drag then
      beginDrag()
    end
    return
  end

  if message == "mouseEnter" and canvas and target.hoverable then
    canvas[elementId].fillColor = COLORS.hover
    return
  end

  if message == "mouseExit" and canvas and target.hoverable then
    if armed and target.target and armed.target == target.target then
      canvas[elementId].fillColor = COLORS.armed
    elseif target.action == "drag" then
      canvas[elementId].fillColor = COLORS.header
    else
      canvas[elementId].fillColor = COLORS.panel
    end
    return
  end

  if message ~= "mouseUp" then
    return
  end
  if hs.timer.secondsSinceEpoch() < suppressClickUntil then
    return
  end

  if target.action == "kill" then
    if armed and armed.target == target.target then
      killTask(target.target, target.verb)
      armed = nil
      if armTimer then
        armTimer:stop()
        armTimer = nil
      end
    else
      armed = { target = target.target }
      if armTimer then
        armTimer:stop()
      end
      armTimer = hs.timer.doAfter(ARM_SECONDS, function()
        armed = nil
        armTimer = nil
        M.draw()
      end)
    end
    M.draw()
  elseif target.action == "jump" then
    -- Clicking the row body is also how you back out of an armed kill.
    armed = nil
    jumpTask(target.target)
  elseif target.action == "fold" then
    ui.collapsed[target.group] = not ui.collapsed[target.group]
    saveUI()
    M.draw()
  elseif target.action == "dim" then
    M.cycleAlpha()
  elseif target.action == "minimize" then
    ui.minimized = true
    saveUI()
    M.draw()
  elseif target.action == "restore" then
    ui.minimized = false
    saveUI()
    M.draw()
  elseif target.action == "hide" then
    hidden = true
    if canvas then
      canvas:hide()
    end
  end
end

local function ensureCanvas(frame)
  if not canvas then
    canvas = hs.canvas.new(frame)
    canvas:level(hs.canvas.windowLevels.floating)
    canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces | hs.canvas.windowBehaviors.stationary)
    -- Without this, clicking a row pulls Hammerspoon to the front and the
    -- terminal you just asked for lands behind it.
    canvas:clickActivating(false)
    canvas:mouseCallback(onMouse)
  else
    canvas:frame(frame)
  end
  canvas:alpha(ui.alpha or 1.0)
  return canvas
end

-- ---------------------------------------------------------------- rendering

local function headerElements(width, withButtons)
  local elements = {
    {
      id = "drag",
      type = "rectangle",
      action = "fill",
      fillColor = COLORS.header,
      frame = { x = 0, y = 0, w = width, h = HEADER_HEIGHT },
      roundedRectRadii = { xRadius = 8, yRadius = 8 },
      trackMouseDown = true,
      trackMouseUp = true,
    },
  }
  clickables["drag"] = { action = "drag" }

  if withButtons then
    elements[#elements + 1] = {
      type = "text",
      text = summaryLine(),
      textColor = COLORS.text,
      textSize = FONT_SIZE,
      textFont = FONT,
      frame = { x = GUTTER, y = (HEADER_HEIGHT - TEXT_H) / 2, w = width - (GUTTER * 2) - (3 * (FONT_SIZE + 7)), h = TEXT_H },
    }
    local buttons = {
      { id = "dim", label = "o", action = "dim" },
      { id = "min", label = "_", action = "minimize" },
      { id = "hide", label = "x", action = "hide" },
    }
    for index, button in ipairs(buttons) do
      local buttonW = FONT_SIZE + 7
      local bx = width - (#buttons - index + 1) * buttonW - 4
      elements[#elements + 1] = {
        id = button.id,
        type = "rectangle",
        action = "fill",
        fillColor = COLORS.header,
        frame = { x = bx, y = 3, w = buttonW - 2, h = HEADER_HEIGHT - 6 },
        roundedRectRadii = { xRadius = 4, yRadius = 4 },
        trackMouseUp = true,
        trackMouseEnterExit = true,
      }
      elements[#elements + 1] = {
        type = "text",
        text = button.label,
        textColor = COLORS.dim,
        textSize = FONT_SIZE,
        textFont = FONT,
        textAlignment = "center",
        frame = {
          x = bx,
          y = (HEADER_HEIGHT - TEXT_H) / 2 + (button.label == "_" and -2 or 0),
          w = buttonW - 2,
          h = TEXT_H,
        },
      }
      clickables[button.id] = { action = button.action, hoverable = true }
    end
  end
  return elements
end

local function drawPill()
  local c = ensureCanvas(panelFrame(PILL_WIDTH, HEADER_HEIGHT))
  c:size({ w = PILL_WIDTH, h = HEADER_HEIGHT })
  clickables = {}
  local elements = {
    {
      id = "pill",
      type = "rectangle",
      action = "fill",
      fillColor = COLORS.header,
      roundedRectRadii = { xRadius = 8, yRadius = 8 },
      trackMouseUp = true,
      trackMouseDown = true,
    },
    {
      type = "text",
      text = pillLine(),
      textColor = COLORS.text,
      textSize = FONT_SIZE,
      textFont = FONT,
      textAlignment = "center",
      frame = { x = 0, y = (HEADER_HEIGHT - TEXT_H) / 2, w = PILL_WIDTH, h = TEXT_H },
    },
  }
  -- One element carries both jobs: press and move to reposition, press and
  -- release in place to expand.
  clickables["pill"] = { action = "restore" }
  clickables["pill"].drag = true
  c:replaceElements(elements)
  c:show()
end

local function drawClear()
  local c = ensureCanvas(panelFrame(PILL_WIDTH, HEADER_HEIGHT))
  c:size({ w = PILL_WIDTH, h = HEADER_HEIGHT })
  clickables = {}
  c:replaceElements({
    {
      type = "rectangle",
      action = "fill",
      fillColor = COLORS.header,
      roundedRectRadii = { xRadius = 8, yRadius = 8 },
    },
    {
      type = "text",
      text = "fleet clear",
      textColor = COLORS.clear,
      textSize = FONT_SIZE,
      textFont = FONT,
      textAlignment = "center",
      frame = { x = 0, y = (HEADER_HEIGHT - TEXT_H) / 2, w = PILL_WIDTH, h = TEXT_H },
    },
  })
  c:show()
end

function M.draw()
  if hidden then
    return
  end

  if not shouldShow() then
    drawClear()
    if clearTimer then
      clearTimer:stop()
    end
    clearTimer = hs.timer.doAfter(CLEAR_LINGER_SECONDS, function()
      if canvas and not shouldShow() and not hidden then
        canvas:hide()
      end
    end)
    return
  end

  if clearTimer then
    clearTimer:stop()
    clearTimer = nil
  end

  if ui.minimized then
    drawPill()
    return
  end

  local groups = visibleGroups()
  local height = contentHeight(groups)
  local c = ensureCanvas(panelFrame(WIDTH, height))
  c:size({ w = WIDTH, h = height })
  clickables = {}

  local elements = {
    {
      type = "rectangle",
      action = "fill",
      fillColor = COLORS.panel,
      roundedRectRadii = { xRadius = 8, yRadius = 8 },
    },
  }
  for _, element in ipairs(headerElements(WIDTH, true)) do
    elements[#elements + 1] = element
  end

  -- Column geometry, right to left: the kill button and the meta text claim
  -- fixed room, the name takes whatever is left.
  local killW = FONT_SIZE + 10
  local killX = WIDTH - GUTTER - killW
  local metaW = math.floor(FONT_SIZE * 9)
  local metaX = killX - 8 - metaW
  local nameX = GUTTER + 2 + FONT_SIZE + 10
  local nameW = math.max(80, metaX - nameX - 8)

  local y = HEADER_HEIGHT + PAD
  local rowIndex = 0

  for groupIndex, group in ipairs(groups) do
    local sectionId = "sect" .. groupIndex
    elements[#elements + 1] = {
      id = sectionId,
      type = "rectangle",
      action = "fill",
      fillColor = COLORS.panel,
      frame = { x = 2, y = y, w = WIDTH - 4, h = SECTION_HEIGHT },
      trackMouseUp = true,
      trackMouseEnterExit = true,
    }
    elements[#elements + 1] = {
      type = "text",
      text = string.format("%s %s (%d)", group.collapsed and "+" or "-", group.name, #group.rows),
      textColor = COLORS.section,
      textSize = SMALL_SIZE,
      textFont = FONT_BOLD,
      frame = { x = GUTTER, y = y + (SECTION_HEIGHT - TEXT_H) / 2, w = WIDTH - (GUTTER * 2), h = TEXT_H },
    }
    clickables[sectionId] = { action = "fold", group = group.name, hoverable = true }
    y = y + SECTION_HEIGHT

    if not group.collapsed then
      local shown = math.min(#group.rows, ROWS_PER_GROUP)
      for i = 1, shown do
        local row = group.rows[i]
        rowIndex = rowIndex + 1
        local id = "row" .. rowIndex
        clickables[id] = { action = "jump", target = row.target, hoverable = true }

        local isArmed = armed ~= nil and row.killTarget ~= "" and armed.target == row.killTarget
        elements[#elements + 1] = {
          id = id,
          type = "rectangle",
          action = "fill",
          fillColor = isArmed and COLORS.armed or COLORS.panel,
          frame = { x = 2, y = y, w = WIDTH - 4, h = ROW_HEIGHT },
          trackMouseUp = true,
          trackMouseEnterExit = true,
        }
        elements[#elements + 1] = {
          type = "text",
          text = row.glyph,
          textColor = GLYPH_COLORS[row.glyph] or COLORS.dim,
          textSize = FONT_SIZE,
          textFont = FONT,
          frame = { x = GUTTER + 2, y = y + (ROW_HEIGHT - TEXT_H) / 2, w = FONT_SIZE + 4, h = TEXT_H },
        }
        elements[#elements + 1] = {
          type = "text",
          text = row.name,
          textColor = COLORS.text,
          textSize = FONT_SIZE,
          textFont = FONT,
          frame = { x = nameX, y = y + (ROW_HEIGHT - TEXT_H) / 2, w = nameW, h = TEXT_H },
        }
        elements[#elements + 1] = {
          type = "text",
          text = isArmed
              and (row.killVerb == "remove" and "click x to DELETE" or "click x again")
            or duration(row.minutes),
          textColor = isArmed and COLORS.danger or COLORS.dim,
          textSize = SMALL_SIZE,
          textFont = FONT,
          textAlignment = "right",
          frame = { x = metaX, y = y + (ROW_HEIGHT - TEXT_H) / 2, w = metaW, h = TEXT_H },
        }

        if row.killTarget ~= "" then
          local killId = "kill" .. rowIndex
          clickables[killId] = {
            action = "kill",
            target = row.killTarget,
            verb = row.killVerb,
            hoverable = true,
          }
          elements[#elements + 1] = {
            id = killId,
            type = "rectangle",
            action = "fill",
            fillColor = isArmed and COLORS.armed or COLORS.panel,
            frame = { x = killX, y = y + 2, w = killW, h = ROW_HEIGHT - 4 },
            roundedRectRadii = { xRadius = 4, yRadius = 4 },
            trackMouseUp = true,
            trackMouseEnterExit = true,
          }
          elements[#elements + 1] = {
            type = "text",
            text = "x",
            textColor = isArmed and COLORS.danger or COLORS.dim,
            textSize = FONT_SIZE,
            textFont = FONT,
            textAlignment = "center",
            frame = { x = killX, y = y + (ROW_HEIGHT - TEXT_H) / 2, w = killW, h = TEXT_H },
          }
        end
        y = y + ROW_HEIGHT
      end

      if #group.rows > shown then
        elements[#elements + 1] = {
          type = "text",
          text = string.format("+%d more", #group.rows - shown),
          textColor = COLORS.dim,
          textSize = SMALL_SIZE,
          textFont = FONT,
          frame = { x = nameX, y = y + (ROW_HEIGHT - TEXT_H) / 2, w = nameW, h = TEXT_H },
        }
        y = y + ROW_HEIGHT
      end
    end
  end

  c:replaceElements(elements)
  c:show()
end

-- ---------------------------------------------------------------- tasks

jumpTask = function(target)
  if not target or target == "" then
    return
  end
  hs.task
    .new(PYTHON, function(exitCode, _, stdErr)
      if exitCode ~= 0 then
        hs.alert.show("fleet: " .. (stdErr or "jump failed"), 3)
      end
      M.refresh()
    end, { SCRIPT, "jump", target })
    :start()
end

killTask = function(target, verb)
  if not target or target == "" then
    return
  end
  verb = verb == "remove" and "remove" or "kill"
  hs.task
    .new(PYTHON, function(exitCode, stdOut, stdErr)
      local message = ((exitCode == 0 and stdOut or stdErr) or ""):gsub("%s+$", "")
      hs.alert.show(message ~= "" and message or ("fleet: " .. verb .. " returned nothing"), 4)
      M.refresh()
    end, { SCRIPT, verb, target, "--yes" })
    :start()
end

local function writeHeartbeat(rowCount)
  ensureCacheDir()
  local beat = io.open(HEARTBEAT, "w")
  if beat then
    beat:write(string.format('{"at":%d,"rows":%d}', os.time(), rowCount))
    beat:close()
  end
end

function M.refresh()
  hs.task
    .new(PYTHON, function(exitCode, stdOut, stdErr)
      if exitCode ~= 0 then
        -- Report once per distinct failure rather than every poll, so a missing
        -- binary does not produce an alert every three seconds.
        local message = (stdErr or "claude-fleet failed"):gsub("%s+$", "")
        if message ~= lastError then
          lastError = message
          hs.alert.show(message, 4)
        end
        return
      end
      lastError = nil
      local ok, parsed = pcall(hs.json.decode, stdOut)
      if not ok or type(parsed) ~= "table" then
        return
      end

      grouped, counts = {}, {}
      for _, row in ipairs(parsed) do
        local group = row.group or "Unknown"
        grouped[group] = grouped[group] or {}
        table.insert(grouped[group], {
          name = row.name,
          glyph = row.glyph,
          minutes = row.minutes,
          target = row.target,
          killTarget = row.killTarget or "",
          killVerb = row.killVerb or "stop",
        })
        counts[group] = (counts[group] or 0) + 1
      end

      writeHeartbeat(#parsed)
      M.draw()
    end, { SCRIPT, "list", "--json" })
    :start()
end

-- ---------------------------------------------------------------- lifecycle

-- On/off stops the 3s poll as well as hiding the panel. Hiding alone would
-- leave a python process spawning every three seconds for a panel nobody is
-- looking at, which is the kind of thing that gets discovered in Activity
-- Monitor a month later.
function M.setEnabled(enabled)
  ui.enabled = enabled and true or false
  saveUI()
  if ui.enabled then
    hidden = false
    if timer then
      timer:stop()
    end
    timer = hs.timer.doEvery(POLL_SECONDS, M.refresh)
    M.refresh()
    hs.alert.show("fleet on", 1)
  else
    hidden = true
    if timer then
      timer:stop()
      timer = nil
    end
    if canvas then
      canvas:hide()
    end
    hs.alert.show("fleet off", 1)
  end
end

function M.toggle()
  M.setEnabled(not ui.enabled)
end

function M.isEnabled()
  return ui.enabled
end

function M.cycleAlpha()
  local current = ui.alpha or 1.0
  local index = 1
  for i, step in ipairs(ALPHA_STEPS) do
    if math.abs(step - current) < 0.01 then
      index = i
      break
    end
  end
  ui.alpha = ALPHA_STEPS[(index % #ALPHA_STEPS) + 1]
  saveUI()
  if canvas then
    canvas:alpha(ui.alpha)
  end
end

-- Steps by 1 rather than by a ratio: at these sizes a ratio either does
-- nothing or overshoots, and a predictable +1 is easier to land on.
function M.setFontSize(size)
  ui.fontSize = math.max(MIN_FONT_SIZE, math.min(tonumber(size) or DEFAULT_FONT_SIZE, MAX_FONT_SIZE))
  applyMetrics()
  saveUI()
  M.draw()
  hs.alert.show("fleet font " .. FONT_SIZE .. "pt", 1)
end

function M.bumpFontSize(delta)
  M.setFontSize((ui.fontSize or DEFAULT_FONT_SIZE) + delta)
end

function M.setFontName(name)
  name = percentDecode(name)
  if type(name) ~= "string" or name == "" then
    return
  end
  -- `hs.styledtext.fontInfo` answers for names macOS cannot resolve too, so it
  -- is useless as a guard. Membership in the name or family list is the test.
  if not fontExists(name) then
    local near = {}
    local needle = name:lower():gsub("%s", "")
    for candidate in pairs(fontLookup or {}) do
      if #near < 3 and candidate:lower():gsub("%s", ""):find(needle, 1, true) then
        near[#near + 1] = candidate
      end
    end
    local hint = #near > 0 and ("; try " .. table.concat(near, ", ")) or ""
    hs.alert.show("fleet: no font named '" .. name .. "'" .. hint, 4)
    return
  end
  ui.fontName = name
  applyMetrics()
  saveUI()
  M.draw()
  hs.alert.show("fleet font " .. name, 1)
end

function M.resetPosition()
  ui.x, ui.y = nil, nil
  ui.minimized = false
  ui.alpha = 1.0
  ui.fontSize = DEFAULT_FONT_SIZE
  ui.fontName = DEFAULT_FONT_NAME
  applyMetrics()
  saveUI()
  hidden = false
  M.draw()
  hs.alert.show("fleet reset to top right", 1)
end

function M.start()
  loadUI()
  if timer then
    timer:stop()
    timer = nil
  end
  if not ui.enabled then
    hidden = true
    return
  end
  timer = hs.timer.doEvery(POLL_SECONDS, M.refresh)
  M.refresh()
end

-- One bind with an `action` parameter rather than seven separate event names,
-- so adding an action does not mean registering another URL.
hs.urlevent.bind("fleet", function(_, params)
  local action = (params and params.action) or "toggle"
  if action == "toggle" then
    M.toggle()
  elseif action == "on" then
    M.setEnabled(true)
  elseif action == "off" then
    M.setEnabled(false)
  elseif action == "refresh" then
    M.setEnabled(true)
  elseif action == "dim" then
    M.cycleAlpha()
  elseif action == "minimize" then
    ui.minimized = not ui.minimized
    saveUI()
    M.draw()
  elseif action == "bigger" then
    M.bumpFontSize(1)
  elseif action == "smaller" then
    M.bumpFontSize(-1)
  elseif action == "font" then
    if params.size then
      M.setFontSize(params.size)
    end
    if params.name then
      M.setFontName(params.name)
    end
  elseif action == "reset" then
    M.resetPosition()
  else
    hs.alert.show("fleet: unknown action '" .. tostring(action) .. "'", 3)
  end
end)

hs.hotkey.bind({ "cmd", "shift", "alt" }, "F", M.toggle)
hs.hotkey.bind({ "cmd", "shift", "alt" }, "G", function()
  hidden = false
  M.refresh()
end)
hs.hotkey.bind({ "cmd", "shift", "alt" }, "D", function()
  M.cycleAlpha()
end)
hs.hotkey.bind({ "cmd", "shift", "alt" }, "=", function()
  M.bumpFontSize(1)
end)
hs.hotkey.bind({ "cmd", "shift", "alt" }, "-", function()
  M.bumpFontSize(-1)
end)
hs.hotkey.bind({ "cmd", "shift", "alt" }, "H", M.resetPosition)

M.start()

return M
