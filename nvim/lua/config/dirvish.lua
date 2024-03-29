vim.cmd[[
call dirvish#add_icon_fn({p -> p[-1:]=='/'?'📂':'📄'})
" How to unmap things
" augroup dirvish_config
"   autocmd!
"   autocmd FileType dirvish silent! unmap <buffer> <C-p>
" augroup END

augroup dirvish_config
autocmd!
autocmd FileType dirvish
\ nnoremap <silent><buffer> t ddO<Esc>:let @"=substitute(@", '\n', '', 'g')<CR>:r ! find "<C-R>"" -maxdepth 1 -print0 \| xargs -0 ls -Fd<CR>:silent! keeppatterns %s/\/\//\//g<CR>:silent! keeppatterns %s/[^a-zA-Z0-9\/]$//g<CR>:silent! keeppatterns g/^$/d<CR>:noh<CR>
augroup END
]]
