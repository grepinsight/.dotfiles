#!/usr/bin/bash env

set -x

for item in snippets keybindings; do
    for snippet in rstudio/$item/*; do
        item_name="$(basename $snippet)"
        mkdir -p $HOME/.config/rstudio/$item/
        ln -sf $HOME/.dotfiles/rstudio/$item/"$item_name" \
            $HOME/.config/rstudio/$item/"$item_name"
    done
done
