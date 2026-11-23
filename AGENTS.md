# Agent notes

## Neovim keymap and command docs

`nvim/.config/nvim/README.md` is the command and shortcut list for this Neovim config. It goes stale quickly. If a change adds, removes, or modifies a keymap, user command, leader setting, or plugin command / `keys` spec, update the matching README rows in the same change. Before finishing, re-read the source you touched and check that the README rows match it. Do not invent rows. Leave commented-out maps out. A map that nothing loads stays in the README section "Mappings in files nothing loads".

`mapleader` is not set (leader is Vim's default `\`). `maplocalleader` is Space, set in `nvim/.config/nvim/init.lua` and `vim/leaders.vim`.

Look at the file you changed and at the other files that define the same kind of binding:

- Keymaps: `vim.keymap.set`, `vim.api.nvim_set_keymap`, `nnoremap` / `nmap` / `vnoremap` / `xnoremap` / `inoremap` / `tnoremap` / `onoremap` / `noremap` / `map` / `imap` / `smap` / `xmap` / `omap` / `tmap`, which-key or `<Plug>` registrations, lazy.nvim `keys = {}`, LSP `LspAttach` / `on_attach` maps, gitsigns `on_attach`, and nvim-cmp `mapping` tables.
- User commands: `vim.api.nvim_create_user_command`, `nvim_buf_create_user_command`, and `:command` / `command!`.
- Leaders: `mapleader`, `maplocalleader`, `vim.g.mapleader`, `vim.g.maplocalleader`.
- Plugin commands: `cmd = { }`, `command!` wrappers around plugin commands, and command names a keymap runs.

Files:

- `nvim/.config/nvim/init.lua` sources `vim/leaders.vim`, `vim/remaps.vim`, `vim/functions.vim`, and `vim/commands.vim`. Those four are part of the Neovim config.
- `nvim/.config/nvim/lua/plugins.lua` and `nvim/.config/nvim/lua/plugins/**` (`keys`, `cmd`, and maps inside `config`).
- `nvim/.config/nvim/lua/config/**`, `lua/custom_commands.lua`, `lua/annotate/**`, `lua/albertlint/**`, `lua/pilsa/**`, `ftplugin/**`, `after/plugin/**`.
- `nvim/.config/nvim/CLAUDE.md` points here. Do not copy this rule into that file.
