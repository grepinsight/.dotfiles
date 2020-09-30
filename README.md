What is it?
-------------
A bunch of configuration files(aka dotfiles) for many programs I use daily.
It's for personal use, so it's frequently updated & done so with minimal documentation.
If you want to use it as a baseline of your dotfiles, please consider forking it.


Prerequisites
-------------
* make

Installation
-------------

```shell
cd $HOME &&\
  git clone https://github.com/grepinsight/.dotfiles.git &&\
  cd .dotfiles &&\
  make --silent bootstrap &&\
  source bash/bashrc_init &&\
  bash docs/install_toolkit.sh &&\
  make --silent all &&
  source $HOME/.bashrc &&
  make --silent reload
```

