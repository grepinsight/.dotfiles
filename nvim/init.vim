set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath

set relativenumber

" vim: set foldmethod=marker foldlevel=0 nomodeline:
" ============================================================================
" VIMRC of grepinsight
" ============================================================================
" Neovim setup {{{
if has('nvim')
    autocmd CmdwinEnter * let b:coc_suggest_disable = 1
    " system clipboard
    " set clipboard+=unnamedplus

    " terminal split
    command! -nargs=* T split | terminal <args>
    command! -nargs=* VT vsplit | terminal <args>

    " get Lua syntax highlighting inside .vim files
    let g:vimsyn_embed = 'l'
endif

if v:version >= 802 && has('popupwin') || has('nvim')
    let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.6 } }
endif
" }}}
" ============================================================================
" set - settings {{{
" ============================================================================

" Vim 8 defaults
unlet! skip_defaults_vim



silent! source $VIMRUNTIME/defaults.vim
set encoding=UTF-8
filetype plugin indent on
runtime macros/matchit.vim
set pastetoggle=<F6>
set history=1000        " enable longer command mode history
set autoread            " automatically read changed file again
set autowrite
set nocompatible        " enable modern vim features
set cursorline          " highlight current line
"set lazyredraw          " redraw only when we need to.
set regexpengine=1
set showmatch           " highlight matching [{()}]
set foldenable          " enable folding
set foldlevelstart=10    " open most folds by default
"set foldmethod=indent   " fold based on indent level
set splitright          " split navigation
set hidden              " allow modified/unsaved buffers in the background.
set number              " set number
set smartcase           " if capital letter is used, then do not ignore case
set ignorecase          " If the 'ignorecase' option is on, the case of normal letters is ignored.
set shiftwidth=4        " size of an indent
set softtabstop=4       " Indentation levels very four columns"
set tabstop=4           " size of a hard tabstop number of visual spaces per TAB
set incsearch           " search as characters are entered
set hlsearch            " highlight matches
set path+=**            " provides tab-completion for all file-related tasks
set wildmenu            " display all matching files when we tab complete
set noswapfile
set conceallevel=0
set splitbelow          " put the horizontal split below
set scrolloff=2         " Minimal number of screen lines to keep above and below the cursor.
set iskeyword+=\-       " for autocompleting a word containing '-'
set background=dark     " Setting dark mode
"set clipboard=unnamed
set undofile                " Save undos after file closes
set undodir=$HOME/.vim/undo " where to save undo histories
set undolevels=10000         " How many undos
set undoreload=10000        " number of lines to save for undo
set mouse=a
" List Chars
set list                              " show whitespace
set listchars=nbsp:⦸                  " CIRCLED REVERSE SOLIDUS (U+29B8, UTF-8: E2 A6 B8)
set listchars+=tab:▷┅                 " WHITE RIGHT-POINTING TRIANGLE (U+25B7, UTF-8: E2 96 B7)
                                      " + BOX DRAWINGS HEAVY TRIPLE DASH HORIZONTAL (U+2505, UTF-8: E2 94 85)
set listchars+=extends:»  " RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK (U+00BB, UTF-8: C2 BB)
set listchars+=precedes:« " LEFT-POINTING DOUBLE ANGLE QUOTATION MARK (U+00AB, UTF-8: C2 AB)
set listchars+=trail:•    " BULLET (U+2022, UTF-8: E2 80 A2)
set nojoinspaces          " don't autoinsert two spaces after '.', '?', '!' for join command
set t_ut=                 " Make sure background doesn't break
set t_Co=256

set exrc                  " use project specific .vimrc file
" Use bash rather than sh
if &shell == 'sh'
    set shell=bash
endif

" Set completeopt to have a better completion experience
" :help completeopt
" menuone: popup even when there's only one match
" noinsert: Do not insert text until a selection is made
" noselect: Do not select, force user to select one from the menu
set completeopt=menuone,noinsert,noselect

" Avoid showing extra messages when using completion
set shortmess+=c

" }}}
" ============================================================================
" Variables {{{
" ============================================================================

" }}}
" ============================================================================
source ~/.dotfiles/nvim/autocmds.vim
source ~/.dotfiles/vim/plugins.vim
source ~/.dotfiles/vim/lsp.vim
source ~/.dotfiles/nvim/shortcuts.vim
source ~/.dotfiles/vim/functions.vim
lua <<EOF
require("init")
EOF


if has('termguicolors')
    set termguicolors
    let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
    let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
endif

let g:deus_termcolors=256


" }}}

" Functions

" ============================================================================
" Productivity Aliases {{{
" ============================================================================
" never ring a bell {{{
if exists('&belloff')
    set belloff=all
endif
" }}}

" First line

" 3rd line
function! ToggleQuickFix()
  if exists("g:qwindow")
    lclose
    unlet g:qwindow
  else
    try
      lopen 10
      let g:qwindow = 1
    catch
      echo "No Errors found!"
    endtry
  endif
endfunction

" }}}
" Switch between the last two files
" ----------------------------------------------------------------------------
" R assignment {{{
" execute "set <M-->=\033-"
" execute "set <M-m>=\033m"
inoremap <M--> <-
inoremap <M-m> %>%
" }}}
" ----------------------------------------------------------------------------
" Remapping {{{



nmap \q :nohlsearch<CR>
"nmap <leader>e :NERDTreeToggle<CR>
nmap <leader>e :Dirvish<CR>

" Use sane regexes.
nnoremap / /\v
vnoremap / /\v



command! ReadOnlyfy execute "normal! \<esc>:!chmod 440 %<CR>"

