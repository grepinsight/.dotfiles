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
  local command = { "/bin/sh", "-c", "todoist sync && todoist list --filter 'overdue | today'" }

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

-- Task sorting with effort/impact prioritization
-- Configuration for priority calculation
local SORT_CONFIG = {
  impact_weight = 1.0,
  effort_weight = 1.0,
}

-- Parse a task line and extract effort, impact, and urgent values
local function parse_task(line)
  -- Match task format: - [ ] description ; effort=N ; impact=N ; urgent=N
  -- Also handle typos like "effor" instead of "effort"
  -- All fields (effort, impact, urgent) are optional
  local checkbox, description = line:match("^(%-? %[.%])(.*)$")
  if not checkbox then
    return nil
  end

  -- Extract effort (handle both "effort" and "effor" typo)
  local effort_str = description:match("effor?t%s*=%s*(%d+)")
  local effort = effort_str and tonumber(effort_str) or nil

  -- Extract impact
  local impact_str = description:match("impact%s*=%s*(%d+)")
  local impact = impact_str and tonumber(impact_str) or nil

  -- Extract urgent
  local urgent_str = description:match("urgent%s*=%s*(%d+)")
  local urgent = urgent_str and tonumber(urgent_str) or nil

  -- At least one field should be present to be considered a task with metrics
  if not effort and not impact and not urgent then
    return nil
  end

  return {
    line = line,
    checkbox = checkbox,
    effort = effort,
    impact = impact,
    urgent = urgent,
    description = description,
  }
end

-- Calculate priority score: (Impact * impact_weight) / (Effort * effort_weight)
-- Higher score = higher priority (high impact, low effort)
local function calculate_priority(task)
  -- Use defaults if fields are missing
  local impact = task.impact or 0
  local effort = task.effort or 50 -- Default to medium effort

  if effort == 0 then
    -- Avoid division by zero, treat 0 effort as minimal (0.1)
    effort = 0.1
  end

  return (impact * SORT_CONFIG.impact_weight) / (effort * SORT_CONFIG.effort_weight)
end

-- Sort tasks based on criteria
local function sort_tasks_by(tasks, sort_by, descending)
  local sorted = vim.deepcopy(tasks)

  table.sort(sorted, function(a, b)
    local value_a, value_b

    if sort_by == "effort" then
      value_a = a.effort or 999 -- Tasks without effort go to end
      value_b = b.effort or 999
    elseif sort_by == "impact" then
      value_a = a.impact or 0 -- Tasks without impact go to beginning
      value_b = b.impact or 0
    elseif sort_by == "urgent" then
      value_a = a.urgent or 0 -- Tasks without urgent go to beginning
      value_b = b.urgent or 0
    elseif sort_by == "priority" then
      value_a = calculate_priority(a)
      value_b = calculate_priority(b)
    else
      return false
    end

    if descending then
      return value_a > value_b
    else
      return value_a < value_b
    end
  end)

  return sorted
end

