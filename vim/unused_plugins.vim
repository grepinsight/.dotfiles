Plug 'scrooloose/nerdtree'
Plug 'francoiscabrol/ranger.vim'
Plug 'vim-scripts/taglist.vim'
Plug 'majutsushi/tagbar'
Plug 'Xuyuanp/nerdtree-git-plugin'
Plug 'MattesGroeger/vim-bookmarks'
Plug 'jiangmiao/auto-pairs'
Plug 'bronson/vim-trailing-whitespace'
Plug 'wellle/context.vim'
Plug 'w0rp/ale'
Plug 'mhinz/vim-signify'
" Completions and snippets
if v:version >= 800
    try
        Plug 'Valloric/YouCompleteMe'
    catch
    endtry
endif
let g:titlecase_map_keys = 0
Plug 'beloglazov/vim-online-thesaurus'
Plug 'jceb/vim-orgmode'
Plug 'JamshedVesuna/vim-markdown-preview'
Plug 'wincent/terminus'  " Make terminal and vim play nicely. Supports auto change
Plug 'autozimu/LanguageClient-neovim', {
    \ 'branch': 'next',
    \ 'do': 'bash install.sh',
    \ }
Plug 'szw/vim-g'
Plug 'mattn/emmet-vim'
Plug 'DougBeney/pickachu'
Plug 'luochen1990/rainbow'  " parenthesis colors

Plug 'vimwiki/vimwiki'

" ============================================================================
" Themes
" Plug 'ajmwagar/vim-deus'
" Plug 'junegunn/seoul256.vim'
