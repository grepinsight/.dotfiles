"  Dynamic Numbering

" Dynamic numbering + Colorize line numbers in insert and visual modes
" From https://stackoverflow.com/a/15587011/1058663
" ------------------------------------------------
function! SetCursorLineNrColorInsert(mode)
    " Insert mode: blue
    if a:mode == "i"
        highlight CursorLineNr ctermfg=4 guifg=#268bd2
        set norelativenumber

    " Replace mode: red
    elseif a:mode == "r"
        highlight CursorLineNr ctermfg=1 guifg=#dc322f

    endif
endfunction


function! SetCursorLineNrColorVisual()
    set updatetime=0

    " Visual mode: orange
    highlight CursorLineNr cterm=none ctermfg=9 guifg=#cb4b16
    set relativenumber
endfunction


function! ResetCursorLineNrColor()
    set updatetime=4000
    highlight CursorLineNr cterm=none ctermfg=0 guifg=#073642
    set norelativenumber
endfunction


" " Toggle relative number / absolute number based on visual mode or normal mode
" vnoremap <silent> <expr> <SID>SetCursorLineNrColorVisual SetCursorLineNrColorVisual()

" " Need to set this in order to make SetCursorLineNrColorVisual work
" nnoremap <silent> <script> v :call SetCursorLineNrColorVisual()<CR>v
" nnoremap <silent> <script> V :call SetCursorLineNrColorVisual()<CR>V
" nnoremap <silent> <script> <C-v> :call SetCursorLineNrColorVisual()<CR><C-v>

" augroup CursorLineNrColorSwap
"     autocmd!
"     autocmd InsertEnter * call SetCursorLineNrColorInsert(v:insertmode)
"     autocmd InsertLeave * call ResetCursorLineNrColor()
"     autocmd CursorHold * call ResetCursorLineNrColor()
" augroup END

