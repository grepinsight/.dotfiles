set -x

command -v jupyter || exit 1

ln -sf $HOME/.dotfiles/jupyter/shortcuts.jupyterlab-settings $(jupyter --config-dir)/lab/user-settings/@jupyterlab/shortcuts-extension/
