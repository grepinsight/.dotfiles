help: ## Prints help for targets with comments
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

all: tmux_setup git_setup ## run all recipes

tmux_setup: tmux/tmux.conf.combined ## combine tmux base and tmux.conf and link it to $HOME/.tmux.conf 

tmux/tmux.conf.combined: tmux/tmux.conf.share tmux/tmux.conf.local
	cat tmux/tmux.conf.share tmux/tmux.conf.local > tmux/tmux.conf.combined
	ln -sf $$HOME/.dotfiles/tmux/tmux.conf.combined $$HOME/.tmux.conf
	
git_setup: git/gitconfig.combined ## combine gitconfig base and gitconfig local and link it to $HOME/.gitconfig

git/gitconfig.combined: git/gitconfig.share git/gitconfig.local
	cat git/gitconfig.share git/gitconfig.local > git/gitconfig.combined
	ln -sf $$HOME/.dotfiles/git/gitconfig.combined $$HOME/.gitconfig