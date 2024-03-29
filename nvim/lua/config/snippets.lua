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


require("luasnip.loaders.from_lua").load({ paths = "~/.dotfiles/nvim/lua/config/snippets/" })
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
keymap1({"i", "s"}, "<C-j>", function()
    if ls.choice_active() then
        ls.change_choice(1)
    elseif ls.jumpable(1) then
        ls.jump(1)
    end
end)
keymap1({"i", "s"}, "<C-k>", function()
    if ls.choice_active() then
        ls.change_choice(-1)
    elseif ls.jumpable(-1) then
        ls.jump(-1)
    end
end)

ls.config.set_config({
    store_selection_keys = '<c-s>',
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
    ext_prio_increase = 1
    --
})


local date = function() return {os.date('%Y-%m-%d')} end



ls.add_snippets(nil, {
    all = {
        snip("todo", {
            choice(1,
                   {t "TODO(allee): ", t "FIXME(allee): ", t "TODONT(allee): "}),
            insert(0)
        }),
        s({trig = "mamba", namr = "mamba", desc = "mamba"}, fmt([[
           mamba create -n {} python=3.10 python-lsp-server lab_black jupyter jupyterlab numpy pandas matplotlib altair
          ]], {insert(1, "condition")})),
        snip(
            {
                trig = "date",
                namr = "Date",
                dscr = "Date in the form of YYYY-MM-DD"
            }, {func(date, {})}), snip({
            trig = "meta",
            namr = "Metadata",
            dscr = "Yaml metadata format for markdown"
        }, {
            text({"---", "title: "}), insert(1, "note_title"),
            text({"", "author: "}), insert(2, "author"), text({"", "date: "}),
            func(date, {}), text({"", "categories: ["}), insert(3, ""),
            text({"]", "lastmod: "}), func(date, {}), text({"", "tags: ["}),
            insert(4), text({"]", "comments: true", "---", ""}), insert(0)
        }), snip({
            trig = "link",
            namr = "markdown_link",
            dscr = "Create markdown link [txt](url)"
        }, {
            text('['), insert(1), text(']('),
            func(function(_, s_)
                return s_.env.TM_SELECTED_TEXT[1] or {}
            end, {}), text(')'), insert(0)
        })
    },
    python = {
        -- rec_ls is self-referencing. That makes this snippet 'infinite' eg. have as many
        -- \item as necessary by utilizing a choiceNode.
        snip({
            trig = "ipdb",
            namr = "ipython debugger",
            dscr = "ipython debugger"
        }, {t({"import ipdb; ipdb.set_trace()"})}),
        s({trig = "if", namr = "If statement", desc = "If statement"}, fmt([[
          if {}:
              {}
          ]], {insert(1, "condition"), insert(2, "body")})),
        s({trig = "import plotl", namr = "science statck", desc = "science statck"}, fmt([[
        import plotly.express as px
          ]], {})),
        s({trig = "ds", namr = "science statck", desc = "science statck"}, fmt([[
        """{}"""
          ]], {i(1)})),
        s({trig = "\"\"\"", namr = "science statck", desc = "science statck"}, fmt([[
        """{}"""
          ]], {i(1)})),
        snip("dag", {t({"from airflow.models import DAG"})}), snip("defopt", {
            t({
                "def main(argv: List[str] = sys.argv[1:]) -> None:",
                "    \"\"\"Entrypoint", "", "    Args:",
                "        argv: args list", "", "    Returns:", "        None",
                "    \"\"\"", "    defopt.run("
            }), insert(1), t({", argv=argv)"})
        })
    }
})
require("luasnip.loaders.from_snipmate").load({
    path = {"~/.config/nvim/mysnippets"}
}) -- Load snippets from my-snippets folder

vim.keymap.set("n", "<Leader><CR>", "<cmd>LuaSnipEdit<cr>", { silent = true, noremap = true })