" highlight last inserted text
nnoremap gV `[v`]

"reselect after indenting
vnoremap < <gv
vnoremap > >gv
"never use Ex mode -- I never *mean* to press it
nnoremap Q <ESC>
"Escape Mode
imap jj <Esc>
"never use F1 -- I'm reaching for escape
noremap  <F1> <ESC>
noremap! <F1> <ESC>
lnoremap <F1> <ESC>
nnoremap aa pkj


" }}}
" Buffers  {{{
" close buffer
function! BufferSmartDelete()
	let num_buf = len(filter(range(1, bufnr('$')), 'buflisted(v:val)'))

	if num_buf == 1
		bd
		return
	endif
	let diffbufnr = bufnr('^fugitive:')
    if diffbufnr > -1 && &diff
        diffoff | q
        if bufnr('%') == diffbufnr
            Gedit
        endif
        setlocal nocursorbind
        return
    endif

	bp
	bd #
	if winnr() == 2
		q
	endif
endfunction

" reopen the closed buffer
nnoremap <c-s-t> :b#<CR>:e<CR>
"

" }}}
" ============================================================================
" ============================================================================
" save when losing focus {{{
autocmd FocusLost * :silent! wall
autocmd FocusLost * :wa

" Make sure Vim returns to the same line when you reopen a file.
augroup line_return
    autocmd!
    autocmd BufReadPost *
        \ if line("'\"") > 0 && line("'\"") <= line("$") |
        \     execute 'normal! g`"zvzz' |
        \ endif
augroup END

" check file change every 4 seconds ('CursorHold') and reload the buffer upon detecting change
autocmd CursorHold * checktime


" }}}
" ============================================================================
function! MarkWindowSwap() "{{{
  let g:markedWinNum = winnr()
  endfunction

function! DoWindowSwap()
  "Mark destination
  let curNum = winnr()
  let curBuf = bufnr( "%" )
  exe g:markedWinNum . "wincmd w"
  "Switch to source and shuffle dest->source
  let markedBuf = bufnr( "%" )
  "Hide and open so that we aren't prompted and keep history
  exe 'hide buf' curBuf
  "Switch to dest and shuffle source->dest
  exe curNum . "wincmd w"
  "Hide and open so that we aren't prompted and keep history
  exe 'hide buf' markedBuf
endfunction

nmap <silent> <leader>mw :call MarkWindowSwap()<CR>
nmap <silent> <leader>pw :call DoWindowSwap()<CR>


function! s:CopyMotionForType(type)
    if a:type ==# 'v'
        silent execute "normal! `<" . a:type . "`>y"
    elseif a:type ==# 'char'
        silent execute "normal! `[v`]y"
    endif
endfunction

function! s:AckMotion(type) abort
    let reg_save = @@

    call s:CopyMotionForType(a:type)

    execute "normal! :Ack! --literal " . shellescape(@@) . "\<cr>"

    let @@ = reg_save
endfunction





" crontab stuff
if $VIM_CRONTAB == "true"
    set nobackup
    set nowritebackup
endif

"Golang
let g:go_fmt_command = "goimports"

if executable('ag')
  let g:ackprg = 'ag --vimgrep'
endif

" NERDTreee
let NERDTreeIgnore = ['\.pyc$', 'db.sqlite3']
let NERDTreeChDirMode=0


" ----------------------------------------------------------------------------
" Plugin - CtrlP
" ----------------------------------------------------------------------------
let g:ctrlp_use_caching = 0
let g:ctrlp_user_command = 'fd $FD_OPTS -E "*.pdf" -E "*.Rd"'

" ----------------------------------------------------------------------------
" Plugin - Fugitive
" ----------------------------------------------------------------------------

"  - status
" Obtained from https://gist.github.com/actionshrimp/6493611
function! ToggleGStatus()
    if buflisted(bufname('.git/index'))
        bd .git/index
    else
        Gstatus
    endif
endfunction
command! ToggleGStatus :call ToggleGStatus()


" Autopair
let g:AutoPairsShortcutToggle = '<Leader>m'


" Spell file
" set spelllang=en
set spellfile=$HOME/.dotfiles/vim/spell/en.utf-8.add
" set spell
nnoremap <Leader>sp :e $HOME/.dotfiles/vim/spell/en.utf-8.add<CR>
nnoremap <Leader>ssp :mkspell! $HOME/.dotfiles/vim/spell/en.utf-8.add<CR>


" Tag for R
let g:tagbar_type_r = {
    \ 'ctagstype' : 'r',
    \ 'kinds'     : [
        \ 'f:Functions',
        \ 'g:GlobalVariables',
        \ 'v:FunctionVariables',
    \ ]
\ }

" Tag for markdown (https://github.com/majutsushi/tagbar/issues/70)
let g:tagbar_type_markdown = {
    \ 'ctagstype': 'markdown',
    \ 'ctagsbin' : '~/src/markdown2ctags/markdown2ctags.py',
    \ 'ctagsargs' : '-f - --sort=yes',
    \ 'kinds' : [
        \ 's:sections',
        \ 'i:images'
    \ ],
    \ 'sro' : '|',
    \ 'kind2scope' : {
        \ 's' : 'section',
    \ },
    \ 'sort': 0,
\ }

"" Set color scheme according to current time of day.
let hr = str2nr(strftime('%H'))
if hr <= 6 || hr >= 18
    let cs = 'dracula'
else
    let cs = 'seoul256-light'
endif

try
    let cs = 'dracula'
    execute 'colorscheme '.cs
catch
endtry

