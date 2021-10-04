" set foldmethod=syntax "need to disable this otherwise it's very slow in
" neovim
set foldlevelstart=10 "open's all folds
set nospell
setlocal nolist

nnoremap <C-c><C-c> :wq<CR>
inoremap <C-c><C-c> <ESC>:wq<CR>