--
--
--
-- local ls = require("luasnip")
-- -- some shorthands...
-- local s = ls.snippet
-- local sn = ls.snippet_node
-- local t = ls.text_node
-- local i = ls.insert_node
-- local f = ls.function_node
-- local c = ls.choice_node
-- local d = ls.dynamic_node
-- local r = ls.restore_node
-- local l = require("luasnip.extras").lambda
-- local rep = require("luasnip.extras").rep
-- local p = require("luasnip.extras").partial
-- local m = require("luasnip.extras").match
-- local n = require("luasnip.extras").nonempty
-- local dl = require("luasnip.extras").dynamic_lambda
-- local fmt = require("luasnip.extras.fmt").fmt
-- local fmta = require("luasnip.extras.fmt").fmta
-- local types = require("luasnip.util.types")
-- local conds = require("luasnip.extras.expand_conditions")
--
--
--
-- -- Make sure to not pass an invalid command, as io.popen() may write over nvim-text.
-- local function bash(_, _, command)
-- 	local file = io.popen(command, "r")
-- 	local res = {}
-- 	for line in file:lines() do
-- 		table.insert(res, line)
-- 	end
-- 	return res
-- end
--
-- -- If you're reading this file for the first time, best skip to around line 190
-- -- where the actual snippet-definitions start.
--
-- -- Every unspecified option will be set to the default.
-- ls.config.set_config({
-- 	history = true,
-- 	-- Update more often, :h events for more info.
-- 	updateevents = "TextChanged,TextChangedI",
-- 	ext_opts = {
-- 		[types.choiceNode] = {
-- 			active = {
-- 				virt_text = { { "choiceNode", "Comment" } },
-- 			},
-- 		},
-- 	},
-- 	-- treesitter-hl has 100, use something higher (default is 200).
-- 	ext_base_prio = 300,
-- 	-- minimal increase in priority.
-- 	ext_prio_increase = 1,
--
-- 	enable_autosnippets = true,
--
--     -- This one is cool cause if you have dynamic snippets, it updates as you type!
--     updateevents = "TextChanged,TextChangedI",
--     ext_opts = {
--         [types.choiceNode] = {
--             active = {
--                 virt_text = { { " <- Current Choice", "NonTest" } },
--             },
--         },
--     },
--
--
--
-- })
--
-- -- args is a table, where 1 is the text in Placeholder 1, 2 the text in
-- -- placeholder 2,...
-- local function copy(args)
-- 	return args[1]
-- end
--
-- -- 'recursive' dynamic snippet. Expands to some text followed by itself.
-- local rec_ls
-- rec_ls = function()
-- 	return sn(
-- 		nil,
-- 		c(1, {
-- 			-- Order is important, sn(...) first would cause infinite loop of expansion.
-- 			t(""),
-- 			sn(nil, { t({ "", "\t\\item " }), i(1), d(2, rec_ls, {}) }),
-- 		})
-- 	)
-- end
--
-- -- complicated function for dynamicNode.
-- local function jdocsnip(args, _, old_state)
-- 	-- !!! old_state is used to preserve user-input here. DON'T DO IT THAT WAY!
-- 	-- Using a restoreNode instead is much easier.
-- 	-- View this only as an example on how old_state functions.
-- 	local nodes = {
-- 		t({ "/**", " * " }),
-- 		i(1, "A short Description"),
-- 		t({ "", "" }),
-- 	}
--
-- 	-- These will be merged with the snippet; that way, should the snippet be updated,
-- 	-- some user input eg. text can be referred to in the new snippet.
-- 	local param_nodes = {}
--
-- 	if old_state then
-- 		nodes[2] = i(1, old_state.descr:get_text())
-- 	end
-- 	param_nodes.descr = nodes[2]
--
-- 	-- At least one param.
-- 	if string.find(args[2][1], ", ") then
-- 		vim.list_extend(nodes, { t({ " * ", "" }) })
-- 	end
--
-- 	local insert = 2
-- 	for indx, arg in ipairs(vim.split(args[2][1], ", ", true)) do
-- 		-- Get actual name parameter.
-- 		arg = vim.split(arg, " ", true)[2]
-- 		if arg then
-- 			local inode
-- 			-- if there was some text in this parameter, use it as static_text for this new snippet.
-- 			if old_state and old_state[arg] then
-- 				inode = i(insert, old_state["arg" .. arg]:get_text())
-- 			else
-- 				inode = i(insert)
-- 			end
-- 			vim.list_extend(
-- 				nodes,
-- 				{ t({ " * @param " .. arg .. " " }), inode, t({ "", "" }) }
-- 			)
-- 			param_nodes["arg" .. arg] = inode
--
-- 			insert = insert + 1
-- 		end
-- 	end
--
-- 	if args[1][1] ~= "void" then
-- 		local inode
-- 		if old_state and old_state.ret then
-- 			inode = i(insert, old_state.ret:get_text())
-- 		else
-- 			inode = i(insert)
-- 		end
--
-- 		vim.list_extend(
-- 			nodes,
-- 			{ t({ " * ", " * @return " }), inode, t({ "", "" }) }
-- 		)
-- 		param_nodes.ret = inode
-- 		insert = insert + 1
-- 	end
--
-- 	if vim.tbl_count(args[3]) ~= 1 then
-- 		local exc = string.gsub(args[3][2], " throws ", "")
-- 		local ins
-- 		if old_state and old_state.ex then
-- 			ins = i(insert, old_state.ex:get_text())
-- 		else
-- 			ins = i(insert)
-- 		end
-- 		vim.list_extend(
-- 			nodes,
-- 			{ t({ " * ", " * @throws " .. exc .. " " }), ins, t({ "", "" }) }
-- 		)
-- 		param_nodes.ex = ins
-- 		insert = insert + 1
-- 	end
--
-- 	vim.list_extend(nodes, { t({ " */" }) })
--
-- 	local snip = sn(nil, nodes)
-- 	-- Error on attempting overwrite.
-- 	snip.old_state = param_nodes
-- 	return snip
-- end
--
--
-- -- Returns a snippet_node wrapped around an insert_node whose initial
-- -- text value is set to the current date in the desired format.
-- local date_input = function(args, state, fmt)
-- 	local fmt = fmt or "%Y-%m-%d"
-- 	return sn(nil, i(1, os.date(fmt)))
-- end
--
-- -- in a lua file: search lua-, then c-, then all-snippets.
-- ls.filetype_extend("lua", { "c" })
-- -- in a cpp file: search c-snippets, then all-snippets only (no cpp-snippets!!).
-- ls.filetype_set("cpp", { "c" })
--
-- --[[
-- -- Beside defining your own snippets you can also load snippets from "vscode-like" packages
-- -- that expose snippets in json files, for example <https://github.com/rafamadriz/friendly-snippets>.
-- -- Mind that this will extend  `ls.snippets` so you need to do it after your own snippets or you
-- -- will need to extend the table yourself instead of setting a new one.
-- ]]
--
-- require("luasnip.loaders.from_vscode").load() -- Load only python snippets
-- require("luasnip.loaders.from_snipmate").load({paths = "~/.dotfiles/rstudio/snippets"})
-- -- The directories will have to be structured like eg. <https://github.com/rafamadriz/friendly-snippets> (include
-- -- a similar `package.json`)
-- -- require("luasnip.loaders.from_vscode").load({ paths = { "./my-snippets" } }) -- Load snippets from my-snippets folder
--
-- -- You can also use lazy loading so you only get in memory snippets of languages you use
-- -- require("luasnip.loaders.from_vscode").lazy_load() -- You can pass { paths = "./my-snippets/"} as well
--
-- -- You can also use snippets in snipmate format, for example <https://github.com/honza/vim-snippets>.
-- -- The usage is similar to vscode.
--
-- -- One peculiarity of honza/vim-snippets is that the file with the global snippets is _.snippets, so global snippets
-- -- are stored in `ls.snippets._`.
-- -- We need to tell luasnip that "_" contains global snippets:
-- ls.filetype_extend("all", { "_" })
--
-- require("luasnip.loaders.from_snipmate").load({ include = { "c" } }) -- Load only python snippets
--
-- require("luasnip.loaders.from_snipmate").load({ path = { "~/.config/nvim/mysnippets" } }) -- Load snippets from my-snippets folder
-- require("luasnip.loaders.from_snipmate").load({ path = { "./my-snippets" } }) -- Load snippets from my-snippets folder
-- -- If path is not specified, luasnip will look for the `snippets` directory in rtp (for custom-snippet probably
-- -- `~/.config/nvim/snippets`).
--
-- require("luasnip.loaders.from_snipmate").lazy_load() -- Lazy loading
--
-- ls.snippets = {
-- 	-- When trying to expand a snippet, luasnip first searches the tables for
-- 	-- each filetype specified in 'filetype' followed by 'all'.
-- 	-- If ie. the filetype is 'lua.c'
--
--     all = {
--         s("todo", {
--             c(1, {
--                 t "TODO(allee): ",
--                 t "FIXME(allee): ",
--                 t "TODONT(allee): ",
--             }),
--         }),
-- 		-- Example(choice): Alternative printf-like notation for defining snippets. It uses format
-- 		-- string with placeholders similar to the ones used with Python's .format().
-- 		s(
-- 			"fmt1",
-- 			fmt("To {title} {} {}.", {
-- 				i(2, "Name"),
-- 				i(3, "Surname"),
-- 				title = c(1, { t("Mr."), t("Ms.") }),
-- 			})
-- 		),
-- 		-- When regTrig is set, trig is treated like a pattern, this snippet will expand after any number.
-- 		ls.parser.parse_snippet({ trig = "%d", regTrig = true }, "A Number!!"),
--
-- 		-- Example(regex trigger): It's possible to use capture-groups inside regex-triggers.
-- 		s(
-- 			{ trig = "b(%d)", regTrig = true },
-- 			f(function(_, snip)
-- 				return "Captured Text: " .. snip.captures[1] .. "."
-- 			end, {})
-- 		),
--         -- Example: choice node
--         s("trig", c(1, {
--             t("Ugh boring, a text node"),
--             i(nil, "At least I can edit something now..."),
--             f(function(args) return "Still only counts as text!!" end, {})
--         })),
--         s("ann", c(1, {
--             t("We’re thrilled to announce that"),
--             i(nil, "At least I can edit something now..."),
--             f(function(args) return "Still only counts as text!!" end, {})
--         })),
-- 		-- Exmaple: Use a function to execute any shell command and print its text.
-- 		s("ls", f(bash, {}, "ls")),
-- 		-- there's some built-in conditions in "luasnip.extras.expand_conditions".
-- 		s("cond2", {
-- 			t("will only expand at the beginning of the line"),
-- 		}, {
-- 			condition = conds.line_begin,
-- 		}),
-- 		-- Shorthand for repeating the text in a given node.
-- 		s("repeat", { i(1, "text"), t({ "", "" }), rep(1) }),
-- 		-- Directly insert the ouput from a function evaluated at runtime.
-- 		s("part", p(os.date, "%Y")),
-- 		-- Use a dynamic_node to interpolate the output of a
-- 		-- function (see date_input above) into the initial
-- 		-- value of an insert_node.
-- 		s("novel", {
-- 			t("It was a dark and stormy night on "),
-- 			d(1, date_input, {}, "%A, %B %d of %Y"),
-- 			t(" and the clocks were striking thirteen."),
-- 		}),
--         s("trigger", {
--             t({"", "After expanding, the cursor is here ->"}), i(1),
--             t({"After jumping forward once, cursor is here ->"}), i(2),
--             t({"", "After jumping once more, the snippet is exited there ->"}), i(0),
--         }),
--         s("trigger2", i(1, "This text is SELECTed after expanding the snippet.")),
-- 		-- trigger is fn.
-- 		s("fn", {
-- 			-- Simple static text.
-- 			t("//Parameters: "),
-- 			-- function, first parameter is the function, second the Placeholders
-- 			-- whose text it gets as input.
-- 			f(copy, 2),
-- 			t({ "", "function " }),
-- 			-- Placeholder/Insert.
-- 			i(1),
-- 			t("("),
-- 			-- Placeholder with initial text.
-- 			i(2, "int foo"),
-- 			-- Linebreak
-- 			t({ ") {", "\t" }),
-- 			-- Last Placeholder, exit Point of the snippet. EVERY 'outer' SNIPPET NEEDS Placeholder 0.
-- 			i(0),
-- 			t({ "", "}" }),
-- 		}),
-- 		s("class", {
-- 			-- Choice: Switch between two different Nodes, first parameter is its position, second a list of nodes.
-- 			c(1, {
-- 				t("public "),
-- 				t("private "),
-- 			}),
-- 			t("class "),
-- 			i(2),
-- 			t(" "),
-- 			c(3, {
-- 				t("{"),
-- 				-- sn: Nested Snippet. Instead of a trigger, it has a position, just like insert-nodes. !!! These don't expect a 0-node!!!!
-- 				-- Inside Choices, Nodes don't need a position as the choice node is the one being jumped to.
-- 				sn(nil, {
-- 					t("extends "),
-- 					-- restoreNode: stores and restores nodes.
-- 					-- pass position, store-key and nodes.
-- 					r(1, "other_class", i(1)),
-- 					t(" {"),
-- 				}),
-- 				sn(nil, {
-- 					t("implements "),
-- 					-- no need to define the nodes for a given key a second time.
-- 					r(1, "other_class"),
-- 					t(" {"),
-- 				}),
-- 			}),
-- 			t({ "", "\t" }),
-- 			i(0),
-- 			t({ "", "}" }),
-- 		}),
-- 		-- To escape delimiters use double them, e.g. `{}` -> `{{}}`.
-- 		-- Multi-line format strings by default have empty first/last line removed.
-- 		-- Indent common to all lines is also removed. Use the third `opts` argument
-- 		-- to control this behaviour.
-- 		s(
-- 			"fmt2",
-- 			fmt(
-- 				[[
-- 			foo({1}, {3}) {{
-- 				return {2} * {4}
-- 			}}
-- 			]],
-- 				{
-- 					i(1, "x"),
-- 					rep(1),
-- 					i(2, "y"),
-- 					rep(2),
-- 				}
-- 			)
-- 		),
-- 		-- Empty placeholders are numbered automatically starting from 1 or the last
-- 		-- value of a numbered placeholder. Named placeholders do not affect numbering.
-- 		s(
-- 			"fmt3",
-- 			fmt("{} {a} {} {1} {}", {
-- 				t("1"),
-- 				t("2"),
-- 				a = t("A"),
-- 			})
-- 		),
-- 		-- The delimiters can be changed from the default `{}` to something else.
-- 		s(
-- 			"fmt4",
-- 			fmt("foo() { return []; }", i(1, "x"), { delimiters = "[]" })
-- 		),
-- 		-- `fmta` is a convenient wrapper that uses `<>` instead of `{}`.
-- 		s("fmt5", fmta("foo() { return <>; }", i(1, "x"))),
-- 		-- By default all args must be used. Use strict=false to disable the check
-- 		s(
-- 			"fmt6",
-- 			fmt("use {} only", { t("this"), t("not this") }, { strict = false })
-- 		),
-- 		-- Parsing snippets: First parameter: Snippet-Trigger, Second: Snippet body.
-- 		-- Placeholders are parsed into choices with 1. the placeholder text(as a snippet) and 2. an empty string.
-- 		-- This means they are not SELECTed like in other editors/Snippet engines.
-- 		ls.parser.parse_snippet(
-- 			"lspsyn",
-- 			"Wow! This ${1:Stuff} really ${2:works. ${3:Well, a bit.}}"
-- 		),
--
-- 		-- When wordTrig is set to false, snippets may also expand inside other words.
-- 		ls.parser.parse_snippet(
-- 			{ trig = "te", wordTrig = false },
-- 			"${1:cond} ? ${2:true} : ${3:false}"
-- 		),
--
-- 		-- Using the condition, it's possible to allow expansion only in specific cases.
-- 		s("cond", {
-- 			t("will only expand in c-style comments"),
-- 		}, {
-- 			condition = function(line_to_cursor, matched_trigger, captures)
-- 				-- optional whitespace followed by //
-- 				return line_to_cursor:match("%s*//")
-- 			end,
-- 		}),
-- 		-- The last entry of args passed to the user-function is the surrounding snippet.
-- 		s(
-- 			{ trig = "a%d", regTrig = true },
-- 			f(function(_, snip)
-- 				return "Triggered with " .. snip.trigger .. "."
-- 			end, {})
-- 		),
-- 		s({ trig = "c(%d+)", regTrig = true }, {
-- 			t("will only expand for even numbers"),
-- 		}, {
-- 			condition = function(line_to_cursor, matched_trigger, captures)
-- 				return tonumber(captures[1]) % 2 == 0
-- 			end,
-- 		}),
-- 		-- Short version for applying String transformations using function nodes.
-- 		s("transform", {
-- 			i(1, "initial text"),
-- 			t({ "", "" }),
-- 			-- lambda nodes accept an l._1,2,3,4,5, which in turn accept any string transformations.
-- 			-- This list will be applied in order to the first node given in the second argument.
-- 			l(l._1:match("[^i]*$"):gsub("i", "o"):gsub(" ", "_"):upper(), 1),
-- 		}),
-- 		s("transform2", {
-- 			i(1, "initial text"),
-- 			t("::"),
-- 			i(2, "replacement for e"),
-- 			t({ "", "" }),
-- 			-- Lambdas can also apply transforms USING the text of other nodes:
-- 			l(l._1:gsub("e", l._2), { 1, 2 }),
-- 		}),
-- 		s({ trig = "trafo(%d+)", regTrig = true }, {
-- 			-- env-variables and captures can also be used:
-- 			l(l.CAPTURE1:gsub("1", l.TM_FILENAME), {}),
-- 		}),
-- 		-- Set store_selection_keys = "<Tab>" (for example) in your
-- 		-- luasnip.config.setup() call to access TM_SELECTED_TEXT. In
-- 		-- this case, select a URL, hit Tab, then expand this snippet.
-- 		s("link_url", {
-- 			t('<a href="'),
-- 			f(function(_, snip)
-- 				return snip.env.TM_SELECTED_TEXT[1] or {}
-- 			end, {}),
-- 			t('">'),
-- 			i(1),
-- 			t("</a>"),
-- 			i(0),
-- 		}),
-- 		-- use matchNodes to insert text based on a pattern/function/lambda-evaluation.
-- 		s("mat", {
-- 			i(1, { "sample_text" }),
-- 			t(": "),
-- 			m(1, "%d", "contains a number", "no number :("),
-- 		}),
-- 		-- The inserted text defaults to the first capture group/the entire
-- 		-- match if there are none
-- 		s("mat2", {
-- 			i(1, { "sample_text" }),
-- 			t(": "),
-- 			m(1, "[abc][abc][abc]"),
-- 		}),
-- 		-- It is even possible to apply gsubs' or other transformations
-- 		-- before matching.
-- 		s("mat3", {
-- 			i(1, { "sample_text" }),
-- 			t(": "),
-- 			m(
-- 				1,
-- 				l._1:gsub("[123]", ""):match("%d"),
-- 				"contains a number that isn't 1, 2 or 3!"
-- 			),
-- 		}),
-- 		-- `match` also accepts a function, which in turn accepts a string
-- 		-- (text in node, \n-concatted) and returns any non-nil value to match.
-- 		-- If that value is a string, it is used for the default-inserted text.
-- 		s("mat4", {
-- 			i(1, { "sample_text" }),
-- 			t(": "),
-- 			m(1, function(text)
-- 				return (#text % 2 == 0 and text) or nil
-- 			end),
-- 		}),
-- 		-- The nonempty-node inserts text depending on whether the arg-node is
-- 		-- empty.
-- 		s("nempty", {
-- 			i(1, "sample_text"),
-- 			n(1, "i(1) is not empty!"),
-- 		}),
-- 		-- dynamic lambdas work exactly like regular lambdas, except that they
-- 		-- don't return a textNode, but a dynamicNode containing one insertNode.
-- 		-- This makes it easier to dynamically set preset-text for insertNodes.
-- 		s("dl1", {
-- 			i(1, "sample_text"),
-- 			t({ ":", "" }),
-- 			dl(2, l._1, 1),
-- 		}),
-- 		-- Obviously, it's also possible to apply transformations, just like lambdas.
-- 		s("dl2", {
-- 			i(1, "sample_text"),
-- 			i(2, "sample_text_2"),
-- 			t({ "", "" }),
-- 			dl(3, l._1:gsub("\n", " linebreak ") .. l._2, { 1, 2 }),
-- 		}),
-- 	},
-- 	java = {
-- 		-- Very long example for a java class.
-- 		s("fn", {
-- 			d(6, jdocsnip, { 2, 4, 5 }),
-- 			t({ "", "" }),
-- 			c(1, {
-- 				t("public "),
-- 				t("private "),
-- 			}),
-- 			c(2, {
-- 				t("void"),
-- 				t("String"),
-- 				t("char"),
-- 				t("int"),
-- 				t("double"),
-- 				t("boolean"),
-- 				i(nil, ""),
-- 			}),
-- 			t(" "),
-- 			i(3, "myFunc"),
-- 			t("("),
-- 			i(4),
-- 			t(")"),
-- 			c(5, {
-- 				t(""),
-- 				sn(nil, {
-- 					t({ "", " throws " }),
-- 					i(1),
-- 				}),
-- 			}),
-- 			t({ " {", "\t" }),
-- 			i(0),
-- 			t({ "", "}" }),
-- 		}),
-- 	},
--     sh = {
-- 		s("#", {
-- 			t({ "#!/usr/bin/env bash"}),
-- 		}),
--     },
-- 	tex = {
-- 		-- rec_ls is self-referencing. That makes this snippet 'infinite' eg. have as many
-- 		-- \item as necessary by utilizing a choiceNode.
-- 		s("ls", {
-- 			t({ "\\begin{itemize}", "\t\\item " }),
-- 			i(1),
-- 			d(2, rec_ls, {}),
-- 			t({ "", "\\end{itemize}" }),
-- 		}),
-- 	},
--     python = {
--             -- rec_ls is self-referencing. That makes this snippet 'infinite' eg. have as many
--             -- \item as necessary by utilizing a choiceNode.
--             s("ipdb", {
--                 t({ "import ipdb; ipdb.set_trace()" }),
--             }),
--             s("dag", {
--                 t({"from airflow.models import DAG"})
--             }),
--         },
-- }
--
-- -- autotriggered snippets have to be defined in a separate table, luasnip.autosnippets.
-- ls.autosnippets = {
-- 	all = {
-- 		s("autotrigger", {
-- 			t("autosnippet"),
-- 		}),
-- 	},
--     python = {
--             s(";idag", {
--                 t({"from airflow.models import DAG"})
--             }),
--             s(";inp", {
--                 t({"import numpy as np"})
--             }),
--             s(";ipa", {
--                 t({"import pandas as pd"})
--             }),
--             s("import nu", {
--                 t({"import numpy as np"})
--             }),
--             s("import pan", {
--                 t({"import pandas as pd"})
--             }),
--             s(";ipdb", {
--                 t({"import ipdb; ipdb.set_trace()"})
--             }),
--             s(";idum", {
--                 t({"from airflow.operators.dummy import DummyOperator"})
--             }),
--             s(";wdag",
--             fmt([[
--                 with DAG(
--                     "{}",
--                     start_date=pendulum.datetime(2021, 1, 1, tz="UTC"),
--                     schedule_interval="{}",
--                     catchup=False,
--                     default_args={{
--                         "owner": "albert",
--                         "depends_on_past": False,
--                         "start_date": datetime(2021, 5, 18),
--                         "email_on_failure": False,
--                         "email_on_retry": False,
--                         "retries": 0,
--                         "retry_delay": timedelta(minutes=5),
--                     }},
--                 ) as dag:
--                     op = DummyOperator(task_id="task")
--     ]], {
--         i(1, "wow"),
--         c(2, {
--             t "@daily",
--             t "@weekly",
--             t "@monthly",
--         }),
--     })
--
--             ),
--         },
-- }
--
--
-- local current_nsid = vim.api.nvim_create_namespace("LuaSnipChoiceListSelections")
-- local current_win = nil
--
-- local function window_for_choiceNode(choiceNode)
--     local buf = vim.api.nvim_create_buf(false, true)
--     local buf_text = {}
--     local row_selection = 0
--     local row_offset = 0
--     local text
--     for _, node in ipairs(choiceNode.choices) do
--         text = node:get_docstring()
--         -- find one that is currently showing
--         if node == choiceNode.active_choice then
--             -- current line is starter from buffer list which is length usually
--             row_selection = #buf_text
--             -- finding how many lines total within a choice selection
--             row_offset = #text
--         end
--         vim.list_extend(buf_text, text)
--     end
--
--     vim.api.nvim_buf_set_text(buf, 0,0,0,0, buf_text)
--     local w, h = vim.lsp.util._make_floating_popup_size(buf_text)
--
--     -- adding highlight so we can see which one is been selected.
--     local extmark = vim.api.nvim_buf_set_extmark(buf,current_nsid,row_selection ,0,
--         {hl_group = 'incsearch',end_line = row_selection + row_offset})
--
--     -- shows window at a beginning of choiceNode.
--     local win = vim.api.nvim_open_win(buf, false, {
--         relative = "win", width = w, height = h, bufpos = choiceNode.mark:pos_begin_end(), style = "minimal", border = 'rounded'})
--
--     -- return with 3 main important so we can use them again
--     return {win_id = win,extmark = extmark,buf = buf}
-- end
--
-- function choice_popup(choiceNode)
-- 	-- build stack for nested choiceNodes.
-- 	if current_win then
-- 		vim.api.nvim_win_close(current_win.win_id, true)
--                 vim.api.nvim_buf_del_extmark(current_win.buf,current_nsid,current_win.extmark)
-- 	end
--         local create_win = window_for_choiceNode(choiceNode)
-- 	current_win = {
-- 		win_id = create_win.win_id,
-- 		prev = current_win,
-- 		node = choiceNode,
--                 extmark = create_win.extmark,
--                 buf = create_win.buf
-- 	}
-- end
--
-- function update_choice_popup(choiceNode)
--     vim.api.nvim_win_close(current_win.win_id, true)
--     vim.api.nvim_buf_del_extmark(current_win.buf,current_nsid,current_win.extmark)
--     local create_win = window_for_choiceNode(choiceNode)
--     current_win.win_id = create_win.win_id
--     current_win.extmark = create_win.extmark
--     current_win.buf = create_win.buf
-- end
--
-- function choice_popup_close()
-- 	vim.api.nvim_win_close(current_win.win_id, true)
--         vim.api.nvim_buf_del_extmark(current_win.buf,current_nsid,current_win.extmark)
--         -- now we are checking if we still have previous choice we were in after exit nested choice
-- 	current_win = current_win.prev
-- 	if current_win then
-- 		-- reopen window further down in the stack.
--                 local create_win = window_for_choiceNode(current_win.node)
--                 current_win.win_id = create_win.win_id
--                 current_win.extmark = create_win.extmark
--                 current_win.buf = create_win.buf
-- 	end
-- end
--
-- vim.cmd([[
-- augroup choice_popup
-- au!
-- au User LuasnipChoiceNodeEnter lua choice_popup(require("luasnip").session.event_node)
-- au User LuasnipChoiceNodeLeave lua choice_popup_close()
-- au User LuasnipChangeChoice lua update_choice_popup(require("luasnip").session.event_node)
-- augroup END
-- ]])
--
