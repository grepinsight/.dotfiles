#!/usr/bin/bash env

set -x

mkdir -p $HOME/.config/rstudio
for snippet in rstudio/snippets/*; do
    snippet_name="$(basename $snippet)"
    ln -sf $HOME/.dotfiles/rstudio/snippets/"$snippet_name"\
        $HOME/.R/snippets/"$snippet_name"
done
