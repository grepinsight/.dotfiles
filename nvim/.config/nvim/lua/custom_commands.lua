-- Define a function to call the Lua script
function SuggestAccounts()
  local transaction_description = vim.fn.input("Enter transaction description: ")
  local script_path = "/Users/allee/scratch/2024-11-04--lua-hledger/mapper.lua"
  local command = string.format("lua %s %q", script_path, transaction_description)
  os.execute(command)
end

-- Create a Neovim command to trigger the function
vim.api.nvim_create_user_command("SuggestAccounts", SuggestAccounts, {})

-- Daily notes command
function OpenDaily(opts)
  local date = os.date("%Y-%m-%d")
  local filepath = vim.fn.expand("~/Thoughts/02-Calendar/Daily/" .. date .. ".md")

  -- Create directory if it doesn't exist
  vim.fn.mkdir(vim.fn.expand("~/Thoughts/02-Calendar/Daily"), "p")

  -- Open file based on provided argument
  if opts.args == "vertical" or opts.args == "v" then
    vim.cmd("vsplit " .. filepath)
  elseif opts.args == "horizontal" or opts.args == "h" then
    vim.cmd("split " .. filepath)
  else
    vim.cmd("edit " .. filepath)
  end
end

-- Weekly notes command
function OpenWeekly(opts)
  -- Get ISO week number and year
  local year = os.date("%Y")
  local week = os.date("%V")
  local filepath = vim.fn.expand("~/Thoughts/02-Calendar/Weekly/" .. year .. "-W" .. week .. ".md")

  -- Create directory if it doesn't exist
  vim.fn.mkdir(vim.fn.expand("~/Thoughts/02-Calendar/Weekly"), "p")

  -- Open file based on provided argument
  if opts.args == "vertical" or opts.args == "v" then
    vim.cmd("vsplit " .. filepath)
  elseif opts.args == "horizontal" or opts.args == "h" then
    vim.cmd("split " .. filepath)
  else
    vim.cmd("edit " .. filepath)
  end
end

-- Quarterly notes command
function OpenQuarterly(opts)
  local year = os.date("%Y")
  local month = tonumber(os.date("%m"))
  local quarter = math.ceil(month / 3)
  local filepath = vim.fn.expand("~/Thoughts/02-Calendar/Quarterly/" .. year .. "-Q" .. quarter .. ".md")

  -- Create directory if it doesn't exist
  vim.fn.mkdir(vim.fn.expand("~/Thoughts/02-Calendar/Quarterly"), "p")

  -- Open file based on provided argument
  if opts.args == "vertical" or opts.args == "v" then
    vim.cmd("vsplit " .. filepath)
  elseif opts.args == "horizontal" or opts.args == "h" then
    vim.cmd("split " .. filepath)
  else
    vim.cmd("edit " .. filepath)
  end
end

-- Yearly notes command
function OpenYearly(opts)
  local year = os.date("%Y")
  local filepath = vim.fn.expand("~/Thoughts/02-Calendar/Yearly/" .. year .. ".md")

  -- Create directory if it doesn't exist
  vim.fn.mkdir(vim.fn.expand("~/Thoughts/02-Calendar/Yearly"), "p")

  -- Open file based on provided argument
  if opts.args == "vertical" or opts.args == "v" then
    vim.cmd("vsplit " .. filepath)
  elseif opts.args == "horizontal" or opts.args == "h" then
    vim.cmd("split " .. filepath)
  else
    vim.cmd("edit " .. filepath)
  end
end

-- Create user commands for calendar notes
vim.api.nvim_create_user_command("Daily", OpenDaily, {
  nargs = "?",
  complete = function(ArgLead, CmdLine, CursorPos)
    return { "vertical", "horizontal", "v", "h" }
  end,
  desc = "Open daily note for today",
})

vim.api.nvim_create_user_command("Weekly", OpenWeekly, {
  nargs = "?",
  complete = function(ArgLead, CmdLine, CursorPos)
    return { "vertical", "horizontal", "v", "h" }
  end,
  desc = "Open weekly note for current week",
})

vim.api.nvim_create_user_command("Quarterly", OpenQuarterly, {
  nargs = "?",
  complete = function(ArgLead, CmdLine, CursorPos)
    return { "vertical", "horizontal", "v", "h" }
  end,
  desc = "Open quarterly note for current quarter",
})

vim.api.nvim_create_user_command("Yearly", OpenYearly, {
  nargs = "?",
  complete = function(ArgLead, CmdLine, CursorPos)
    return { "vertical", "horizontal", "v", "h" }
  end,
  desc = "Open yearly note for current year",
})

-- Todo command to open TODO.md
vim.api.nvim_create_user_command("Todo", function(opts)
  local filepath = vim.fn.expand("~/Thoughts/TODO.md")

  -- Open file based on provided argument
  if opts.args == "vertical" or opts.args == "v" then
    vim.cmd("vsplit " .. filepath)
  elseif opts.args == "horizontal" or opts.args == "h" then
    vim.cmd("split " .. filepath)
  else
    vim.cmd("edit " .. filepath)
  end
end, {
  nargs = "?",
  complete = function(ArgLead, CmdLine, CursorPos)
    return { "vertical", "horizontal", "v", "h" }
  end,
  desc = "Open TODO.md file",
})

function assign_to_variable(var_name)
  -- Default variable name if none provided
  var_name = var_name or "df"

  -- Get current cursor position
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1], cursor[2]

  -- Get current line content
  local line = vim.api.nvim_get_current_line()

  -- Create the assignment prefix
  local prefix = var_name .. " = "

  -- Create the new line with variable assignment
  local new_line = prefix .. line

  -- Set the modified line
  vim.api.nvim_set_current_line(new_line)

  -- Calculate new cursor position (adjust for added characters)
  local new_col = col + string.len(prefix)

  -- Restore cursor to the adjusted position
  vim.api.nvim_win_set_cursor(0, { row, new_col })
end

-- Create a command to call the function
vim.api.nvim_create_user_command("AssignToVar", function(opts)
  local var_name = opts.args ~= "" and opts.args or nil
  assign_to_variable(var_name)
end, {
  nargs = "?", -- Optional argument
  desc = "Assign current line to a variable",
})

-- Optional: Create a keymap for quick access
vim.keymap.set("n", "<leader>av", function()
  -- Prompt for variable name
  local var_name = vim.fn.input("Variable name (default: df): ")
  var_name = var_name ~= "" and var_name or nil
  assign_to_variable(var_name)
end, { desc = "Assign line to variable" })
