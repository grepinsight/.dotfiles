augroup rst_build
    autocmd!
    " autocmd FileType rst syntax off
    autocmd FileType rst exec "LspStop"
    " autocmd BufWritePre *.rst execute ':Make html'
augroup END
