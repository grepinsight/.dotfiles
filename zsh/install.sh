#!/usr/bin/env bash

if grep "zshrc_init" $HOME/.zshrc > /dev/null; then
	echo "zshrc_init already in $HOME/.zshrc"
else

    echo '[ -f $HOME/.dotfiles/zsh/zshrc_init ] && source $HOME/.dotfiles/zsh/zshrc_init' >> $HOME/.zshrc
fi
