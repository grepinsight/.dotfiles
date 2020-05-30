configure:
	# Assume neovim is a default editor
	mkdir -p $$HOME/config/nvim
	# install nvim if not ready
	ls $$HOME/.config/nvim/ftplugin > /dev/null || ln -sf $$HOME/.dotfiles/vim/ftplugin $$HOME/.config/nvim/ftplugin
	ls $$HOME/.config/nvim/mysnippets > /dev/null || ln -sf $$HOME/.dotfiles/vim/mysnippets $$HOME/.config/nvim/mysnippets
	# command -v nvim > /dev/null || bash install.sh

	# link vimrc
	mkdir -p $$HOME/.config/nvim/
	ln -sf $$HOME/.dotfiles/nvim/init.vim $$HOME/.config/nvim/init.vim