"=================================================================
" Plugin - Vim Test
"=================================================================
let test#python#runner = 'pytest'
"let test#python#pytest#options = '-s -v'
let test#python#pytest#options = ''

let g:test#preserve_screen = 1
let test#strategy = "dispatch"


function! s:goyo_enter()
  silent !tmux set status off
  silent !tmux list-panes -F '\#F' | grep -q Z || tmux resize-pane -Z
  set noshowmode
  set noshowcmd
  set scrolloff=999
  set nospell
  set norelativenumber
  Limelight
  let b:coc_suggest_disable = 1
  " ...
endfunction

function! s:goyo_leave()
  silent !tmux set status on
  silent !tmux list-panes -F '\#F' | grep -q Z && tmux resize-pane -Z
  set showmode
  set showcmd
  set scrolloff=2
  set spell
  set relativenumber
  Limelight!
  let b:coc_suggest_disable = 0
  " ...
endfunction

autocmd! User GoyoEnter nested call <SID>goyo_enter()
autocmd! User GoyoLeave nested call <SID>goyo_leave()

" Plugin - jedi-vim ----
" to play nicely with YCM
"let g:jedi#completions_enabled = 0

" }}}

" }}}
" ============================================================================
" Plugin Specific Settings {{{
" ============================================================================
" ----------------------------------------------------------------------------
" # coc {{{
" ----------------------------------------------------------------------------

autocmd FileType vimwiki let b:coc_suggest_disable = 1
let g:coc_global_extensions = ['coc-emoji', 'coc-eslint', 'coc-prettier', 'coc-tsserver', 'coc-tslint', 'coc-tslint-plugin', 'coc-css', 'coc-json', 'coc-pyls', 'coc-yaml']


function! ShowDocumentation()
  if &filetype == 'vim'
    execute 'h '.expand('<cWORD>')
  else
    call CocAction('doHover')
  endif
endfunction
" Use K for show documentation in preview window
nnoremap <silent> <leader>K :call ShowDocumentation()<CR>

" Highlight symbol under cursor on CursorHold
"autocmd CursorHold * silent call CocActionAsync('highlight')
nmap gs <Plug>(coc-git-chunkinfo)

" Create mappings for function text object, requires document symbols feature of languageserver.
xmap if <Plug>(coc-funcobj-i)
xmap af <Plug>(coc-funcobj-a)
omap if <Plug>(coc-funcobj-i)
omap af <Plug>(coc-funcobj-a)

function! CocSuggestionToggle()
    if !exists("b:coc_suggest_disable")
        let b:coc_suggest_disable = 1
        echo("Coc Suggestion Disabled!")
    elseif b:coc_suggest_disable
        let b:coc_suggest_disable = 0
        echo("Coc Suggestion Enabled!")
    else
        let b:coc_suggest_disable = 1
        echo("Coc Suggestion Disabled!")
    endif
endfunction


nnoremap yococ :call CocSuggestionToggle()<CR>

inoremap <expr> <cr> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"
" }}}
" ----------------------------------------------------------------------------
" Pandoc {{{
" ----------------------------------------------------------------------------
let g:pandoc#modules#disabled = ['formatting']
" }}}
" ----------------------------------------------------------------------------
" Whichkey {{{
" ----------------------------------------------------------------------------
nnoremap <silent> <Leader> :<c-u>WhichKey  '\'<CR>
nnoremap <silent> , :<c-u>WhichKey  ','<CR>
" }}}
" }}}
" ----------------------------------------------------------------------------
" Plugin - vim-sneak {{{
" ----------------------------------------------------------------------------
let g:sneak#s_next = 1

" }}}

" ----------------------------------------------------------------------------
" Plugin - vim-surround {{{
" ----------------------------------------------------------------------------
let g:surround_45 = "``` \r ```"
" }}}
" ----------------------------------------------------------------------------
" Plugin - vim-go {{{
" ----------------------------------------------------------------------------
let g:go_version_warning = 0
" }}}
" ----------------------------------------------------------------------------
" Plugin - fzf {{{
" ----------------------------------------------------------------------------
nnoremap <F4> :call fzf#run(fzf#wrap({'source': 'fd $FD_OPTS . $HOME $HOME/.dotfiles $HOME/.vim', 'sink': 'edit'}))<CR>
inoremap <F4> :call fzf#run(fzf#wrap({'source': 'fd $FD_OPTS . $HOME $HOME/.dotfiles $HOME/.vim', 'sink': 'edit'}))<CR>
" nnoremap <F4> :call fzf#run(fzf#wrap({'source': 'fd --no-ignore $FD_OPTS .', 'sink': 'edit'}))<CR>
" inoremap <F4> :call fzf#run(fzf#wrap({'source': 'fd --no-ignore $FD_OPTS .', 'sink': 'edit'}))<CR>
nnoremap <F5> :call fzf#run(fzf#wrap({'source': 'fd --no-ignore $FD_OPTS . $HOME', 'sink': 'edit'}))<CR>
inoremap <F5> :call fzf#run(fzf#wrap({'source': 'fd --no-ignore $FD_OPTS . $HOME', 'sink': 'edit'}))<CR>
" }}}

" ----------------------------------------------------------------------------
" vim-after-object {{{
" ----------------------------------------------------------------------------
" }}}
" ----------------------------------------------------------------------------
" Plugin - Calendar {{{
" ----------------------------------------------------------------------------
let g:calendar_google_calendar = 1
let g:calendar_google_task = 1
" }}}
" ----------------------------------------------------------------------------
" Ale {{{
" ----------------------------------------------------------------------------

