#!/bin/bash


if $(which apt-get); then

  sudo apt-get --yes install libssl-dev           # Install Secure Sockets Layer toolkit
  sudo apt-get --yes install make                     # install make
  sudo apt-get --yes install libcurl4-openssl-dev # Install curl
  sudo apt-get --yes install libxml2-dev          # Instal xml

  sudo apt install silversearcher-ag         # Install ag
fi
