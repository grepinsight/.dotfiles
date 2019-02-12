# if mac
platform=`uname`
if [[ $platform == "Darwin" ]]; then
	#statements
	 brew install ripgrep
	 brew install fd
else
	# install ripgrep
	 curl -LO https://github.com/BurntSushi/ripgrep/releases/download/0.10.0/ripgrep_0.10.0_amd64.deb
	 dpkg -i ripgrep_0.10.0_amd64.deb
	 apt-get install ripgrep

	 dpkg -i fd_7.2.0_amd64.deb
	 apt-get install fd-find

fi

#pip install csvkit
