" R - related
let r_syntax_folding = 1

vmap af :<C-U>silent! normal! [[vt{%<CR>
omap af :normal Vaf<CR>

" nnoremap <F5> :call LanguageClient_contextMenu()<CR>
" nnoremap <silent> K :call LanguageClient#textDocument_hover()<CR>
" nnoremap <silent> gd :call LanguageClient#textDocument_definition()<CR>
" nnoremap <silent> <F2> :call LanguageClient#textDocument_rename()<CR>

let g:projectionist_heuristics["DESCRIPTION"] = {
				\  "R/*.R": {"alternate": "tests/testthat/test-{basename}.R"},
				\  "tests/testthat/test-*.R": {"alternate": "R/{basename}.R"},
			\}


" LSP

" Code navigation shortcuts
" nnoremap <silent> <c-]> <cmd>lua vim.lsp.buf.definition()<CR>


" Visualize diagnostics
let g:diagnostic_enable_virtual_text = 1
let g:diagnostic_trimmed_virtual_text = '40'
" Don't show diagnostics while in insert mode
let g:diagnostic_insert_delay = 1

" Set updatetime for CursorHold
" 300ms of no cursor movement to trigger CursorHold
set updatetime=300
" Show diagnostic popup on cursor hold
" autocmd CursorHold * lua vim.lsp.util.show_line_diagnostics()

" Goto previous/next diagnostic warning/error
nnoremap <silent> g[ <cmd>PrevDiagnosticCycle<cr>
nnoremap <silent> g] <cmd>NextDiagnosticCycle<cr>


" have a fixed column for the diagnostics to appear in
" this removes the jitter when warnings/errors flow in
set signcolumn=yes
