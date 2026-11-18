all:
	@echo "Linking herdr config"
	# ~/.config/herdr also holds herdr's sockets, logs and session state, so it
	# stays a real directory and only config.toml is linked (--no-folding)
	mkdir -p $$HOME/.config/herdr
	# stow refuses to replace a real file, so move a pre-existing one aside
	[ -L $$HOME/.config/herdr/config.toml ] || [ ! -f $$HOME/.config/herdr/config.toml ] || mv $$HOME/.config/herdr/config.toml $$HOME/.config/herdr/config.toml.pre-stow
	stow --dir=$$HOME/.dotfiles --target=$$HOME --no-folding --restow herdr
