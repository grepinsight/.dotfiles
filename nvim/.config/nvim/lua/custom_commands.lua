-- Vault root comes from $OBSIDIAN_VAULT; see lua/util/vault.lua.
local vault = require("util.vault")

-- The hledger account mapper lives outside this repo, so its path is resolved at call time
-- rather than hardcoded. Same reasoning as `util/vault.lua`, and for the same reason: this
-- config is tracked and the repo is public, so a checkout under another username pointed at
-- an absolute `/Users/<someone>/...` path that does not exist.
--
-- Resolution order:
--   1. `$HLEDGER_MAPPER` -- full path to the script, for a non-standard location
--   2. `$SCRATCH_DIR`    -- the scratch root, if one is exported
--   3. `~/scratch`       -- last-resort default, which is where it actually lives
local HLEDGER_MAPPER_REL = "2024-11-04--lua-hledger/mapper.lua"

---@return string
local function hledger_mapper_path()
  local explicit = vim.env.HLEDGER_MAPPER
  if explicit ~= nil and explicit ~= "" then
    return vim.fs.normalize(explicit)
  end
  local root = vim.env.SCRATCH_DIR
  if root == nil or root == "" then
    root = "~/scratch"
  end
  return vim.fs.joinpath(vim.fs.normalize(root), HLEDGER_MAPPER_REL)
end

-- Define a function to call the Lua script
function SuggestAccounts()
  local script_path = hledger_mapper_path()
  -- Checked before the prompt, not after: asking for a description and then failing wastes
  -- the typing, and the old code failed with a raw `lua: cannot open ...` instead.
  if vim.fn.filereadable(script_path) == 0 then
    vim.notify(
      ("SuggestAccounts: no mapper script at %s. Set $HLEDGER_MAPPER to its full path, or "
        .. "$SCRATCH_DIR to the directory containing %s."):format(script_path, HLEDGER_MAPPER_REL),
      vim.log.levels.ERROR
    )
    return
  end

  local transaction_description = vim.fn.input("Enter transaction description: ")
  if transaction_description == "" then
    return
  end

  -- `shellescape` on both, because `%q` is Lua's string quoting and not the shell's, and
  -- the path was previously unquoted entirely, so a space anywhere in it split the command.
  os.execute(("lua %s %s"):format(
    vim.fn.shellescape(script_path),
    vim.fn.shellescape(transaction_description)
  ))
end

-- Create a Neovim command to trigger the function
vim.api.nvim_create_user_command("SuggestAccounts", SuggestAccounts, {})

-- Daily notes command
function OpenDaily(opts)
  local date = os.date("%Y-%m-%d")
  local filepath = vault.path("02-Calendar/Daily", date .. ".md")

  -- Create directory if it doesn't exist
  vim.fn.mkdir(vault.path("02-Calendar/Daily"), "p")

  -- Open file based on provided argument
  if opts.args == "vertical" or opts.args == "v" then
    vim.cmd("vsplit " .. filepath)
  elseif opts.args == "horizontal" or opts.args == "h" then
    vim.cmd("split " .. filepath)
  else
    vim.cmd("edit " .. filepath)
  end
end

-- Yesterday's daily note command
function OpenYesterday(opts)
  local t = os.date("*t")
  t.day = t.day - 1
  t.hour = 12 -- midday so DST shifts can't roll the date over
  local date = os.date("%Y-%m-%d", os.time(t))
  local filepath = vault.path("02-Calendar/Daily", date .. ".md")

  -- Create directory if it doesn't exist
  vim.fn.mkdir(vault.path("02-Calendar/Daily"), "p")

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
  local filepath = vault.path("02-Calendar/Weekly", year .. "-W" .. week .. ".md")

  -- Create directory if it doesn't exist
  vim.fn.mkdir(vault.path("02-Calendar/Weekly"), "p")

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
  local filepath = vault.path("02-Calendar/Quarterly", year .. "-Q" .. quarter .. ".md")

  -- Create directory if it doesn't exist
  vim.fn.mkdir(vault.path("02-Calendar/Quarterly"), "p")

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
  local filepath = vault.path("02-Calendar/Yearly", year .. ".md")

  -- Create directory if it doesn't exist
  vim.fn.mkdir(vault.path("02-Calendar/Yearly"), "p")

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

