-- require'sniprun'.setup({})
require'nvim-treesitter.configs'.setup {
    highlight = {
        enable = true,
        disable = {'org', 'html'}, -- Remove this to use TS highlighter for some of the highlights (Experimental)
        additional_vim_regex_highlighting = {'org'}, -- Required since TS highlighter doesn't support all syntax features (conceal)
    },
    playground = {
        enable = true,
        disable = {},
        updatetime = 25, -- Debounced time for highlighting nodes in the playground from source code
        persist_queries = false, -- Whether the query persists across vim sessions
        keybindings = {
            toggle_query_editor = 'o',
            toggle_hl_groups = 'i',
            toggle_injected_languages = 't',
            toggle_anonymous_nodes = 'a',
            toggle_language_display = 'I',
            focus_language = 'f',
            unfocus_language = 'F',
            update = 'R',
            goto_node = '<cr>',
            show_help = '?',
        },
    },
    textobjects = {
        select = {
            enable = true,

            -- Automatically jump forward to textobj, similar to targets.vim
            lookahead = true,

            keymaps = {
                -- You can use the capture groups defined in textobjects.scm
                ["aa"] = "@parameter.outer",
                ["ia"] = "@parameter.inner",

                ["af"] = "@function.outer",
                ["if"] = "@function.inner",

                ["ai"] = "@conditional.outer",
                ["ii"] = "@conditional.inner",

                ["al"] = "@loop.outer",
                ["il"] = "@loop.inner",

                ["at"] = "@comment.outer",
                ["it"] = "@comment.inner",

                ["ac"] = "@class.outer",
                -- You can optionally set descriptions to the mappings (used in the desc parameter of
                -- nvim_buf_set_keymap) which plugins like which-key display
                ["ic"] = { query = "@class.inner", desc = "Select inner part of a class region" },
                -- You can also use captures from other query groups like `locals.scm`
                ["as"] = { query = "@scope", query_group = "locals", desc = "Select language scope" },
            },
            -- You can choose the select mode (default is charwise 'v')
            --
            -- Can also be a function which gets passed a table with the keys
            -- * query_string: eg '@function.inner'
            -- * method: eg 'v' or 'o'
            -- and should return the mode ('v', 'V', or '<c-v>') or a table
            -- mapping query_strings to modes.
            selection_modes = {
                ['@parameter.outer'] = 'v', -- charwise
                ['@function.outer'] = 'V', -- linewise
                ['@class.outer'] = '<c-v>', -- blockwise
            },
            -- If you set this to `true` (default is `false`) then any textobject is
            -- extended to include preceding or succeeding whitespace. Succeeding
            -- whitespace has priority in order to act similarly to eg the built-in
            -- `ap`.
            --
            -- Can also be a function which gets passed a table with the keys
            -- * query_string: eg '@function.inner'
            -- * selection_mode: eg 'v'
            -- and should return true of false
            include_surrounding_whitespace = true,
        },
        move = {
            enable = true,
            set_jumps = true, -- whether to set jumps in the jumplist
            goto_next_start = {
                ["]m"] = "@function.outer",
                ["]]"] = "@class.outer",
            },
            goto_next_end = {
                ["]M"] = "@function.outer",
                ["]["] = "@class.outer",
            },
            goto_previous_start = {
                ["[m"] = "@function.outer",
                ["[["] = "@class.outer",
            },
            goto_previous_end = {
                ["[M"] = "@function.outer",
                ["[]"] = "@class.outer",
            },
        },
	},

    --     lsp_interop = {
    --         enable = true,
    --         border = 'none',
    --         peek_definition_code = {
    --             ["<leader>df"] = "@function.outer",
    --             ["<leader>dF"] = "@class.outer",
    --         },
    --     },
    --     swap = {
    --         enable = true,
    --         swap_next = {
    --             [",,n"] = "@parameter.inner",
    --         },
    --         swap_previous = {
    --             [",,p"] = "@parameter.inner",
    --         },
    --     },
    --     move = {
    --         enable = true,
    --         set_jumps = true, -- whether to set jumps in the jumplist
    --         goto_next_start = {
    --             ["]m"] = "@function.outer",
    --             ["]]"] = "@class.outer",
    --         },
    --         goto_next_end = {
    --             ["]M"] = "@function.outer",
    --             ["]["] = "@class.outer",
    --         },
    --         goto_previous_start = {
    --             ["[m"] = "@function.outer",
    --             ["[["] = "@class.outer",
    --         },
    --         goto_previous_end = {
    --             ["[M"] = "@function.outer",
    --             ["[]"] = "@class.outer",
    --         },
    --     },
    --     select = {
    --         enable = true,
    --
    --         -- Automatically jump forward to textobj, similar to targets.vim
    --         lookahead = true,
    --
    --         keymaps = {
    --             -- You can use the capture groups defined in textobjects.scm
    --             ["aa"] = "@parameter.outer",
    --             ["ia"] = "@parameter.inner",
    --             ["af"] = "@function.outer",
    --             ["if"] = "@function.inner",
    --             ["ac"] = "@class.outer",
    --             ["ic"] = "@class.inner",
    --
    --             -- Or you can define your own textobjects like this
    --             ["iF"] = {
    --                 python = "(function_definition) @function",
    --                 cpp = "(function_definition) @function",
    --                 c = "(function_definition) @function",
    --                 java = "(method_declaration) @function",
    --             },
    --         },
    --     },
    -- },
    incremental_selection = {
        enable = true,
        keymaps = {
            init_selection = '<CR>',
            scope_incremental = 'CR>',
            node_incremental = '<S-TAB>',
            node_decremental = '<TAB>'
        }
    }
}

