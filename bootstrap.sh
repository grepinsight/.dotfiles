#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo_red() {
	echo -e "${RED}$@${NC}"
}
echo_green() {
	echo -e "${GREEN}$@${NC}"
}

echo_install() {
	echo -e "${GREEN}Installing ${NC}$@"
}
section() {
	echo -e "==============[ ${GREEN}$@${NC} ] ================"
}

get_platform() {
    if [[ $(uname) == "Darwin" ]];then
        echo "mac"
    else
        echo "linux"
    fi
}
export -f get_platform
# Administrative

#set -x
ROOT_DIR="$HOME/.dotfiles"

section "Check if $SHELL is ${RED}ZSH${NC}"
if [ -n $ZSH_VERSION ]; then
	# check if ohmyzsh is installed
	echo_install "Oh My Zsh"
	if [ -d ~/.oh-my-zsh/ ]; then
		echo_red "Oh My Zsh already exists. Skipping"
	else
		sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
	fi
fi


### BASHRC setup
echo "--- Setting up bashrc ---"
if [[ -f $HOME/.bash_profile ]]; then
    echo "$HOME/.bash_profile already exists!"
else
    echo "source $HOME/.dotfiles/bash/bashrc_init" >> $HOME/.bash_profile
    echo "Making $HOME/.dotfiles/bash/local/"
    mkdir -p $HOME/.dotfiles/bash/local/
    echo "Creating $HOME/.dotfiles/bash/local/bash_aliases_local"
    echo "Creating $HOME/.dotfiles/bash/local/bash_paths_local"
    echo "Creating $HOME/.dotfiles/bash/local/bash_settings_local"
    touch $HOME/.dotfiles/bash/local/bash_aliases_local
    touch $HOME/.dotfiles/bash/local/bash_paths_local
    touch $HOME/.dotfiles/bash/local/bash_settings_local
fi


### Vim setup
echo "--- Setting up vimrc ---"
if [[ -f $HOME/.vimrc ]]; then
    echo "$HOME/.vimrc already exists!"
else
    echo " * Creating a symbolic link"
    echo " ->  ln -sf .dotfiles/vim/vimrc ../.vimrc"
    ln -s .dotfiles/vim/vimrc ../.vimrc
fi

if [[ ! -d $HOME/.vim/ftplugin ]]; then
    echo "Installing vim ftplugin"
    mkdir -p $HOME/.vim/
    git clone https://github.com/grepinsight/ftplugin.git
fi


### FD
if [[ ! -f  $HOME/.fdignore ]]; then
    echo "Adding FD ignore"
    ln -s $HOME/.dotfiles/fd/fdignore ../.fdignore
fi

# Mac setup
echo "--- Mac specific setup ---"
if [[ $(get_platform) == mac ]]; then
    echo "this is mac"
    if which brew 2>/dev/null; then
        echo "brew is installed. skpping"
    else
        echo "brew is not installed"
        echo "Installing brew..."
        /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    fi

    echo "Do you want to install software using brew from scratch? [n/Y]"
    read varname

    if [[ $varname == "Y" ]]; then
        echo "installing"
        if which brew 2>/dev/null; then
            echo "brew is installed."
            # need to install vim first with python3 support
            brew install vim --with-python3
            brew bundle --file=osx/Brewfile
        fi
    else
        echo "not installing"
    fi

    echo " * Creating a symbolic link for .spacemacs"
    echo " ->  ln -sf .dotfiles/emacs/spacemacs ../.spacemacs"
    ln -sf .dotfiles/emacs/spacemacs ../.spacemacs
else
    echo "Not a mac. skipping"
fi


### Tools
echo "--- Downloading useful tools ---"
if which git 2>/dev/null >&2 ; then
    if [[ ! -e $HOME/src/bashmarks ]]; then
        echo "installing bashmarks"
        mkdir -p $HOME/src
        cd $HOME/src && git clone https://github.com/huyng/bashmarks.git && cd -
        mkdir -p $HOME/.dotfiles/bash/local
        cd $HOME/src/bashmarks && \
            make install && \
            echo "source ~/.local/bin/bashmarks.sh" >> $HOME/.dotfiles/bash/local/bash_settings_local && \
            source ~/.local/bin/bashmarks.sh \
            cd - \
            s dot
        # set up basisc book mark files
            echo "export DIR_dot=\"$HOME/.dotfiles\"" >> $HOME/.sdirs
            echo "export DIR_src=\"$HOME/src\"" >> $HOME/.sdirs
            echo "export DIR_dotvim=\"$HOME/.vim/bundle\"" >> $HOME/.sdirs
            echo "export DIR_tmuxp=\"$HOME/.tmuxp\"" >> $HOME/.sdirs
            echo "export DIR_bundle=\"$HOME/.vim/bundle\"" >> $HOME/.sdirs
            echo "export DIR_dt=\"$HOME/Desktop\"" >> $HOME/.sdirs
            echo "export DIR_ssh=\"$HOME/.ssh\"" >> $HOME/.sdirs
            echo "export DIR_prj=\"$HOME/prj\"" >> $HOME/.sdirs
            echo "export DIR_vim=\"$HOME/.vim\"" >> $HOME/.sdirs
            echo "export DIR_p=\"$HOME/prj\"" >> $HOME/.sdirs
            echo "export DIR_md=\"$HOME/Documents\"" >> $HOME/.sdirs
            echo "export DIR_bin=\"$HOME/bin\"" >> $HOME/.sdirs
            echo "export DIR_prd=\"$HOME/src/productivity\"" >> $HOME/.sdirs
            echo "export DIR_d=\"$HOME/Desktop\"" >> $HOME/.sdirs
            echo "export DIR_prod=\"$HOME/src/productivity\"" >> $HOME/.sdirs
            echo "export DIR_wiki=\"$HOME/Dropbox/vimwiki\"" >> $HOME/.sdirs
            echo "export DIR_l=\"$HOME/Downloads\"" >> $HOME/.sdirs
            echo "export DIR_doc=\"$HOME/Documents\"" >> $HOME/.sdirs
            echo "export DIR_snip=\"$HOME/.vim/plugged/mysnippets/UltiSnips\"" >> $HOME/.sdirs
            echo "export DIR_iwki=\"$HOME/Dropbox/vimwiki\"" >> $HOME/.sdirs
            echo "export DIR_c=\"$HOME/current\"" >> $HOME/.sdirs
        cd $HOME/src && s src && cd -
    fi

    mkdir -p $HOME/src
    if [[ ! -e $HOME/src/gitstats ]]; then
        echo "installing gitstats"
        cd $HOME/src && git clone git://github.com/hoxu/gitstats.git && cd -
    fi

    if [[ ! -e $HOME/src/git-radar ]]; then
        echo "installing git-radar"
        cd $HOME/src && git clone https://github.com/michaeldfallen/git-radar && cd -
    fi

    if [[ ! -e $HOME/src/productivity ]]; then
        echo "installing productivity"
        cd $HOME/src && git clone https://github.com/grepinsight/productivity.git && cd -
    fi

    if [[ ! -e $HOME/src/forgit ]]; then
        echo "installing productivity"
        cd $HOME/src && git clone https://github.com/grepinsight/forgit.git && cd -
    fi
