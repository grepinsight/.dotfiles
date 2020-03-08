#!/usr/bin/bash env

set -x

for snippet in rstudio/snippets/*; do
    snippet_name="$(basename $snippet)"
    ln -sf $HOME/.dotfiles/rstudio/snippets/"$snippet_name"\
        $HOME/.config/rstudio/snippets/"$snippet_name"
done
