require('orgmode').setup({
    -- default mappings vailable at https://github.com/kristijanhusak/orgmode.nvim/blob/master/lua/orgmode/config/defaults.lua
    org_agenda_files = {'~/org/*'},
    org_todo_keywords = { 'TODO', 'INPROGRESS', '|', 'DONE' , 'WONTDO'},
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
            org_timestamp_up = '+',
            org_timestamp_down = '<C-x>',
            org_move_subtree_up = 'gK',
            org_move_subtree_down = 'gJ',
            org_todo = '<C-c><C-t>',
            org_deadline = '<C-c><C-d>',
            org_schedule = '<C-c><C-s>',
            org_insert_heading_respect_content = '<Leader>oih', -- Add new headling after current heading block with same level
            org_insert_todo_heading = '<Leader>oiT', -- Add new todo headling right after current heading with same level
            org_insert_todo_heading_respect_content = '<Leader>oit', -- Add new todo headling after current heading block on same level
        }
    }
})
vim.cmd [[
nnoremap <silent> <Plug>MyMap :lua require('orgmode').action('org_mappings.archive')<CR>
silent! call repeat#set("\<Plug>MyMap",-1)
nmap ,,a <Plug>MyMap
]]

require("org-bullets").setup {
    symbols = { "◉", "○", "✸", "✿" }
}
