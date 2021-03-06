#!/usr/bin/env bash


command -v starship || curl -o starship_installer.sh -fsSL https://starship.rs/install.sh && bash starship_installer.sh --yes && rm starship_installer.sh
