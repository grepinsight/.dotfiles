configure:
	# install nvim if not ready
	command -v nvim > /dev/null || bash install.sh

	# link vimrc
	mkdir -p $$HOME/.config/nvim/
	ln -sf $$HOME/.dotfiles/nvim/init.vim $$HOME/.config/nvim/init.vim
