#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -x

touch $HOME/.dotfiles/git/gitconfig.local
cat $HOME/.dotfiles/git/gitconfig.local gitconfig.share > gitconfig.combined

ln -sf $HOME/.dotfiles/git/gitconfig.combined $HOME/.gitconfig
