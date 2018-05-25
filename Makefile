help: ## Prints help for targets with comments
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Boostrap configuration
	bash bootstrap.sh

all: tmux_setup git_setup editorconfig_setup## run all recipes

tmux_setup: tmux/tmux.conf.combined ## combine tmux base and tmux.conf and link it to $HOME/.tmux.conf 

tmux/tmux.conf.combined: tmux/tmux.conf.share tmux/tmux.conf.local
	touch tmux/tmux.conf.local
	cat tmux/tmux.conf.share tmux/tmux.conf.local > tmux/tmux.conf.combined
	ln -sf $$HOME/.dotfiles/tmux/tmux.conf.combined $$HOME/.tmux.conf

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
	brew bundle dump --force