let g:ale_linters={'python': ['mypy', 'pydocstyle'], 'r': ['lintr'], 'wdl': ['wdl-linter'] }
let g:ale_fixers = {'python': ['yapf'], 'r': ['styler'], 'rmd': ['styler']}
let g:ale_python_flake8_options = "--ignore=E501"
let g:ale_python_pydocstyle_options = "--ignore=E501,D203,D221,D407 --convention=google"

autocmd FileType r let g:ale_fix_on_save = 1
autocmd FileType rmd let g:ale_fix_on_save = 1
let g:ale_python_mypy_options="--ignore-missing-imports"


"let g:ale_set_loclist = 0
"let g:ale_set_quickfix = 1
" let g:ale_open_list = 1
"nnoremap ]al <Plug>(ale_next)
"nnoremap ]al <Plug>(ale_previous)
" }}}
" ----------------------------------------------------------------------------
" Ultistnip {{{
" ----------------------------------------------------------------------------

" }}}
" ----------------------------------------------------------------------------
" Wordy {{{
" ----------------------------------------------------------------------------
noremap  <silent> <F9> :<C-u>NextWordy<cr>
xnoremap <silent> <F9> :<C-u>NextWordy<cr>
inoremap <silent> <F9> <C-o>:NextWordy<cr>

let g:wordy#ring = [
  \ 'alby',
  \ 'weak',
  \ ['being', 'passive-voice', ],
  \ 'business-jargon',
  \ 'weasel',
  \ 'puffery',
  \ ['problematic', 'redundant', ],
  \ ['colloquial', 'idiomatic', 'similies', ],
  \ 'art-jargon',
  \ ['contractions', 'opinion', 'vague-time', 'said-synonyms', ],
  \ 'adjectives',
  \ 'adverbs',
  \ ]

" }}}
" ----------------------------------------------------------------------------
" Thesaurus {{{
" ----------------------------------------------------------------------------
let g:tq_enabled_backends=["mthesaur_txt"]

" }}}
" ----------------------------------------------------------------------------
"  Vimpector {{{
" ----------------------------------------------------------------------------
let g:vimspector_enable_mappings = 'VISUAL_STUDIO'

" }}}
" ============================================================================
" Etc {{{
" ============================================================================
"
" If two files are loaded, switch to the alternate file, then back.
" That sets # (the alternate file).
if argc() == 2
  n
  e #
endif

function! RenameFile() "{{{
    let old_name = expand('%')
    let new_name = input('New file name: ', expand('%'), 'file')
    if new_name != '' && new_name != old_name
        exec ':saveas ' . new_name
        exec ':silent !rm ' . old_name
        redraw!
    endif
endfunction
nnoremap <F2> :call RenameFile()<cr>

" ============================================================================
" Editing Setting {{{
" ============================================================================

" * Sane Line Joins
" when joining multiple commented lines, comment symbol such as '#' will
" be removed  seamlessly.
if v:version > 703 || v:version == 703 && has('patch541')
    set formatoptions+=j
