-- Load modules from 'modules' directory
-- Load modules from 'modules' directory
-- This allows us use ~/.hammerspoon/modules/ to store our modules
package.path = package.path .. ";" .. hs.configdir .. "/modules/?.lua"

-- Load Slack hotkeys configuration
require("slack")
require("unclassified")

-- Function to show current time in South Korea and US (PST)
local function showCurrentTime()
  local currentTime = os.time()

  -- Calculate South Korea Time (KST)
  local koreaTime = os.date("!%a, %Y-%m-%d %H:%M:%S", currentTime + 9 * 3600) -- KST is UTC+9
  -- Calculate US Pacific Time (PST)
  local pacificTime = os.date("!%a, %Y-%m-%d %H:%M:%S", currentTime - 8 * 3600) -- PST is UTC-8

  -- Create styled text for KST
  local kstStyled =
    hs.styledtext.new("🇰🇷 KST: ", { font = { weight = "bold", size = 28 }, color = { hex = "#FFFFFF" } })
  local kstTimeStyled = hs.styledtext.new(koreaTime, { font = { size = 25 }, color = { hex = "#FFFFFF" } })

  -- Create styled text for PST
  local pstStyled =
    hs.styledtext.new("🇺🇸 PST: ", { font = { weight = "bold", size = 18 }, color = { hex = "#FFFFFF" } })
  local pstTimeStyled = hs.styledtext.new(pacificTime, { font = { size = 25 }, color = { hex = "#FFFFFF" } })

  -- Combine styled texts into a list
  local message = kstStyled .. kstTimeStyled .. "\n" .. pstStyled .. pstTimeStyled
  hs.alert.show(message, 3) -- Show the times for 3 seconds
end

-- Bind Cmd + Shift + Option + T to show current time
hs.hotkey.bind({ "cmd", "shift", "alt" }, "T", showCurrentTime)

-- Bind Cmd + Shift + Option + R to reload Hammerspoon
hs.hotkey.bind({ "cmd", "shift", "alt" }, "R", function()
  hs.reload()
  hs.notify.new({ title = "Hammerspoon", informativeText = "Configuration reloaded" }):send()
end)

-- Function to calculate sleep duration if sleeping now and waking up at 5 AM
local function showSleepDuration()
  local currentTime = os.time()
  local currentDate = os.date("*t")
  local wakeUpTime = os.time({
    year = currentDate.year,
    month = currentDate.month,
    day = currentDate.day,
    hour = 5,
    min = 0,
    sec = 0,
  })

  -- If the current time is past 5 AM, set wake up time to the next day
  if currentTime > wakeUpTime then
    wakeUpTime = wakeUpTime + 24 * 3600
  end

  local sleepDuration = os.difftime(wakeUpTime, currentTime)
  local hours = math.floor(sleepDuration / 3600)
  local minutes = math.floor((sleepDuration % 3600) / 60)

  local message = string.format("🛌 Sleep Duration: %02d hours and %02d minutes", hours, minutes)
  hs.alert.show(message, 5) -- Show the sleep duration for 5 seconds
end

-- Bind Cmd + Shift + Option + E to show sleep duration
hs.hotkey.bind({ "cmd", "shift", "alt" }, "I", showSleepDuration)

hs.hotkey.bind({ "cmd", "alt" }, "1", function()
  local screen = hs.screen.allScreens()[1]
  local center = hs.geometry.rectMidPoint(screen:frame())
  hs.mouse.absolutePosition(center)
end)

hs.hotkey.bind({ "cmd", "alt" }, "2", function()
  local screen = hs.screen.allScreens()[2]
  local center = hs.geometry.rectMidPoint(screen:frame())
  hs.mouse.absolutePosition(center)
end)
