#!/usr/bin/env bash



set -x

ln -sf $HOME/.dotfiles/nvim/after $HOME/.config/nvim/after
ln -sf $HOME/.dotfiles/nvim/init.lua $HOME/.config/nvim/init.lua
ln -sf $HOME/.dotfiles/nvim/lua $HOME/.config/nvim/lua
ln -sf $HOME/.dotfiles/nvim/ftplugin $HOME/.config/nvim/ftplugin
ln -sf $HOME/.dotfiles/nvim/mysnippets $HOME/.config/nvim/mysnippets
