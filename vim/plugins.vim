" vim: set foldmethod=marker foldlevel=0 nomodeline:
" ============================================================================
" Automatically install Vim Plug {{{
" ----------------------------------------------------------------------------
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif
" }}}
"
call plug#begin('~/.vim/plugged')

" Plug 'kassio/neoterm'
Plug 'ms-jpq/coq_nvim', {'branch': 'coq'}
Plug 'ms-jpq/coq.artifacts', {'branch': 'artifacts'}

" " Colorschemes
"Plug 'dracula/vim', { 'as': 'dracula' }
Plug 'morhetz/gruvbox'
" Plug 'sainnhe/gruvbox-material'
" Plug 'EdenEast/nightfox.nvim'
" autocmd vimenter * ++nested colorscheme nightfox
autocmd vimenter * ++nested colorscheme gruvbox
Plug 'mhinz/vim-startify'
"Plug 'rbong/vim-crystalline'
Plug 'vim-airline/vim-airline'
    let g:airline#extensions#tabline#enabled = 1
  "let g:airline#extensions#disable_rtp_load = 1
" Plug 'cormacrelf/vim-colors-github'
Plug 'norcalli/nvim-colorizer.lua'
autocmd FileType r lua require'colorizer'.setup()
autocmd FileType python lua require'colorizer'.setup()

" " Looks / Status
" " Start page
" Plug 'ryanoasis/vim-devicons'

" Session Management
" Plug 'tpope/vim-obsession'
Plug 'airblade/vim-rooter'
    let g:rooter_silent_chdir = 1
    let g:startify_change_to_dir = 0
    let g:rooter_change_directory_for_non_project_files = 'current'
    let g:rooter_patterns = ['.git', 'Makefile', '.prjroot', '.hg']

" Javscript, typescript
Plug 'maxmellon/vim-jsx-pretty'
" Plug 'jiangmiao/auto-pairs'
Plug 'pangloss/vim-javascript'
Plug 'alvan/vim-closetag'
let g:closetag_filenames = '*.html,*.xhtml,*.phtml,*.tsx'
let g:closetag_xhtml_filenames = '*.xhtml,*.jsx,*.tsx'
let g:closetag_filetypes = 'html,xhtml,phtml,tsx'
let g:closetag_xhtml_filetypes = 'xhtml,jsx,typescriptreact,tsx'
let g:closetag_shortcut = '>'







" Plug "mlaursen/vim-react-snippets"
Plug 'prettier/vim-prettier'
Plug 'mattn/emmet-vim'
" Plug 'jose-elias-alvarez/nvim-lsp-ts-utils'
" Plug 'jose-elias-alvarez/null-ls.nvim'

"Buffer Management
Plug 'vim-scripts/BufOnly.vim'

" " Files related
Plug 'justinmk/vim-dirvish'
Plug 'kyazdani42/nvim-web-devicons' " for file icons
Plug 'kyazdani42/nvim-tree.lua'

Plug 'tpope/vim-eunuch'

" " Search files
Plug 'grepinsight/ctrlp.vim' " my mutated version that supports vimwiki tag search
"Plug 'grepinsight/fzf', { 'dir': '~/.fzf', 'do': './install --all'  }
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all'  }
Plug 'junegunn/fzf.vim'
" Plug 'junegunn/vim-peekaboo'
" Plug 'mileszs/ack.vim'
" Plug 'google/vim-searchindex'
" Plug 'bronson/vim-visual-star-search'

" " Navigation
" Plug 'Lokaltog/vim-easymotion'
Plug 'justinmk/vim-sneak'
Plug 'preservim/tagbar'
Plug 'liuchengxu/vista.vim'
Plug 'tpope/vim-projectionist'

" let g:projectionist_heuristics= {
"     \ '*': {
"     \   'R/*.R': {
"     \     'alternate': 'tests/testthat/test-{basename}.R'
"     \    },
"     \   'tests/testthat/test-*.R': {
"     \     'alternate': 'R/{basename}.R'
"     \   }
"     \ },
"     \ 'pyproject.toml': {
"     \   '*.py': {
"     \     'alternate': 'test_{basename}.py'
"     \    },
"     \ }
"     \ }

Plug 'tpope/vim-unimpaired'
" Plug 'christoomey/vim-tmux-navigator'

" Folding
Plug 'tmhedberg/SimpylFold'
let g:SimpylFold_docstring_preview = 1
Plug 'masukomi/vim-markdown-folding'
" Plug 'Konfekt/FastFold'
Plug 'matze/vim-tex-fold'
Plug 'lambdalisue/fern.vim'

