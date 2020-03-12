help: ## Prints help for targets with comments
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Boostrap configuration
	bash bootstrap.sh

all: tmux_setup git_setup symlinks run_scripts ## run all '*_setup' recipes

tmux_setup: ## setup tmux
	ln -sf $$HOME/.dotfiles/tmux/tmux.conf.share $$HOME/.tmux.conf
	git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

tmux/tmux.conf.local:
	touch $@

git_setup: git/gitconfig.combined ## combine gitconfig base and gitconfig local and link it to $HOME/.gitconfig

git/gitconfig.combined: git/gitconfig.share git/gitconfig.local
	touch git/gitconfig.local
	cat git/gitconfig.share git/gitconfig.local > git/gitconfig.combined
	ln -sf $$HOME/.dotfiles/git/gitconfig.combined $$HOME/.gitconfig

git/gitconfig.local:
	touch $@

update_brew:
	brew bundle dump --force && mv Brewfile osx
	brew list > osx/brew.list
	brew cask list > osx/brew.cask.list
	brew leaves > osx/brew.leaves.list

migrate:  ## migrate helper
	fd --no-ignore -t f local

.PHONY: symlinks
symlinks:
	ln -sf $$HOME/.dotfiles/bash/share/bash_inputrc $$HOME/.inputrc
	ln -sf $$HOME/.dotfiles/rstudio/rstudio-prefs.json $$HOME/.config/rstudio/rstudio-prefs.json
	ln -sf $$HOME/.dotfiles/ctags/ctags.share $$HOME/.ctags
	ln -sf $$HOME/.dotfiles/editorconfig $$HOME/.editorconfig

.PHONY: run_scripts
run_scripts:
	bash scripts/link-rstudio-snippets-and-bindings.sh # link rstudio scripts
