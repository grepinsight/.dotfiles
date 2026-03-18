-- Bind Shift+Ctrl+R
hs.hotkey.bind({ "shift", "ctrl", "cmd" }, "R", function()
  -- Get the frontmost application
  local focusedApp = hs.application.frontmostApplication()

  if focusedApp:name() == "Google Chrome" then
    -- Existing actions for Google Chrome

    -- Press Esc key
    hs.eventtap.keyStroke({}, "escape")

    -- Short pause to ensure Esc is processed
    hs.timer.usleep(50000) -- 50ms delay

    -- Send Ctrl+Shift+P
    hs.eventtap.keyStroke({ "ctrl", "shift" }, "p")

    -- Short pause to ensure the command palette is open
    hs.timer.usleep(100000) -- 100ms delay

    -- Type 'reload'
    hs.eventtap.keyStrokes("reload")

    -- Short pause to ensure 'reload' is typed
    hs.timer.usleep(50000) -- 50ms delay

    -- Press Enter
    hs.eventtap.keyStroke({}, "return")
  else
    -- If not Google Chrome, pass Cmd+Shift+R to the active application
    hs.eventtap.keyStroke({ "cmd", "shift" }, "R")
  end
end)

-- Rest of your script remains unchanged

-- Create a variable to store the last three characters typed
local lastThreeChars = ""

-- Create a keystroke tap
local typingWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
  local keyChar = event:getCharacters()

  -- Update lastThreeChars
  lastThreeChars = (lastThreeChars .. keyChar):sub(-3)

  -- Check if the last three characters are ";;)"
  if lastThreeChars == ";;)" then
    -- Delete the ";;)" sequence
    hs.eventtap.keyStroke({}, "delete", 100)
    hs.eventtap.keyStroke({}, "delete", 100)
    hs.eventtap.keyStroke({}, "delete", 100)

    -- Move cursor left to the start of the line
    hs.eventtap.keyStroke({ "cmd" }, "left")

    -- Insert opening parenthesis
    hs.eventtap.keyStrokes("(")

    -- Move cursor right to the end of the line
    hs.eventtap.keyStroke({ "cmd" }, "right")

    -- Insert closing parenthesis
    hs.eventtap.keyStrokes(")")

    -- Move cursor left once to place it back at the original position
    hs.eventtap.keyStroke({}, "left")

    -- Reset lastThreeChars
    lastThreeChars = ""

    -- Prevent the original ")" from being typed
    return true
  end

  -- Allow the keystroke to pass through
  return false
end)

-- Start the keystroke tap
typingWatcher:start()
