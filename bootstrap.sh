#!/usr/bin/env bash

function get_platform
{
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
