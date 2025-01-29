set foldlevelstart=10
set foldlevel=11
set nolist
set relativenumber

nnoremap <C-c><C-c> :call magit#commit_command('CC') <CR>
inoremap <C-c><C-c> <ESC>:call magit#commit_command('CC') <CR>

nnoremap <C-c><C-f> :call magit#commit_command('CF') <CR>
inoremap <C-c><C-f> <ESC>:call magit#commit_command('CF') <CR>

nnoremap <C-c><C-a> :call magit#commit_command('CA') <CR>
inoremap <C-c><C-a> <ESC>:call magit#commit_command('CA') <CR>

let g:magit_jump_next_hunk              = get(g:, 'magit_jump_next_hunk',            '<C-J>')
let g:magit_jump_prev_hunk              = get(g:, 'magit_jump_prev_hunk',            '<C-K>')
let g:magit_discard_untracked_do_delete = 1

