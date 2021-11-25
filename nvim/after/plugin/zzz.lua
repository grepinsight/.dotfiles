-- require("twilight").setup({
--     exclude = {"lua"},
-- })
function setup_treesitter()
    require'sniprun'.setup({})
    require("indent_blankline").setup {
        char = "|",
        buftype_exclude = {"terminal"}
    }


    require'nvim-treesitter.configs'.setup({})
    require('nvim-biscuits').setup({
        toggle_keybind = "<leader>cb",
        cursor_line_only = true,
        default_config = {
            max_length = 12,
            min_distance = 5,
            prefix_string = " 📎 "
        },
        language_config = {
            html = {
                prefix_string = " 🌐 "
            },
            javascript = {
                prefix_string = " ✨ ",
                max_length = 80
            },
            python = {
                -- disabled = true
                -- prefix_string = " ✨ ",
            }
        }
    })


    require'nvim-treesitter.configs'.setup {
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
            lsp_interop = {
                enable = true,
                border = 'none',
                peek_definition_code = {
                    ["<leader>df"] = "@function.outer",
                    ["<leader>dF"] = "@class.outer",
                },
            },
            swap = {
                enable = true,
                swap_next = {
                    [",,n"] = "@parameter.inner",
                },
                swap_previous = {
                    [",,p"] = "@parameter.inner",
                },
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
            select = {
                enable = true,

                -- Automatically jump forward to textobj, similar to targets.vim
                lookahead = true,

                keymaps = {
                    -- You can use the capture groups defined in textobjects.scm
                    ["af"] = "@function.outer",
                    ["if"] = "@function.inner",
                    ["ac"] = "@class.outer",
                    ["ic"] = "@class.inner",

                    -- Or you can define your own textobjects like this
                    ["iF"] = {
                        python = "(function_definition) @function",
                        cpp = "(function_definition) @function",
                        c = "(function_definition) @function",
                        java = "(method_declaration) @function",
                    },
                },
            },
        },
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

    require'treesitter-context'.setup{
            enable = true, -- Enable this plugin (Can be enabled/disabled later via commands)
            throttle = true, -- Throttles plugin updates (may improve performance)
            max_lines = 0, -- How many lines the window should span. Values <= 0 mean no limit.
            patterns = { -- Match patterns for TS nodes. These get wrapped to match at word boundaries.
            -- For all filetypes
            -- Note that setting an entry here replaces all other patterns for this entry.
            -- By setting the 'default' entry below, you can control which nodes you want to
            -- appear in the context window.
            default = {
                'class',
                'function',
                'method',
                -- 'for', -- These won't appear in the context
                -- 'while',
                -- 'if',
                -- 'switch',
                -- 'case',
            },
            -- Example for a specific filetype.
            -- If a pattern is missing, *open a PR* so everyone can benefit.
            --   rust = {
            --       'impl_item',
            --   },
        },
    }

    local parser_config = require "nvim-treesitter.parsers".get_parser_configs()
    parser_config.org = {
      install_info = {
        url = 'https://github.com/milisims/tree-sitter-org',
        revision = 'main',
        files = {'src/parser.c', 'src/scanner.cc'},
      },
      filetype = 'org',
    }



    require'nvim-treesitter.configs'.setup {
      -- If TS highlights are not enabled at all, or disabled via `disable` prop, highlighting will fallback to default Vim syntax highlighting
      highlight = {
        enable = true,
        disable = {'org'}, -- Remove this to use TS highlighter for some of the highlights (Experimental)
        additional_vim_regex_highlighting = {'org'}, -- Required since TS highlighter doesn't support all syntax features (conceal)
      },
      ensure_installed = {'org'}, -- Or run :TSUpdate org
    }
end
vim.cmd([[autocmd User nvim-treesitter lua setup_treesitter()]])

function setup_due_nvim()
    -- require'shade'.setup({})
    require('due_nvim').setup({
        prescript = 'due: ',           -- prescript to due data
        prescript_hi = 'Comment',      -- highlight group of it
        due_hi = 'String',             -- highlight group of the data itself
        ft = '*.org,*.md',                   -- filename template to apply aucmds :)
        today = 'TODAY',               -- text for today's due
        today_hi = 'Character',        -- highlight group of today's due
        overdue = 'OVERDUE',           -- text for overdued
        overdue_hi = 'Error',          -- highlight group of overdued
        date_hi = 'Conceal',           -- highlight group of date string
        pattern_start = '<',           -- start for a date string pattern
        pattern_end = '>',             -- end for a date string pattern
        use_clock_time = false,        -- allow due.nvim to calculate hours, minutes, and seconds
        default_due_time = "midnight", -- if use_clock_time == true, calculate time until option on specified date.
        --   Accepts "midnight", for 23:59:59, or noon, for 12:00:00
    })

end
vim.cmd([[autocmd User due.nvim lua setup_due_nvim()]])
