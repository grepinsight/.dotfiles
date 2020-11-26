vmap af :echo("hi")<CR>
omap af :normal Vaf<CR>

" Or map each action separately


" Make a string f-string ; here I use '@z' as a placeholder register
"nnoremap <LocalLeader>f mzF"if`zl



" nnoremap <silent> <c-]> <cmd>lua vim.lsp.buf.definition()<CR>
nnoremap <silent> K     <cmd>lua vim.lsp.buf.hover()<CR>
nnoremap <silent> gD    <cmd>lua vim.lsp.buf.implementation()<CR>
nnoremap <silent> <c-k> <cmd>lua vim.lsp.buf.signature_help()<CR>
nnoremap <silent> 1gD   <cmd>lua vim.lsp.buf.type_definition()<CR>
nnoremap <silent> gr    <cmd>lua vim.lsp.buf.references()<CR>
nnoremap <silent> g0    <cmd>lua vim.lsp.buf.document_symbol()<CR>
nnoremap <silent> gW    <cmd>lua vim.lsp.buf.workspace_symbol()<CR>
nnoremap <silent> gd    <cmd>lua vim.lsp.buf.definition()<CR>
nnoremap <silent> ga    <cmd>lua vim.lsp.buf.code_action()<CR>
nnoremap <silent> <leader>rn    <cmd>lua vim.lsp.buf.rename()<CR>


" Visualize diagnostics
let g:diagnostic_enable_virtual_text = 1
let g:diagnostic_trimmed_virtual_text = '40'
" Don't show diagnostics while in insert mode
let g:diagnostic_insert_delay = 1

" Set updatetime for CursorHold
" 300ms of no cursor movement to trigger CursorHold
set updatetime=300
" Show diagnostic popup on cursor hold
autocmd CursorHold * lua vim.lsp.util.show_line_diagnostics()

" Goto previous/next diagnostic warning/error
nnoremap <silent> g[ <cmd>PrevDiagnosticCycle<cr>
nnoremap <silent> g] <cmd>NextDiagnosticCycle<cr>


" have a fixed column for the diagnostics to appear in
" this removes the jitter when warnings/errors flow in
set signcolumn=yes

" Import fix
nnoremap <Leader>if ^cwfrom<Esc>$F.r i import<Esc>^

command! BlackAuto autocmd BufWritePre *.py execute ':Black'

autocmd FileType python nmap <Space> <Plug>SlimeParagraphSend
autocmd FileType python vmap <Space> <Plug>SlimeRegionSend
