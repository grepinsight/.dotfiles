#!/bin/bash
# set up essential vim modules
#

mkdir -p ~/.vim/autoload ~/.vim/bundle && curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim
cd ~/.vim/bundle
git clone git://github.com/tpope/vim-sensible.git
git clone https://github.com/scrooloose/nerdtree.git
git clone https://github.com/kien/ctrlp.vim.git
git clone https://github.com/Lokaltog/vim-easymotion.git
git clone git://github.com/garbas/vim-snipmate.git
git clone https://github.com/tomtom/tlib_vim.git
git clone https://github.com/honza/vim-snippets.git
git clone git://github.com/tpope/vim-fugitive.git                  
git clone git://github.com/tpope/vim-surround.git
git clone https://github.com/Lokaltog/vim-powerline               #Powerline improvement
git clone https://github.com/scrooloose/syntastic                 #synatistic -  syntax checking plugin
git clone git://github.com/tpope/vim-commentary.git
git clone https://github.com/grepinsight/mysnippets.git           #my custom snippets
git clone https://github.com/ervandew/supertab.git                #Supertab
git clone https://github.com/mileszs/ack.vim.git                  #Ack vim
git clone https://github.com/vim-scripts/taglist.vim.git          #Ctags
git clone https://github.com/tpope/vim-abolish.git                #Abolish:https://github.com/tpope/vim-abolish
git clone https://github.com/tpope/vim-repeat.git                 #Repeat:https://github.com/tpope/vim-repeat
git clone https://github.com/tommcdo/vim-exchange.git             #Exchange
git clone https://github.com/vim-scripts/ZoomWin.git
git clone https://github.com/MarcWeber/vim-addon-mw-utils.git
# git clone https://github.com/honza/snipmate-snippets.git
# git clone https://github.com/paradigm/vim-multicursor.git         #multipcursor
# git clone git://github.com/LaTeX-Box-Team/LaTeX-Box.git           #Latex
# git clone https://github.com/terryma/vim-multiple-cursors         #multiple cursor
git clone https://github.com/flazz/vim-colorschemes.git           #Coloescheme
git clone https://github.com/gorodinskiy/vim-coloresque.git      #Css colorizer
git clone https://github.com/sjl/gundo.vim.git                   # gundo
#git clone https://github.com/maverickg/stan.vim.git
git clone https://github.com/plasticboy/vim-markdown.git