vim.api.nvim_create_user_command("Yesterday", OpenYesterday, {
  nargs = "?",
  complete = function(ArgLead, CmdLine, CursorPos)
    return { "vertical", "horizontal", "v", "h" }
  end,
  desc = "Open daily note for yesterday",
})

-- Open last N daily notes (skipping dates without files)
function OpenRecentDailies(opts)
  local count = tonumber(opts.args) or 5
  local dir = vault.path("02-Calendar/Daily")
  local day_seconds = 86400
  local now = os.time()
  local found = 0
  local days_checked = 0
  local max_days = 365 -- safety limit

  while found < count and days_checked < max_days do
    days_checked = days_checked + 1
    local t = now - (days_checked * day_seconds)
    local date = os.date("%Y-%m-%d", t)
    local filepath = vim.fs.joinpath(dir, date .. ".md")

    if vim.fn.filereadable(filepath) == 1 then
      found = found + 1
      vim.cmd("edit " .. filepath)
    end
  end

  if found == 0 then
    vim.notify("No recent daily notes found", vim.log.levels.WARN)
  else
    vim.notify(string.format("Opened %d recent daily note(s)", found), vim.log.levels.INFO)
  end
end

vim.api.nvim_create_user_command("RecentDailies", OpenRecentDailies, {
  nargs = "?",
  desc = "Open last N daily notes (default 5), skipping missing dates",
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
  local filepath = vault.path("TODO.md")

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

-- Join wrapped URL / long string into a single line.
-- Removes newlines and any leading whitespace on continuation lines.
-- Range: visual selection, explicit :Nm,Nn, or the enclosing ``` code block /
-- paragraph when invoked from normal mode without a range.
function JoinURL(opts)
  local bufnr = vim.api.nvim_get_current_buf()
  local start_line, end_line

  if opts.range == 2 then
    start_line = opts.line1 - 1
    end_line = opts.line2
  else
    local cur = vim.api.nvim_win_get_cursor(0)[1]
    local total = vim.api.nvim_buf_line_count(bufnr)

    -- Try to detect surrounding fenced code block ```...```
    local fence_start, fence_end
    for i = cur, 1, -1 do
      local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1] or ""
      if line:match("^%s*```") then
        fence_start = i
        break
      end
    end
    if fence_start then
      for i = cur, total do
        local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1] or ""
        if i > fence_start and line:match("^%s*```") then
          fence_end = i
          break
        end
      end
    end

    if fence_start and fence_end and cur > fence_start and cur < fence_end then
      start_line = fence_start -- exclusive of the opening fence
      end_line = fence_end - 1 -- exclusive of the closing fence
    else
      -- Fallback: current paragraph (run of non-blank lines).
      local s = cur
      while s > 1 do
        local line = vim.api.nvim_buf_get_lines(bufnr, s - 2, s - 1, false)[1] or ""
        if line:match("^%s*$") then break end
        s = s - 1
      end
      local e = cur
      while e < total do
        local line = vim.api.nvim_buf_get_lines(bufnr, e, e + 1, false)[1] or ""
        if line:match("^%s*$") then break end
        e = e + 1
      end
      start_line = s - 1
      end_line = e
    end
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
  if #lines == 0 then
    vim.notify("JoinURL: nothing to join", vim.log.levels.WARN)
    return
  end

  local pieces = {}
  for i, line in ipairs(lines) do
    local piece
    if i == 1 then
      piece = line:gsub("%s+$", "")
    else
      piece = line:gsub("^%s+", ""):gsub("%s+$", "")
    end
    table.insert(pieces, piece)
  end
  local joined = table.concat(pieces, "")

  vim.api.nvim_buf_set_lines(bufnr, start_line, end_line, false, { joined })
  vim.notify(string.format("JoinURL: joined %d lines", #lines), vim.log.levels.INFO)
end

vim.api.nvim_create_user_command("JoinURL", JoinURL, {
  range = true,
  desc = "Join wrapped URL/string into one line (strips leading whitespace on continuations)",
})

vim.keymap.set("n", "<leader>uj", ":JoinURL<CR>", {
  desc = "Join wrapped URL into one line",
  silent = true,
})

vim.keymap.set("v", "<leader>uj", ":JoinURL<CR>", {
  desc = "Join wrapped URL into one line",
  silent = true,
})

-- Strip Claude Code console quote markers (▎) and join wrapped prose
-- into a single line. Unlike JoinURL (which joins without spaces because URLs
-- can't contain whitespace), this joins with single spaces because the input
-- is prose: text copied from a Claude/CLI console where long lines have been
-- soft-wrapped and continuation lines are prefixed with "  ▎ ".
function JoinClaude(opts)
  local bufnr = vim.api.nvim_get_current_buf()
  local start_line, end_line

  if opts.range == 2 then
    start_line = opts.line1 - 1
    end_line = opts.line2
  else
    local cur = vim.api.nvim_win_get_cursor(0)[1]
    local total = vim.api.nvim_buf_line_count(bufnr)

    -- Try to detect surrounding fenced code block ```...```
    local fence_start, fence_end
    for i = cur, 1, -1 do
      local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1] or ""
      if line:match("^%s*```") then
        fence_start = i
        break
      end
    end
    if fence_start then
      for i = cur, total do
        local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1] or ""
        if i > fence_start and line:match("^%s*```") then
          fence_end = i
          break
        end
      end
    end

    if fence_start and fence_end and cur > fence_start and cur < fence_end then
      start_line = fence_start -- exclusive of the opening fence
      end_line = fence_end - 1 -- exclusive of the closing fence
    else
      -- Fallback: current paragraph (run of non-blank lines).
      local s = cur
      while s > 1 do
        local line = vim.api.nvim_buf_get_lines(bufnr, s - 2, s - 1, false)[1] or ""
        if line:match("^%s*$") then break end
        s = s - 1
      end
      local e = cur
      while e < total do
        local line = vim.api.nvim_buf_get_lines(bufnr, e, e + 1, false)[1] or ""
        if line:match("^%s*$") then break end
        e = e + 1
      end
      start_line = s - 1
      end_line = e
    end
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
  if #lines == 0 then
    vim.notify("JoinClaude: nothing to join", vim.log.levels.WARN)
    return
  end

  local pieces = {}
  for _, line in ipairs(lines) do
    -- Strip optional leading "  ▎ " quote marker, then trim ends.
    local cleaned = line:gsub("^%s*▎%s*", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if cleaned ~= "" then
      table.insert(pieces, cleaned)
    end
  end

  if #pieces == 0 then
    vim.notify("JoinClaude: all lines empty after stripping", vim.log.levels.WARN)
    return
  end

  local joined = table.concat(pieces, " "):gsub("%s+", " ")

  vim.api.nvim_buf_set_lines(bufnr, start_line, end_line, false, { joined })
  vim.notify(string.format("JoinClaude: joined %d lines", #lines), vim.log.levels.INFO)
end

vim.api.nvim_create_user_command("JoinClaude", JoinClaude, {
  range = true,
  desc = "Strip Claude console quote markers (▎) and join wrapped prose into one line",
})

vim.keymap.set("n", "<leader>cj", ":JoinClaude<CR>", {
  desc = "Join Claude console quoted text into one line",
  silent = true,
})

vim.keymap.set("v", "<leader>cj", ":JoinClaude<CR>", {
  desc = "Join Claude console quoted text into one line",
  silent = true,
})

-- ============================================================================
-- Nucleobase ASCII diagrams
-- :Adenine :Guanine :Cytosine :Thymine :Uracil insert an annotated ASCII
-- structure of the base at the cursor.
--
--   Pyrimidines (C / T / U)  -> one 6-membered ring, drawn linearly N1..C6.
--   Purines     (A / G)      -> fused 6+5 ring (pyrimidine + imidazole).
--
-- Annotations flag the substituent that DISTINGUISHES each base: amino (-NH2)
-- vs carbonyl (=O) vs methyl (-CH3). Structures (standard 9H/keto tautomers):
--   Cytosine : 2-oxo,            4-amino                  (pyrimidine)
--   Thymine  : 2-oxo, 4-oxo,     5-methyl                 (pyrimidine)
--   Uracil   : 2-oxo, 4-oxo,     5-H  (thymine minus CH3) (pyrimidine)
--   Adenine  : 6-amino                                    (purine)
--   Guanine  : 6-oxo,            2-amino, N1-H            (purine)
-- ============================================================================

local NUCLEOBASES = {
  DNA = {
    "DNA  (double-stranded, antiparallel)",
    "",
    "  5' ─S─P─S─P─S─P─S─P─S─ 3'   ← strand 1 backbone",
    "          │   │   │   │",
    "          A   G   C   T       bases point inward",
    "          ‖   ‖   ‖   ‖       H-bonds hold the strands",
    "          T   C   G   A",
    "          │   │   │   │",
    "  3' ─S─P─S─P─S─P─S─P─S─ 5'   ← strand 2 (complementary)",
    "",
    "  pairing:  A = T (2 H-bonds)   G ≡ C (3 H-bonds)",
    "  sugar:    deoxyribose (2'-H)",
    "  4th base: thymine (T)",
  },
  RNA = {
    "RNA  (single-stranded)",
    "",
    "  5' ─S─P─S─P─S─P─S─P─S─ 3'   ← one strand only",
    "          │   │   │   │",
    "          A   G   C   U       U replaces T",
    "",
    "  sugar:    ribose (2'-OH)    ← the 'O' DNA lacks",
    "  4th base: uracil (U)        ← no methyl (T has CH₃)",
    "  usually single-stranded (folds and self-pairs)",
  },
  PyrimidineBackbone = {
    "N1",
    "|",
    "C2",
    "|",
    "N3",
    "|",
    "C4",
    "|",
    "C5",
    "|",
    "C6",
  },
  Cytosine = {
    "CYTOSINE  (pyrimidine ring; amino-keto tautomer)",
    "",
    "   N1 - H     ← H here (sugar attaches here in DNA/RNA)",
    "   │",
    "   C2 = O     ← carbonyl",
    "   │",
    "   N3",
    "   ║          ← N3 = C4 double bond (why C4 has no H)",
    "   C4 - NH₂   ← amino",
    "   │",
    "   C5 - H",
    "   ║          ← C5 = C6 double bond",
    "   C6 - H",
    "   └──► back to N1 (the ring closes)",
  },
  MethylCytosine = {
    "5-METHYLCYTOSINE  (5mC; amino-keto tautomer)",
    "",
    "   N1 - H",
    "   │",
    "   C2 = O     ← carbonyl",
    "   │",
    "   N3",
    "   ║          ← N3 = C4 double bond",
    "   C4 - NH₂   ← amino (same as cytosine)",
    "   │",
    "   C5 - CH₃   ← methyl! (the epigenetic mark)",
    "   ║          ← C5 = C6 double bond",
    "   C6 - H",
    "   └──► back to N1 (the ring closes)",
  },
  Thymine = {
    "THYMINE  (pyrimidine ring; 2,4-dioxo)",
    "",
    "   N1 - H",
    "   │",
    "   C2 = O     ← carbonyl",
    "   │",
    "   N3 - H     ← N3 also bears H (both ring N's)",
    "   │",
    "   C4 = O     ← carbonyl, not amino",
    "   │",
    "   C5 - CH₃   ← methyl, not amino",
    "   ║          ← C5 = C6 (the only ring C=C)",
    "   C6 - H",
    "   └──► back to N1 (the ring closes)",
  },
  Uracil = {
    "URACIL  (pyrimidine ring; 2,4-dioxo)",
    "",
    "   N1 - H",
    "   │",
    "   C2 = O     ← carbonyl",
    "   │",
    "   N3 - H     ← N3 also bears H",
    "   │",
    "   C4 = O     ← carbonyl, not amino",
    "   │",
    "   C5 - H     ← H here (Thymine carries CH₃)",
    "   ║          ← C5 = C6 double bond",
    "   C6 - H",
    "   └──► back to N1 (the ring closes)",
  },
  Adenine = {
    "ADENINE  (purine, fused double ring)",
    "",
    "               NH₂         ← 6-amino  (adenine's signature)",
    "               |",
    "         N1 == C6",
    "        /          \\",
    "    H - C2          C5 ===== N7",
    "        ||          |          \\",
    "        N3          |           C8",
    "         \\          |          /",
    "          +======= C4 ====== N9",
    "                               |",
    "                               H",
  },
  Guanine = {
    "GUANINE  (purine, fused double ring)",
    "",
    "               O           ← 6-carbonyl, not amino",
    "               ||",
    "        H-N1 == C6",
    "        /          \\",
    "  H₂N - C2          C5 ===== N7",
    "        ||          |          \\",
    "        N3          |           C8",
    "         \\          |          /",
    "          +======= C4 ====== N9",
    "                               |",
    "                               H",
  },
}

-- Insert a block of lines immediately below the cursor line.
local function insert_block_below_cursor(lines)
  local bufnr = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(bufnr, row, row, false, lines)
end

for name, lines in pairs(NUCLEOBASES) do
  vim.api.nvim_create_user_command(name, function()
    insert_block_below_cursor(lines)
  end, {
    desc = "Insert ASCII structure of " .. name .. " at the cursor",
  })
end

-- ============================================================================
-- Periodic-table position diagrams
-- :Nitrogen (and future elements) insert a periods 1-3 excerpt with the
-- element highlighted (▓X▓) so its group/period is read off at a glance.
-- Transition metals (groups 3-12) are omitted to keep the s/p blocks aligned.
-- ============================================================================

local ELEMENTS = {
  Nitrogen = {
    "  Group  1   2                                   13  14  15  16  17  18",
    "       ┌───┐                                                        ┌───┐",
    "  P1   │ H │                                                        │He │",
    "       ├───┼───┐                                ┌───┬───┬───┬───┬───┼───┤",
    "  P2   │Li │Be │                                │ B │ C │▓N▓│ O │ F │Ne │  ← here",
    "       ├───┼───┤                                ├───┼───┼───┼───┼───┼───┤",
    "  P3   │Na │Mg │  (transition metals omitted)   │Al │Si │ P │ S │Cl │Ar │",
    "       └───┴───┘                                └───┴───┴───┴───┴───┴───┘",
  },
}

for name, lines in pairs(ELEMENTS) do
  vim.api.nvim_create_user_command(name, function()
    insert_block_below_cursor(lines)
  end, {
    desc = "Insert periodic-table position of " .. name .. " at the cursor",
  })
end

-- ============================================================================
-- Typewriter mode  (arnamak/stay-centered.nvim)
-- Keeps the current line vertically centered while writing via `zz` recentering
-- (not the scrolloff trick), so the active last line stays centered as you type.
-- The plugin loads disabled (see lua/plugins.lua); this only toggles it.
-- Caveat: the top ~half-screen of a file can't center (no virtual space above
-- line 1 in Neovim); centering engages once you're past a half screen.
-- ============================================================================
local typewriter_on = false

vim.api.nvim_create_user_command("Typewriter", function()
  require("stay-centered").toggle()
  typewriter_on = not typewriter_on
  vim.notify("Typewriter mode " .. (typewriter_on and "ON" or "OFF"), vim.log.levels.INFO)
end, {
  desc = "Toggle typewriter mode (keep the current line vertically centered)",
})

vim.keymap.set("n", "<leader>tw", "<cmd>Typewriter<CR>", {
  desc = "Toggle typewriter mode",
  silent = true,
})

-- ============================================================================
-- ClaudeAsk: send a selection to Claude Code as a background job
-- Logic lives in lua/util/claude.lua; read that file's header for the flow and
-- for why this uses jobstart instead of a terminal split.
-- ============================================================================
local claude = require("util.claude")

vim.api.nvim_create_user_command("ClaudeAsk", claude.ask, {
  range = true,
  nargs = "*",
  desc = "Send the range to `claude -p` as a background job (prompts when given no args)",
})

vim.api.nvim_create_user_command("ClaudeLast", claude.last, {
  desc = "Open the most recently finished Claude reply in a split",
})

vim.api.nvim_create_user_command("ClaudeJobs", claude.list, {
  desc = "List this session's Claude background jobs",
})

vim.keymap.set("v", "<leader>cc", ":ClaudeAsk<CR>", {
  desc = "Send selection to Claude Code (background)",
  silent = true,
})

-- Same command, forcing whole-buffer context. The prompt still comes from
-- vim.ui.input, because an empty prompt after the +full token falls through.
vim.keymap.set("v", "<leader>cf", ":ClaudeAsk +full<CR>", {
  desc = "Send selection to Claude Code with whole-buffer context",
  silent = true,
})

-- Same command with every customisation off: no skills, plugins, hooks,
-- CLAUDE.md or MCP servers. For when the surrounding config is the problem.
vim.api.nvim_create_user_command("ClaudeRaw", function(o)
  claude.ask(o, { raw = true })
end, {
  range = true,
  nargs = "*",
  desc = "Like :ClaudeAsk with skills, plugins, hooks, CLAUDE.md and MCP disabled",
})

vim.api.nvim_create_user_command("ClaudeSave", claude.save, {
  count = true,
  nargs = 1,
  bang = true,
  complete = "file",
  desc = "Write a Claude reply to a path (:[count]ClaudeSave[!] {path})",
})

vim.api.nvim_create_user_command("ClaudeExport", claude.export, {
  count = true,
  desc = "Export a Claude reply to a vault note (:[count]ClaudeExport)",
})

vim.keymap.set("v", "<leader>cr", ":ClaudeRaw<CR>", {
  desc = "Send selection to Claude Code, raw (no skills/plugins/CLAUDE.md)",
  silent = true,
})

vim.keymap.set("n", "<leader>ce", "<cmd>ClaudeExport<CR>", {
  desc = "Export the last Claude reply to a vault note",
  silent = true,
})

-- ============================================================================
-- ClaudeAnalyze: break down the English of a selection
-- Prompt lives in lua/util/english.lua; the job plumbing is the same
-- util.claude one, so :ClaudeLast / :ClaudeSave / :ClaudeExport all apply.
-- ============================================================================
local english = require("util.english")

vim.api.nvim_create_user_command("ClaudeAnalyze", english.analyze, {
  range = true,
  nargs = "*",
  desc = "Break the range's English into verbs, nouns, adjectives, idioms and sentence structures",
})

-- Visual-mode slot only. Normal-mode <leader>ca is the LSP code action
-- (lua/plugins/lsp/init.lua), and this command has no normal-mode meaning.
vim.keymap.set("v", "<leader>ca", ":ClaudeAnalyze<CR>", {
  desc = "Analyze selection's English (verbs, nouns, adjectives, idioms, structures)",
  silent = true,
})
