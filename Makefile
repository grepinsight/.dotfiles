help: ## Prints help for targets with comments
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

install:
	make --silent bootstrap &&\
	make --silent all &&\
	make --silent reload

bootstrap: ## Boostrap configuration
	bash bootstrap.sh

all:
	ln -sf $$HOME/.dotfiles/ctags/ctags.share $$HOME/.ctags
	ln -sf $$HOME/.dotfiles/editorconfig $$HOME/.editorconfig

reload:  ## Reload configs
	cd rstudio && make
	cd bash && make
	cd tmux && make
	cd nvim && make
	cd starship && make
	cd nvim && make  # nvim has to come before vim
	cd vim && make
	cd ctags && make
	cd doom && make
	cd zsh && make
	cd git && make
	cd jupyter && make


update_brew:
	brew bundle dump --force && mv Brewfile osx
	brew list > osx/brew.list
	brew cask list > osx/brew.cask.list
	brew leaves > osx/brew.leaves.list

migrate:  ## migrate helper
	fd --no-ignore -t f local

