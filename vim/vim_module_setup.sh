#!/bin/bash
# set up essential vim modules
#

mkdir -p ~/.vim/autoload ~/.vim/bundle && curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim
if cd $HOME/.vim/bundle; then

    # Essentials
    git clone git://github.com/tpope/vim-sensible.git
    git clone git://github.com/tpope/vim-fugitive.git                  
    git clone git://github.com/tpope/vim-surround.git
    git clone git://github.com/tpope/vim-commentary.git
    git clone https://github.com/tpope/vim-abolish.git
    git clone https://github.com/tpope/vim-repeat.git

    git clone https://github.com/scrooloose/nerdtree.git
    git clone https://github.com/scrooloose/syntastic                 # syntax checking plugin
    git clone https://github.com/kien/ctrlp.vim.git
    git clone https://github.com/ervandew/supertab.git

    # Navigation
    git clone https://github.com/Lokaltog/vim-easymotion.git
    git clone https://github.com/tomtom/tlib_vim.git
    git clone https://github.com/tommcdo/vim-exchange.git             # Exchange
    git clone https://github.com/vim-scripts/taglist.vim.git          # Ctags

    # Status 
    git clone https://github.com/vim-airline/vim-airline.git
    git clone https://github.com/sjl/gundo.vim.git                    # Undo tree
    #git clone https://github.com/mileszs/ack.vim.git                  # Ack vim
    #git clone https://github.com/Lokaltog/vim-powerline               # Powerline improvement
    # git clone https://github.com/vim-scripts/ZoomWin.git
    # git clone https://github.com/MarcWeber/vim-addon-mw-utils.git

    # Esthetics
    git clone https://github.com/flazz/vim-colorschemes.git
    git clone https://github.com/gorodinskiy/vim-coloresque.git

    # Language specifics
    git clone https://github.com/plasticboy/vim-markdown.git

    # Snippets
    git clone https://github.com/honza/vim-snippets.git
    git clone https://github.com/SirVer/ultisnips.git
else
    echo "Cannot chdir to $HOME/.vim/bundle"
fi
