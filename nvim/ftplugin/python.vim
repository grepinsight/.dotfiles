vmap af :echo("hi")<CR>
omap af :normal Vaf<CR>

" Or map each action separately


" Make a string f-string ; here I use '@z' as a placeholder register
nnoremap ,,f mzF"if`zl
inoremap xxf <C-[>mzF"if`zlli
let b:surround_{char2nr('f')} = "f\"\r\""


" Set updatetime for CursorHold
" 300ms of no cursor movement to trigger CursorHold
" set updatetime=300
" Show diagnostic popup on cursor hold

" Goto previous/next diagnostic warning/error
nnoremap <silent> g[ <cmd>PrevDiagnosticCycle<cr>
nnoremap <silent> g] <cmd>NextDiagnosticCycle<cr>


" have a fixed column for the diagnostics to appear in
" this removes the jitter when warnings/errors flow in
set signcolumn=yes

" Import fix
nnoremap <Leader>if ^cwfrom<Esc>$F.r i import<Esc>^

command! BlackAuto autocmd BufWritePre *.py execute ':Black'

" autocmd FileType python nmap <Space> <Plug>SlimeParagraphSend
" autocmd FileType python vmap <Space> <Plug>SlimeRegionSend
augroup BiscuitHighlight
    autocmd!
    autocmd BufWritePre *.py hi BiscuitColorpython ctermfg=grey guifg=grey
augroup END


silent exec ":UpdateRemotePlugins"

" autoflake --in-place --remove-unused-variables %
