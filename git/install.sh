#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -x

touch $HOME/.gitconfig.local
cat $HOME/.gitconfig.local gitconfig.share > gitconfig.combined

ln -sf $HOME/.dotfiles/git/gitconfig.combined $HOME/.gitconfig
