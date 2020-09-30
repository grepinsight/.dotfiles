#!/usr/bin/env bash

if grep core $HOME/.gitconfig ; then 
	echo "git already configured"
else
	cat gitconfig.share >> $HOME/.gitconfig
fi
