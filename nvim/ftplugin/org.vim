nnoremap <C-c><C-s> :call OrgDateEdit('SCHEDULED')<cr>
nnoremap <C-c><C-d> :call OrgDateEdit('DEADLINE')<cr>


"let g:agenda_select_dirs=["~/Dropbox/vimwiki"]
let g:agenda_files = ["~/Dropbox/vimwiki/work.org", "~/Dropbox/vimwiki/kanban.org"]

" Do not use autocomplete
let b:coc_suggest_disable = 1

nnoremap <C-c>* 0d^i** <Esc>
