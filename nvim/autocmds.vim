augroup syntax_setup
    autocmd!
    autocmd FileType rst syntax off
    autocmd FileType json set foldmethod=indent
    autocmd BufNewFile,BufRead *.org setfiletype org
    autocmd BufNewFile,BufRead *.snk setfiletype snakemake
    autocmd BufNewFile,BufRead Snakefile* setfiletype snakemake
augroup END

autocmd BufEnter *.png,*.jpg,*gif exec "!open ".expand("%") | bw
autocmd BufEnter *.pdf exec "!open -a 'PDF Expert' "."\"".expand("%")."\"" | bw


autocmd FileType gitcommit set foldlevelstart=10 "open's all folds
autocmd FileType gitcommit set foldlevel=10 "open's all folds

autocmd FileType make set foldlevelstart=1 "open's all folds
autocmd FileType make set foldlevel=1 "open's all folds

let g:golden_ratio_autocommand = 0
autocmd FileType r let g:golden_ratio_autocommand = 0
autocmd FileType rbrowser let g:golden_ratio_autocommand = 0