else
    echo "git not found! install git and rerun this script again"
fi


#### Ctags Setup

# for universal-ctags
mkdir -p $HOME/.ctags.d/
cp $HOME/.dotfiles/ctags/markdown.ctags $HOME/.ctags.d/

# Basic set up

cd $ROOT_DIR && touch tmux/tmux.conf.local
cd $ROOT_DIR && touch git/gitconfig.local


touch ~/.bashrc
if [[ $(cat ~/.bashrc | grep bashrc_init | wc -l) -eq 0 ]]; then
    echo "source \$HOME/.dotfiles/bash/bashrc_init" >> $HOME/.bashrc
    echo "Adding the line finished"
else
    echo "bashrc already loaded with the dotfile setup"
fi


# ---------------------------------------------------

set -x
platform=`uname`
if [[ $platform == "Darwin" ]]; then
    # useful tools
    command -v rg || brew install ripgrep
    command -v fd || brew install fd
    command -v tree || brew install tree
    command -v diff-so-fancy || brew install diff-so-fancy
    command -v starship || brew install starship
    command -v cmake || brew install cmake
    command -v parallel || brew install parallel

    echo "Do you want to install emacs-plus? [n/Y]"
    read varname
    if [[ $varname == "Y" ]]; then
        echo "installing"
        brew tap "d12frosted/emacs-plus" && brew install emacs-plus

        echo "Installing doom emacs (see https://github.com/hlissner/doom-emacs)"
        git clone --depth 1 https://github.com/hlissner/doom-emacs ~/.emacs.d
        ~/.emacs.d/bin/doom install

    else
        echo "not installing"
    fi

else

	sudo apt-get update
	command -v curl || sudo apt-get --yes install curl
	command -v graphviz || sudo apt-get --yes install graphviz

	# install ripgrep
	 command -v rg || \
     DEB_RIPGREP="ripgrep_0.10.0_amd64.deb" && \
     curl -LO https://github.com/BurntSushi/ripgrep/releases/download/0.10.0/${DEB_RIPGREP} && \
     sudo dpkg -i ${DEB_RIPGREP} && \
     sudo apt-get install ripgrep && \
     sudo rm -rf ${DEB_RIPGREP}


    command -v fd || \
	 DEB_FD="fd_7.3.0_amd64.deb" && \
	 curl -LO https://github.com/sharkdp/fd/releases/download/v7.3.0/${DEB_FD} && \
	 sudo dpkg -i ${DEB_FD} && \
	 sudo apt-get install fd && \
	 sudo rm -rf ${DEB_FD}

	sudo apt-get install tree

	# install tmux
	command -v tmux || bash ./etc/install_tmux.ubuntu.sh


	 # pyenv related prereques
	 sudo apt-get install -y make build-essential libssl-dev zlib1g-dev libbz2-dev \
	 libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev \
	 xz-utils tk-dev libffi-dev liblzma-dev python-openssl

    # required for lpass
     sudo apt-get --no-install-recommends -yqq install \
      bash-completion \
      build-essential \
      cmake \
      libcurl4  \
      libcurl4-openssl-dev  \
      libssl-dev  \
      libxml2 \
      libxml2-dev  \
      libssl1.1 \
      pkg-config \
      ca-certificates \
      xclip

    command -v lpass || \
      cd $HOME/src && git clone https://github.com/lastpass/lastpass-cli.git && \
      cd lastpass-cli && \
      make && \
      sudo make install  &&
      cd -
fi

curl https://pyenv.run | bash
echo "export PATH=\"~/.pyenv/bin:\$PATH\""    >> $HOME/.bashrc
echo "eval \"\$(pyenv init -)\""              >> $HOME/.bashrc
echo "eval \"\$(pyenv virtualenv-init -)\""   >> $HOME/.bashrc

#pip install csvkit

mkdir $HOME/bin

# diff-so-fancy
cd $HOME/bin/; curl -O "https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy" ; chmod 750 diff-so-fancy; cd -

set +x
