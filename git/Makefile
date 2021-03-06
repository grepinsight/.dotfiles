install:
	touch gitconfig.local
	cat gitconfig.share gitconfig.local > gitconfig.combined
	ln -sf $$HOME/.dotfiles/git/gitconfig.combined $$HOME/.gitconfig
	bash install.sh
