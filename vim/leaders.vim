" Systems
"
" Double Characters
" Double Capital Letters
" Unimpaired style
" F1-F9
" Backslash Leader
" Space Leader
" Comma Leader

nnoremap <SPACE> <Nop>
let maplocalleader=" "

" Allow gf to open non-existent files
map gf :edit <cfile><cr>


nnoremap   <silent>   ==   :Neoformat<CR>
nnoremap   <silent>   <F9>   :FloatermToggle<CR>
tnoremap   <silent>   <F9>   <C-\><C-n>:FloatermToggle<CR>

" Double Capital letters
nnoremap BB :call BufferSmartDelete()<CR>
" nnoremap BB :Sayonara!<CR>

nnoremap TA :Telescope aerial<CR>
nnoremap TB :lua require('telescope.builtin').buffers()<CR>
nnoremap TC :lua require('telescope.builtin').commands()<CR>
nnoremap TF :lua require('telescope.builtin').find_files()<CR>
nnoremap TG :lua require('telescope.builtin').grep_string { search = vim.fn.expand("<cword>") }<CR>
nnoremap TM :Telescope marks<CR>
nnoremap TO :Telescope oldfiles path_display=shorten<CR>
nnoremap TR :Telescope lsp_references<CR>
nnoremap TS :lua require('telescope.builtin').grep_string({ search = vim.fn.input("Grep For > ")})<CR>
nnoremap TH :Telescope help_tags<CR>
nnoremap TT :lua require('telescope').extensions.git_worktree.create_git_worktree()
nnoremap TW :lua require('telescope').extensions.git_worktree.git_worktrees()<CR>

