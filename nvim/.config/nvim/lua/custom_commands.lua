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

-- Todoist command to sync and paste tasks at cursor position
function InsertTodoistTasks()
  local command = { "sh", "-c", "todoist sync && todoist list --filter 'overdue | today'" }

  -- Get current cursor position
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local bufnr = vim.api.nvim_get_current_buf()

  local output_lines = {}

  -- Find existing "## From Todoist" section and return start/end line numbers
  local function find_todoist_section()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local start_line = nil
    local end_line = nil

    for i, line in ipairs(lines) do
      if line:match("^## From Todoist") then
        start_line = i - 1 -- Convert to 0-indexed
      elseif start_line and line:match("^## ") then
        -- Found next h2 heading, end of our section
        end_line = i - 1
        break
      end
    end

    -- If we found a start but no end, section goes to end of file
    if start_line and not end_line then
      end_line = #lines
    end

    return start_line, end_line
  end

  -- Parse and format todoist tasks
  local function format_tasks(raw_lines)
    local tasks = {}

    -- Parse each line
    for _, line in ipairs(raw_lines) do
      if line ~= "" then
        -- Extract components: ID, priority, date, section, and description
        local id, priority, date, rest = line:match("^(%d+)%s+(p%d)%s+([^#]+)(.*)$")
        if id and priority and rest then
          local section, description = rest:match("^#([^%s]+)%s+(.*)$")
          if not section then
            section = "Other"
            description = rest:gsub("^%s+", "")
          end

          table.insert(tasks, {
            id = id,
            priority = priority,
            priority_num = tonumber(priority:match("p(%d)")),
            date = date:gsub("%s+$", ""),
            section = section,
            description = description:gsub("^%s+", ""),
          })
        end
      end
    end

    -- Group by section
    local sections = {}
    for _, task in ipairs(tasks) do
      if not sections[task.section] then
        sections[task.section] = {}
      end
      table.insert(sections[task.section], task)
    end

    -- Sort tasks within each section by priority (p1 first)
    for _, section_tasks in pairs(sections) do
      table.sort(section_tasks, function(a, b)
        return a.priority_num < b.priority_num
      end)
    end

    -- Build formatted output
    local formatted = { "## From Todoist", "" }
    local section_order = {}

    -- Collect and sort section names
    for section_name, _ in pairs(sections) do
      table.insert(section_order, section_name)
    end
    table.sort(section_order)

    -- Format each section
    for _, section_name in ipairs(section_order) do
      table.insert(formatted, "### " .. section_name)
      table.insert(formatted, "")
      for _, task in ipairs(sections[section_name]) do
        local priority_label = task.priority
        if task.priority == "p1" then
          priority_label = priority_label .. " 🚩"
        end
        table.insert(formatted, string.format("- [ ] (%s) %s (id: %s)", priority_label, task.description, task.id))
      end
      table.insert(formatted, "")
    end

    return formatted
  end

  -- Run command asynchronously
  vim.fn.jobstart(command, {
    stdout_buffered = true,
    on_stdout = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(output_lines, line)
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            vim.schedule(function()
              vim.notify("Todoist stderr: " .. line, vim.log.levels.WARN)
            end)
          end
        end
      end
    end,
    on_exit = function(_, exit_code, _)
      vim.schedule(function()
        if exit_code == 0 then
          local formatted
          if #output_lines > 0 then
            formatted = format_tasks(output_lines)
          else
            -- Create a section with "no tasks" message
            formatted = { "## From Todoist", "", "No task to do in todoist", "" }
          end

          -- Find and replace existing section, or insert at cursor
          local start_line, end_line = find_todoist_section()
          if start_line then
            -- Replace existing section
            vim.api.nvim_buf_set_lines(bufnr, start_line, end_line, false, formatted)
            vim.notify("Updated Todoist section", vim.log.levels.INFO)
          else
            -- Insert at cursor position
            vim.api.nvim_buf_set_lines(bufnr, row, row, false, formatted)
            vim.notify("Inserted Todoist tasks", vim.log.levels.INFO)
          end
        else
          vim.notify("Todoist command failed with exit code: " .. exit_code, vim.log.levels.ERROR)
        end
      end)
    end,
  })

  vim.notify("Fetching Todoist tasks...", vim.log.levels.INFO)
end

vim.api.nvim_create_user_command("Todoist", InsertTodoistTasks, {
  desc = "Sync Todoist and insert overdue/today tasks at cursor",
})

-- TodoistSync: Close checked-off tasks in Todoist
function SyncTodoistCompleted()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Find existing "## From Todoist" section
  local function find_todoist_section()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local start_line = nil
    local end_line = nil

    for i, line in ipairs(lines) do
      if line:match("^## From Todoist") then
        start_line = i - 1 -- Convert to 0-indexed
      elseif start_line and line:match("^## ") then
        end_line = i - 1
        break
      end
    end

    if start_line and not end_line then
      end_line = #lines
    end

    return start_line, end_line
  end

  -- Find the Todoist section
  local start_line, end_line = find_todoist_section()
  if not start_line then
    vim.notify("No '## From Todoist' section found", vim.log.levels.WARN)
    return
  end

  -- Get lines in the Todoist section
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)

  -- Find all checked tasks with IDs
  local checked_tasks = {}
  for i, line in ipairs(lines) do
    if line:match("^%- %[x%]") then
      -- Extract description and ID
      local description = line:match("^%- %[x%] %(.-%)%s+(.-)%s+%(id:")
      local id = line:match("%(id:%s*(%d+)%)")

      if id and description then
        table.insert(checked_tasks, {
          line_num = start_line + i - 1, -- Absolute line number (0-indexed)
          id = id,
          description = description,
        })
      else
        vim.notify("Warning: Malformed checked task on line " .. (start_line + i), vim.log.levels.WARN)
      end
    end
  end

  -- Check if any tasks found
  if #checked_tasks == 0 then
    vim.notify("No checked tasks found to sync", vim.log.levels.INFO)
    return
  end

  -- Process each task with confirmation
  local closed_tasks = {}
  for _, task in ipairs(checked_tasks) do
    -- Ask for confirmation
    local response = vim.fn.input(string.format("Close task: '%s'? (y/N): ", task.description))
    print("") -- Clear the input line

    if response:lower() == "y" or response:lower() == "yes" then
      -- Run todoist close command
      local result = vim.fn.system("todoist close " .. task.id)
      local exit_code = vim.v.shell_error

      if exit_code == 0 then
        table.insert(closed_tasks, task)
        vim.notify("Closed: " .. task.description, vim.log.levels.INFO)
      else
        vim.notify("Failed to close task " .. task.id .. ": " .. result, vim.log.levels.ERROR)
      end
    else
      vim.notify("Skipped: " .. task.description, vim.log.levels.INFO)
    end
  end

  -- Remove closed tasks from buffer (bottom-up to avoid index shifting)
  table.sort(closed_tasks, function(a, b)
    return a.line_num > b.line_num
  end)

  for _, task in ipairs(closed_tasks) do
    vim.api.nvim_buf_set_lines(bufnr, task.line_num, task.line_num + 1, false, {})
  end

  -- Final summary
  if #closed_tasks > 0 then
    vim.notify(string.format("Closed %d task(s) in Todoist", #closed_tasks), vim.log.levels.INFO)
  end
end

vim.api.nvim_create_user_command("TodoistSync", SyncTodoistCompleted, {
  desc = "Close checked-off tasks in Todoist",
})
