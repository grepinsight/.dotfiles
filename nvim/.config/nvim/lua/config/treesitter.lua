-- nvim-treesitter `main` branch. The old `nvim-treesitter.configs` module and
-- its `highlight` / `textobjects` / `incremental_selection` modules are gone:
-- Neovim owns highlighting now, and everything is enabled per filetype.

local ts = require("nvim-treesitter")

ts.setup({})

-- Parsers to keep installed. `org` is deliberately absent -- nvim-orgmode ships
-- its own parser and we keep org on the vim regex engine (see below). `rmd` has
-- no parser of its own and is handled by the markdown ones.
local parsers = {
  "bash",
  "cpp",
  "go",
  "html",
  "javascript",
  "json",
  "lua",
  "markdown",
  "markdown_inline",
  "python",
  "query",
  "r",
  "rust",
  "svelte",
  "tsx",
  "typescript",
  "yaml",
}

ts.install(parsers)

-- Filetypes that get the treesitter highlighter. `org` and `html` stay on the
-- vim regex engine, as they did under the old `highlight.disable`.
local highlight_filetypes = {
  "bash",
  "cpp",
  "go",
  "javascript",
  "json",
  "lua",
  "markdown",
  "python",
  "query",
  "r",
  "rmd",
  "rust",
  "svelte",
  "tsx",
  "typescript",
  "yaml",
}

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("config_treesitter_highlight", { clear = true }),
  pattern = highlight_filetypes,
  callback = function(args)
    local ok, err = pcall(vim.treesitter.start, args.buf)
    if not ok then
      vim.notify_once(
        ("treesitter: no highlighting for %q (%s). Run :TSInstall %s"):format(args.match, err, args.match),
        vim.log.levels.WARN
      )
    end
  end,
})

------------------------------------------------------------------------------
-- Incremental selection
--
-- Dropped in the `main` rewrite with no upstream replacement, so this is a
-- minimal stand-in for the keymaps we already had. The old `scope_incremental`
-- binding is gone -- it was typo'd as "CR>" and never actually mapped.
------------------------------------------------------------------------------

-- Stack of selected nodes, per buffer, so <TAB> can walk back down.
local selections = {}

local function same_range(a, b)
  local a1, a2, a3, a4 = a:range()
  local b1, b2, b3, b4 = b:range()
  return a1 == b1 and a2 == b2 and a3 == b3 and a4 == b4
end

local ESC = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)

local function select_node(node)
  local srow, scol, erow, ecol = node:range()
  -- Treesitter ranges are 0-indexed and end-exclusive. A node ending at column
  -- 0 really ends at the end of the previous line.
  if ecol == 0 and erow > srow then
    erow = erow - 1
    ecol = #vim.api.nvim_buf_get_lines(0, erow, erow + 1, true)[1]
  end
  -- Drive the selection with a real `v` rather than setting the '< and '> marks:
  -- those marks are ignored until the buffer has actually been in visual mode.
  -- `v` toggles, so leave any active visual mode first.
  if vim.fn.mode():find("^[vV\22]") then
    vim.cmd("normal! " .. ESC)
  end
  vim.api.nvim_win_set_cursor(0, { srow + 1, scol })
  vim.cmd("normal! v")
  vim.api.nvim_win_set_cursor(0, { erow + 1, math.max(ecol - 1, 0) })
end

local function init_selection()
  local ok, parser = pcall(vim.treesitter.get_parser)
  if not ok or not parser then
    return
  end
  -- The highlighter only parses what it is about to redraw, so the tree can
  -- still be empty here. Without this, get_node() returns nil and <CR> no-ops.
  parser:parse(true)

  local node = vim.treesitter.get_node()
  if not node then
    return
  end
  selections[vim.api.nvim_get_current_buf()] = { node }
  select_node(node)
end

