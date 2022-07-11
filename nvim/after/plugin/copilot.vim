let g:copilot_filetypes = {
      \ '*': v:true,
      \ 'python': v:true,
      \ 'go': v:true,
      \ }

imap <silent><script><expr> <C-c> copilot#Accept("\<CR>")
let g:copilot_no_tab_map = v:true
