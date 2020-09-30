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
