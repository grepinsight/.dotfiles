configure:
	@echo "Configuring Neovim"
	# Assume neovim is a default editor
	mkdir -p $$HOME/.config/nvim
	# Install neovim
	command -v nvim > /dev/null || bash install.sh


	# install nvim if not ready
	ls $$HOME/.config/nvim/ftplugin > /dev/null || ln -sf $$HOME/.dotfiles/vim/ftplugin $$HOME/.config/nvim/ftplugin
	ls $$HOME/.config/nvim/mysnippets > /dev/null || ln -sf $$HOME/.dotfiles/vim/mysnippets $$HOME/.config/nvim/mysnippets


	# link vimrc
	mkdir -p $$HOME/.config/nvim/
	mkdir -p $$HOME/.config/nvim/lua
	ln -sf $$HOME/.dotfiles/nvim/init.lua $$HOME/.config/nvim/lua/init.lua
