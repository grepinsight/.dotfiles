#!/bin/bash

# install pyenv first!
curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash


Add this to bashrc

```
export PATH="/home/allee/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
```
