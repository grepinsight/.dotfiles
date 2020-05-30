setlocal keywordprg=rhelp
" nnoremap <F5> :call LanguageClient_contextMenu()<CR>
" " Or map each action separately
" nnoremap <silent> K :call LanguageClient#textDocument_hover()<CR>
" nnoremap <silent> gd :call LanguageClient#textDocument_definition()<CR>
" nnoremap <silent> <F2> :call LanguageClient#textDocument_rename()<CR>

" ----------------------------------------------------------------------------
" # R markdown related
" ----------------------------------------------------------------------------

call textobj#user#plugin('rmd', {
      \   'chunk': {
      \     'select-a-function': 'textobj#markdown#chunk#af',
      \     'select-a': '<buffer>ak',
      \     'select-i-function': 'textobj#markdown#chunk#if',
      \     'select-i': '<buffer>ik',
      \     'pattern': '```\S',
      \     'move-n': '<buffer>]k',
      \     'move-p': '<buffer>[k',
      \     'region-type': 'V',
      \   },
      \   'Btext': {
      \     'select-a': '<buffer>aM',
      \     'select-a-function': 'textobj#markdown#text#aM',
      \     'select-i': '<buffer>iM',
      \     'select-i-function': 'textobj#markdown#text#iM',
      \     'move-n': '<buffer>]n',
      \     'move-n-function': 'textobj#markdown#text#N',
      \     'move-p': '<buffer>[n',
      \     'move-p-function': 'textobj#markdown#text#P',
      \     'region-type': 'V',
      \   },
      \ })

" Custom text object
call textobj#user#plugin('rmdmine', {
\   'date': {
\     'pattern': '\<\d\d\d\d-\d\d-\d\d\>',
\     'select': ['ad', 'id'],
\   },
\   'bfunc': {
\     'pattern': 'function\S',
\     'move-p': '<buffer>[i',
\   },
\   'ffunc': {
\     'pattern': 'function\S',
\     'move-n': '<buffer>]i',
\   },
\   'FuncBlock': {
\     'pattern': '# Funcs\S',
\     'move-n': '<buffer>[F',
\   },
\ })


" Rmd specific hotkeys
nmap ,n <Plug>RNextRChunk
nmap ,p <Plug>RPreviousRChunk
