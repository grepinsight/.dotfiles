configure:
	ln -sf $$HOME/.dotfiles/starship/starship.toml $$HOME/.config/starship.toml
	grep "starship init bash" ~/.dotfiles/bash/local/bash_settings_local ||  echo 'eval "$(starship init bash)"' >> ~/.dotfiles/bash/local/bash_settings_local

install_mac:
	brew install starship

install_genenral:
	curl -fsSL https://starship.rs/install.sh | bash
