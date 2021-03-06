configure:
	# check if ctags is installed
	command -v ctags || bash install.sh
	ln -sf $$HOME/.dotfiles/ctags/ctags.share $$HOME/.ctags
	bash symlink-tag-defs.sh
