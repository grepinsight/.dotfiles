-- ~/.hammerspoon/slack.lua

-- Define variables for the hotkeys
local f9Hotkey = nil
local f10Hotkey = nil

-- Function to perform the extended key sequence
local function performExtendedKeySequence(pageKey)
  hs.eventtap.keyStroke({}, "tab")
  hs.timer.usleep(100) -- Small delay to ensure key events are processed
  hs.eventtap.keyStroke({ "shift" }, "tab")
  hs.timer.usleep(100)
  hs.eventtap.keyStroke({ "shift" }, pageKey)
end

-- Function to enable hotkeys
local function enableSlackHotkeys()
  -- If not already defined, define them
  if not f9Hotkey then
    f9Hotkey = hs.hotkey.new({}, "f9", function()
      performExtendedKeySequence("pageDown")
    end)
  end

  if not f10Hotkey then
    f10Hotkey = hs.hotkey.new({}, "f10", function()
      performExtendedKeySequence("pageUp")
    end)
  end

  -- Enable the hotkeys
  f9Hotkey:enable()
  f10Hotkey:enable()
end

-- Function to disable hotkeys
local function disableSlackHotkeys()
  if f9Hotkey then
    f9Hotkey:disable()
  end

  if f10Hotkey then
    f10Hotkey:disable()
  end
end

-- Application watcher function
local function applicationWatcher(appName, eventType, appObject)
  if eventType == hs.application.watcher.activated then
    if appName == "Slack" then
      enableSlackHotkeys()
    else
      disableSlackHotkeys()
    end
  elseif eventType == hs.application.watcher.deactivated then
    if appName == "Slack" then
      disableSlackHotkeys()
    end
  elseif eventType == hs.application.watcher.terminated then
    if appName == "Slack" then
      disableSlackHotkeys()
    end
  end
end

-- Create Application Watcher
local appWatcher = hs.application.watcher.new(applicationWatcher)
appWatcher:start()
