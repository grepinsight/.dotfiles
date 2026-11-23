all:
	@echo "Linking kitty config"
	# stow refuses to replace a real directory, so move a pre-existing one aside
	[ -L $$HOME/.config/kitty ] || [ ! -d $$HOME/.config/kitty ] || mv $$HOME/.config/kitty $$HOME/.config/kitty.pre-stow
	mkdir -p $$HOME/.config
	# per-machine settings (e.g. env KITTY_START_DIR=...), git-ignored via *.local
	[ -f .config/kitty/kitty.conf.local ] || touch .config/kitty/kitty.conf.local
	stow --dir=$$HOME/.dotfiles --target=$$HOME --restow kitty
