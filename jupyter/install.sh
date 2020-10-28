#!/usr/bin/env bash

set -x

echo "Install vim_binding"

JUPYTER_DIR="$(jupyter --data-dir)"
if [[ ! -d $(jupyter --data-dir)/nbextensions/vim_binding ]]; then
    # Create required directory in case (optional)
    mkdir -p $(jupyter --data-dir)/nbextensions
    # Clone the repository
    cd $(jupyter --data-dir)/nbextensions
    git clone https://github.com/lambdalisue/jupyter-vim-binding vim_binding
    # Activate the extension
    jupyter nbextension enable vim_binding/vim_binding
fi


mkdir -p ${JUPYTER_DIR}/nbconfig
ln -sf $HOME/.dotfiles/jupyter/notebook.json  ${JUPYTER_DIR}/nbconfig/notebook.json