-- Main sorting function
function SortTasks(opts)
  local bufnr = vim.api.nvim_get_current_buf()
  local sort_by = opts.fargs[1] or "priority"
  local order = opts.fargs[2] or "desc"
  local descending = (order == "desc" or order == "d")

  -- Validate sort_by parameter
  if sort_by ~= "effort" and sort_by ~= "impact" and sort_by ~= "urgent" and sort_by ~= "priority" then
    vim.notify("Invalid sort option. Use: effort, impact, urgent, or priority", vim.log.levels.ERROR)
    return
  end

  -- Get range to sort
  local start_line, end_line
  if opts.range == 2 then
    -- Visual selection
    start_line = opts.line1 - 1
    end_line = opts.line2
  else
    -- Use paragraph as text object
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local current_line = cursor_pos[1]

    -- Find paragraph boundaries (empty lines or beginning/end of buffer)
    start_line = current_line - 1
    while start_line > 0 do
      local line = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, start_line, false)[1]
      if line == "" or line:match("^%s*$") then
        break
      end
      start_line = start_line - 1
    end

    end_line = current_line
    local total_lines = vim.api.nvim_buf_line_count(bufnr)
    while end_line < total_lines do
      local line = vim.api.nvim_buf_get_lines(bufnr, end_line, end_line + 1, false)[1]
      if not line or line == "" or line:match("^%s*$") then
        break
      end
      end_line = end_line + 1
    end
  end

  -- Get lines in range
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)

  -- Parse tasks
  local tasks = {}
  local non_task_lines = {}
  for i, line in ipairs(lines) do
    local task = parse_task(line)
    if task then
      task.original_index = i
      table.insert(tasks, task)
    else
      table.insert(non_task_lines, { index = i, line = line })
    end
  end

  if #tasks == 0 then
    vim.notify("No valid tasks found to sort", vim.log.levels.WARN)
    return
  end

  -- Sort tasks
  local sorted_tasks = sort_tasks_by(tasks, sort_by, descending)

  -- Reconstruct lines with sorted tasks
  local new_lines = {}
  local task_idx = 1
  for i = 1, #lines do
    -- Check if this was a task line
    local is_task = false
    for _, task in ipairs(tasks) do
      if task.original_index == i then
        is_task = true
        break
      end
    end

    if is_task then
      table.insert(new_lines, sorted_tasks[task_idx].line)
      task_idx = task_idx + 1
    else
      -- Keep non-task lines in place
      for _, non_task in ipairs(non_task_lines) do
        if non_task.index == i then
          table.insert(new_lines, non_task.line)
          break
        end
      end
    end
  end

  -- Replace lines in buffer
  vim.api.nvim_buf_set_lines(bufnr, start_line, end_line, false, new_lines)

  -- Notify user
  local sort_desc = sort_by
  if sort_by == "priority" then
    sort_desc = string.format("priority (impact×%.1f / effort×%.1f)", SORT_CONFIG.impact_weight, SORT_CONFIG.effort_weight)
  end
  vim.notify(
    string.format("Sorted %d tasks by %s (%s)", #tasks, sort_desc, descending and "high→low" or "low→high"),
    vim.log.levels.INFO
  )
end

-- Command to configure priority weights
function SetSortWeights(opts)
  local args = opts.fargs
  if #args ~= 2 then
    vim.notify(
      string.format(
        "Current weights: impact=%.1f, effort=%.1f\nUsage: SetSortWeights <impact_weight> <effort_weight>",
        SORT_CONFIG.impact_weight,
        SORT_CONFIG.effort_weight
      ),
      vim.log.levels.INFO
    )
    return
  end

  local impact_weight = tonumber(args[1])
  local effort_weight = tonumber(args[2])

  if not impact_weight or not effort_weight or impact_weight <= 0 or effort_weight <= 0 then
    vim.notify("Weights must be positive numbers", vim.log.levels.ERROR)
    return
  end

  SORT_CONFIG.impact_weight = impact_weight
  SORT_CONFIG.effort_weight = effort_weight

  vim.notify(
    string.format("Updated weights: impact=%.1f, effort=%.1f", SORT_CONFIG.impact_weight, SORT_CONFIG.effort_weight),
    vim.log.levels.INFO
  )
end

vim.api.nvim_create_user_command("SortTasks", SortTasks, {
  nargs = "*",
  range = true,
  complete = function(ArgLead, CmdLine, CursorPos)
    local args = vim.split(CmdLine, "%s+")
    if #args == 2 then
      return { "effort", "impact", "urgent", "priority" }
    elseif #args == 3 then
      return { "asc", "desc", "a", "d" }
    end
    return {}
  end,
  desc = "Sort tasks by effort, impact, urgent, or priority (default: priority desc)",
})

vim.api.nvim_create_user_command("SetSortWeights", SetSortWeights, {
  nargs = "*",
  desc = "Set priority calculation weights (impact_weight effort_weight)",
})

-- Convert long bash command to multiline format with backslashes
function BashMultiline(opts)
  local bufnr = vim.api.nvim_get_current_buf()
  local start_line, end_line

  -- Get range
  if opts.range == 2 then
    -- Visual selection
    start_line = opts.line1 - 1
    end_line = opts.line2
  else
    -- Current line
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    start_line = cursor_pos[1] - 1
    end_line = cursor_pos[1]
  end

  -- Get the lines and join them
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
  local command = table.concat(lines, " ")

  -- Trim leading/trailing whitespace
  command = command:gsub("^%s+", ""):gsub("%s+$", "")

  if command == "" then
    vim.notify("No command to format", vim.log.levels.WARN)
    return
  end

  -- Tokenize the command
  local function tokenize(cmd)
    local tokens = {}
    local current = ""
    local in_single_quote = false
    local in_double_quote = false
    local paren_depth = 0
    local i = 1

    while i <= #cmd do
      local char = cmd:sub(i, i)
      local prev_char = i > 1 and cmd:sub(i - 1, i - 1) or ""

      -- Track quote state
      if char == "'" and not in_double_quote and prev_char ~= "\\" then
        in_single_quote = not in_single_quote
        current = current .. char
      elseif char == '"' and not in_single_quote and prev_char ~= "\\" then
        in_double_quote = not in_double_quote
        current = current .. char
      elseif char == "$" and not in_single_quote and not in_double_quote and cmd:sub(i + 1, i + 1) == "(" then
        -- Start of command substitution
        current = current .. char
      elseif char == "(" and not in_single_quote and not in_double_quote then
        paren_depth = paren_depth + 1
        current = current .. char
      elseif char == ")" and not in_single_quote and not in_double_quote then
        paren_depth = paren_depth - 1
        current = current .. char
        if paren_depth == 0 and current:match("%$%(") then
          -- End of command substitution
          table.insert(tokens, { type = "subcommand", value = current })
          current = ""
        end
      elseif char == "|" and not in_single_quote and not in_double_quote and paren_depth == 0 then
        if current ~= "" then
          table.insert(tokens, { type = "text", value = current })
        end
        table.insert(tokens, { type = "pipe", value = "|" })
        current = ""
      elseif char == " " and not in_single_quote and not in_double_quote and paren_depth == 0 then
        if current ~= "" then
          -- Check if this looks like a flag
          if current:match("^%-%-?") then
            table.insert(tokens, { type = "flag", value = current })
          else
            table.insert(tokens, { type = "text", value = current })
          end
          current = ""
        end
      else
        current = current .. char
      end

      i = i + 1
    end

    if current ~= "" then
      if current:match("^%-%-?") then
        table.insert(tokens, { type = "flag", value = current })
      else
        table.insert(tokens, { type = "text", value = current })
      end
    end

    return tokens
  end

  -- Format a command substitution
  local function format_subcommand(sub, base_indent)
    -- Remove $( and )
    local inner = sub:gsub("^%$%(", ""):gsub("%)$", "")
    local tokens = tokenize(inner)
    local result = {}
    local indent = base_indent .. "  "

    table.insert(result, base_indent .. "$( \\")

    local i = 1
    while i <= #tokens do
      local token = tokens[i]
      local next_token = tokens[i + 1]

      if token.type == "pipe" then
        table.insert(result, indent .. "| \\")
      elseif token.type == "text" or token.type == "flag" then
        local line = indent .. token.value
        -- Add following flags/args on same line if they're short
        while next_token and (next_token.type == "flag" or next_token.type == "text") and #(line .. " " .. next_token.value) < 80 do
          line = line .. " " .. next_token.value
          i = i + 1
          next_token = tokens[i + 1]
        end

        if i < #tokens then
          table.insert(result, line .. " \\")
        else
          table.insert(result, line .. " \\")
        end
      end

      i = i + 1
    end

    table.insert(result, base_indent .. ")")

    return result
  end

  -- Main formatting
  local tokens = tokenize(command)
  local result = {}
  local indent = "  "

  local i = 1
  while i <= #tokens do
    local token = tokens[i]
    local next_token = tokens[i + 1]

    if token.type == "subcommand" then
      -- Format the command substitution
      local sub_lines = format_subcommand(token.value, indent)
      for j, line in ipairs(sub_lines) do
        table.insert(result, line)
      end
    elseif token.type == "pipe" then
      table.insert(result, indent .. "| \\")
    elseif token.type == "text" or token.type == "flag" then
      if i == 1 then
        -- First token
        local line = token.value
        -- Add following args if they fit
        while next_token and next_token.type ~= "pipe" and next_token.type ~= "subcommand" and #(line .. " " .. next_token.value) < 60 do
          line = line .. " " .. next_token.value
          i = i + 1
          next_token = tokens[i + 1]
        end
        table.insert(result, line .. " \\")
      else
        local line = indent .. token.value
        if i < #tokens then
          table.insert(result, line .. " \\")
        else
          table.insert(result, line)
        end
      end
    end

    i = i + 1
  end

  -- Remove trailing backslash from last line
  if #result > 0 then
    result[#result] = result[#result]:gsub("%s*\\%s*$", "")
  end

  -- Replace the original line(s) with formatted version
  vim.api.nvim_buf_set_lines(bufnr, start_line, end_line, false, result)

  vim.notify("Formatted bash command to multiline", vim.log.levels.INFO)
end

vim.api.nvim_create_user_command("BashMultiline", BashMultiline, {
  range = true,
  desc = "Convert long bash command to multiline format with backslashes",
})

-- Add keymaps for quick access
vim.keymap.set("n", "<leader>bm", ":BashMultiline<CR>", {
  desc = "Convert bash to multiline",
  silent = true,
})

vim.keymap.set("v", "<leader>bm", ":BashMultiline<CR>", {
  desc = "Convert bash to multiline",
  silent = true,
})
