let g:copilot_filetypes = {
      \ '*': v:false,
      \ 'python': v:true,
      \ 'go': v:true,
      \ 'rust': v:true,
      \ }

imap <silent><script><expr> <C-c> copilot#Accept("\<CR>")
let g:copilot_no_tab_map = v:true

let local_node = "~/.nvm/versions/node/v18.13.0/bin/node"

" if local_node exsits, then set g:copilot_node_command to local_node
if filereadable(local_node)
  let g:copilot_node_command = local_node
endif
