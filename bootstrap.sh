#!/usr/bin/env bash

### bashrc


echo "--- Setting up bashrc ---"
if [[ -f $HOME/.bash_profile ]]; then
    echo "$HOME/.bash_profile already exists!"
else
    echo "source $HOME/.dotfiles/bash/bashrc_init" >> $HOME/.bash_profile
fi


### vimrc
echo "--- Setting up vimrc ---"
if [[ -f $HOME/.vimrc ]]; then
    echo "$HOME/.vimrc already exists!"
else
    echo " * Creating a symbolic link"
    echo " ->  ln -sf .dotfiles/vim/vimrc ../.vimrc"
    ln -s .dotfiles/vim/vimrc ../.vimrc

    echo " * Installing vim plugins"
    bash vim/vim_module_setup.sh
fi

#touch tmux/tmux.conf.local
#touch git/gitconfig.local
