#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -x

touch $HOME/.gitconfig.local
cat $HOME/.gitconfig.local gitconfig.share > gitconfig.combined

if [[ ! -f $HOME/.gitconfig ]]; then
    ln -sf $HOME/.dotfiles/git/gitconfig.combined $HOME/.gitconfig
else
    echo "$HOME/.gitconfig already exists!"
fi
