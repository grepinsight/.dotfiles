#!/usr/bin/env bash

set -x
for tagdef in $HOME/.dotfiles/ctags/*.ctags; do
    ln -sf $tagdef $HOME/.ctags.d/
done
