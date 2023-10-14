augroup remember_cursor_position
    autocmd!
    autocmd BufEnter *.vim silent! normal! g`"
augroup END

augroup syntax_setup
    autocmd!
    " autocmd FileType rst syntax off autocmd FileType rst exec "LspStop"
    autocmd FileType json set foldmethod=indent
    autocmd BufNewFile,BufRead *.org setfiletype org
    autocmd BufNewFile,BufRead *.snk setfiletype snakemake
    autocmd BufNewFile,BufRead justfile setfiletype justfile
    autocmd BufNewFile,BufRead Justfile setfiletype justfile
    autocmd BufNewFile,BufRead Snakefile* setfiletype snakemake
    autocmd BufNewFile,BufRead Jenkinsfile setfiletype groovy
    autocmd BufNewFile,BufRead .envrc setfiletype envrc
    autocmd BufNewFile,BufRead .rules setfiletype rules

    " set foldmethod to marker if ft is rules
    autocmd BufNewFile,BufRead *.rules set foldmethod=marker
augroup END

autocmd BufEnter *.png,*.jpg,*gif exec "!open ".expand("%") | bw
autocmd BufEnter *.pdf exec "!open -a 'PDF Expert' "."\"".expand("%")."\"" | bw
" somehow setthing this up normal doesn't work
autocmd BufEnter * set laststatus=3


autocmd FileType gitcommit set foldlevelstart=10 "open's all folds
autocmd FileType gitcommit set foldlevel=10 "open's all folds
" start insert mode if ft is gitcommit
autocmd FileType gitcommit startinsert


autocmd FileType make set foldlevelstart=1 "open's all folds
autocmd FileType make set foldlevel=1 "open's all folds

let g:golden_ratio_autocommand = 0
autocmd FileType r let g:golden_ratio_autocommand = 0
autocmd FileType rbrowser let g:golden_ratio_autocommand = 0


let g:direnv_loaded = {}
fun! DirenvReload()
    " Don't strip on these filetypes
    if !system('test -f .envrc')
        return
    if &ft =~ 'fzf'
        return
    endif
    if bufname(bufnr("%")) =~ 'pytest'
        return
    endif
    if bufname(bufnr("%")) =~ 'python'
        return
    endif
    if bufname(bufnr("%")) =~ ':vd'
        return
    endif
    let fn = bufname("%") + "__" +bufnr("%")
    if !has_key(g:direnv_loaded, fn)
        call jobsend(b:terminal_job_id, "direnv reload 2>/dev/null\n")
        let g:direnv_loaded[fn] = 1
    endif
endfun

augroup terminal_setup | au!
    autocmd TermEnter * call DirenvReload()
augroup end



if filereadable(".vimrc_proj")
    so .vimrc_proj
endif

autocmd BufWritePre *.js execute ':Prettier'
autocmd BufWritePre *.tsx execute ':Prettier'
autocmd BufWritePre *.css execute ':Prettier'
" autocmd BufWritePre *.html execute ':Prettier'

" When editing a file, always jump to the last known cursor position.
" Don't do it when the position is invalid, when inside an event handler
" (happens when dropping a file on gvim) and for a commit message (it's
" likely a different one than last time).
autocmd BufReadPost *
  \ if line("'\"") >= 1 && line("'\"") <= line("$") && &ft !~# 'commit'
  \ |   exe "normal! g`\""
  \ | end



augroup highlight_yank
    autocmd!
    au TextYankPost * silent! lua vim.highlight.on_yank{higroup="IncSearch", timeout=200}
augroup END

" augroup cursorholds
"   autocmd!
"   autocmd CursorHold <buffer>  lua vim.lsp.buf.document_highlight()
"   autocmd CursorHoldI <buffer> lua vim.lsp.buf.document_highlight()
"   autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()
" augroup END
"
