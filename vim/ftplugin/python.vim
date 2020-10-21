vmap af :echo("hi")<CR>
omap af :normal Vaf<CR>
set foldmethod=indent

" Or map each action separately


" Make a string f-string ; here I use '@z' as a placeholder register
nnoremap <LocalLeader>f mzF"if`zl
