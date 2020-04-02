#!/usr/bin/bash env

set -x

mkdir -p $HOME/.config/rstudio
for item in snippets keybindings; do
    for snippet in rstudio/$item/*; do
        item_name="$(basename $snippet)"
        if [[ -e $HOME/.dotfiles/rstudio/$item/"$item_name" ]];then
            ln -sf $HOME/.dotfiles/rstudio/$item/"$item_name" \
                $HOME/.config/rstudio/$item/"$item_name"
        fi
    done
done
