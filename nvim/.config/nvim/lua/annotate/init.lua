---Fast in-buffer phrase annotation.
---
---Select a word, phrase, or paragraph and press one key to file it under a category.
---Marks persist in JSON keyed by source file and export to a single grouped markdown
---review note. See docs/superpowers/specs/2026-08-26-nvim-annotate-design.md.
---
---Usage:
---  require("annotate").setup({})
local config = require("annotate.config")
local export = require("annotate.export")
local marks = require("annotate.marks")
local picker = require("annotate.picker")
local store = require("annotate.store")

local M = {}

---Default appearances, linked rather than hard-coded so a colorscheme change cannot
---leave a mark invisible. Underline styles are used instead of a background because a
---filled block over prose is loud enough to interfere with reading.
local PALETTE = {
  "DiagnosticUnderlineHint",
  "DiagnosticUnderlineInfo",
  "DiagnosticUnderlineOk",
  "DiagnosticUnderlineWarn",
  "Underlined",
}

---Define a default for every highlight group the configured categories name.
---
---Driven off the config rather than a fixed list, so a user-added category gets a
---sensible appearance without having to define a highlight group by hand. `default =
---true` means an explicit user or colorscheme definition always wins.
local function apply_highlights()
  for i, category in ipairs(config.ordered_categories()) do
    vim.api.nvim_set_hl(0, category.hl, {
      default = true,
      link = PALETTE[((i - 1) % #PALETTE) + 1],
    })
  end
  vim.api.nvim_set_hl(0, "AnnotateVirtual", { default = true, link = "Comment" })
end

---@return integer
local function current_buf()
  return vim.api.nvim_get_current_buf()
end

local function register_commands()
  local commands = {
    AnnotateList = {
      function()
        picker.list({})
      end,
      "Browse every annotation",
    },
    AnnotateOrphans = {
      function()
        picker.list({ orphans_only = true })
      end,
      "Browse annotations that could no longer be located",
    },
    AnnotateBuffer = {
      function()
        picker.list({ source = vim.api.nvim_buf_get_name(current_buf()) })
      end,
      "Browse annotations in the current file",
    },
    AnnotateNote = {
      function()
        marks.note_at_cursor(current_buf())
      end,
      "Add or edit the note on the mark under the cursor",
    },
    AnnotateDelete = {
      function()
        marks.delete_at_cursor(current_buf())
      end,
      "Delete the mark under the cursor",
    },
    AnnotateToggle = {
      function()
        marks.toggle(current_buf())
      end,
      "Show or hide annotation highlights in this buffer",
    },
    AnnotateExport = {
      function()
        local ok, err, stats = export.run()
        if not ok then
          vim.notify(err or "export failed", vim.log.levels.ERROR, { title = "annotate" })
          return
        end
        local message = ("exported %d mark%s from %d file%s to %s")
          :format(stats.marks, stats.marks == 1 and "" or "s", stats.files, stats.files == 1 and "" or "s", stats.path)
        if stats.orphans > 0 then
          message = message .. ("\n%d orphaned mark%s skipped; see :AnnotateOrphans")
            :format(stats.orphans, stats.orphans == 1 and "" or "s")
        end
        vim.notify(message, vim.log.levels.INFO, { title = "annotate" })
      end,
      "Regenerate the markdown review note",
    },
  }

  for name, spec in pairs(commands) do
    vim.api.nvim_create_user_command(name, spec[1], { desc = spec[2] })
  end
end

local function register_keymaps()
  local prefix = config.get().prefix
  if prefix == nil or prefix == "" then
    return
  end

  for _, category in ipairs(config.ordered_categories()) do
    vim.keymap.set("x", prefix .. category.key, function()
      marks.add(category.name)
    end, { desc = "Annotate: mark as " .. category.label:lower() })
  end

  local normal = {
    { "N", ":AnnotateNote<CR>", "Annotate: add or edit note" },
    { "d", ":AnnotateDelete<CR>", "Annotate: delete mark" },
    { "l", ":AnnotateList<CR>", "Annotate: list all marks" },
    { "b", ":AnnotateBuffer<CR>", "Annotate: list marks in this file" },
    { "x", ":AnnotateExport<CR>", "Annotate: export review note" },
    { "t", ":AnnotateToggle<CR>", "Annotate: toggle highlights" },
  }
  for _, spec in ipairs(normal) do
    vim.keymap.set("n", prefix .. spec[1], spec[2], { silent = true, desc = spec[3] })
  end
end

---True for real file buffers only; scratch, terminal, and plugin buffers are skipped.
---@param bufnr integer
---@return boolean
local function is_annotatable(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  if vim.bo[bufnr].buftype ~= "" then
    return false
  end
  return vim.api.nvim_buf_get_name(bufnr) ~= ""
end

local function register_autocmds()
  local group = vim.api.nvim_create_augroup("annotate", { clear = true })

  -- Loading is gated on "does this file have marks", not on filetype. Gating it on
  -- filetype would mean a mark saved in a file outside the list persisted on disk but
  -- never came back, quietly breaking the one promise the module makes. The guard is a
  -- single stat, so running it on every file open costs nothing.
  --
  -- FileType rather than BufReadPost because at BufReadPost the buffer name is set but
  -- the filetype is not, and `is_annotatable` wants a settled buffer.
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "*",
    callback = function(args)
      if is_annotatable(args.buf) and store.exists(vim.api.nvim_buf_get_name(args.buf)) then
        marks.load(args.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(args)
      -- sync is a no-op for buffers with no loaded marks, so no filetype gate is needed.
      marks.sync(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    callback = function(args)
      marks.detach_buffer(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = apply_highlights,
  })
end

---@param opts table|nil See lua/annotate/config.lua for the full option list
---@return boolean ok
function M.setup(opts)
  local _, errors = config.setup(opts)
  if errors then
    vim.notify(
      "annotate: invalid configuration\n  " .. table.concat(errors, "\n  "),
      vim.log.levels.ERROR,
      { title = "annotate" }
    )
    return false
  end

  apply_highlights()
  register_commands()
  register_keymaps()
  register_autocmds()
  return true
end

-- Re-exported so callers do not have to know the module layout.
M.add = marks.add
M.export = export.run
M.list = picker.list

return M
