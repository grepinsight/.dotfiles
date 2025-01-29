
" Visualize diagnostics
let g:diagnostic_enable_virtual_text = 1
let g:diagnostic_trimmed_virtual_text = '40'
" Don't show diagnostics while in insert mode
let g:diagnostic_insert_delay = 1

" Set updatetime for CursorHold
" 300ms of no cursor movement to trigger CursorHold
set updatetime=300
" Show diagnostic popup on cursor hold
"autocmd CursorHold * lua vim.lsp.util.show_line_diagnostics()

" Goto previous/next diagnostic warning/error
nnoremap <silent> g[ <cmd>PrevDiagnosticCycle<cr>
nnoremap <silent> g] <cmd>NextDiagnosticCycle<cr>


" have a fixed column for the diagnostics to appear in
" this removes the jitter when warnings/errors flow in
set signcolumn=yes

" Enable type inlay hints
" autocmd CursorMoved,InsertLeave,BufEnter,BufWinEnter,TabEnter,BufWritePost *
" \ lua require'lsp_extensions'.inlay_hints{ prefix = '<', highlight = "Comment" }


let g:rustfmt_autosave = 1


syntax keyword Normal function conceal cchar=λ
syntax keyword rustMacro println conceal cchar=프린트엘렌
syntax keyword Keyword return conceal cchar=>
