" augroup fmt
"   autocmd!
"   autocmd BufWritePre * undojoin | Neoformat
" augroup END

let b:surround_{char2nr('r')} = "```ruby\r```"
let b:surround_{char2nr('p')} = "```python\r```"

map gf :edit <cfile>.md<cr>