endif
""" }}}
if exists('+colorcolumn')
  " Highlight up to 255 columns (this is the current Vim max) beyond 'textwidth'
  let &l:colorcolumn='+' . join(range(0, 254), ',+')
endif
" ============================================================================
" Whitespace Decoration {{{
" View white space with special characters
"

" }}}
" ============================================================================
" ============================================================================
" Leader Keys {{{
nnoremap <Leader>fw :FixWhitespace<CR>
" }}}
" ============================================================================
" ============================================================================
" Follow symlinks when opening a file  {{{
" Sources:
"  - https://github.com/tpope/vim-fugitive/issues/147#issuecomment-7572351
"  - http://www.reddit.com/r/vim/comments/yhsn6/is_it_possible_to_work_around_the_symlink_bug/c5w91qw
" Echoing a warning does not appear to work:
"   echohl WarningMsg | echo "Resolving symlink." | echohl None |
function! MyFollowSymlink(...)
  let fname = a:0 ? a:1 : expand('%')
  if getftype(fname) != 'link'
    return
  endif
  let resolvedfile = fnameescape(resolve(fname))
  exec 'file ' . resolvedfile
endfunction
command! FollowSymlink call MyFollowSymlink()

autocmd BufReadPost * call MyFollowSymlink(expand('<afile>'))

" }}}
" ============================================================================

" ============================================================================
" Variable Settings {{{
"
let g:slime_target = "tmux"
let g:slime_default_config = {"socket_name": get(split($TMUX, ","), 0), "target_pane": ":.2"}

let vim_markdown_preview_hotkey='<C-m>'
let vim_markdown_preview_github=1
let vim_markdown_preview_browser='Google Chrome'


let g:vim_markdown_conceal = 0 "make markdown sane

let g:vimwiki_folding='expr'
"
" Make python <> vim-slime play well together
let g:slime_python_ipython = 1

" Vimtex
let g:vimtex_view_method = 'skim'

" }}}
" ============================================================================ "

" ============================================================================ "
" Leader keys {{{
" Useful shortcuts
"
inoremap \date <C-R>=strftime("%Y-%m-%d")<CR>
inoremap \dow <C-R>=strftime("%A")<CR>
inoremap \time <C-R>=strftime("%Y-%m-%dT%H:%M:%S")<CR>
inoremap \iso <C-R>=strftime("%FT%T%z")<CR>
inoremap \todo [ ]
inoremap \td [ ]
inoremap \qtd [ ] :question:
nnoremap \nosym :e <C-R>=resolve(expand("%"))<CR>
noremap <silent> <Leader>tme :TableModeEnable<CR>
noremap <silent> <Leader>one :e $MY_ONE_ON_ONE<CR>

nnoremap <Leader>def :e $HOME/vimwiki/Definitions.wiki<CR>
nnoremap <Leader>fs :!fs<CR>
nnoremap <Leader>h1 yypVr=
nnoremap <Leader>h2 yypVr-
nnoremap <Leader>k :VimwikiToggleListItem<CR>
nnoremap <Leader>ma :make -C <C-R>=GitRootFromDir(expand('%:p:h'))<CR>
nnoremap <Leader>ml :r !make lint <CR>
nnoremap <Leader>pf :%s/<F2[23]>//g <CR>
nnoremap <Leader>rmd :!Rscript -e "setwd(Sys.getenv('PWD')); rmarkdown::render('%')" && open %:r.html <CR>
nnoremap <Leader>rtt :!clear; Rscript -e "setwd(Sys.getenv('PWD')); devtools::load_all();testthat::test_file('%')"<CR>
nnoremap <Leader>tag :!tmsu tag %
nnoremap <Leader>tts :%s/\t/    /g<CR> " tab to space
nnoremap <Leader>vf :%s/ / /g <CR>

nnoremap TT :wall<CR>: !tmux kill-pane<CR>
" }}}
" ============================================================================

" ============================================================================
" Korean {{{
nnoremap ㅏ k
nnoremap ㅓ j
nnoremap ㅑ i
nnoremap ㅐ o
nnoremap ㅒ O
nnoremap ㅇㅇ dd
" }}}
" ============================================================================

" ============================================================================
" FZF!!!  {{{
inoremap <expr> <c-x><c-k> fzf#complete('cat /usr/share/dict/words $HOME/.dotfiles/vim/spell/en.utf-8.add 2>/dev/null')
" }}}
" ============================================================================

" ============================================================================
" resize panes {{{
nnoremap <silent> <Right> :vertical resize +5<cr>
nnoremap <silent> <Left> :vertical resize -5<cr>
nnoremap <silent> <Up> :resize +5<cr>
nnoremap <silent> <Down> :resize -5<cr>
" automatically rebalance windows on vim resize
autocmd VimResized * :wincmd =

" }}}
" ============================================================================

" qq to record, Q to replay
nnoremap Q @q

" ============================================================================
" tmux related {{{
" ----------------------------------------------------------------------------
function! s:tmux_send(content, dest) range
  let dest = empty(a:dest) ? input('To which pane? ') : a:dest
  let tempfile = tempname()
  call writefile(split(a:content, "\n", 1), tempfile, 'b')
  call system(printf('tmux load-buffer -b vim-tmux %s \; paste-buffer -d -b vim-tmux -t %s',
        \ shellescape(tempfile), shellescape(dest)))
  call delete(tempfile)
endfunction

function! s:tmux_map(key, dest)
  execute printf('nnoremap <silent> %s "tyy:call <SID>tmux_send(@t, "%s")<cr>', a:key, a:dest)
  execute printf('xnoremap <silent> %s "ty:call <SID>tmux_send(@t, "%s")<cr>gv', a:key, a:dest)
endfunction

call s:tmux_map('<leader>tt', '')
call s:tmux_map('<leader>th', '.left')
call s:tmux_map('<leader>tj', '.bottom')
call s:tmux_map('<leader>tk', '.top')
call s:tmux_map('<leader>tl', '.right')
call s:tmux_map('<leader>ty', '.top-left')
call s:tmux_map('<leader>to', '.top-right')
call s:tmux_map('<leader>tn', '.bottom-left')
call s:tmux_map('<leader>t.', '.bottom-right')

" }}}
" ============================================================================

" ----------------------------------------------------------------------------
" #!! | Shebang
" ----------------------------------------------------------------------------
inoreabbrev <expr> #!! "#!/usr/bin/env" . (empty(&filetype) ? '' : ' '.&filetype)


function! s:root()
  let root = systemlist('git rev-parse --show-toplevel')[0]
  if v:shell_error
    echo 'Not in git repo'
  else
    execute 'lcd' root
    echo 'Changed directory to: '.root
  endif
endfunction
command! Root call s:root()



function! s:hl()
  " echo synIDattr(synID(line('.'), col('.'), 0), 'name')
  echo join(map(synstack(line('.'), col('.')), 'synIDattr(v:val, "name")'), '/')
endfunction
command! HL call <SID>hl()
" ----------------------------------------------------------------------------
" Todo
" ----------------------------------------------------------------------------
function! s:todo() abort
  let entries = []
  for cmd in ['git grep -niI -e TODO -e FIXME -e XXX -e "\[ \]" 2> /dev/null',
            \ 'grep -rniI -e TODO -e FIXME -e XXX -e "\[ \]" * 2> /dev/null']
    let lines = split(system(cmd), '\n')
    if v:shell_error != 0 | continue | endif
    for line in lines
      let [fname, lno, text] = matchlist(line, '^\([^:]*\):\([^:]*\):\(.*\)')[1:3]
      call add(entries, { 'filename': fname, 'lnum': lno, 'text': text })
    endfor
    break
  endfor

  if !empty(entries)
    call setqflist(entries)
    copen
  endif
endfunction
command! Todo call s:todo()
nnoremap <Leader>T :call s:todo()


" ----------------------------------------------------------------------------
" <Leader>?/! | Google it / Feeling lucky
" ----------------------------------------------------------------------------
function! s:goog(pat, lucky)
  let q = '"'.substitute(a:pat, '["\n]', ' ', 'g').'"'
  let q = substitute(q, '[[:punct:] ]',
       \ '\=printf("%%%02X", char2nr(submatch(0)))', 'g')
  call system(printf('open "https://www.google.com/search?%sq=%s"',
                   \ a:lucky ? 'btnI&' : '', q))
endfunction

nnoremap <leader>? :call <SID>goog(expand("<cWORD>"), 0)<cr>
nnoremap <leader>! :call <SID>goog(expand("<cWORD>"), 1)<cr>
xnoremap <leader>? "gy:call <SID>goog(@g, 0)<cr>gv
xnoremap <leader>! "gy:call <SID>goog(@g, 1)<cr>gv

" ----------------------------------------------------------------------------
" switch.vim
" ----------------------------------------------------------------------------
let g:switch_mapping = '-'
let g:switch_custom_definitions = [
\   ['MON', 'TUE', 'WED', 'THU', 'FRI'],
\   ['TRUE', 'FALSE']
\ ]


" Automatic rename of tmux window
" if exists('$TMUX') && !exists('$NORENAME')
"     au BufEnter * if empty(&buftype) | call system('tmux rename-window '.expand('%:t:S')) | endif
"     au VimLeave * call system('tmux set-window automatic-rename on')
" endif

autocmd FileType r vnoremap af :<C-U>silent! normal! [[vt{%<CR>
autocmd FileType r omap af :normal Vaf<CR>

map <leader>C :CtrlPClearCache<cr>

command! -bang -nargs=* Rg
  \ call fzf#vim#grep(
  \   'rg -g "!*.pkl" -g "!*.Rd" --column --line-number --no-heading --color=always --smart-case '.shellescape(<q-args>), 1,
  \   <bang>0 ? fzf#vim#with_preview('up:60%')
  \           : fzf#vim#with_preview('right:50%:hidden', '?'),
  \   <bang>0)

command! -bang -nargs=* Foc
  \ call fzf#vim#grep(
  \   'rg -g "!*.pkl" --column --line-number -H --color=always --smart-case "^#" '.shellescape(expand('%')), 1,
  \   <bang>0 ? fzf#vim#with_preview('up:60%')
  \           : fzf#vim#with_preview('right:50%:hidden', '?'),
  \   <bang>0)

command! -bang -nargs=* J
  \ call fzf#vim#grep(
  \   'rg -g "!*.pkl" --column --line-number -H --color=always --smart-case "^\`\`\`" '.shellescape(expand('%')), 1,
  \   <bang>0 ? fzf#vim#with_preview('up:60%')
  \           : fzf#vim#with_preview('right:50%:hidden', '?'),
  \   <bang>0)


" Zoom / Restore window.
function! s:ZoomToggle() abort
    if exists('t:zoomed') && t:zoomed
        call system("tmux resize-pane -Z")
        execute t:zoom_winrestcmd
        let t:zoomed = 0
        "execute 'silent ' . '!tmux resize-pane -Z'
    else
        let t:zoom_winrestcmd = winrestcmd()
        call system("tmux resize-pane -Z")
        resize
        vertical resize
        let t:zoomed = 1
        "execute 'silent ' . '!tmux resize-pane -Z'

    endif
endfunction
command! ZoomToggle call s:ZoomToggle()

let g:tagbar_type_vimwiki = {
            \   'ctagstype':'vimwiki'
            \ , 'kinds':['h:header']
            \ , 'sro':'&&&'
            \ , 'kind2scope':{'h':'header'}
            \ , 'sort':0
            \ , 'ctagsbin':"$HOME/src/productivity/tagbar_vimwiki.py"
            \ , 'ctagsargs': 'markdown'
            \ }

let g:tagbar_type_rmd = {
          \   'ctagstype':'rmd'
          \ , 'kinds':['h:header', 'c:chunk', 'f:function', 'v:variable']
          \ , 'sro':'&&&'
          \ , 'kind2scope':{'h':'header', 'c':'chunk', 'f':'function', 'v':'variable'}
          \ , 'sort':0
          \ , 'ctagsbin':"$HOME/src/productivity/tagbar_rmarkdown.py"
          \ , 'ctagsargs':''
          \ }

let g:sneak#use_ic_scs = 1
inoremap <Leader>fix <c-g>u<Esc>[s1z=`]a<c-g>u
inoremap <Leader>sp <c-g>u<Esc>[s1z=`]a<c-g>u

nmap <Leader>ha <Plug>GitGutterStageHunk :w<CR> :e<CR>
nmap <Leader>hr <Plug>GitGutterUndoHunk
nnoremap <Leader>vpn :!anyconnect <CR>


nmap <Leader>ju <Plug>(VcsJump)


nnoremap <Leader>pyan :!pyan % --dot -c -e \| dot -Tpng > <C-R>=expand('%:r')<CR>.png && open <C-R>=expand('%:r')<CR>.png <CR>
nnoremap <Leader>tgf :!pyan % --tgf -c -e  > <C-R>=expand('%:r')<CR>.tgf<CR>


if filereadable(expand("~/.vimrc_work"))
    source ~/.vimrc_work
endif
"UltiSnipsAddFiletypes Rmd.R
"
"

function! GitRootFromDir(myarg)
    let cmd ='cd '. a:myarg .' && '. 'git rev-parse --show-toplevel '
    let root = substitute(system(cmd), '\n', '', 'g')
    return root
endfunction


" ============================================================================
" YOT YOO {{{
nnoremap yot :if exists("g:syntax_on") <Bar>
    \   syntax off <Bar>
    \ else <Bar>
    \   syntax enable <Bar>
    \ endif <CR>

nnoremap yoo :if &conceallevel==2<Bar>
    \   set conceallevel=0<Bar>
    \ else <Bar>
    \   set conceallevel=2<Bar>
    \ endif <CR>


nnoremap yof :if &foldlevelstart==0<Bar>
    \   set foldlevel=10<Bar>
    \   set foldlevelstart=10<Bar>
    \ elseif &foldlevelstart==10<Bar>
    \   set foldlevel=0<Bar>
    \   set foldlevelstart=0<Bar>
    \ endif <CR><CR>
" }}}
" ============================================================================


" au FileWritePost * :redraw!
" au TermResponse * :redraw!
" au TextChanged * :redraw!
" au QuickFixCmdPre * :redraw!
" au QuickFixCmdPost * :redraw!


" ============================================================================
" Next fold {{{
nnoremap <silent> <leader>zj :call NextClosedFold('j')<cr>
nnoremap <silent> <leader>zk :call NextClosedFold('k')<cr>
function! NextClosedFold(dir)
    let cmd = 'norm!z' . a:dir
    let view = winsaveview()
    let [l0, l, open] = [0, view.lnum, 1]
    while l != l0 && open
        exe cmd
        let [l0, l] = [l, line('.')]
        let open = foldclosed(l) < 0
    endwhile
    if open
        call winrestview(view)
    endif
endfunction
" }}}
" ============================================================================



let g:SimpylFold_fold_import = 1

set autoindent
set copyindent

" let g:LanguageClient_serverCommands = {
"     \ 'r': ['R', '--slave', '-e', 'languageserver::run()'],
"     \ 'rmd': ['R', '--slave', '-e', 'languageserver::run()'],
"     \ }

"let g:signify_vcs_list = [ 'git', 'hg' ]


let g:ctrlp_working_path_mode = 0


" ============================================================================
" NVim R {{{

let R_args = ['--no-save', '--quiet']

" press -- to have Nvim-R insert the assignment operator: <-
let R_assign_map = "--"

" set a minimum source editor width
let R_min_editor_width = 80

" make sure the console is at the bottom by making it really wide
let R_rconsole_width = 1000

" show arguments for functions during omnicompletion
let R_show_args = 1

" Don't expand a dataframe to show columns by default
let R_objbr_opendf = 0

" Press the space bar to send lines and selection to R console
"nmap <Space> <Plug>RDSendParagraph


" Filetype specific
autocmd FileType r nmap <Space> :call SendParagraphToR("echo", "down")<CR>
autocmd FileType r vmap <Space> :call SendSelectionToR("echo", "stay", "normal")<CR>


" Mac iTerm: custom map control-enter to something unique. Maltese cross in this case.
autocmd FileType r nnoremap <silent> ✠ :call SendLineToR("stay")<CR><Esc><Home><Down>
autocmd FileType r nnoremap <silent> œ :call SendParagraphToR("echo", "stay")<CR>
autocmd FileType r inoremap <silent> ✠ <Esc>:call SendLineToR("stay")<CR><Esc>A<DOWN>
autocmd FileType r inoremap <silent> œ <Esc>:call SendParagraphToR("echo", "stay")<CR>A
autocmd FileType r vnoremap ✠ :call SendSelectionToR("echo", "stay", "normal")<CR>

autocmd FileType rmd nmap <Space> :call SendParagraphToR("echo", "down")<CR>
autocmd FileType rmd vmap <Space> :call SendSelectionToR("echo", "stay", "normal")<CR>
autocmd FileType rmd nnoremap <silent> ✠ :call SendLineToR("stay")<CR><Esc><Home><Down>
autocmd FileType rmd nnoremap <silent> œ :call SendParagraphToR("echo", "stay")<CR>
autocmd FileType rmd inoremap <silent> ✠ <Esc>:call SendLineToR("stay")<CR><Esc>A<DOWN>
autocmd FileType rmd inoremap <silent> œ <Esc>:call SendParagraphToR("echo", "stay")<CR>A
"autocmd FileType rmd vnoremap ✠ :call SendSelectionToR("echo", "stay", "normal")<CR>

let R_assign = 0
if has('terminal')
	tnoremap <C-k> <C-w>k
	tnoremap <C-h> <C-w>h
	tnoremap <C-l> <C-w>l
	tnoremap b] <C-w>N:TmuxNavigateUp<cr>:bnext<CR>

	" For R package development
	nnoremap <Leader>rll :RSend devtools::load_all()<CR>
	tnoremap <Leader>rll <C-w>N:RSend devtools::load_all()<CR>i
	tmap <C-j> <C-w>N:TmuxNavigateDown<cr>
	tmap <C-z> <C-w>N<C-z>
endif

" }}}



function! GotoJump()
  jumps
  let j = input("Please select your jump: ")
  if j != ''
    let pattern = '\v\c^\+'
    if j =~ pattern
      let j = substitute(j, pattern, '', 'g')
      execute "normal " . j . "\<c-i>"
    else
      execute "normal " . j . "\<c-o>"
    endif
  endif
endfunction

command! Jump :call GotoJump()


function! JumpToLastEdit()

    echom expand('%:p')
    let last_two_commits = systemlist("git log -n 2 --oneline -- " .  expand('%:p'))
    echom last_two_commits

    let hash1= split(last_two_commits[0], ' ' )[0]
    let hash2= split(last_two_commits[1], ' ' )[0]

    echom hash1
    echom hash2

    let cmd="VcsJump diff " . hash2 . ".." . hash1
    echom cmd

    execute cmd
endfunction
command! JumpToLastEdit :call JumpToLastEdit()

" ============================================================================
" # SortUnfold {{{

":[range]SortUnfolded[!] [i][u][r][n][x][o] [/{pattern}/]
"            Sort visible lines in [range]. Lines inside closed folds
"            are kept intact; sorting is done only on the first line
"            of the fold; the other lines inside the fold move with
"            it as a unit.
" Copyright: (C) 2012 Ingo Karkat
"   The VIM LICENSE applies to this scriptlet; see ':help copyright'.
" Inspiration:
"   http://stackoverflow.com/questions/13554191/sorting-vim-folds
function! s:ErrorMsg( text )
    let v:errmsg = a:text
    echohl ErrorMsg
    echomsg v:errmsg
    echohl None
endfunction
function! s:ExceptionMsg( exception )
    " v:exception contains what is normally in v:errmsg, but with extra
    " exception source info prepended, which we cut away.
    call s:ErrorMsg(substitute(a:exception, '^Vim\%((\a\+)\)\=:', '', ''))
endfunction
function! s:GetClosedFolds( startLnum, endLnum )
"******************************************************************************
"* PURPOSE:
"   Determine the ranges of closed folds within the passed range.
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   None.
"* INPUTS:
"   a:startLnum First line of the range.
"   a:endLnum   Last line of the range.
"* RETURN VALUES:
"   List of [foldStartLnum, foldEndLnum] elements.
"******************************************************************************
    let l:folds = []
    let l:lnum = a:startLnum
    while l:lnum <= a:endLnum
    let l:foldEndLnum = foldclosedend(l:lnum)
    if l:foldEndLnum == -1
        let l:lnum += 1
    else
        call add(l:folds, [l:lnum, l:foldEndLnum])
        let l:lnum = l:foldEndLnum + 1
    endif
    endwhile
    return l:folds
endfunction
function! s:Join( lnum, isKeepSpace, separator )
    if a:isKeepSpace
    let l:lineLen = len(getline(a:lnum))
    execute a:lnum . 'join!'
    if ! empty(a:separator)
        if len(getline(a:lnum)) == l:lineLen
        " The next line was completely empty.
        execute 'normal! A' . a:separator . "\<Esc>"
        else
        call cursor(a:lnum, l:lineLen + 1)
        execute 'normal! i' . a:separator . "\<Esc>"
        endif
    endif
    else
    execute a:lnum
    normal! J
    if ! empty(a:separator)
        execute 'normal! ciw' . a:separator . "\<Esc>"
    endif
    endif
endfunction
function! s:JoinFolded( isKeepSpace, startLnum, endLnum, separator )
    let l:folds = s:GetClosedFolds(a:startLnum, a:endLnum)
    if empty(l:folds)
    return [0, 0]
    endif

    let l:joinCnt = 0
    let l:save_foldenable = &foldenable
    set nofoldenable
    try
    for [l:foldStartLnum, l:foldEndLnum] in reverse(l:folds)
        let l:cnt = l:foldEndLnum - l:foldStartLnum
        for l:i in range(l:cnt)
        call s:Join(l:foldStartLnum, a:isKeepSpace, a:separator)
        endfor
        let l:joinCnt += l:cnt
    endfor
    finally
    let &foldenable = l:save_foldenable
    endtry
    return [len(l:folds), l:joinCnt]
endfunction
function! s:SortUnfolded( bang, startLnum, endLnum, sortArgs )
    let [l:foldNum, l:joinCnt] = s:JoinFolded(1, a:startLnum, a:endLnum, "\<C-V>\<C-J>")
    if empty(l:foldNum)
    call s:ErrorMsg('No folds found')
    return
    endif

    let l:reducedEndLnum = a:endLnum - l:joinCnt
    try
    execute printf('%d,%dsort%s %s', a:startLnum, l:reducedEndLnum, a:bang, a:sortArgs)
    catch /^Vim\%((\a\+)\)\=:E/
    call s:ExceptionMsg(v:exception)
    finally
    silent execute printf('%d,%dsubstitute/\%%d0/\r/g', a:startLnum, l:reducedEndLnum)
    endtry
endfunction
command! -bang -range=% -nargs=* SortUnfolded call setline(<line1>, getline(<line1>)) | call s:SortUnfolded('<bang>', <line1>, <line2>, <q-args>)



" }}}
" ============================================================================

let g:cmdline_app = {'python':  'ipython'}
let cmdline_map_send_paragraph = '<Space>'

autocmd BufNewFile *.Rmd 0r ~/src/templates/report-template.Rmd



" Spacemacs compatible

if has('nvim')
    inoremap <D-v> <C-r>+
    nnoremap <D-v> "+p
    vnoremap <D-v> "+p
else
    autocmd TerminalOpen * if bufwinnr('') > 0 | setlocal nobuflisted | endif
endif


" vim-highlightedyank: duration
let g:highlightedyank_highlight_duration = 200


" }}}
" ============================================================================
" Leader Key Mappings {{{
source ~/.dotfiles/vim/leaders.vim
source ~/.dotfiles/vim/remaps.vim
source ~/.dotfiles/vim/commands.vim
" }}}
" ============================================================================
let g:floaterm_gitcommit = 'floaterm'

function! s:setup_git_messenger_popup() abort
    " Your favorite configuration here

    " For example, set go back/forward history to <C-o>/<C-i>
    nmap <buffer><C-j> o
    nmap <buffer><C-k> O
endfunction
autocmd FileType gitmessengerpopup call s:setup_git_messenger_popup()

let g:node_host_prog = '/usr/local/bin/neovim-node-host'


autocmd BufEnter *.rules set filetype=hledgerrules




function! s:check_back_space() abort
    let col = col('.') - 1
    return !col || getline('.')[col - 1]  =~ '\s'
endfunction

" ----------