local function node_incremental()
  local buf = vim.api.nvim_get_current_buf()
  local stack = selections[buf]
  if not stack or #stack == 0 then
    return init_selection()
  end

  local node = stack[#stack]
  -- Skip parents that cover exactly the same text as the child, otherwise the
  -- selection appears not to grow.
  local parent = node:parent()
  while parent and same_range(parent, node) do
    parent = parent:parent()
  end
  if not parent then
    return select_node(node)
  end

  table.insert(stack, parent)
  select_node(parent)
end

local function node_decremental()
  local buf = vim.api.nvim_get_current_buf()
  local stack = selections[buf]
  if not stack or #stack < 2 then
    return
  end
  table.remove(stack)
  select_node(stack[#stack])
end

vim.keymap.set("n", "<CR>", init_selection, { desc = "Treesitter: start selection" })
vim.keymap.set("x", "<S-TAB>", node_incremental, { desc = "Treesitter: grow selection" })
vim.keymap.set("x", "<TAB>", node_decremental, { desc = "Treesitter: shrink selection" })

------------------------------------------------------------------------------
-- Textobjects
------------------------------------------------------------------------------

require("nvim-treesitter-textobjects").setup({
  select = {
    lookahead = true,
    selection_modes = {
      ["@parameter.outer"] = "v", -- charwise
      ["@function.outer"] = "V", -- linewise
      ["@class.outer"] = "<c-v>", -- blockwise
    },
    include_surrounding_whitespace = true,
  },
  move = {
    set_jumps = true,
  },
})

-- { lhs, query, query_group, desc }
local select_maps = {
  { "aa", "@parameter.outer", "textobjects", "Select outer part of a parameter" },
  { "ia", "@parameter.inner", "textobjects", "Select inner part of a parameter" },
  { "af", "@function.outer", "textobjects", "Select outer part of a function" },
  { "if", "@function.inner", "textobjects", "Select inner part of a function" },
  { "ai", "@conditional.outer", "textobjects", "Select outer part of a conditional" },
  { "ii", "@conditional.inner", "textobjects", "Select inner part of a conditional" },
  { "al", "@loop.outer", "textobjects", "Select outer part of a loop" },
  { "il", "@loop.inner", "textobjects", "Select inner part of a loop" },
  { "at", "@comment.outer", "textobjects", "Select outer part of a comment" },
  { "it", "@comment.inner", "textobjects", "Select inner part of a comment" },
  { "ac", "@class.outer", "textobjects", "Select outer part of a class region" },
  { "ic", "@class.inner", "textobjects", "Select inner part of a class region" },
  { "as", "@scope", "locals", "Select language scope" },
}

for _, map in ipairs(select_maps) do
  local lhs, query, group, desc = unpack(map)
  vim.keymap.set({ "x", "o" }, lhs, function()
    require("nvim-treesitter-textobjects.select").select_textobject(query, group)
  end, { desc = desc })
end

-- move function name -> { lhs = { query, query_group } }
local move_maps = {
  goto_next_start = {
    ["]m"] = { "@function.outer", "textobjects" },
    ["]s"] = { "@statement.outer", "textobjects" },
    ["]]"] = { "@class.outer", "textobjects" },
    ["]z"] = { "@fold", "folds" },
  },
  goto_next_end = {
    ["]M"] = { "@function.outer", "textobjects" },
    ["]S"] = { "@statement.outer", "textobjects" },
    ["]["] = { "@class.outer", "textobjects" },
    ["]Z"] = { "@fold", "folds" },
  },
  goto_previous_start = {
    ["[m"] = { "@function.outer", "textobjects" },
    ["[s"] = { "@statement.outer", "textobjects" },
    ["[["] = { "@class.outer", "textobjects" },
    ["[z"] = { "@fold", "folds" },
  },
  goto_previous_end = {
    ["[M"] = { "@function.outer", "textobjects" },
    ["[S"] = { "@statement.outer", "textobjects" },
    ["[]"] = { "@class.outer", "textobjects" },
    ["[Z"] = { "@fold", "folds" },
  },
  goto_next = {
    ["]i"] = { "@conditional.inner", "textobjects" },
  },
  goto_previous = {
    ["[i"] = { "@conditional.inner", "textobjects" },
  },
}

for move_fn, maps in pairs(move_maps) do
  for lhs, spec in pairs(maps) do
    local query, group = spec[1], spec[2]
    vim.keymap.set({ "n", "x", "o" }, lhs, function()
      require("nvim-treesitter-textobjects.move")[move_fn](query, group)
    end, { desc = ("Treesitter: %s %s"):format(move_fn:gsub("_", " "), query) })
  end
end

local swap_maps = {
  swap_next = { [",,n"] = "@parameter.inner" },
  swap_previous = { [",,N"] = "@parameter.inner", [",,p"] = "@parameter.inner" },
}

for swap_fn, maps in pairs(swap_maps) do
  for lhs, query in pairs(maps) do
    vim.keymap.set("n", lhs, function()
      require("nvim-treesitter-textobjects.swap")[swap_fn](query)
    end, { desc = ("Treesitter: %s %s"):format(swap_fn:gsub("_", " "), query) })
  end
end
