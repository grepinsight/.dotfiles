set foldlevelstart=10
set foldlevel=10
set nolist

nnoremap <C-c><C-c> :call magit#commit_command('CC') <CR>
inoremap <C-c><C-c> <ESC>:call magit#commit_command('CC') <CR>

let g:magit_jump_next_hunk              = get(g:, 'magit_jump_next_hunk',            '<C-J>')
let g:magit_jump_prev_hunk              = get(g:, 'magit_jump_prev_hunk',            '<C-K>')
let g:magit_discard_untracked_do_delete = 1

