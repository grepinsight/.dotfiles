local ls = require("luasnip")
-- some shorthands...
local snip = ls.snippet
local node = ls.snippet_node
local text = ls.text_node
local insert = ls.insert_node
local func = ls.function_node
local choice = ls.choice_node
local dynamicn = ls.dynamic_node
local types = require("luasnip.util.types")
local fmt = require("luasnip.extras.fmt").fmt

local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local c = ls.choice_node
local d = ls.dynamic_node
local r = ls.restore_node
local l = require("luasnip.extras").lambda

require("luasnip.loaders.from_lua").load({ paths = "lua/config/snippets/" })
vim.cmd([[command! LuaSnipEdit :lua require("luasnip.loaders.from_lua").edit_snippet_files()]])

-- Make sure to not pass an invalid command, as io.popen() may write over nvim-text.
local function bash(_, _, command)
  local file = io.popen(command, "r")
  local res = {}
  for line in file:lines() do
    table.insert(res, line)
  end
  return res
end

local keymap1 = vim.keymap.set
keymap1({ "i", "s" }, "<C-j>", function()
  if ls.choice_active() then
    ls.change_choice(1)
  elseif ls.jumpable(1) then
    ls.jump(1)
  end
end)
keymap1({ "i", "s" }, "<C-k>", function()
  if ls.choice_active() then
    ls.change_choice(-1)
  elseif ls.jumpable(-1) then
    ls.jump(-1)
  end
end)

ls.config.set_config({
  store_selection_keys = "<c-s>",
  history = true,
  -- 	-- Update more often, :h events for more info.
  -- 	updateevents = "TextChanged,TextChangedI",
  -- This one is cool cause if you have dynamic snippets, it updates as you type!
  updateevents = "TextChanged,TextChangedI",
  enable_autosnippets = true,

  ext_opts = {
    [types.choiceNode] = {
      active = {
        virt_text = { { "●", "GruvboxOrange" } },
      },
    },
    -- [types.insertNode] = {
    -- 	active = {
    -- 		virt_text = { { "●", "GruvboxBlue" } },
    -- 	},
    -- },
  },
  -- 	-- treesitter-hl has 100, use something higher (default is 200).
  ext_base_prio = 300,
  -- 	-- minimal increase in priority.
  ext_prio_increase = 1,
  --
})

local date = function()
  return { os.date("%Y-%m-%d") }
end

ls.add_snippets(nil, {
  all = {
    snip("todo", {
      choice(1, { t("TODO(allee): "), t("FIXME(allee): "), t("TODONT(allee): ") }),
      insert(0),
    }),
    s(
      { trig = "mamba", namr = "mamba", desc = "mamba" },
      fmt(
        [[
           mamba create -n {} python=3.10 python-lsp-server lab_black jupyter jupyterlab numpy pandas matplotlib altair
          ]],
        { insert(1, "condition") }
      )
    ),
    snip({
      trig = "date",
      namr = "Date",
      dscr = "Date in the form of YYYY-MM-DD",
    }, { func(date, {}) }),
    snip({
      trig = "meta",
      namr = "Metadata",
      dscr = "Yaml metadata format for markdown",
    }, {
      text({ "---", "title: " }),
      insert(1, "note_title"),
      text({ "", "author: " }),
      insert(2, "author"),
      text({ "", "date: " }),
      func(date, {}),
      text({ "", "categories: [" }),
      insert(3, ""),
      text({ "]", "lastmod: " }),
      func(date, {}),
      text({ "", "tags: [" }),
      insert(4),
      text({ "]", "comments: true", "---", "" }),
      insert(0),
    }),
    snip({
      trig = "link",
      namr = "markdown_link",
      dscr = "Create markdown link [txt](url)",
    }, {
      text("["),
      insert(1),
      text("]("),
      func(function(_, s_)
        return s_.env.TM_SELECTED_TEXT[1] or {}
      end, {}),
      text(")"),
      insert(0),
    }),
  },
  python = {
    -- rec_ls is self-referencing. That makes this snippet 'infinite' eg. have as many
    -- \item as necessary by utilizing a choiceNode.
    snip({
      trig = "ipdb",
      namr = "ipython debugger",
      dscr = "ipython debugger",
    }, { t({ "import ipdb; ipdb.set_trace()" }) }),
    s(
      { trig = "if", namr = "If statement", desc = "If statement" },
      fmt(
        [[
          if {}:
              {}
          ]],
        { insert(1, "condition"), insert(2, "body") }
      )
    ),
    s(
      { trig = "import plotl", namr = "science statck", desc = "science statck" },
      fmt(
        [[
        import plotly.express as px
          ]],
        {}
      )
    ),
    s(
      { trig = "ds", namr = "science statck", desc = "science statck" },
      fmt(
        [[
        """{}"""
          ]],
        { i(1) }
      )
    ),
    s(
      { trig = '"""', namr = "science statck", desc = "science statck" },
      fmt(
        [[
        """{}"""
          ]],
        { i(1) }
      )
    ),
    snip("dag", { t({ "from airflow.models import DAG" }) }),
    snip("defopt", {
      t({
        "def main(argv: List[str] = sys.argv[1:]) -> None:",
        '    """Entrypoint',
        "",
        "    Args:",
        "        argv: args list",
        "",
        "    Returns:",
        "        None",
        '    """',
        "    defopt.run(",
      }),
      insert(1),
      t({ ", argv=argv)" }),
    }),
  },
})
require("luasnip.loaders.from_snipmate").load({
  path = { "~/.config/nvim/mysnippets" },
}) -- Load snippets from my-snippets folder

vim.keymap.set("n", "<Leader><CR>", "<cmd>LuaSnipEdit<cr>", { silent = true, noremap = true })
