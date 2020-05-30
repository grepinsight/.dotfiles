#!/usr/bin/env bash

set -x

IS_MAC=$(uname -a | grep Darwin)


if $IS_MAC; then
    echo "is mac"
fi

IS_UBUNTU=$(uname -a | grep -i Ubuntu)

if $IS_UBUNTU; then
    mkdir -p $HOME/src
    cd $HOME/src && curl -O -L https://github.com/neovim/neovim/releases/download/v0.4.3/nvim-linux64.tar.gz
    tar xvzf nvim-linux64.tar.gz

    sudo cp -r bin/* /usr/bin/
    sudo cp -r share/* /usr/share/

fi

