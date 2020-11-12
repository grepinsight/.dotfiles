#!/usr/bin/env bash


# check if rust exists
command -v cargo || \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# check if rust-analyzer exists
IS_UBUNTU=$(uname -a | egrep -i "Ubuntu|Linux")
if [[ -n $IS_UBUNTU ]]; then
    mkdir -p $HOME/bin
    command -v rust-analyzer || \
        curl -L https://github.com/rust-analyzer/rust-analyzer/releases/latest/download/rust-analyzer-linux -o ~/bin/rust-analyzer
    chmod 750 $HOME/bin/rust-analyzer
fi

