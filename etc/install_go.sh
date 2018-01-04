#!/bin/bash
# http://www.hostingadvice.com/how-to/install-golang-on-ubuntu/
# gvm issue: https://github.com/moovweb/gvm/issues/210

bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)

source /home/ubuntu/.gvm/scripts/gvm

# install go1.4 first
gvm install go1.4 --binary
gvm use go1.4
export GOROOT_BOOTSTRAP=$GOROOT

gvm install go1.9.2 --binary
gvm use go1.9.2