help: ## Prints help for targets with comments
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Boostrap configuration
	bash bootstrap.sh

all: bash_setup tmux_setup git_setup editorconfig_setup## run all recipes

bash_setup:
	@echo "Setting up inputrc to give bash superpower of Vim :)"
	ln -sf $$HOME/.dotfiles/bash/share/bash_inputrc $$HOME/.inputrc

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

editorconfig_setup:
	ln -sf $$HOME/.dotfiles/editorconfig $$HOME/.editorconfig

ctags_setup: ctags/ctags.share  ## ctags setup
	ln -sf $$HOME/.dotfiles/ctags/ctags.share $$HOME/.ctags

vim_setup: vim/vimrc ## vim setup
	bash vim/vim_module_setup.sh

update_brew:
	brew bundle dump --force && mv Brewfile osx
	brew list > osx/brew.list
	brew cask list > osx/brew.cask.list
	brew leaves > osx/brew.leaves.list

doing_setup:
	@echo "Setting up doingrc"
	ln -sf $$HOME/.dotfiles/etc/doingrc $$HOME/.doingrc
