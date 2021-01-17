#!/usr/bin/env bash

set -x
SCRIPT_DIR=$(dirname $0)

mkdir -p $HOME/.config/rstudio/
CONFIG_DIR=~/.config/rstudio/

cp -r keybindings $CONFIG_DIR
cp rstudio-prefs.json $CONFIG_DIR
cp -r snippets $CONFIG_DIR