" Editing
Plug 'tpope/vim-surround'              " surround text objects with whatever
Plug 'AndrewRadev/splitjoin.vim'
Plug 'junegunn/vim-easy-align'         " perform alignment easier
" Plug 'tommcdo/vim-exchange'            " swap two text objects
" Plug 'michaeljsmith/vim-indent-object' " text object
Plug 'tpope/vim-repeat'
"Plug 'terryma/vim-multiple-cursors'
" Plug 'junegunn/vim-after-object'
    silent! if has_key(g:plugs, 'vim-after-object')
      autocmd VimEnter * silent! call after_object#enable('=', ':', '#', ' ', '|')
    endif
Plug 'sjl/gundo.vim'
  " python3 support
  let g:gundo_prefer_python3 = 1

Plug 'tpope/vim-commentary'
Plug 'Yggdroot/indentLine'
Plug 'dhruvasagar/vim-table-mode'
" Plug 'elzr/vim-json'
" Plug 'kalekundert/vim-coiled-snake'

" " Git
Plug 'rhysd/committia.vim'
"autocmd BufEnter __committia_diff__ setlocal nospell
let g:committia_hooks = {}
function! g:committia_hooks.edit_open(info)
    " Additional settings
    setlocal nospell

    " If no commit message, start with insert mode
    if a:info.vcs ==# 'git' && getline(1) ==# ''
        startinsert
    endif

    " Scroll the diff window from insert mode
    " Map <C-n> and <C-p>
    imap <buffer><C-d> <Plug>(committia-scroll-diff-down-half)
    imap <buffer><C-u> <Plug>(committia-scroll-diff-up-half)
    nmap <buffer><C-d> <Plug>(committia-scroll-diff-down-half)
    nmap <buffer><C-u> <Plug>(committia-scroll-diff-up-half)
endfunction
Plug 'airblade/vim-gitgutter'
"Plug 'kshenoy/vim-signature'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-rhubarb'
Plug 'jreybert/vimagit'
Plug 'junegunn/gv.vim'
Plug 'rhysd/git-messenger.vim'
Plug 'junkblocker/git-time-lapse'
" Plug 'lambdalisue/gina.vim' " TRIAL PERIOD
" Plug 'fcpg/vim-osc52'
" Plug 'junegunn/vim-github-dashboard'
" Plug 'mattn/gist-vim'
" Plug 'mattn/webapi-vim'

" " Testing
" Plug 'metakirby5/codi.vim'
Plug 'vim-test/vim-test'
Plug 'tpope/vim-dispatch'
" Plug 'puremourning/vimspector'

" " Rlang
" Plug 'ncm2/ncm2'
" Plug 'roxma/nvim-yarp'
" Plug 'jalvesaq/Nvim-R'
"let vimrplugin_assign = 0 " Stop annoying vimRplugin reassignment
" Plug 'gaalcaras/ncm-R'
" Plug 'ncm2/ncm2-bufword'
" Plug 'ncm2/ncm2-path'


" Plug 'jalvesaq/vimcmdline'                             " sort of like slim

" Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'rust-lang/rust.vim'
" Plug 'fatih/vim-go'
Plug 'kana/vim-textobj-user'
" Plug 'davidhalter/jedi-vim'                            " python intellisense
Plug 'dense-analysis/ale'
" Plug 'jeetsukumaran/vim-pythonsense'                   " text object for python
Plug 'goerz/jupytext.vim'
" Plug 'vim-pandoc/vim-pandoc'
" Plug 'vim-pandoc/vim-pandoc-syntax'


Plug 'SirVer/ultisnips'
    let g:UltiSnipsExpandTrigger="<S-tab>"
    let g:UltiSnipsJumpForwardTrigger="<Tab>"
    let g:UltiSnipsJumpBackwardTrigger="<S-Tab>"
    "
    "let g:UltiSnipsExpandTrigger = '<tab>'
    "let g:UltiSnipsJumpForwardTrigger = '<tab>'
    "let g:UltiSnipsJumpBackwardTrigger = '<s-tab>'

    " " If you want :UltiSnipsEdit to split your window.
    let g:UltiSnipsEditSplit="vertical"
    let g:UltiSnipsNoPythonWarning = 1
    let g:UltiSnipsSnippetDirectories=["mysnippets"]

    noremap <silent> <Leader>ult :UltiSnipsEdit!<CR>2<CR>
    vmap <F9> :call UltiSnips#SaveLastVisualSelection()<CR>gvs
    imap <F9> <C-R>=UltiSnips#ExpandSnippet()<CR>

Plug 'honza/vim-snippets'
Plug 'ervandew/supertab'
" Plug 'grepinsight/mysnippets'

" " Writing
" Plug 'christoomey/vim-titlecase'
" Plug 'plasticboy/vim-markdown'
" Plug 'coachshea/vim-textobj-markdown'
Plug 'tpope/vim-abolish'
Plug 'junegunn/goyo.vim'
Plug 'junegunn/limelight.vim'
" Plug 'ron89/thesaurus_query.vim' "thesaurus
" Plug 'mattn/calendar-vim'
Plug 'tpope/vim-speeddating'
" Plug 'vim-scripts/utl.vim'
" Plug 'vim-scripts/SyntaxRange'

