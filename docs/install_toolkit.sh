# if mac
platform=`uname`
if [[ $platform == "Darwin" ]]; then
	#statements
	 brew install ripgrep
	 brew install fd
	 brew install tree

else
	# install ripgrep
	 DEB_RIPGREP="ripgrep_0.10.0_amd64.deb"
	 curl -LO https://github.com/BurntSushi/ripgrep/releases/download/0.10.0/${DEB_RIPGREP}
	 dpkg -i ${DEB_RIPGREP}
	 apt-get install ripgrep
	 rm -rf ${DEB_RIPGREP}

	 DEB_FD="fd_7.3.0_amd64.deb"
	 curl -LO https://github.com/sharkdp/fd/releases/download/v7.3.0/${DEB_FD}
	 dpkg -i ${DEB_FD}
	 apt-get install fd
	 rm -rf ${DEB_FD}

	 sudo apt-get install tree


	 # pyenv related prereques
	 sudo apt-get install -y make build-essential libssl-dev zlib1g-dev libbz2-dev \
	 libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev \
	 xz-utils tk-dev libffi-dev liblzma-dev python-openssl

fi

curl https://pyenv.run | bash
#pip install csvkit


mkdir $HOME/bin

# diff-so-fancy
cd $HOME/bin/; curl -O "https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy" ; chmod 750 diff-so-fancy; cd -
