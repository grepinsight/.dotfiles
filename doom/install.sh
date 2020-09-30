#!/usr/bin/env bash

set -x

if [[ -L "$HOME/.doom.d" ]]; then
	echo "Doom already installed"
else
	ln -sf $HOME/.dotfiles/doom/doom.d $HOME/.doom.d
fi

