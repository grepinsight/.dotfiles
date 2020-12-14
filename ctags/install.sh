#!/usr/bin/env bash

set -x

IS_MAC=$(uname -a | grep Darwin)


if $IS_MAC; then
    brew tap universal-ctags/universal-ctags
    brew install --HEAD universal-ctags

fi

IS_UBUNTU=$(uname -a | grep -i Ubuntu)

if $IS_UBUNTU; then
    sudo apt-get install -y universal-ctags
fi
