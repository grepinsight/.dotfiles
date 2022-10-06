#!/usr/bin/env bash

NEOVIM_DIST="nvim-linux64"
NEOVIM_VERSION="v0.7.2"
set -x

IS_MAC=$(uname -a | grep Darwin)


if [[ -n $IS_MAC ]]; then
    NEOVIM_DIST="nvim-macos"
fi

IS_UBUNTU=$(uname -a | egrep -i "Ubuntu|Linux")

mkdir -p $HOME/src
cd $HOME/src && curl -O -L https://github.com/neovim/neovim/releases/download/$NEOVIM_VERSION/$NEOVIM_DIST.tar.gz
tar xvzf $NEOVIM_DIST.tar.gz

if cd $HOME/src/$NEOVIM_DIST; then
  sudo cp -r bin/* /usr/bin/
  sudo cp -r share/* /usr/share/
elif [[ -n $IS_MAC ]]; then
  if cd $HOME/src/nvim-osx64; then
    sudo cp -r bin/*   /usr/local/bin/
    sudo cp -r share/* /usr/local/share/
    sudo cp -r lib/*   /usr/local/lib/
    sudo cp -r libs/*    /usr/local/libs/
  fi
fi


