# Setup fzf
# ---------
if [[ ! "$PATH" == *${HOME}/.fzf/bin* ]]; then
  export PATH="$PATH:${HOME}/.fzf/bin"
fi

# Auto-completion
# ---------------
[[ $- == *i* ]] && source "$HOME/.dotfiles/fzf/completion.bash" 2> /dev/null

# Key bindings
# ------------
source "$HOME/.dotfiles/fzf/key-bindings.bash"

