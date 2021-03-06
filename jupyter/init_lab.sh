set -x

command -v jupyter || exit 1


DEST="$(jupyter --config-dir)/lab/user-settings/@jupyterlab/shortcuts-extension/"

mkdir -p $DEST

ln -sf $HOME/.dotfiles/jupyter/shortcuts.jupyterlab-settings $DEST

