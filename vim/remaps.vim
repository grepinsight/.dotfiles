" Make movement more visual oriented

" Jumplist mutations
" nnoremap j gj
" nnoremap k gk
" this is from Primagen's https://www.youtube.com/watch?v=hSHATqh8svM
nnoremap <expr> k (v:count > 5 ? "m'" . v:count : "") . 'gk'
nnoremap <expr> j (v:count > 5 ? "m'" . v:count : "") . 'gj'


xnoremap j gj
xnoremap k gk


" Undo break points
inoremap , ,<c-g>u
inoremap . .<c-g>u
inoremap ! !<c-g>u
inoremap ? ?<c-g>u


"Keep search matches in the middle of the window and pulse the line when moving to them
nnoremap n nzzzv
nnoremap N Nzzzv
nnoremap vv ^vg_
nnoremap J mzJ`z

" Moving Text
vnoremap K :m '<-2<CR>gv=gv
vnoremap J :m '>+1<CR>gv=gv

" inoremap <C-k> <esc>:m .-2<CR>==
" inoremap <C-j> <esc>:m .+1<CR>==