nnoremap ]s :GitGutterStageHunk<CR>
nnoremap [s :GitGutterUndoHunk<CR>

nnoremap QQ :q<CR>
" ZZ        : q

command! R :FloatermNew --width=0.5 --wintype=normal --name=repl --position=right R --vanilla
command! Py :FloatermNew --width=0.5 --wintype=normal --name=repl --position=right ipython --TerminalInteractiveShell.editing_mode=vi
command! PY :FloatermNew --width=0.5 --wintype=normal --name=repl --position=right ipython --TerminalInteractiveShell.editing_mode=vi

nnoremap   <leader>ts   :FloatermSend<CR>
vnoremap   <leader>ts   :FloatermSend<CR>
nnoremap   <leader>tt   :NvimTreeToggle<CR>

nnoremap <Leader>pyan :!pyan % --dot -c -e \| dot -Tpng > <C-R>=expand('%:r')<CR>.png && open <C-R>=expand('%:r')<CR>.png <CR>
nnoremap <Leader>tgf :!pyan % --tgf -c -e  > <C-R>=expand('%:r')<CR>.tgf<CR>


" vim: set foldmethod=marker foldlevel=0 nomodeline:
" these "Ctrl mappings" work well when Caps Lock is mapped to Ctrl
nmap <silent> t<C-n> :TestNearest<CR>
nmap <silent> t<C-f> :TestFile<CR>
nmap <silent> t<C-s> :TestSuite<CR>
nmap <silent> t<C-l> :TestLast<CR>
nmap <silent> t<C-g> :TestVisit<CR>
nnoremap <silent> <C-p> :Telescope find_files<CR>

" # Bracket Leader keys
nnoremap <silent> ]j :call NextClosedFold('j')<cr>
nnoremap <silent> [j :call NextClosedFold('k')<cr>
nnoremap <silent> ]al :ALENext<CR>
nnoremap <silent> [al :ALEPrevious<CR>

" Remap keys for gotos
nmap <silent> <leader>ld <Plug>(coc-definition)
nmap <silent> <F12> <Plug>(coc-definition)
nmap <silent> <leader>lt <Plug>(coc-type-definition)
nmap <silent> <leader>li <Plug>(coc-implementation)
nmap <silent> <leader>lf <Plug>(coc-references)
" coc.vim stuff
"nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
" nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)
" Remap for rename current word
nmap <leader>rn <Plug>(coc-rename)
" Mapping selecting mappings
nmap <leader><tab> <plug>(fzf-maps-n)
xmap <leader><tab> <plug>(fzf-maps-x)
omap <leader><tab> <plug>(fzf-maps-o)

" Insert mode completion
imap <c-x><c-k> <plug>(fzf-complete-word)
imap <c-x><c-f> <plug>(fzf-complete-path)
imap <c-x><c-j> <plug>(fzf-complete-file-ag)
imap <c-x><c-l> <plug>(fzf-complete-line)



" Leader {{{
nmap <F8> :TagbarToggle<CR>

" nnoremap <leader>b :Gblame<CR>
nnoremap <leader><leader>s :ToggleGStatus<CR>
nnoremap <leader>b :call BlameToggle()<CR>
nnoremap <leader>es :vsplit ~/.vim/plugged/mysnippets/UltiSnips<CR>
nnoremap <leader>ev :e $HOME/.dotfiles/nvim/init.lua<CR>
nnoremap <leader>el :e $HOME/.dotfiles/vim/leaders.vim<CR><bar>:lua vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')<CR>
nnoremap <leader>eo :e $HOME/org/notes.org<CR>
nnoremap <leader>eO :e $HOME/.dotfiles/nvim/after/plugin/org.lua<CR>
nnoremap <leader>gau :Git add -u<CR><CR>
nnoremap <leader>gcv :Git commit -v <CR>
nnoremap <leader>gs :term git diff --staged -- %<CR>
nnoremap <leader>gd :term git diff -- % <CR>
nnoremap <leader>gf :GitGutterFold<CR>
nnoremap <leader>gvd :Gvdiffsplit<CR>
nnoremap <leader>gw :Gwrite <CR>:Gcommit -v<CR>
nnoremap <leader>ln :Lines<CR>
nnoremap <leader>pv :call fzf#vim#gitfiles('', fzf#vim#with_preview('right'))<CR>
nnoremap <leader>s  :ToggleGStatus<CR>
nnoremap <leader>ss :ToggleGStatus<CR>
nnoremap <leader>sv :source $MYVIMRC<CR>
nnoremap <leader>sn :luafile ~/.dotfiles/nvim/lua/config/snippets.lua<CR>
nnoremap <leader>vd :Gvdiff<CR>
nnoremap <leader>ut :Ultest<CR>
nnoremap <leader>un :UltestNearest<CR>
nnoremap <leader>us :UltestSummary<CR>
nnoremap <leader>uo :UltestOutput<CR>
nnoremap <leader>x :!chmod 750 %<CR>

" Copy and Paste : https://vi.stackexchange.com/questions/84/how-can-i-copy-text-to-the-system-clipboard-from-vim
"noremap <Leader>y "*y
noremap <Leader>y :call SendViaOSC52(getreg('"'))<cr>
noremap <Leader>Y "+y
noremap <Leader>p "*p
noremap <Leader>P "+p

nnoremap <leader>Al :left<cr>
nnoremap <leader>Ac :center<cr>
nnoremap <leader>Ar :right<cr>
vnoremap <leader>Al :left<cr>
vnoremap <leader>Ac :center<cr>
vnoremap <leader>Ar :right<cr>
nnoremap <Leader>dot :!cat % \| dot -Tpng > <C-R>=expand('%:r')<CR>.png && open <C-R>=expand('%:r')<CR>.png<CR>

"insert file name : \fn in insert mode
inoremap \fn <C-R>=expand("%:t")<CR>
" git last commit message
inoremap \gl <Esc>:r !git log -1 --pretty=\%B<CR>kA
inoremap <Leader>fn <C-R>=expand("%:t")<CR>
inoremap <Leader>dn <C-R>=expand("%:p:h:t")<CR>

"focus current fold
nnoremap zs zMzvzz

" Bash alias shortcut
nnoremap <Leader>bas :e $HOME/.dotfiles/bash/share/bash_aliases_share<CR>
nnoremap <Leader>bcs :e $HOME/.dotfiles/bash/share/bash_colors_share<CR>
nnoremap <Leader>bfs :e $HOME/.dotfiles/bash/share/bash_functions_share<CR>
nnoremap <Leader>bfl :e $HOME/.dotfiles/bash/share/bash_functions_local<CR>
nnoremap <Leader>bss :e $HOME/.dotfiles/bash/share/bash_settings_share<CR>
nnoremap <Leader>bal :e $HOME/.dotfiles/bash/local/bash_aliases_local<CR>
nnoremap <Leader>bpl :e $HOME/.dotfiles/bash/local/bash_paths_local<CR>
nnoremap <Leader>bsl :e $HOME/.dotfiles/bash/local/bash_settings_local<CR>

nnoremap <Leader>btt :bufdo tab split<CR>
nnoremap <Leader>c :ccl<CR>
nnoremap <Leader>di :sp ~/Dropbox/vimwiki/diary/<C-R>=strftime("%Y-%m-%d")<CR>.md<CR>
nnoremap <Leader>fme :set foldmethod=expr<CR>
nnoremap <Leader>fmi :set foldmethod=indent<CR>
nnoremap <Leader>fmm :set foldmethod=marker<CR>
nnoremap <Leader>fms :set foldmethod=syntax<CR>

" Move to start of fold
nnoremap <leader>fs zo[z
" Move to end of fold
nnoremap <leader>fe zo]z
nnoremap <Leader>syn :echo "hi<" . synIDattr(synID(line("."),col("."),1),"name") . '> trans<'
\ . synIDattr(synID(line("."),col("."),0),"name") . "> lo<"
\ . synIDattr(synIDtrans(synID(line("."),col("."),1)),"name") . ">"<CR>
nnoremap <Leader>gi :e ./.gitignore<CR>
nnoremap <Leader>hh :Helptags<CR>
nnoremap <Leader>ht :Helptags<CR>
nnoremap <Leader>ls :ls<CR>
nnoremap <Leader>md :w<CR> :!cygstart %<CR> " Open markdown
vnoremap <Leader>tc :<C-U>silent! normal! gV:!titlecase<CR>

" s{char}{char} to move to {char}{char}
nnoremap <Leader>rg :Rg! <C-R><C-W><CR>

" Edit the macro quickly; "q<leader>m
nnoremap <leader>m  :<c-u><c-r><c-r>='let @'. v:register .' = '. string(getreg(v:register))<cr><c-f><left>
nnoremap <Leader>mg :Magit<CR>



"}}}

"nnoremap <LocalLeader>c :ccl<CR>
nnoremap <LocalLeader><LocalLeader> <C-^>
"nnoremap <LocalLeader>a :A <CR>
nnoremap <LocalLeader>af :lua require("harpoon.mark").add_file()<CR>
nnoremap <leader>aa :A <CR>
nnoremap <LocalLeader>1 :lua require("harpoon.ui").nav_file(1)<CR>
nnoremap <LocalLeader>2 :lua require("harpoon.ui").nav_file(2)<CR>
nnoremap <LocalLeader>3 :lua require("harpoon.ui").nav_file(3)<CR>
nnoremap <LocalLeader>4 :lua require("harpoon.ui").nav_file(4)<CR>
nnoremap <LocalLeader>b :GitMessenger<CR>
nnoremap <LocalLeader>d :Gvdiff<CR>
nnoremap <LocalLeader>e :edit <C-R>=expand('%:p:h') . '/' <CR>
nnoremap <LocalLeader>ff <cmd>Telescope find_files<cr>
nnoremap <LocalLeader>fw :lua require('telescope.builtin').grep_string { search = vim.fn.expand("<cword>") } <CR>
nnoremap <LocalLeader>fg <cmd>Telescope live_grep<cr>
nnoremap <LocalLeader>fc <cmd>Telescope git_commits<cr>
nnoremap <LocalLeader>fb <cmd>Telescope buffers<cr>
nnoremap <LocalLeader>fh <cmd>Telescope help_tags<cr>
nnoremap <LocalLeader>fq <cmd>Telescope quickfix<cr>
nnoremap <LocalLeader>fs <cmd>Telescope git_status<cr>
nnoremap <LocalLeader>fm <cmd>Telescope marks<cr>
nnoremap <LocalLeader>fr <cmd>Telescope lsp_references<cr>

nnoremap <LocalLeader>K :Lspsaga hover_doc<CR>
nnoremap <LocalLeader>g :GV<CR>
nnoremap <LocalLeader>gf :<c-u>vie <c-r>=findfile(expand('<cfile>'))<cr><cr>
nnoremap <LocalLeader>gd :Lspsaga preview_definition<CR>
nnoremap <LocalLeader>ji :BTags<CR>
nnoremap <LocalLeader>lc :lclose<CR>
nnoremap <LocalLeader>lf :BLines<CR>
nnoremap <LocalLeader>ss :BLines<CR>
nnoremap <LocalLeader>lo :lopen<CR>
nnoremap <LocalLeader>m :Magit<CR>
nnoremap <LocalLeader>o :lua require('orgmode').action('clock.org_clock_goto')<CR>
nnoremap <LocalLeader>pro :e ~/src/productivity/
nnoremap <silent> <LocalLeader>p :let @" = expand("%:p")<CR> <bar> :echo expand('%:p')<CR>
nnoremap <silent> <LocalLeader>pzp :!echo <C-R>=expand("%:p")<CR> \| rpbcopy <CR> <bar> :echo expand('%:p')<CR>
nnoremap <LocalLeader>pt :NERDTreeToggle<CR>
nnoremap <LocalLeader>qq :quit <CR>
nnoremap <LocalLeader>qf :call ToggleQuickFix()<CR>
nnoremap <LocalLeader>s1 :lua require("harpoon.term").sendCommand(1, "ipython --TerminalInteractiveShell.editing_mode=vi")<CR>
nnoremap <LocalLeader>s2 :lua require("harpoon.term").sendCommand(1, 2)<CR>
nnoremap <LocalLeader>ty :!typora "%"<CR>
nnoremap <LocalLeader>tn :TestNearest<CR>
nnoremap <LocalLeader>t1 :lua require("harpoon.term").gotoTerminal(1)<CR>
nnoremap <LocalLeader>t2 :lua require("harpoon.term").gotoTerminal(2)<CR>

nnoremap <LocalLeader>toc :VimwikiTOC<CR>
nnoremap <LocalLeader>tog :!toggl-start <C-R>=expand('<cWORD>')<CR>
nnoremap <LocalLeader>v :Vista<CR>
nnoremap <LocalLeader>w :write <CR>
nnoremap <LocalLeader>wq :wq <CR>
nnoremap <LocalLeader>ww <C-w>w
nnoremap <LocalLeader>y :Goyo 120<CR>
nnoremap <silent> <LocalLeader> :<c-u>WhichKey  '<Space>'<CR>
nnoremap <silent> <LocalLeader>z :Focus2<CR>
noremap <LocalLeader>x :Focus<CR>
noremap <silent> <LocalLeader>ch :wincmd h<CR>:close<CR>
noremap <silent> <LocalLeader>cj :wincmd j<CR>:close<CR>
noremap <silent> <LocalLeader>ck :wincmd k<CR>:close<CR>
noremap <silent> <LocalLeader>cl :wincmd l<CR>:close<CR>
" nnoremap <LocalLeader>ot :call ChooseTerm("term-slider", 1)<CR>

" Tertiary leaderkey
"
" COMMA LEADER
"nnoremap ,a :CtrlPMRUFiles<CR>
" nnoremap ,a :lua require("telescope.builtin").oldfiles {path_display = {"shorten"}}<CR>
nnoremap ,a :Telescope oldfiles<CR>
nnoremap ,b :Telescope buffers<CR>
nnoremap ,c :GitGutterQuickFix<CR> <bar> :copen <CR> /<C-R>=bufname(winbufnr(1))<CR><CR>
nnoremap ,d :DogeGenerate<CR>
nnoremap ,e :e <C-R>=expand("%:p:h") . "/" <CR>
nnoremap ,f :Rg! <C-R><C-W><CR>
nnoremap ,g :GV!<CR>
nnoremap ,h :History<CR>
nnoremap ,i :e <C-R>=resolve(expand("%:h"))<CR>/
imap ,S <Plug>luasnip-expand-or-jump
imap <silent><expr> <C-j> luasnip#choice_active() ? '<Plug>luasnip-next-choice' : '<C-j>'
smap <silent><expr> <C-j> luasnip#choice_active() ? '<Plug>luasnip-next-choice' : '<C-j>'
imap <silent><expr> <C-k> luasnip#choice_active() ? '<Plug>luasnip-prev-choice' : '<C-k>'
smap <silent><expr> <C-k> luasnip#choice_active() ? '<Plug>luasnip-prev-choice' : '<C-k>'
imap <silent><expr> <C-y> luasnip#choice_active() ? '<Plug>luasnip-expand-or-jump' : '<C-y>'
smap <silent><expr> <C-y> luasnip#choice_active() ? '<Plug>luasnip-expand-or-jump' : '<C-y>'
"nnoremap ,j
nnoremap ,k :lua require("harpoon.mark").add_file()<CR>
nmap ,l yor
nnoremap ,m :Magit<CR>
nnoremap ,n <cmd>lua require'telescope.builtin'.live_grep{}<CR>
nnoremap ,o  :only<CR>
nnoremap ,O :BOnly<CR>
nnoremap ,p :e <C-R>=resolve(expand("%"))<CR>
nnoremap ,q :Rg! <C-R>=expand("%:t")<CR>
nnoremap ,r :BTags<CR>
nmap s :HopChar2AC<CR>
nmap S :HopChar2BC<CR>
" nnoremap ,t :call ChooseTerm("term-slider", 1)<CR>
nnoremap ,t :sp<CR><Esc>:lua require("harpoon.term").gotoTerminal(1)<CR>
nnoremap ,,t :call ChooseTerm("term-slider2", 1)<CR>
nnoremap ,u :GundoToggle<CR>
nnoremap ,v :call fzf#run(fzf#wrap({'source': 'fd $FD_OPTS . $HOME/Thoughts', 'sink': 'split'}))<CR>
nnoremap ,w :NvimTreeToggle<CR>
nnoremap ,x :Focus<CR>
"nnoremap ,y :call ChooseTerm("term-pane", 0)<CR>
vnoremap <silent> ,y :'<,'>w !rpbcopy<CR><CR>
nnoremap <silent> ,y :!echo <C-R>=expand("<cword>")<CR> \| rpbcopy <CR><CR>
nnoremap ,z :Focus2<CR>

vnoremap <silent> ,e :'<,'>!equalify<CR><CR>
vnoremap <silent> ,i :'<,'>!itemify<CR><CR>
vnoremap <silent> ,l :'<,'>!listify<CR><CR>

" Unimparied style
" nnoremap [t :tabprevious<CR>
" nnoremap ]t :tabnext<CR>
nmap ]t <Plug>(ultest-next-fail)
nmap [t <Plug>(ultest-prev-fail)
nnoremap ]1 :lua require("harpoon.ui").nav_file(1)<CR>
nnoremap ]2 :lua require("harpoon.ui").nav_file(2)<CR>
nnoremap ]3 :lua require("harpoon.ui").nav_file(3)<CR>
nnoremap ]4 :lua require("harpoon.ui").nav_file(4)<CR>
nnoremap [1 :lua require("harpoon.term").gotoTerminal(1)<CR>
nnoremap [2 :lua require("harpoon.term").gotoTerminal(2)<CR>
nnoremap [3 :lua require("harpoon.term").gotoTerminal(3)<CR>
nnoremap [4 :lua require("harpoon.term").gotoTerminal(4)<CR>
" nnoremap <LocalLeader>t1 :lua require("harpoon.term").gotoTerminal(1)<CR>
" nnoremap <LocalLeader>t2 :lua require("harpoon.term").gotoTerminal(2)<CR>


" Ctrl <C-***>
nnoremap <C-e> :lua require("harpoon.ui").toggle_quick_menu()<CR>
" nnoremap <C-y> :lua require("harpoon.cmd-ui").toggle_quick_menu()<CR>


nnoremap <C-t> :Files<CR>

" terminal
tnoremap ,t <C-\><C-n>:q<CR>
tnoremap [b <C-\><C-n>:bp<CR>
tnoremap ]b <C-\><C-n>:bnext<CR>
tnoremap [t <C-\><C-n>:tabprevious<CR>
tnoremap ]t <C-\><C-n>:tabnext<CR>
tnoremap ]1 <C-\><C-n>:lua require("harpoon.ui").nav_file(1)<CR>
tnoremap ]2 <C-\><C-n>:lua require("harpoon.ui").nav_file(2)<CR>
tnoremap ]3 <C-\><C-n>:lua require("harpoon.ui").nav_file(3)<CR>
tnoremap ]4 <C-\><C-n>:lua require("harpoon.ui").nav_file(4)<CR>
tnoremap [1 <C-\><C-n>:lua require("harpoon.term").gotoTerminal(1)<CR>
tnoremap [2 <C-\><C-n>:lua require("harpoon.term").gotoTerminal(2)<CR>
tnoremap [3 <C-\><C-n>:lua require("harpoon.term").gotoTerminal(3)<CR>
tnoremap [4 <C-\><C-n>:lua require("harpoon.term").gotoTerminal(4)<CR>
tnoremap <C-w>s <C-\><C-n>:split<CR>
"tmap <C-p> <C-\><C-n>:CtrlP<CR>
tnoremap <silent> <C-p> :Telescope find_files<CR>

tnoremap <C-w><C-h> <C-\><C-n><C-w><C-h>
tnoremap <C-w><C-j> <C-\><C-n><C-w><C-j>
tnoremap <C-w><C-k> <C-\><C-n><C-w><C-k>
tnoremap <C-w><C-l> <C-\><C-n><C-w><C-l>


" ----------------------------------------------------------------------------
" EasyAlign {{{
" ----------------------------------------------------------------------------
" Start interactive EasyAlign in visual mode (e.g. vip<Enter>)
vmap <Enter> <Plug>(EasyAlign)
" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)
" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)



let g:table_mode_delete_column_map = '<Leader>tdc'
let g:table_mode_insert_column_after_map = '<Leader>tic'


" This changes the binding in popup
"inoremap <expr> <C-j> pumvisible() ? "\<C-n>" : "\<C-j>"
"inoremap <expr> <C-k> pumvisible() ? "\<C-p>" : "\<C-k>"

" au FileType javascript setlocal formatprg=prettier\ --parser\ typescript
" au FileType javascript.jsx setlocal formatprg=prettier\ --parser\ typescript
" au FileType typescript setlocal formatprg=prettier\ --parser\ typescript
" au FileType html setlocal formatprg=js-beautify\ --type\ html
" au FileType scss setlocal formatprg=prettier\ --parser\ css
" au FileType css setlocal formatprg=prettier\ --parser\ css
" " command! Prettier execute "normal! mwgggqGgg=G`w"


let g:user_emmet_settings = {
\ 'typescript' : {
\     'extends' : 'jsx',
\ },
\ 'javascript' : {
\     'extends' : 'jsx',
\ },
\}

"autocmd BufEnter * lua require'completion'.on_attach()



nmap <Leader>wj <Plug>(grammarous-move-to-info-window)
nmap <Leader>wo <Plug>(grammarous-open-info-window)
nmap <Leader>wr <Plug>(grammarous-reset)
nmap <Leader>wf <Plug>(grammarous-fixit)
nmap <Leader>wa <Plug>(grammarous-fixall)
nmap <Leader>wc <Plug>(grammarous-close-info-window)
nmap <Leader>wr <Plug>(grammarous-remove-error)
nmap <Leader>wd <Plug>(grammarous-disable-rule)
nmap <Leader>wn <Plug>(grammarous-move-to-next-error)
nmap <Leader>wp <Plug>(grammarous-move-to-previous-error)

xmap s S


map <Leader>yc      :YodeCreateSeditorFloating<CR>
map <Leader>yr :YodeCreateSeditorReplace<CR>
nmap <Leader>bd :YodeBufferDelete<cr>
imap <Leader>bd <esc>:YodeBufferDelete<cr>
" these commands fall back to overwritten keys when cursor is in split window
map <C-W>r :YodeLayoutShiftWinDown<CR>
map <C-W>R :YodeLayoutShiftWinUp<CR>
map <C-W>J :YodeLayoutShiftWinBottom<CR>
map <C-W>K :YodeLayoutShiftWinTop<CR>

vnoremap > >gv
vnoremap < <gv