Plug 'lervag/vimtex'
" Disable overfull/underfull \hbox and all package warnings
let g:tex_flavor = "latex"

" Plug 'reedes/vim-wordy'
" Plug 'AndrewRadev/switch.vim'

" Interactive coding
Plug 'jpalardy/vim-slime'

" Reading
Plug 'roman/golden-ratio'

" " Misc
" Plug 'dhruvasagar/vim-zoom'
" Plug 'tomtom/tlib_vim'
" Plug 'itchyny/calendar.vim'
Plug 'sgur/vim-editorconfig'
" Plug 'chrisbra/csv.vim'
" Plug 'liuchengxu/vim-which-key'
Plug 'machakann/vim-highlightedyank'

" terminal
Plug 'voldikss/vim-floaterm'

"Plug 'direnv/direnv.vim'


" Syntax Highlighting / FileType
" Plug 'maverickg/stan.vim'
" Plug 'Glench/Vim-Jinja2-Syntax'
" Plug 'ibab/vim-snakemake'
Plug 'broadinstitute/vim-wdl'


" VimOrganizer sutff
"Plug 'hsitz/VimOrganizer'
    " let g:org_agenda_files=['~/Dropbox/vimwiki/*.org']
    " let g:org_todo_keywords=['TODO', 'DONE', 'MEETING', 'QUESTION']
    "
Plug 'axvr/org.vim'
Plug 'chrisbra/NrrwRgn' " like emacs narrow region
Plug 'mattn/calendar-vim'
Plug 'nvim-neorg/neorg' " Neovim notetaking


" Etc Plugins
"Plug 'ThePrimeagen/vim-be-good'
Plug 'burneyy/vim-snakemake'

" if executable('black')
Plug 'psf/black', { 'on':  'Black' }
" endif

Plug 'kkoomen/vim-doge', { 'do': { -> doge#install() } }
let g:doge_doc_standard_python = 'google'

" " Profiling
Plug 'tweekmonster/startuptime.vim'

Plug 'wfxr/minimap.vim', {'do': ':!cargo install --locked code-minimap'}

" " Collection of common configurations for the Nvim LSP client
Plug 'nvim-treesitter/nvim-treesitter'
"
Plug 'neovim/nvim-lspconfig'
Plug 'tjdevries/lsp_extensions.nvim'
Plug 'nvim-lua/completion-nvim'
Plug 'glepnir/lspsaga.nvim'

" Plug 'hrsh7th/cmp-nvim-lsp'
" Plug 'hrsh7th/cmp-buffer'
" Plug 'hrsh7th/nvim-cmp'

Plug 'onsails/lspkind-nvim'


Plug 'ms-jpq/coq_nvim', {'branch': 'coq'}

" " Diagnostic navigation and settings for built-in LSP
"Plug 'nvim-lua/diagnostic-nvim'

if getcwd() != $HOME
    " frameworks.vim causes massive slow down in home directory
    Plug 'dbeniamine/cheat.sh-vim'
endif

" ---

" Debugger Plugins
"Plug 'puremourning/vimspector'
Plug 'szw/vim-maximizer'

Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-telescope/telescope-fzy-native.nvim'

" Fire Nvim
Plug 'glacambre/firenvim', { 'do': { _ -> firenvim#install(0) } }
if exists('g:started_by_firenvim')
    let g:startify_disable_at_vimenter = 1
    let g:airline_extensions = []
    set guifont=Monaco:h12
    nnoremap ,l set lines=10
    set lines=30
    augroup firenvim_setting
      autocmd!
      autocmd BufEnter dbc*. nnoremap ZZ :wq!
      autocmd BufEnter dbc*. set lines=10
      autocmd BufEnter dbc*. ALEDisable
      autocmd BufEnter dbc*. nnoremap <C-c><C-c> :wq!
      " autocmd BufEnter dbc* set updatetime=500
      " autocmd CursorHold dbc* set lines=10
    augroup END
endif
let g:firenvim_config = {
    \ 'globalSettings': {
        \ 'alt': 'all',
    \  },
    \ 'localSettings': {
        \ '.*': {
            \ 'cmdline': 'neovim',
            \ 'content': 'text',
            \ 'priority': 0,
            \ 'selector': 'textarea',
            \ 'takeover': 'always',
        \ },
    \ }
\ }
let fc = g:firenvim_config['localSettings']
let fc['https://www\.linkedin\.com'] = { 'takeover': 'never', 'priority': 1 }
let fc['https://translate\.google\.com'] = { 'takeover': 'never', 'priority': 1 }
let fc['https://www\.spanishdict\.com/'] = { 'takeover': 'never', 'priority': 1 }
" extension available at  https://chrome.google.com/webstore/detail/firenvim/egpjdkipkomnmjhjmdamaniclmdlobbo

call plug#end()

