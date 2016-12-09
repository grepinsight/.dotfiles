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
    ln -s .dotfiles/vim/vimrc ../.vimrc
fi

#touch tmux/tmux.conf.local
#touch git/gitconfig.local
