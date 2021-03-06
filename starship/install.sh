#!/usr/bin/env bash


mkdir -p $HOME/bin

command -v starship || \
    curl -o starship_installer.sh -fsSL https://starship.rs/install.sh && \
    bash starship_installer.sh --yes -b $HOME/bin && rm starship_installer.sh
