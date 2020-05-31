#!/usr/bin/env bash

NEOVIM_DIST="nvim-linux64"
NEOVIM_VERSION="v0.4.3"
set -x

IS_MAC=$(uname -a | grep Darwin)


if [[ -n $IS_MAC ]]; then
    echo "Mac implementation not written yet"
fi

IS_UBUNTU=$(uname -a | grep -i Ubuntu)

if [[ -n $IS_UBUNTU ]]; then
    mkdir -p $HOME/src
    cd $HOME/src && curl -O -L https://github.com/neovim/neovim/releases/download/$NEOVIM_VERSION/$NEOVIM_DIST.tar.gz
    tar xvzf $NEOVIM_DIST.tar.gz

    if cd $HOME/src/$NEOVIM_DIST; then
        sudo cp -r bin/* /usr/bin/
        sudo cp -r share/* /usr/share/
    fi

fi

