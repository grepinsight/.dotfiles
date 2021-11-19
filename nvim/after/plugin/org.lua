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

require('orgmode').setup({
    -- default mappings vailable at https://github.com/kristijanhusak/orgmode.nvim/blob/master/lua/orgmode/config/defaults.lua
    org_agenda_files = {'~/org/*'},
    org_default_notes_file = '~/org/notes.org',
    org_agenda_templates = {
        t = {
            description = 'Task',
            template = '* TODO %?\n  %u',
        },
        c = {
            description = 'Note',
            template = '* %?\n  %u',
        },
    },
    mappings = {
        global = {
            org_agenda = {'gA', '<C-c>a'},
            org_capture = 'gC'
        },
        capture = {
          org_capture_finalize = '<C-c><C-c>',
          org_capture_refile = '<C-c><C-w>',
          org_capture_kill = '<C-c><C-k>',
        },
        org = {
            org_set_tags_command = '<C-c>q',
            org_timestamp_up = '<C-i>',
            org_timestamp_down = '<C-x>',
            org_move_subtree_up = 'gK',
            org_move_subtree_down = 'gJ',
            org_todo = '<C-c><C-t>',
            org_deadline = '<C-c><C-d>',
            org_schedule = '<C-c><C-s>',
        }
    }
})

require("org-bullets").setup {
  symbols = { "◉", "○", "✸", "✿" }
}


