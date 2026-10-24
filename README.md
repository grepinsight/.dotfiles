What is it?
-------------
A bunch of configuration files(aka dotfiles) for many programs I use daily.
It's for personal use, so it's frequently updated & done so with minimal documentation.
If you want to use it as a baseline of your dotfiles, please consider forking it.


Prerequisites
-------------
* make
* [GNU Stow](https://www.gnu.org/software/stow/) (`brew install stow`), for the stow packages below

Installation
-------------

```shell
cd $HOME &&\
  git clone https://github.com/grepinsight/.dotfiles.git &&\
  cd .dotfiles &&\
  make install
```

`make install` runs `bootstrap.sh`, then `make reload`, which links every
package into place. The repo must live at `~/.dotfiles`.


How the symlinks work
-------------
Every config lives in this repo and is symlinked to where its program reads it.
There are two kinds of package.

### Stow packages

A stow package mirrors the layout under `$HOME`: `kitty/.config/kitty/kitty.conf`
becomes `~/.config/kitty/kitty.conf`.

| Package | Links |
|---|---|
| `kitty` | `~/.config/kitty` |
| `espanso` | `~/.config/espanso` |
| `hammerspoon` | `~/.hammerspoon` |
| `nvim` | `~/.config/nvim/*` |

Link one package:

```shell
stow --dir=$HOME/.dotfiles --target=$HOME kitty
```

Preview first with `--no --verbose`, and relink after adding files with `--restow`.
Stow refuses to replace a real file or directory, so move an existing config aside
first. `kitty/Makefile` does that for you (to `~/.config/kitty.pre-stow`), and
`make reload` runs it.

Anything at a package's top level that is not a dotfile (a `Makefile`, `tests/`)
would be linked into `$HOME` too. List those in the package's `.stow-local-ignore`.

### Makefile packages

The other packages link their files with `ln -sf` from their own `Makefile`, for
example `tmux/Makefile` links `~/.tmux.conf`. `make reload` runs each one.

### Per-machine settings

Files named `*.local` are git-ignored, so a setting that differs per machine goes
in one of them next to the tracked config. For kitty that is
`~/.config/kitty/kitty.conf.local`:

```
env KITTY_START_DIR=${HOME}/projects
```

New tabs (`cmd+t`, `cmd+shift+t`) open there, or in `$HOME` when it is unset.
Restart kitty after changing it: reloading the config (`kitty @ load-config`) did
not pick up a new `env` value when tested.
