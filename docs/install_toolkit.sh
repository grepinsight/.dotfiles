# if mac
platform=`uname`
if [[ $platform == "Darwin" ]]; then
	#statements
	 brew install ripgrep
	 brew install fd
	 brew install tree

else
	sudo apt-get update
	sudo apt-get --yes install curl
	sudo apt-get --yes install graphviz

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

    command -v lpass || \
      git clone https://github.com/lastpass/lastpass-cli.git && \
      cd lastpass-cli && \
      make && \
      make install


fi

curl https://pyenv.run | bash
echo "export PATH=\"~/.pyenv/bin:\$PATH\""    >> $HOME/.bashrc
echo "eval \"\$(pyenv init -)\""              >> $HOME/.bashrc
echo "eval \"\$(pyenv virtualenv-init -)\""   >> $HOME/.bashrc

#pip install csvkit

mkdir $HOME/bin

# diff-so-fancy
cd $HOME/bin/; curl -O "https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy" ; chmod 750 diff-so-fancy; cd -
