#!/usr/bin/env bash


echo "Install vim_binding"

if [[ ! -d $(jupyter --data-dir)/nbextensions/vim_binding ]]; then
    # Create required directory in case (optional)
    mkdir -p $(jupyter --data-dir)/nbextensions
    # Clone the repository
    cd $(jupyter --data-dir)/nbextensions
    git clone https://github.com/lambdalisue/jupyter-vim-binding vim_binding
    # Activate the extension
    jupyter nbextension enable vim_binding/vim_binding
fi
