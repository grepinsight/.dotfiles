# Neovim config

Personal Neovim setup. It lives in this repo at `nvim/.config/nvim` and is stowed onto `~/.config/nvim`. `init.lua` also sources four files from `vim/` (`leaders.vim`, `remaps.vim`, `functions.vim`, `commands.vim`), so those are part of the running config even though they sit outside this directory.

## Layout

| Path | Role |
|---|---|
| `init.lua` | Options, lazy.nvim bootstrap, sourced Vim files, then `annotate`, `albertlint`, `pilsa` |
| `lua/plugins.lua` and `lua/plugins/` | Plugin specs. lazy.nvim loads both via `{ import = "plugins" }` |
| `lua/config/` | Setup for treesitter, snippets, UFO, bufferline, keymaps, telescope (required from a plugin spec), and others |
| `lua/custom_commands.lua` | Vault notes, Todoist, Claude, capture, and related commands |
| `lua/albertlint/` | Prose diagnostics, graded review levels, collocations, syntax tree, bullets |
| `lua/annotate/` | In-buffer phrase marks |
| `lua/pilsa/` | Transcription practice and read mode |
| `lua/taskpaper/` | TaskPaper outline moves, done-toggle, and focus view |
| `ftplugin/`, `after/plugin/`, `syntax/` | Filetype and late startup files |
| `shortcuts.vim` | Abolish abbreviations, sourced when `tpope/vim-abolish` loads for markdown |
| `mysnippets/` | Snipmate snippets loaded by LuaSnip |
| `tests/` | Plenary specs (`tests/minimal_init.lua` does not load `plugins.lua`) |
| `install.sh` | Downloads a Neovim binary into `~/src` |

`lua/config/dap.lua`, `lua/config/windows.lua`, `lua/config/org.lua`, `lua/config/ultest.lua`, `lua/config/lualine.lua`, `lua/config/dirvish.lua`, and `lua/config/multi.lua` are not `require`d. Their maps are listed at the end and are not active. The live dirvish and visual-multi settings are the copies in `lua/plugins.lua`.

## Plugin manager

[lazy.nvim](https://github.com/folke/lazy.nvim), branch `stable`. On first launch `init.lua` clones it into `stdpath("data")/lazy/lazy.nvim` if that directory is missing.

`require("lazy").setup` uses `defaults = { lazy = true }`, colorscheme fallback `tokyonight` (only for lazy's installer UI), and turns the update checker off. The colorscheme that actually loads is `github_dark` from `projekt0n/github-nvim-theme` (`lazy = false`).

Disabled runtime plugins: `gzip`, `matchit`, `matchparen`, `netrwPlugin`, `tarPlugin`, `tohtml`, `tutor`, `zipPlugin`.

## Key plugins

Editing and UI: `nvim-treesitter` plus textobjects and treesitter-context, `nvim-ufo`, `bufferline.nvim`, `Comment.nvim`, `vim-surround`, `vim-unimpaired`, `vim-easy-align`, `vim-abolish`, `flash.nvim`, `vim-visual-multi`, `zen-mode.nvim`, `stay-centered.nvim` (typewriter mode, loaded off), `nvim-tree.lua`, `vim-dirvish`, `vim-floaterm`, `harpoon`, `vim-tmux-navigator`.

Finding: `telescope.nvim` with `telescope-fzy-native` and `git-worktree.nvim`, plus `fzf.vim`.

Git: `vim-fugitive`, `vim-rhubarb`, `gv.vim`, `vimagit`, `gitsigns.nvim`, `git-messenger.vim`, `octo.nvim`.

Language: `nvim-lspconfig`, `mason.nvim` with `mason-lspconfig` and `mason-tool-installer`, `nvim-cmp` (LSP, buffer, path, LuaSnip, cmdline, and the `english` collocation source), `null-ls.nvim` for formatting and linting, `vim-test`.

Servers enabled from `lua/plugins/lsp/lsp_servers.lua`: `ruff`, `html`, `pyright`, `rust_analyzer`, `tailwindcss`, `lua_ls`, `gopls`, `bashls`, `zls`. `r_language_server` is `disabled = true`. `ts_ls` and `svelte` are enabled beside that table. Copilot is `vim.lsp` inline completion, started only when `util.headless.has_ui()` is true, and `copilot_gate.lua` blocks it in markdown.

Writing: `obsidian.nvim` (vault from `util.vault`, filetype markdown), plus the local `albertlint`, `annotate`, `pilsa`, and `taskpaper` modules. `epwalsh/obsidian.nvim` is the notes UI; calendar commands in `custom_commands.lua` open the same vault.

## Install and use

The repo is expected at `~/.dotfiles`. From the repo root, `make install` bootstraps and stows packages. The `nvim` package links `nvim/.config/nvim/*` into `~/.config/nvim`. `nvim/.stow-local-ignore` keeps `docs/` (and a few junk patterns) from being linked into `$HOME`.

`install.sh` in this directory downloads a Neovim release (default `nightly`) into `~/src`. `--install-copy` or `--install-symlink` installs it under `/usr/local`. `-v VERSION` picks the release. Without one of those flags the script only downloads and extracts.

Opening Neovim the first time installs lazy.nvim and the plugins. A readable `~/.vimrc_work` is sourced at the end of startup if it exists.

Run the Plenary suite from this directory the way `CLAUDE.md` records it:

```bash
cd ~/.dotfiles/nvim/.config/nvim
PLENARY_DIR=~/.local/share/nvim/lazy/plenary.nvim nvim --headless \
  -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests { minimal_init = 'tests/minimal_init.lua' }"
```

`~/.config/nvim/lua/` is one symlink per top-level module. A new directory under `lua/` is invisible until it is linked. See `CLAUDE.md`.

## Leaders

`mapleader` is never set. Vim's default leader is `\`, and the comment at the top of `init.lua` says "Map \ as leader key". Every `<leader>` / `<Leader>` mapping below is `\`.

Local leader is Space. `init.lua` sets `vim.g.maplocalleader = " "` and `vim/leaders.vim` sets `let maplocalleader=" "`. In the tables, `<Space>` is that local leader.

Comma is a third prefix, written as a literal `,` in `vim/leaders.vim`. It is not `mapleader`.

`vim/leaders.vim` first maps Space to `<Nop>`, then later maps bare `<LocalLeader>` to `:WhichKey '<Space>'`. The later mapping is the one that remains for Space alone. `folke/which-key.nvim` is not in the lazy specs.

Commented-out mappings are omitted. Where two files bind the same keys, both rows are listed; the note says which one is buffer-local or which file runs later.

## Commands

User commands defined in this config. Descriptions are the `desc` field when one is set, otherwise a reading of the command body.

### Notes, vault, and tasks

| Command | Description | Source |
|---|---|---|
| `SuggestAccounts` | Prompt for a transaction description and run the hledger mapper script (`$HLEDGER_MAPPER`, else `$SCRATCH_DIR` or `~/scratch` plus `2024-11-04--lua-hledger/mapper.lua`). No `desc`. | `lua/custom_commands.lua` |
| `Daily` | Open daily note for today. Optional `vertical`/`v` or `horizontal`/`h`. | `lua/custom_commands.lua` |
| `Yesterday` | Open daily note for yesterday. Same split arguments. | `lua/custom_commands.lua` |
| `RecentDailies` | Open last N daily notes (default 5), skipping missing dates. | `lua/custom_commands.lua` |
| `Weekly` | Open weekly note for current week. | `lua/custom_commands.lua` |
| `Quarterly` | Open quarterly note for current quarter. | `lua/custom_commands.lua` |
| `Yearly` | Open yearly note for current year. | `lua/custom_commands.lua` |
| `Todo` | Open `TODO.md` in the vault. | `lua/custom_commands.lua` |
| `Todoist` | Sync Todoist and insert overdue/today tasks at cursor. | `lua/custom_commands.lua` |
| `TodoistSync` | Close checked-off tasks in Todoist. | `lua/custom_commands.lua` |
| `SortTasks` | Sort tasks by effort, impact, urgent, or priority (default: priority desc). | `lua/custom_commands.lua` |
| `SetSortWeights` | Set priority calculation weights (impact_weight effort_weight). | `lua/custom_commands.lua` |
| `Capture` | Capture a thought into the vault's `00-Capture` folder (`!` also opens it). | `lua/custom_commands.lua` |
| `Captures` | Pick from recent captures, newest first (optional count, default 200). | `lua/custom_commands.lua` |
| `Focus` | `normal! zMzvzz`. | `vim/commands.vim` |
| `Focus2` | `normal! zMzOzt`. | `vim/commands.vim` |
| `InsightSystem` | Edit `~/Dropbox/vimwiki/shared/albert-s-system.org`. | `vim/commands.vim` |
| `InsightPrinciples` | Edit `~/Dropbox/vimwiki/shared/principles.org`. | `vim/commands.vim` |
| `InsightTodo` | Edit `~/todo.org`. | `vim/commands.vim` |
| `InsightNotes` | Edit `~/notes.org`. | `vim/commands.vim` |
| `InsightScratch` | Edit `~/scratch.org`. | `vim/commands.vim` |
| `InsightThoughts` | Edit `~/thoughts.org`. | `vim/commands.vim` |
| `InsightOrg` | Edit `~/index.org`. | `vim/commands.vim` |
| `Kanban` | Edit `~/Dropbox/vimwiki/shared/kanban.org`. | `vim/commands.vim` |
| `Meeting` | Split `~/Dropbox/vimwiki/shared/meeting--YYYY-MM-DD.md`. | `vim/commands.vim` |
| `Month` | Edit `~/Dropbox/vimwiki/shared/diary/YYYY-MM.md`. | `vim/commands.vim` |
| `Stats` | Edit `~/Dropbox/vimwiki/shared/statistics.org`. | `vim/commands.vim` |
| `Today` | Edit `~/Thoughts/02-Calendar/Daily/YYYY-MM-DD.md`. | `vim/commands.vim` |
| `Topics` | Edit `~/Dropbox/vimwiki/shared/topics.org`. | `vim/commands.vim` |
| `Week` | Edit `~/Dropbox/vimwiki/shared/diary/YYYY-weekWW.md`. | `vim/commands.vim` |
| `Work` | Edit `~/Dropbox/vimwiki/shared/work.org`. | `vim/commands.vim` |
| `Wq` | `:wq`. | `vim/commands.vim` |
| `Year` | Edit `~/Dropbox/vimwiki/diary/YYYY.md`. | `vim/commands.vim` |

### Editing helpers

| Command | Description | Source |
|---|---|---|
| `AssignToVar` | Assign current line to a variable (optional name, default `df`). | `lua/custom_commands.lua` |
| `BashMultiline` | Convert long bash command to multiline format with backslashes. | `lua/custom_commands.lua` |
| `JoinURL` | Join wrapped URL/string into one line (strips leading whitespace on continuations). | `lua/custom_commands.lua` |
| `JoinClaude` | Strip Claude console quote markers (`▎`) and join wrapped prose into one line. | `lua/custom_commands.lua` |
| `Typewriter` | Toggle typewriter mode (keep the current line vertically centered) via `stay-centered.nvim`. | `lua/custom_commands.lua` |
| `DNA`, `RNA`, `PyrimidineBackbone`, `Cytosine`, `MethylCytosine`, `Thymine`, `Uracil`, `Adenine`, `Guanine` | `Insert ASCII structure of <name> at the cursor`. | `lua/custom_commands.lua` |
| `Nitrogen` | Insert periodic-table position of Nitrogen at the cursor. | `lua/custom_commands.lua` |
| `BufferSmartDelete` | Delete the current buffer; with one listed buffer, `:bd`; in a fugitive diff, close the diff. | `vim/functions.vim` |
| `MoveLibrary` | Delete lines starting with `library` into register `a` and paste them at the top. | `vim/functions.vim` |
| `OpenFileTypeSetting` | Edit `~/.config/nvim/ftplugin/<filetype>.vim`. | `vim/functions.vim` |
| `Greview` | `:Git! diff --staged`. | `vim/commands.vim` |
| `MakeTags` | `!ctags -R .` | `vim/commands.vim` |
| `Black` | `:Neoformat! python black`. | `vim/commands.vim` |
| `Yapf` | `:Neoformat! python yapf`. | `vim/commands.vim` |
| `PreWrite` | `:split ~/.prewrite`. | `vim/commands.vim` |
| `PreWriteRead` | `:r ~/.prewrite`. | `vim/commands.vim` |
| `ChoreEqualer` | Yank the first word and append ` = <word>`. | `vim/commands.vim` |
| `PrCheck` | `lua require('pr_check').pr_check()`. | `vim/commands.vim` |
| `PipeSplit` | `:s/\|/\| \\\r   /g`. | `vim/commands.vim` |
| `Equalify` | Yank the line, append ` =`, and join the duplicate. | `vim/commands.vim` |
| `A` | Alias of `:Other`. | `lua/config/keymaps.lua` |
| `AS` | Alias of `:OtherSplit`. | `lua/config/keymaps.lua` |
| `AV` | Alias of `:OtherVSplit`. | `lua/config/keymaps.lua` |
| `BlackAuto` | `autocmd BufWritePre *.py execute ':Black'`. Defined from the Python ftplugin. | `ftplugin/python.vim` |

### Terminals the config creates

| Command | Description | Source |
|---|---|---|
| `NNN` | `FloatermNew nnn`. | `lua/plugins.lua` |
| `LL` | `FloatermNew --height=0.9 --width=0.9 lazygit`. | `lua/plugins.lua` |
| `LG` | `FloatermNew lazygit`. | `lua/plugins.lua` |
| `R` | Floaterm on the right running `R --vanilla`. | `vim/leaders.vim` |
| `Py`, `PY` | Floaterm on the right running `ipython` in vi editing mode. | `vim/leaders.vim` |

### Claude

| Command | Description | Source |
|---|---|---|
| `ClaudeAsk` | Send the range to `claude -p` as a background job (prompts when given no args). | `lua/custom_commands.lua` |
| `ClaudeLast` | Open the most recently finished Claude reply in a split. | `lua/custom_commands.lua` |
| `ClaudeJobs` | List this session's Claude background jobs. | `lua/custom_commands.lua` |
| `ClaudeRaw` | Like `:ClaudeAsk` with skills, plugins, hooks, CLAUDE.md and MCP disabled. | `lua/custom_commands.lua` |
| `ClaudeSave` | Write a Claude reply to a path (`:[count]ClaudeSave[!] {path}`). | `lua/custom_commands.lua` |
| `ClaudeExport` | Export a Claude reply to a vault note (`:[count]ClaudeExport`). | `lua/custom_commands.lua` |
| `ClaudeAnalyze` | Break the range's English into verbs, nouns, adjectives, idioms and sentence structures. | `lua/custom_commands.lua` |

### Annotate

Prefix for the matching keys is `<leader>a` (`annotate.config` default `prefix`).

| Command | Description | Source |
|---|---|---|
| `AnnotateList` | Browse every annotation. | `lua/annotate/init.lua` |
| `AnnotateOrphans` | Browse annotations that could no longer be located. | `lua/annotate/init.lua` |
| `AnnotateBuffer` | Browse annotations in the current file. | `lua/annotate/init.lua` |
| `AnnotateNote` | Add or edit the note on the mark under the cursor. | `lua/annotate/init.lua` |
| `AnnotateDelete` | Delete the mark under the cursor. | `lua/annotate/init.lua` |
| `AnnotateToggle` | Show or hide annotation highlights in this buffer. | `lua/annotate/init.lua` |
| `AnnotateExport` | Regenerate the markdown review note. | `lua/annotate/init.lua` |

### Albertlint

| Command | Description | Source |
|---|---|---|
| `AlbertLint` | Run the free deterministic checks on this buffer (not the LLM one). | `lua/albertlint/init.lua` |
| `AlbertLintToggle` | Pause or resume the automatic diagnostics in this buffer. | `lua/albertlint/init.lua` |
| `AlbertLintCoverage` | Which logged mistake patterns have a rule, and which cannot. | `lua/albertlint/init.lua` |
| `AlbertLintReload` | Reload rules, engine, semantic, level, and config. Does not reload `init.lua` itself. | `lua/albertlint/init.lua` |
| `AlbertLintSemantic` | LLM grammar check over the configured scope, or a given range. | `lua/albertlint/init.lua` |
| `AlbertLintSemanticCancel` | Stop the LLM grammar check running in this buffer. | `lua/albertlint/init.lua` |
| `AlbertLintLevel1` | Level 1 (grammar/usage). `!` ignores the cache. Accepts a range. | `lua/albertlint/init.lua` |
| `AlbertLintLevel2` | Level 2 (coherence/clarity). `!` ignores the cache. Accepts a range. | `lua/albertlint/init.lua` |
| `AlbertLintLevelQuestionsClear` | Drop the unanswered level questions on this buffer. | `lua/albertlint/init.lua` |
| `AlbertLintLevelMode` | Switch practice/finishing mode, or toggle with no argument. | `lua/albertlint/init.lua` |
| `AlbertLintLevelClearCache` | Forget the cached level findings for this buffer. | `lua/albertlint/init.lua` |
| `AlbertLintLevelAccept` | Accept only the line under the cursor, not the whole hunk. | `lua/albertlint/init.lua` |
| `AlbertLintLevelReject` | Reject only the line under the cursor, not the whole hunk. | `lua/albertlint/init.lua` |
| `AlbertLintLevelClose` | Close the level diff and leave diff mode. | `lua/albertlint/init.lua` |
| `AlbertLintLevelCancel` | Stop the level pass running in this buffer. | `lua/albertlint/init.lua` |
| `AlbertLintTree` | Sentence structure of the sentence under the cursor, in a sidebar. | `lua/albertlint/init.lua` |
| `AlbertLintTreeClose` | Close the structure sidebar. | `lua/albertlint/init.lua` |
| `AlbertLintTreeFollow` | Toggle re-rendering the sidebar as the cursor crosses sentences. | `lua/albertlint/init.lua` |
| `AlbertLintTreeLegend` | The part-of-speech color legend for the structure sidebar. | `lua/albertlint/init.lua` |
| `AlbertLintTreeBootstrap` | Create the parser venv and download the model (about 60 MB); `!` uses public PyPI. | `lua/albertlint/init.lua` |
| `AlbertLintTreeStatus` | Parser state, cache size, and the measured hover latency. | `lua/albertlint/init.lua` |
| `AlbertLintTreeBenchmark` | Time the hover path over every cached sentence in this buffer. | `lua/albertlint/init.lua` |
| `AlbertLintTreeClearCache` | Drop the cached parses for this buffer. | `lua/albertlint/init.lua` |
| `AlbertLintBullets` | Turn the range into a bullet list, one bullet per sentence. | `lua/albertlint/init.lua` |
| `AlbertLintStatus` | Report what is on, what scope, and whether the CLI is reachable. | `lua/albertlint/init.lua` |
| `AlbertLintCollocationRebuild` | Rebuild the collocation index from the vault. | `lua/albertlint/collocation/init.lua` |
| `AlbertLintCollocationStatus` | Report collocation index size and cache location. | `lua/albertlint/collocation/init.lua` |

The level diff uses Vim's built-in `do` / `dp` hunk keys. This config does not remap them. `:AlbertLintLevelAccept` and `:AlbertLintLevelReject` exist because Vim merges adjacent lines into one hunk.

### Pilsa

| Command | Description | Source |
|---|---|---|
| `Pilsa` | Transcribe the selection (or the current paragraph) over ghost text. Accepts a range. | `lua/pilsa/init.lua` |
| `PilsaQuit` | Abort the current session. | `lua/pilsa/init.lua` |
| `PilsaReadMode` | Walk the buffer one word at a time, unread text grayed. | `lua/pilsa/read.lua` |
| `PilsaReadQuit` | Leave read mode. | `lua/pilsa/read.lua` |

### TaskPaper (buffer-local)

| Command | Description | Source |
|---|---|---|
| `TaskPaperMoveRight` | `taskpaper.move.right()`. | `ftplugin/taskpaper.vim` |
| `TaskPaperMoveLeft` | `taskpaper.move.left()`. | `ftplugin/taskpaper.vim` |
| `TaskPaperMoveUp` | `taskpaper.move.up()`. | `ftplugin/taskpaper.vim` |
| `TaskPaperMoveDown` | `taskpaper.move.down()`. | `ftplugin/taskpaper.vim` |
| `TaskPaperMoveToProject` | `taskpaper.move.to_project()`. | `ftplugin/taskpaper.vim` |
| `TaskPaperToggleDone` | `taskpaper.done.toggle_range` over the given range. | `ftplugin/taskpaper.vim` |
| `TaskPaperFocusIn` | `taskpaper.focus.focus_in()`. | `ftplugin/taskpaper.vim` |
| `TaskPaperFocusOut` | `taskpaper.focus.focus_out()`. | `ftplugin/taskpaper.vim` |
| `TaskPaperHome` | `taskpaper.focus.home`. Bang discards a view that cannot write back. | `ftplugin/taskpaper.vim` |

### LSP and formatting

| Command | Description | Source |
|---|---|---|
| `FormatToggle` | Toggle format on save. Created on `LspAttach` when the client supports formatting (or is `ruff_lsp`). | `lua/plugins/formatting/init.lua` |
| `OrganizeImports` | Organize imports (`_typescript.organizeImports`). Buffer command, only when `ts_ls` attaches. | `lua/plugins/lsp/init.lua` |
| `LuaSnipEdit` | `require("luasnip.loaders.from_lua").edit_snippet_files()`. | `lua/config/snippets.lua` |

### Plugin commands the config names

These are commands the specs lazy-load on, or that `init.lua`'s comment says the Copilot server config ships. They are not all defined by this repo.

| Command | Role in this config | Source |
|---|---|---|
| `FloatermNew` | Lazy-load `vim-floaterm`. Also what `NNN`, `LL`, `LG`, `R`, `Py` run. | `lua/plugins.lua` |
| `Vista` | Lazy-load `vista.vim`. `<Space>v` runs it. | `lua/plugins.lua` |
| `NvimTreeToggle`, `NvimTreeOpen`, `NvimTreeFindFileToggle` | Lazy-load `nvim-tree.lua`. | `lua/plugins.lua` |
| `ZenMode` | Lazy-load `zen-mode.nvim`. Pilsa read mode calls `require("zen-mode").open()`. | `lua/plugins.lua`, `lua/pilsa/read.lua` |
| `Dispatch`, `Make`, `Start` | Lazy-load `vim-dispatch`. | `lua/plugins.lua` |
| `Focus` | Also listed on `vim-dispatch`'s `cmd`. The user command in `vim/commands.vim` is a different `:Focus`. | `lua/plugins.lua`, `vim/commands.vim` |
| `Git`, `Gwrite` | Lazy-load `vim-fugitive`. | `lua/plugins.lua` |
| `Magit` | Lazy-load `vimagit`. | `lua/plugins.lua` |
| `GV` | Lazy-load `gv.vim`. | `lua/plugins.lua` |
| `Octo` | Lazy-load `octo.nvim`. | `lua/plugins.lua` |
| `StartupTime` | Lazy-load `vim-startuptime` (`g:startuptime_tries = 10`). | `lua/plugins.lua` |
| `Prettier` | Lazy-load `vim-prettier`. | `lua/plugins.lua` |
| `BOnly` | Lazy-load `BufOnly.vim`. `,O` runs it. | `lua/plugins.lua` |
| `Twilight` | Lazy-load `twilight.nvim`. | `lua/plugins.lua` |
| `TmuxNavigateLeft`, `TmuxNavigateDown`, `TmuxNavigateUp`, `TmuxNavigateRight`, `TmuxNavigatePrevious` | Lazy-load `vim-tmux-navigator`. Bound to `<C-h/j/k/l>` and `<C-\>`. | `lua/plugins.lua` |
| `Telescope` | Lazy-load `telescope.nvim`. | `lua/plugins/telescope.lua` |
| `Other` | Lazy-load `other.nvim`. `:A` / `:AS` / `:AV` call `Other` / `OtherSplit` / `OtherVSplit`. Mappings cover `models/*.sql` and `models/*.yml`. | `lua/plugins.lua`, `lua/config/keymaps.lua` |
| `LspCopilotSignIn` | Not defined here. The Copilot block says nvim-lspconfig ships it with `lsp/copilot.lua`. | `lua/plugins/lsp/init.lua` |

## Shortcuts

Modes: `n` normal, `i` insert, `x` visual, `s` select, `o` operator-pending, `t` terminal, `c` command-line. `v` on its own means visual and select (`vnoremap`, `vmap`, and `vim.keymap.set` mode `"v"`). A bare `map` or `noremap` covers normal, visual, select, and operator-pending. Several rows share a key; both definitions are listed.

`<Space>` in the key column is the local leader. `\` is the leader. Mappings written in Lua as `"<space>..."` are the same keys, because the local leader is the space character.

`init.lua` calls `lazy.setup` before it sources `vim/leaders.vim`. A `lazy = false` plugin's `config` therefore runs first, and `leaders.vim` replaces any of those global maps that use the same left-hand side. `]s` and `[s` are the case called out below. Plugins that load later (`VeryLazy`, a filetype, a command) can replace `leaders.vim` again.

### General

| Mode | Key | Action | Source |
|---|---|---|---|
| n | Space | `<Nop>`, then later in the same file bare `<LocalLeader>` runs `:WhichKey '<Space>'`. The WhichKey map is the one that remains. | `vim/leaders.vim` |
| n, v, s, o | `gf` | `:edit <cfile>` so `gf` opens a path that does not exist yet. | `vim/leaders.vim` |
| n | `==` | `:Neoformat`. | `vim/leaders.vim` |
| n | `BB` | `BufferSmartDelete()`. | `vim/leaders.vim` |
| n | `QQ` | `:q`. | `vim/leaders.vim` |
| n | `zs` | `zMzvzz` (comment: focus current fold). | `vim/leaders.vim` |
| n | `j` / `k` | `gj` / `gk`. A count above 5 also sets the jumplist mark (`m'`). | `vim/remaps.vim` |
| x | `j` / `k` | `gj` / `gk`. | `vim/remaps.vim` |
| n | `n` / `N` | `nzzzv` / `Nzzzv`. | `vim/remaps.vim` |
| n | `vv` | `^vg_` (first non-blank through last non-blank). | `vim/remaps.vim` |
| n | `J` | `mzJ`z` so the cursor stays after a line join. | `vim/remaps.vim` |
| v | `J` / `K` | Move the selection down / up (`:m`) and reselect. Set again in `lua/config/keymaps.lua`. | `vim/remaps.vim`, `lua/config/keymaps.lua` |
| i | `,` `.` `!` `?` | Insert the character and `<C-g>u` (undo breakpoint). | `vim/remaps.vim` |
| i | `jj`, `jk` | Escape. | `vim/leaders.vim` |
| n | `yc` | `yygccp` (comment: duplicate a line and comment out the first line). | `lua/config/keymaps.lua` |
| i | `<C-l>` | Insert ` => ` (spaces around `=>`). | `lua/config/keymaps.lua` |
| n | `\` `\` `s` | `:ToggleGStatus`. The command is not defined in this repo. | `vim/leaders.vim` |
| n | `\` `s`, `\` `ss` | `:ToggleGStatus`. Same missing command. After a markdown buffer loads, `\` `s` is replaced by Obsidian quick switch (see Notes). | `vim/leaders.vim` |
| n | `\` `sv` | `:source $MYVIMRC`. | `vim/leaders.vim` |
| n | `\` `sn` | `:luafile ~/.dotfiles/nvim/lua/config/snippets.lua`. | `vim/leaders.vim` |
| n | `\` `ps` | `:PackerSync`. | `vim/leaders.vim` |
| n | `\` `x` | `:!chmod 750 %`. | `vim/leaders.vim` |
| n | `\` `tts` | Replace tabs with four spaces in the buffer. | `vim/leaders.vim` |
| n, v | `\` `Al` / `Ac` / `Ar` | `:left`, `:center`, `:right`. | `vim/leaders.vim` |
| n | `\` `m` | Open the command line on `let @<register> = ...` for the current register (comment: edit the macro). | `vim/leaders.vim` |
| n | `\` `c` | `:ccl`. | `vim/leaders.vim` |
| n | `\` `ls` | `:ls`. | `vim/leaders.vim` |
| n | `\` `hh`, `\` `ht` | `:Helptags`. | `vim/leaders.vim` |
| n | `\` `ln` | `:Lines`. | `vim/leaders.vim` |
| n | `\` `syn` | Echo the syntax id, transparent id, and linked group under the cursor. | `vim/leaders.vim` |
| n | `\` `md` | `:w` then `:!cygstart %` (comment: open markdown). | `vim/leaders.vim` |
| v | `\` `tc` | Filter the selection through `titlecase`. | `vim/leaders.vim` |
| n | `\` `ft` | `OpenFileTypeSetting()`. | `vim/functions.vim` |
| n | `\` `oc` | `cursor <current file>` and notify. Desc: Open in Cursor. | `lua/config/keymaps.lua` |
| n, v, s, o | `\` `y` | `SendViaOSC52` of the unnamed register. Comment: copy to the system clipboard. The function is not defined in this repo. Normal-mode `\` `y` is replaced by Obsidian yesterday after a markdown buffer loads. | `vim/leaders.vim` |
| n, v, s, o | `\` `Y` | `"+y`. | `vim/leaders.vim` |
| n, v, s, o | `\` `p` | `"*p`. | `vim/leaders.vim` |
| n, v, s, o | `\` `P` | `"+p`. | `vim/leaders.vim` |
| i | `\fn`, `\` `fn` | Insert the file tail (`expand("%:t")`). | `vim/leaders.vim` |
| i | `\` `dn` | Insert the head directory name (`expand("%:p:h:t")`). | `vim/leaders.vim` |
| i | `\gl` | Read `git log -1 --pretty=%B` under the cursor. | `vim/leaders.vim` |
| n, i | `<D-v>` | Paste the `+` register (`"+p`). Insert mode escapes first. | `vim/leaders.vim` |
| n | `<Space>` `<Space>` | `<C-^>` (alternate buffer). | `vim/leaders.vim` |
| n | `<Space>` `w` | `:write`. | `vim/leaders.vim` |
| n | `<Space>` `wq` | `:wq`. | `vim/leaders.vim` |
| n | `<Space>` `qq` | `:quit`. | `vim/leaders.vim` |
| n | `<Space>` `ww` | `<C-w>w`. | `vim/leaders.vim` |
| n, v, s, o | `<Space>` `ch` / `cj` / `ck` / `cl` | Move to that window and `:close` it. | `vim/leaders.vim` |
| n | `<Space>` `e` | `:edit` the current file's directory. | `vim/leaders.vim` |
| n | `<Space>` `p` | Yank `expand("%:p")` into `"` and echo it. | `vim/leaders.vim` |
| n | `<Space>` `pzp` | Pipe the full path through `rpbcopy` and echo it. | `vim/leaders.vim` |
| n | `<Space>` `pro` | Leaves `:e ~/src/productivity/` on the command line (no `<CR>`). | `vim/leaders.vim` |
| n | `<Space>` `qf` | `ToggleQuickFix()`. Not defined in this repo. | `vim/leaders.vim` |
| n | `<Space>` `z` | `:Focus2`. | `vim/leaders.vim` |
| n, v, s, o | `<Space>` `x` | `:Focus`. | `vim/leaders.vim` |
| n | `<Space>` `y` | `:Goyo 120`. | `vim/leaders.vim` |
| n | `,o` | `:only`. | `vim/leaders.vim` |
| n | `,O` | `:BOnly`. | `vim/leaders.vim` |
| n | `,e` | `:e` the current file's directory. | `vim/leaders.vim` |
| n | `,i` | `:e` of `resolve(expand("%:h"))/`. | `vim/leaders.vim` |
| n | `,p` | `:e` of `resolve(expand("%"))`. | `vim/leaders.vim` |
| n | `,x` | `:Focus`. | `vim/leaders.vim` |
| n | `,z` | `:Focus2`. | `vim/leaders.vim` |
| n | `,l` | Executes `yor`. | `vim/leaders.vim` |
| n | `zip` | Executes `vip` then `\` `c^`. | `vim/leaders.vim` |
| x | `s` | `S`. | `vim/leaders.vim` |
| v | `>` / `<` | Indent or outdent and reselect (`>gv` / `<gv`). | `vim/leaders.vim` |
| n | `,,ep` | `:s/\|/\| \\\r   /g`. | `vim/leaders.vim` |
| n | `,,el` / `,,ee` / `,,ei` / `,,eq` / `,,en` | `:!listify`, `:!equalify`, `:!itemify`, `:!quotify`, `:!linify`. | `vim/leaders.vim` |
| v | `,e` `,i` `,l` `,b` `,,l` `,j` `,q` `,n` | Filter the selection through `equalify`, `itemify`, `listify`, `command_formatter`, `listify --single-quote`, `myconvert yaml2json` piped to `jq`, `quotify`, `linify`. | `vim/leaders.vim` |
| v | `,p` | `:s/\|/\| \\\r   /g` on the selection. | `vim/leaders.vim` |
| n | `,l10` `,l20` `,l30` | `set lines=` 10, 20, 30. | `vim/leaders.vim` |
| n | `,c130` | `set columns=130`. | `vim/leaders.vim` |
| n | `,s10` `,s15` `,s20` | `set guifont=Monaco:h10` / `h15` / `h20`. | `vim/leaders.vim` |
| n | `ㅎㅎ` | `gg`. | `vim/leaders.vim` |
| n | `ㅓ` | `j`. | `vim/leaders.vim` |
| n | `ㅗ` | `h`. | `vim/leaders.vim` |
| n | `ㅏ` | `k`. | `vim/leaders.vim` |
| n | `ㅣ` | `l`. | `vim/leaders.vim` |

Command-line abbreviations in the same file: `ㅊㅂ` → `cq`, `ㅈㅂ` → `wq`.

### Files and config

| Mode | Key | Action | Source |
|---|---|---|---|
| n | `\` `ev` | Edit `$HOME/.config/nvim/init.lua`. | `vim/leaders.vim` |
| n | `\` `el` | Edit `$HOME/.dotfiles/vim/leaders.vim`, then `:lua vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')`. | `vim/leaders.vim` |
| n | `\` `es` | Vertical split `~/.vim/plugged/mysnippets/UltiSnips`. | `vim/leaders.vim` |
| n | `\` `eo` | Edit `$HOME/org/notes.org`. | `vim/leaders.vim` |
| n | `\` `eO` | Edit `$HOME/.dotfiles/nvim/after/plugin/org.lua`. | `vim/leaders.vim` |
| n | `\` `gi` | Edit `./.gitignore`. | `vim/leaders.vim` |
| n | `\` `di` | Split `~/Dropbox/vimwiki/diary/<today>.md`. | `vim/leaders.vim` |
| n | `\` `bas` | Edit `bash/share/bash_aliases_share`. | `vim/leaders.vim` |
| n | `\` `bcs` | Edit `bash/share/bash_colors_share`. | `vim/leaders.vim` |
| n | `\` `bfs` | Edit `bash/share/bash_functions_share`. | `vim/leaders.vim` |
| n | `\` `bfl` | Edit `bash/share/bash_functions_local`. | `vim/leaders.vim` |
| n | `\` `bss` | Edit `bash/share/bash_settings_share`. | `vim/leaders.vim` |
| n | `\` `bal` | Edit `bash/local/bash_aliases_local`. | `vim/leaders.vim` |
| n | `\` `bpl` | Edit `bash/local/bash_paths_local`. | `vim/leaders.vim` |
| n | `\` `bsl` | Edit `bash/local/bash_settings_local`. | `vim/leaders.vim` |
| n | `\` `aa` | `:A` (the `:Other` alias). | `vim/leaders.vim` |
| n | `<C-p>` | `telescope.builtin.find_files()`. | `lua/config/keymaps.lua` |
| n | `<C-t>` | `:Files`. | `vim/leaders.vim` |
| n | `,a` | `:Telescope oldfiles`. | `vim/leaders.vim` |
| n | `,v` | fzf over `fd` in `$HOME/Thoughts`, sink `split`. | `vim/leaders.vim` |
| n | `,h` | `:History`. | `vim/leaders.vim` |

### Telescope and fzf

`TB`–`TZ` are normal-mode maps in `vim/leaders.vim`. `<Space>f*` maps are there too.

| Mode | Key | Action | Source |
|---|---|---|---|
| n | `TB` | `telescope.builtin.buffers()`. | `vim/leaders.vim` |
| n | `TC` | `telescope.builtin.commands()`. | `vim/leaders.vim` |
| n | `TD` | `telescope.builtin.lsp_definitions()`. | `vim/leaders.vim` |
| n | `TF` | `telescope.builtin.find_files()`. | `vim/leaders.vim` |
| n | `TG` | `grep_string` of `<cword>`. | `vim/leaders.vim` |
| n | `TH` | `:Telescope help_tags`. | `vim/leaders.vim` |
| n | `TI` | `telescope.builtin.git_status()`. | `vim/leaders.vim` |
| n | `TJ` | `jumplist` with `path_display = "hidden"`. | `vim/leaders.vim` |
| n | `TL` | `telescope.builtin.live_grep()`. | `vim/leaders.vim` |
| n | `TM` | `:Telescope marks`. | `vim/leaders.vim` |
| n | `TO` | `oldfiles` with absolute paths and no previewer. | `vim/leaders.vim` |
| n | `TR` | `:Telescope lsp_references`. | `vim/leaders.vim` |
| n | `TS` | `grep_string` of `input("Grep For > ")`. | `vim/leaders.vim` |
| n | `TT` | `git_worktree.create_git_worktree()`. The mapping has no `<CR>`. | `vim/leaders.vim` |
| n | `TW` | `git_worktree.git_worktrees()`. | `vim/leaders.vim` |
| n | `TZ` | `telescope.builtin.resume()`. | `vim/leaders.vim` |
| n | `<Space>` `ff` | `:Telescope find_files`. | `vim/leaders.vim` |
| n | `<Space>` `fw` | `grep_string` of `<cword>`. | `vim/leaders.vim` |
| n | `<Space>` `fg` | `:Telescope live_grep`. | `vim/leaders.vim` |
| n | `<Space>` `fc` | `:Telescope git_commits`. | `vim/leaders.vim` |
| n | `<Space>` `fb` | `:Telescope buffers`. | `vim/leaders.vim` |
| n | `<Space>` `fh` | `:Telescope help_tags`. | `vim/leaders.vim` |
| n | `<Space>` `fq` | `:Telescope quickfix`. | `vim/leaders.vim` |
| n | `<Space>` `fs` | `:Telescope git_status`. | `vim/leaders.vim` |
| n | `<Space>` `fm` | `:Telescope marks`. | `vim/leaders.vim` |
| n | `<Space>` `fr` | `:Telescope lsp_references`. | `vim/leaders.vim` |
| n | `,b` | `:Telescope buffers`. | `vim/leaders.vim` |
| n | `,f` | `:Rg!` of `<cword>`. | `vim/leaders.vim` |
| n | `,q` | `:Rg!` of the filename tail. | `vim/leaders.vim` |
| n | `\` `rg` | `:Rg!` of `<cword>`. | `vim/leaders.vim` |
| n | `\` `pv` | `fzf#vim#gitfiles` with a right preview. | `vim/leaders.vim` |
| n | `\` `<Tab>` | `<plug>(fzf-maps-n)`. | `vim/leaders.vim` |
| x | `\` `<Tab>` | `<plug>(fzf-maps-x)`. | `vim/leaders.vim` |
| o | `\` `<Tab>` | `<plug>(fzf-maps-o)`. | `vim/leaders.vim` |
| i | `<C-x><C-k>` | `<plug>(fzf-complete-word)`. | `vim/leaders.vim` |
| i | `<C-x><C-f>` | `<plug>(fzf-complete-path)`. | `vim/leaders.vim` |
| i | `<C-x><C-j>` | `<plug>(fzf-complete-file-ag)`. | `vim/leaders.vim` |
| i | `<C-x><C-l>` | `<plug>(fzf-complete-line)`. | `vim/leaders.vim` |
| n | `<Space>` `ji` | `:BTags`. | `vim/leaders.vim` |
| n | `,r` | `:BTags`. | `vim/leaders.vim` |
| n | `<Space>` `lf`, `<Space>` `ss` | `:BLines`. | `vim/leaders.vim` |
| t | `<C-p>` | `:Telescope find_files`. | `vim/leaders.vim` |

Telescope prompt (insert) mappings from `lua/plugins/telescope.lua`:

| Mode | Key | Action | Source |
|---|---|---|---|
| i | `<C-j>` / `<C-k>` | `actions.move_selection_next` / `previous`. | `lua/plugins/telescope.lua` |
| i | `<C-q>` | `smart_add_to_qflist` then `open_qflist`. | `lua/plugins/telescope.lua` |
| i | `<C-h>` | `actions.select_horizontal`. | `lua/plugins/telescope.lua` |

### Git

| Mode | Key | Action | Source |
|---|---|---|---|
| n | `\` `b` | `BlameToggle()` (`Git blame`, or close a `fugitiveblame` window). After a markdown buffer loads, normal-mode `\` `b` is Obsidian backlinks. | `vim/leaders.vim`, `vim/functions.vim` |
| n | `\` `gau` | `:Git add -u`. | `vim/leaders.vim` |
| n | `\` `gcv` | `:Git commit -v`. | `vim/leaders.vim` |
| n | `\` `gs` | `:term git diff --staged -- %`. | `vim/leaders.vim` |
| n | `\` `gd` | `:term git diff -- %`. | `vim/leaders.vim` |
| n | `\` `gg` | `ToggleGitStatusWindow()` (close a `fugitive://` buffer, otherwise `:vertical G`). | `vim/leaders.vim` |
| n | `\` `gf` | `:GitGutterFold`. | `vim/leaders.vim` |
| n | `\` `gvd` | `:Gvdiffsplit`. | `vim/leaders.vim` |
| n | `\` `gw` | `:Gwrite` then `:Gcommit -v`. | `vim/leaders.vim` |
| n | `\` `vd` | `:Gvdiff`. | `vim/leaders.vim` |
| n | `\` `mg` | `:Magit`. | `vim/leaders.vim` |
| n | `]s` / `[s` | `:GitGutterStageHunk` / `:GitGutterUndoHunk`. | `vim/leaders.vim` |
| n | `,c` | `:GitGutterQuickFix` then `:copen` and search for the previous buffer's name. | `vim/leaders.vim` |
| n | `,g` | `:GV!`. | `vim/leaders.vim` |
| n | `,m` | `:Magit`. | `vim/leaders.vim` |
| n | `<Space>` `b` | `:GitMessenger`. | `vim/leaders.vim` |
| n | `<Space>` `d` | `:Gvdiff`. | `vim/leaders.vim` |
| n | `<Space>` `g` | `:GV`. | `vim/leaders.vim` |
| n | `<Space>` `m` | `:Magit`. | `vim/leaders.vim` |

Gitsigns `on_attach` (buffer-local, filetypes `python`, `rust`, `r`, `go`, `html`, `css`, `yaml`):

| Mode | Key | Action | Source |
|---|---|---|---|
| n | `]c` / `[c` | Next / previous hunk, unless `'diff'` is set (then the original `]c` / `[c`). | `lua/plugins/gitsigns.lua` |
| n, v | `\` `hs` | Stage hunk (visual: the selected line range). | `lua/plugins/gitsigns.lua` |
| n, v | `\` `hr` | Reset hunk (visual: the selected line range). | `lua/plugins/gitsigns.lua` |
| n | `\` `hS` | Stage buffer. | `lua/plugins/gitsigns.lua` |
| n | `\` `hu` | Undo stage hunk. | `lua/plugins/gitsigns.lua` |
| n | `\` `hR` | Reset buffer. | `lua/plugins/gitsigns.lua` |
| n | `\` `hp` | Preview hunk. Same keys as Harpoon add-file in `vim/leaders.vim`; this one is buffer-local. | `lua/plugins/gitsigns.lua` |
| n | `\` `hb` | `blame_line {full=true}`. | `lua/plugins/gitsigns.lua` |
| n | `\` `tb` | Toggle current line blame. | `lua/plugins/gitsigns.lua` |
| n | `\` `hd` | `diffthis`. | `lua/plugins/gitsigns.lua` |
| n | `\` `hD` | `diffthis('~')`. | `lua/plugins/gitsigns.lua` |
| n | `\` `td` | Toggle deleted. | `lua/plugins/gitsigns.lua` |
| o, x | `ih` | `:Gitsigns select_hunk`. | `lua/plugins/gitsigns.lua` |

Commit and magit buffers:

| Mode | Key | Action | Source |
|---|---|---|---|
| n, i | `<C-c><C-c>` | `:wq` in `gitcommit` buffers. | `ftplugin/gitcommit.vim` |
| n, i | `<C-c><C-c>` | `magit#commit_command('CC')` in `magit` buffers. | `ftplugin/magit.vim` |
| n, i | `<C-c><C-f>` | `magit#commit_command('CF')`. | `ftplugin/magit.vim` |
| n, i | `<C-c><C-a>` | `magit#commit_command('CA')`. | `ftplugin/magit.vim` |
| n, i | `<C-d>` / `<C-u>` | `<Plug>(committia-scroll-diff-down-half)` / `up-half`, inside `g:committia_hooks.edit_open`. `committia.vim` is not in the lazy specs, so the hook runs only if that plugin is loaded some other way. | `after/plugin/committia.vim` |

`ftplugin/magit.vim` also sets `g:magit_jump_next_hunk` to `<C-J>` and `g:magit_jump_prev_hunk` to `<C-K>` when those globals are unset.

### LSP, diagnostics, and coc

Buffer-local maps set on `LspAttach` in `lua/plugins/lsp/init.lua`, unless noted. `\` `rn` here overrides the global coc rename map in attached buffers. Normal-mode `\` `ca` is the code action; visual-mode `\` `ca` is `:ClaudeAnalyze`.

| Mode | Key | Action | Source |
|---|---|---|---|
| n | `gd` | `vim.lsp.buf.definition`. | `lua/plugins/lsp/init.lua` |
| n | `gD` | `vim.lsp.buf.declaration`. | `lua/plugins/lsp/init.lua` |
| n | `gi` | `vim.lsp.buf.implementation`. | `lua/plugins/lsp/init.lua` |
| n | `gr` | `vim.lsp.buf.references`. Also a global coc map below. | `lua/plugins/lsp/init.lua` |
| n | `ga`, `\` `ca` | `vim.lsp.buf.code_action`. | `lua/plugins/lsp/init.lua` |
| n | `g0` | `vim.lsp.buf.document_symbol`. | `lua/plugins/lsp/init.lua` |
| n | `gW` | `vim.lsp.buf.workspace_symbol`. | `lua/plugins/lsp/init.lua` |
| n | `<Space>D` | `vim.lsp.buf.type_definition`. The Lua lhs is `"<space>D"`. | `lua/plugins/lsp/init.lua` |
| n | `K` | `vim.lsp.buf.hover` with a rounded border. | `lua/plugins/lsp/init.lua` |
| n, i | `<C-s>`, `<C-k>` | `vim.lsp.buf.signature_help` with a rounded border. | `lua/plugins/lsp/init.lua` |
| i | `<S-C-k>` | `vim.lsp.buf.signature_help` with a rounded border. | `lua/plugins/lsp/init.lua` |
| n | `\` `rn`, `gN` | `vim.lsp.buf.rename`. | `lua/plugins/lsp/init.lua` |
| n | `\` `dn`, `]d` | `vim.diagnostic.goto_next`. | `lua/plugins/lsp/init.lua` |
| n | `\` `dp`, `[d` | `vim.diagnostic.goto_prev`. | `lua/plugins/lsp/init.lua` |
| n | `\` `dd`, `<Space>e` | `vim.diagnostic.open_float`. | `lua/plugins/lsp/init.lua` |
| n | `<Space>q` | `vim.diagnostic.setloclist`. | `lua/plugins/lsp/init.lua` |
| n | `<Space>wa` | `vim.lsp.buf.add_workspace_folder`. | `lua/plugins/lsp/init.lua` |
| n | `<Space>wr` | `vim.lsp.buf.remove_workspace_folder`. | `lua/plugins/lsp/init.lua` |
| n | `<Space>wl` | Print `vim.lsp.buf.list_workspace_folders()`. | `lua/plugins/lsp/init.lua` |
| i | `<M-l>` | Accept inline completion. Only if the client supports `textDocument/inlineCompletion`. | `lua/plugins/lsp/init.lua` |
| i | `<M-]>` / `<M-[>` | Next / previous inline completion (`select` count 1 / -1). Same support check. | `lua/plugins/lsp/init.lua` |
| n | `\` `tt` | Toggle `vim.diagnostic.enable`. Global, not buffer-local. | `lua/plugins/lsp/init.lua` |
| n | `\` `ld` | `<Plug>(coc-definition)`. | `vim/leaders.vim` |
| n | `<F12>` | `<Plug>(coc-definition)`. Floaterm's config, when that plugin loads, remaps `<F12>` to `:FloatermToggle`. | `vim/leaders.vim`, `lua/plugins.lua` |
| n | `\` `lt` | `<Plug>(coc-type-definition)`. | `vim/leaders.vim` |
| n | `\` `li` | `<Plug>(coc-implementation)`. | `vim/leaders.vim` |
| n | `\` `lf` | `<Plug>(coc-references)`. | `vim/leaders.vim` |
| n | `gy` | `<Plug>(coc-type-definition)`. | `vim/leaders.vim` |
| n | `gr` | `<Plug>(coc-references)`. Global; the LSP map is buffer-local. | `vim/leaders.vim` |
| n | `\` `rn` | `<Plug>(coc-rename)`. Global; the LSP map is buffer-local. | `vim/leaders.vim` |
| n | `<Space>` `K` | `:Lspsaga hover_doc`. | `vim/leaders.vim` |
| n | `<Space>` `gd` | `:Lspsaga preview_definition`. | `vim/leaders.vim` |
| n | `,n` | `:Navbuddy`. | `vim/leaders.vim` |
| n | `g[` / `g]` | `:PrevDiagnosticCycle` / `:NextDiagnosticCycle`. Python and Rust ftplugins. | `ftplugin/python.vim`, `ftplugin/rust.vim` |
| n | `\` `if` | Comment: import fix. `^cwfrom`, then replace the last `.` with ` import`. Python buffers. | `ftplugin/python.vim` |
| n | `,,f` | Comment: make a string an f-string (`mzF"if`). Python buffers. | `ftplugin/python.vim` |
| i | `xxf` | Same f-string edit, from insert mode. Python buffers. | `ftplugin/python.vim` |
| v | `af` | `:echo("hi")`. Python buffers. | `ftplugin/python.vim` |
| o | `af` | `:normal Vaf`. Python buffers. | `ftplugin/python.vim` |
| n, i | `<M-CR>` | Add the Python import for the word (visual: the selection) and notify. Filetype `python`. | `lua/plugins.lua` (`kiyoon/python-import.nvim`) |
| n, x | `<Space>i` | Add the Python import and move the cursor. Filetype `python`. The Lua lhs is `"<space>i"`. | `lua/plugins.lua` |
| n | `<Space>tr` | `add_rich_traceback()`. Filetype `python`. | `lua/plugins.lua` |

`after/plugin/copilot.vim` maps insert `<C-c>` to `copilot#Accept("\<CR>")` and sets `g:copilot_no_tab_map`. The file's own comment says those are `github/copilot.vim` settings and that plugin is not installed. The live accept key is `<M-l>` above.

### Folds, windows, and buffers

| Mode | Key | Action | Source |
|---|---|---|---|
| n | `zR` | `ufo.openAllFolds`. | `lua/config/ufo.lua` |
| n | `zM` | `ufo.closeAllFolds`. | `lua/config/ufo.lua` |
| n | `zr` | `ufo.openFoldsExceptKinds`. | `lua/config/ufo.lua` |
| n | `zm` | `ufo.closeFoldsWith`. | `lua/config/ufo.lua` |
| n | `\` `k` | Peek folded lines under the cursor; if there is no fold, `CocActionAsync('definitionHover')` and `vim.lsp.buf.hover()`. | `lua/config/ufo.lua` |
| n | `]j` / `[j` | `NextClosedFold('j')` / `NextClosedFold('k')`. The function is not defined in this repo. | `vim/leaders.vim` |
| n | `\` `fme` / `fmi` / `fmm` / `fms` | `foldmethod` expr / indent / marker / syntax. | `vim/leaders.vim` |
| n | `\` `fs` | `zo[z` (comment: move to start of fold). | `vim/leaders.vim` |
| n | `\` `fe` | `zo]z` (comment: move to end of fold). | `vim/leaders.vim` |
| n | `]b` / `[b` | `:BufferLineCycleNext` / `Prev`. | `lua/config/bufferline.lua` |
| n | `]z` / `[z` | `:BufferLineMoveNext` / `Prev`. Treesitter binds the same keys, in normal, visual, and operator-pending, to the next / previous `@fold`. Both configs run inside `lazy.setup`, and bufferline's map is normal mode only, so which normal-mode binding remains is whichever config ran last. | `lua/config/bufferline.lua` |
| n | `\` `btt` | `:bufdo tab split`. | `vim/leaders.vim` |
| n | `<Space>` `lc` | `:lclose`. | `vim/leaders.vim` |
| n | `<Space>` `lo` | `:lopen`. | `vim/leaders.vim` |
| n, v, s, o | `<C-w>r` | `:YodeLayoutShiftWinDown`. | `vim/leaders.vim` |
| n, v, s, o | `<C-w>R` | `:YodeLayoutShiftWinUp`. | `vim/leaders.vim` |
| n, v, s, o | `<C-w>J` | `:YodeLayoutShiftWinBottom`. | `vim/leaders.vim` |
| n, v, s, o | `<C-w>K` | `:YodeLayoutShiftWinTop`. | `vim/leaders.vim` |
| n, v, s, o | `\` `yc` | `:YodeCreateSeditorFloating`. | `vim/leaders.vim` |
| n, v, s, o | `\` `yr` | `:YodeCreateSeditorReplace`. | `vim/leaders.vim` |
| n | `\` `bd` | `:YodeBufferDelete`. | `vim/leaders.vim` |
| i | `\` `bd` | Escape, then `:YodeBufferDelete`. | `vim/leaders.vim` |

`ftplugin/taskpaper.vim` says UFO's indent provider already folds TaskPaper, and lists the native fold keys it relies on: `zo`/`zc`, `zO`/`zC`, `zr`/`zm`, `zR`/`zM`. This config does not bind a second set.

### Treesitter

| Mode | Key | Action | Source |
|---|---|---|---|
| n | `<CR>` | Treesitter: start selection. In markdown, Obsidian's buffer-local `<CR>` wins. | `lua/config/treesitter.lua` |
| x | `<S-Tab>` | Treesitter: grow selection. | `lua/config/treesitter.lua` |
| x | `<Tab>` | Treesitter: shrink selection. | `lua/config/treesitter.lua` |
| x, o | `aa` / `ia` | Select outer / inner parameter. | `lua/config/treesitter.lua` |
| x, o | `af` / `if` | Select outer / inner function. | `lua/config/treesitter.lua` |
| x, o | `ai` / `ii` | Select outer / inner conditional. | `lua/config/treesitter.lua` |
| x, o | `al` / `il` | Select outer / inner loop. | `lua/config/treesitter.lua` |
| x, o | `at` / `it` | Select outer / inner comment. | `lua/config/treesitter.lua` |
| x, o | `ac` / `ic` | Select outer / inner class. | `lua/config/treesitter.lua` |
| x, o | `as` | Select language scope (`@scope` in the `locals` group). | `lua/config/treesitter.lua` |
| n, x, o | `]m` / `[m` | Next / previous start of `@function.outer`. | `lua/config/treesitter.lua` |
| n, x, o | `]M` / `[M` | Next / previous end of `@function.outer`. | `lua/config/treesitter.lua` |
| n, x, o | `]s` / `[s` | Next / previous start of `@statement.outer`. `leaders.vim` is sourced afterwards and its `nnoremap` replaces the normal-mode binding with `:GitGutterStageHunk` / `:GitGutterUndoHunk`. Visual and operator-pending stay on this treesitter map. | `lua/config/treesitter.lua` |
| n, x, o | `]S` / `[S` | Next / previous end of `@statement.outer`. | `lua/config/treesitter.lua` |
| n, x, o | `]]` / `[[` | Next / previous start of `@class.outer`. | `lua/config/treesitter.lua` |
| n, x, o | `][` / `[]` | Next / previous end of `@class.outer`. | `lua/config/treesitter.lua` |
| n, x, o | `]z` / `[z` | Next / previous start of `@fold`. | `lua/config/treesitter.lua` |
| n, x, o | `]Z` / `[Z` | Next / previous end of `@fold`. | `lua/config/treesitter.lua` |
| n, x, o | `]i` / `[i` | Next / previous `@conditional.inner`. | `lua/config/treesitter.lua` |
| n | `,,n` | Swap next `@parameter.inner`. | `lua/config/treesitter.lua` |
| n | `,,N`, `,,p` | Swap previous `@parameter.inner`. | `lua/config/treesitter.lua` |

`move` uses `set_jumps = true`. Selection modes in the textobjects setup: `@parameter.outer` charwise, `@function.outer` linewise, `@class.outer` blockwise.

Flash (`folke/flash.nvim`):

| Mode | Key | Action | Source |
|---|---|---|---|
| n, x, o | `s` | `flash.jump`. Desc: Flash. Loads on `VeryLazy`, so this replaces visual `s` → `S` from `vim/leaders.vim`. | `lua/plugins.lua` |
| n, o, x | `S` | `flash.treesitter`. Desc: Flash Treesitter. | `lua/plugins.lua` |
| o | `r` | `flash.remote`. Desc: Remote Flash. | `lua/plugins.lua` |
| n, o, x | `R` | `flash.treesitter_search`. Desc: Treesitter Search. | `lua/plugins.lua` |

### Completion and snippets

Insert-mode nvim-cmp (`lua/plugins/cmp.lua`):

| Mode | Key | Action | Source |
|---|---|---|---|
| i | `<C-y>` | Confirm the selected entry (`cmp.ConfirmBehavior.Insert`, `select = true`). | `lua/plugins/cmp.lua` |
| i | `<C-k>` / `<C-j>` | Previous / next completion item. | `lua/plugins/cmp.lua` |
| i | `<C-d>` / `<C-u>` | Scroll docs by 4 / -4. | `lua/plugins/cmp.lua` |
| i | `<C-Space>` | `cmp.mapping.complete()`. Comment: does not work in Windows Terminal. | `lua/plugins/cmp.lua` |
| i | `<C-e>` | Abort the menu. | `lua/plugins/cmp.lua` |
| i | `<Tab>` | If the menu is visible and the cursor is past a word character, select the next item; otherwise fallback. | `lua/plugins/cmp.lua` |

Command-line `/` and `?`:

| Mode | Key | Action | Source |
|---|---|---|---|
| c | `<C-k>` / `<C-j>` | Previous / next item when the menu is visible, else fallback. | `lua/plugins/cmp.lua` |
| c | `<Tab>` | Confirm the visible menu (`select = true`); otherwise fallback. | `lua/plugins/cmp.lua` |

Command-line `:` (`autocomplete = false`):

| Mode | Key | Action | Source |
|---|---|---|---|
| c | `<C-k>` / `<C-j>` | Previous / next item when the menu is visible, else fallback. | `lua/plugins/cmp.lua` |
| c | `<Tab>` | Confirm if the menu is visible; otherwise `complete()` and select the next item. | `lua/plugins/cmp.lua` |
| c | `<S-Tab>` | Previous item if the menu is visible; otherwise `complete()` and select the previous item. | `lua/plugins/cmp.lua` |

LuaSnip:

| Mode | Key | Action | Source |
|---|---|---|---|
| i, s | `<C-j>` | Next choice if one is active, else jump forward. | `lua/config/snippets.lua` |
| i, s | `<C-k>` | Previous choice if one is active, else jump backward. | `lua/config/snippets.lua` |
| i | `,S` | `<Plug>luasnip-expand-or-jump`. | `vim/leaders.vim` |
| i, s | `<C-j>` | `<Plug>luasnip-next-choice` when a choice is active, else `<C-j>`. | `vim/leaders.vim` |
| i, s | `<C-k>` | `<Plug>luasnip-prev-choice` when a choice is active, else `<C-k>`. | `vim/leaders.vim` |
| i, s | `<C-y>` | `<Plug>luasnip-expand-or-jump` when a choice is active, else `<C-y>`. | `vim/leaders.vim` |
| n | `\` `<CR>` | `:LuaSnipEdit`. | `lua/config/snippets.lua` |

`store_selection_keys` is `"<c-s>"` (`ls.config.set_config` in `lua/config/snippets.lua`). The `cs()` helpers in `lua/config/snippets/{all,python,quarto,text}.lua` can bind a snippet to a key, but nothing in those files calls `cs()`.

### Terminals, Harpoon, tests, and file trees

Floaterm's `config` runs when the plugin loads (`cmd` is `FloatermNew`, `NNN`, `LL`). Until then, `<F9>` is the toggle from `vim/leaders.vim`. After it loads, `<F9>` is next and `<F12>` is the toggle.

| Mode | Key | Action | Source |
|---|---|---|---|
| n, t | `<F7>` | `:FloatermNew`. Terminal mode leaves terminal first. | `lua/plugins.lua` |
| n, t | `<F8>` | `:FloatermPrev`. `vim/leaders.vim` also maps normal `<F8>` to `:TagbarToggle`. | `lua/plugins.lua`, `vim/leaders.vim` |
| n, t | `<F9>` | `:FloatermNext` once floaterm has loaded. `vim/leaders.vim` maps `<F9>` to `:FloatermToggle`. | `lua/plugins.lua`, `vim/leaders.vim` |
| n, t | `<F12>` | `:FloatermToggle` once floaterm has loaded. See the coc `<F12>` row. | `lua/plugins.lua` |
| n, v | `\` `ts` | `:FloatermSend`. | `vim/leaders.vim` |
| t | `,t` | Leave terminal mode and `:q`. | `vim/leaders.vim` |
| t | `[b` / `]b` | Previous / next buffer. | `vim/leaders.vim` |
| t | `[t` / `]t` | Previous / next tab. | `vim/leaders.vim` |
| t | `]1`–`]4` | `harpoon.ui.nav_file(1..4)`. | `vim/leaders.vim` |
| t | `[1`–`[4` | `harpoon.term.gotoTerminal(1..4)`. | `vim/leaders.vim` |
| t | `<C-w>s` | `:split`. | `vim/leaders.vim` |
| t | `<C-w><C-h/j/k/l>` | Leave terminal mode and move to that window. | `vim/leaders.vim` |
| n | `<C-h>` / `<C-j>` / `<C-k>` / `<C-l>` / `<C-\>` | `TmuxNavigateLeft` / `Down` / `Up` / `Right` / `Previous`. | `lua/plugins.lua` |
| n | `\` `hp` | `harpoon.mark.add_file()`. | `vim/leaders.vim` |
| n | `\` `hl` | `harpoon.ui.toggle_quick_menu()`. | `vim/leaders.vim` |
| n | `<Space>` `1`–`4` | `harpoon.ui.nav_file(1..4)`. | `vim/leaders.vim` |
| n | `]1`–`]4` | `harpoon.ui.nav_file(1..4)`. | `vim/leaders.vim` |
| n | `[1`–`[4` | `harpoon.term.gotoTerminal(1..4)`. | `vim/leaders.vim` |
| n | `<Space>` `t1` / `t2` | `harpoon.term.gotoTerminal(1)` / `(2)`. | `vim/leaders.vim` |
| n | `<Space>` `s1` | `harpoon.term.sendCommand(1, "ipython --TerminalInteractiveShell.editing_mode=vi")`. | `vim/leaders.vim` |
| n | `<Space>` `s2` | `harpoon.term.sendCommand(1, 2)`. | `vim/leaders.vim` |
| n | `,k` | `harpoon.mark.add_file()`. | `vim/leaders.vim` |
| n | `,t` | `:sp` then `harpoon.term.gotoTerminal(1)`. | `vim/leaders.vim` |
| n | `,,t` | `ChooseTerm("term-slider2", 1)` (`vim/functions.vim`). | `vim/leaders.vim` |
| n | `t<C-n>` | `:TestNearest`. | `vim/leaders.vim` |
| n | `t<C-f>` | `:TestFile`. | `vim/leaders.vim` |
| n | `t<C-s>` | `:TestSuite`. | `vim/leaders.vim` |
| n | `t<C-l>` | `:TestLast`. | `vim/leaders.vim` |
| n | `t<C-g>` | `:TestVisit`. | `vim/leaders.vim` |
| n | `<Space>` `tn` | `:TestNearest`. | `vim/leaders.vim` |
| n | `\` `ut` / `un` / `us` / `uo` | `:Ultest`, `:UltestNearest`, `:UltestSummary`, `:UltestOutput`. | `vim/leaders.vim` |
| n | `]t` / `[t` | `<Plug>(ultest-next-fail)` / `<Plug>(ultest-prev-fail)`. | `vim/leaders.vim` |
| n | `<Space>` `tt` | `:NvimTreeToggle`. | `vim/leaders.vim` |
| n | `<Space>` `tf` | `:NvimTreeFindFileToggle`. | `vim/leaders.vim` |
| n | `,w` | `:NvimTreeToggle`. | `vim/leaders.vim` |
| n | `<Space>` `pt` | `:NERDTreeToggle`. | `vim/leaders.vim` |
| n | `<Space>` `v` | `:Vista`. | `vim/leaders.vim` |
| n | `t` | Dirvish buffer: delete the line under the cursor and replace the buffer with `find` + `ls -Fd` of that path. | `lua/plugins.lua` |
| n, i | `<M-C-j>` / `<M-C-k>` | vim-visual-multi "Add Cursor Down" / "Add Cursor Up". `g:VM_mouse_mappings = 1`. | `lua/plugins.lua` |

### Notes, Obsidian, annotate, and prose

Obsidian loads for `filetype` markdown. Its `\` maps are global, so opening a markdown buffer replaces the earlier normal-mode maps for `\` `b`, `\` `s`, `\` `o`, and `\` `y`.

| Mode | Key | Action | Source |
|---|---|---|---|
| n | `<CR>` | Buffer-local, expr. Follow a markdown link, toggle an existing checkbox (`^%s*- %[.%] `), otherwise `<CR>`. | `lua/plugins/obsidian.lua` |
| n | `gf` | Expr. `ObsidianFollowLink` when the cursor is on a markdown link, otherwise `gf`. `noremap = false`. | `lua/plugins/obsidian.lua` |
| n | `<C-Space>`, `\` `tc` | `:ObsidianToggleCheckbox`. Desc: Toggle checkbox. Visual `\` `tc` in `vim/leaders.vim` is still `titlecase`. | `lua/plugins/obsidian.lua` |
| n | `\` `s` | `:ObsidianQuickSwitch`. | `lua/plugins/obsidian.lua` |
| n | `\` `b` | `:ObsidianBacklinks`. | `lua/plugins/obsidian.lua` |
| n | `\` `o` | `:ObsidianTOC`. | `lua/plugins/obsidian.lua` |
| n | `\` `y` | `:ObsidianYesterday`. | `lua/plugins/obsidian.lua` |
| n | `<Space>` `o` | `orgmode.action('clock.org_clock_goto')`. | `vim/leaders.vim` |
| n | `<Space>` `toc` | `:VimwikiTOC`. | `vim/leaders.vim` |
| n | `<Space>` `tog` | `:!toggl-start` of `<cWORD>`. | `vim/leaders.vim` |
| n | `<Space>` `ty` | `:!typora "%"`. | `vim/leaders.vim` |
| n | `\` `tw` | `:Typewriter`. Desc: Toggle typewriter mode. | `lua/custom_commands.lua` |
| n | `\` `av` | Prompt for a variable name (default `df`) and prefix the line. Desc: Assign line to variable. | `lua/custom_commands.lua` |
| n, v | `\` `bm` | `:BashMultiline`. | `lua/custom_commands.lua` |
| n, v | `\` `uj` | `:JoinURL`. | `lua/custom_commands.lua` |
| n, v | `\` `cj` | `:JoinClaude`. | `lua/custom_commands.lua` |
| v | `\` `cc` | `:ClaudeAsk`. | `lua/custom_commands.lua` |
| v | `\` `cf` | `:ClaudeAsk +full`. | `lua/custom_commands.lua` |
| v | `\` `cr` | `:ClaudeRaw`. | `lua/custom_commands.lua` |
| n | `\` `ce` | `:ClaudeExport`. | `lua/custom_commands.lua` |
| v | `\` `ca` | `:ClaudeAnalyze`. | `lua/custom_commands.lua` |
| n, v | `\` `nc` | `:Capture`. | `lua/custom_commands.lua` |
| n | `\` `nC` | `:Captures`. | `lua/custom_commands.lua` |
| n, x | `<Space>` `pp` | `:Pilsa`. Desc: 필사 transcription practice. | `lua/pilsa/init.lua` |
| n | `<Space>` `pr` | `:PilsaReadMode`. Desc: 필사 read mode. | `lua/pilsa/read.lua` |

Annotate. Visual keys mark the selection; normal keys use the same prefix plus one letter. Default prefix is `\` `a`.

| Mode | Key | Action | Source |
|---|---|---|---|
| x | `\` `ai` | Mark as idiom. | `lua/annotate/init.lua`, `lua/annotate/config.lua` |
| x | `\` `aj` | Mark as jargon. | `lua/annotate/init.lua`, `lua/annotate/config.lua` |
| x | `\` `ae` | Mark as great expression. | `lua/annotate/init.lua`, `lua/annotate/config.lua` |
| x | `\` `ap` | Mark as great phrase. | `lua/annotate/init.lua`, `lua/annotate/config.lua` |
| x | `\` `an` | Mark as note (this category has `prompt = true`). | `lua/annotate/init.lua`, `lua/annotate/config.lua` |
| n | `\` `aN` | `:AnnotateNote`. | `lua/annotate/init.lua` |
| n | `\` `ad` | `:AnnotateDelete`. | `lua/annotate/init.lua` |
| n | `\` `al` | `:AnnotateList`. | `lua/annotate/init.lua` |
| n | `\` `ab` | `:AnnotateBuffer`. | `lua/annotate/init.lua` |
| n | `\` `ax` | `:AnnotateExport`. | `lua/annotate/init.lua` |
| n | `\` `at` | `:AnnotateToggle`. | `lua/annotate/init.lua` |

Albertlint bullets, and the structure sidebar (buffer-local to that sidebar):

| Mode | Key | Action | Source |
|---|---|---|---|
| n | `gb` | Operator: bullet the lines a motion covers (`gbip`, `gb2j`). | `lua/albertlint/init.lua` |
| x | `gb` | Bullet the visual selection. | `lua/albertlint/init.lua` |
| n | `q` | Close the structure sidebar. | `lua/albertlint/parse/init.lua` |
| n | `K` | Raw tag and dependency label for this token. | `lua/albertlint/parse/init.lua` |
| n | `p` | Toggle the phrase each node stands for. | `lua/albertlint/parse/init.lua` |
| n | `g?` | Open the color legend. | `lua/albertlint/parse/init.lua` |
| n | `q` | Close the legend buffer. | `lua/albertlint/parse/init.lua` |

Pilsa session buffers:

| Mode | Key | Action | Source |
|---|---|---|---|
| n, i | `<C-s>` | Save the note onto today's daily note, or discard if it is empty. Note buffer only. | `lua/pilsa/init.lua` |
| n | `q` | Discard the note. | `lua/pilsa/init.lua` |
| i | `<CR>` | Move to the next line (does not split the line). Transcription buffer. | `lua/pilsa/init.lua` |
| n, i | `<Tab>` | Skip this word. | `lua/pilsa/init.lua` |
| n, i | `<C-s>` | Stop and write the note. Transcription buffer. | `lua/pilsa/init.lua` |
| n | `q` | Abort the transcription. | `lua/pilsa/init.lua` |
| n | `<Tab>` | Next word. Read mode. | `lua/pilsa/read.lua` |
| n | `<S-Tab>`, `<BS>` | Previous word. Read mode. | `lua/pilsa/read.lua` |
| n | `q` | Leave read mode. | `lua/pilsa/read.lua` |

Grammarous, EasyAlign, table mode, and ALE, from `vim/leaders.vim`:

| Mode | Key | Action | Source |
|---|---|---|---|
| n | `\` `wj` | `<Plug>(grammarous-move-to-info-window)`. | `vim/leaders.vim` |
| n | `\` `wo` | `<Plug>(grammarous-open-info-window)`. | `vim/leaders.vim` |
| n | `\` `wr` | Bound twice: `<Plug>(grammarous-reset)`, then `<Plug>(grammarous-remove-error)`. The second assignment is the one that remains. | `vim/leaders.vim` |
| n | `\` `wf` | `<Plug>(grammarous-fixit)`. | `vim/leaders.vim` |
| n | `\` `wa` | `<Plug>(grammarous-fixall)`. | `vim/leaders.vim` |
| n | `\` `wc` | `<Plug>(grammarous-close-info-window)`. | `vim/leaders.vim` |
| n | `\` `wd` | `<Plug>(grammarous-disable-rule)`. | `vim/leaders.vim` |
| n | `\` `wn` / `wp` | Next / previous grammarous error. | `vim/leaders.vim` |
| v | `<Enter>` | `<Plug>(EasyAlign)`. | `vim/leaders.vim` |
| x, n | `ga` | `<Plug>(EasyAlign)`. | `vim/leaders.vim` |
| n | `\` `tdc` | `g:table_mode_delete_column_map`. | `vim/leaders.vim` |
| n | `\` `tic` | `g:table_mode_insert_column_after_map`. | `vim/leaders.vim` |
| n | `]al` / `[al` | `:ALENext` / `:ALEPrevious`. | `vim/leaders.vim` |
| n | `,d` | `:DogeGenerate`. | `vim/leaders.vim` |
| n | `,u` | `:GundoToggle`. | `vim/leaders.vim` |
| n | `<Space>` `gf` | `vie` then `:edit` of `findfile(expand('<cfile>'))`. | `vim/leaders.vim` |

`shortcuts.vim` (markdown, via vim-abolish) defines abbreviation corrections (`:shrug:` and the other emoji abbreviations, `Abolish` pairs such as `teh`/`the`, and the longer spelling list in that file). Those are insert abbreviations, not keymaps.

### TaskPaper

Buffer-local, `ftplugin/taskpaper.vim`. `<Tab>` and `<C-i>` are the same keycode in a terminal, so `<Tab>` replaces the jumplist jump in these buffers.

| Mode | Key | Action | Source |
|---|---|---|---|
| n | `<Tab>` / `<S-Tab>` | `:TaskPaperMoveRight` / `Left`. | `ftplugin/taskpaper.vim` |
| n | `<Space>` `l` / `h` / `k` / `j` | Move right / left / up / down. | `ftplugin/taskpaper.vim` |
| n | `<Space>` `\` | `:TaskPaperMoveToProject`. | `ftplugin/taskpaper.vim` |
| n | `<Space>` `d` | `:TaskPaperToggleDone`. | `ftplugin/taskpaper.vim` |
| n | `<Space>` `f` / `F` | `:TaskPaperFocusIn` / `FocusOut`. | `ftplugin/taskpaper.vim` |
| n | `<Space>` `H` | `:TaskPaperHome`. | `ftplugin/taskpaper.vim` |
| n | `<M-l>` / `<M-h>` / `<M-k>` / `<M-j>` | Move right / left / up / down. | `ftplugin/taskpaper.vim` |
| x | `<Tab>` / `<S-Tab>` | `>gv` / `<gv`. | `ftplugin/taskpaper.vim` |
| x | `<Space>` `d` | `:TaskPaperToggleDone` over the visual range. | `ftplugin/taskpaper.vim` |

### Other filetypes

| Mode | Key | Action | Source |
|---|---|---|---|
| n | `<F5>` | Save and `FloatermNew` `zig run` of this file, killing a previous float named `zigrun`. Zig buffers. | `ftplugin/zig.vim` |
| n | `<C-c>*` | Replace leading whitespace with `** `. Org buffers. | `ftplugin/org.vim` |
| v | `af` | `[[vt{%`. R buffers. | `ftplugin/r.vim` |
| o | `af` | `:normal Vaf`. R buffers. | `ftplugin/r.vim` |
| n | `,n` / `,p` | `<Plug>RNextRChunk` / `<Plug>RPreviousRChunk`. Rmd buffers. | `ftplugin/rmd.vim` |

Rmd textobjects registered with `textobj#user#plugin` in `ftplugin/rmd.vim`:

| Mode | Key | Action | Source |
|---|---|---|---|
| o, x | `ak` / `ik` | Around / inside an Rmd chunk (` ``` `). | `ftplugin/rmd.vim` |
| n | `]k` / `[k` | Next / previous chunk. | `ftplugin/rmd.vim` |
| o, x | `aM` / `iM` | Around / inside markdown text. | `ftplugin/rmd.vim` |
| n | `]n` / `[n` | Next / previous markdown text region. | `ftplugin/rmd.vim` |
| o, x | `ad` / `id` | A `YYYY-MM-DD` date. | `ftplugin/rmd.vim` |
| n | `[i` | Previous `function` match (`bfunc`). | `ftplugin/rmd.vim` |
| n | `]i` | Next `function` match (`ffunc`). | `ftplugin/rmd.vim` |
| n | `[F` | Next `# Funcs` match (`FuncBlock` `move-n`). | `ftplugin/rmd.vim` |

`\` `pyan` runs `pyan % --dot` through graphviz and `open`s the png. `\` `tgf` writes a `.tgf` from `pyan % --tgf`. `\` `dot` runs the current file through `dot -Tpng` and `open`s it. All three are normal-mode maps in `vim/leaders.vim`.

### Firenvim

Only when `g:started_by_firenvim` is set (`lua/config/firenvim.vim`, sourced from the firenvim spec):

| Mode | Key | Action | Source |
|---|---|---|---|
| n | `ZZ` | `:wq!`, on `BufEnter` for `dbc*`. | `lua/config/firenvim.vim` |
| n | `<C-c><C-c>` | `:wq!`, on `BufEnter` for `*cloud.databricks.com*`. | `lua/config/firenvim.vim` |

Takeover for every site is `'never'` (`selector` `textarea, div[role="textbox"]`).

## Mappings in files nothing loads

These are defined in the tree and not `require`d from `init.lua` or a plugin spec.

`lua/config/dap.lua`:

| Mode | Key | Action |
|---|---|---|
| n | `\` `dct` | `dap.continue()` |
| n | `\` `dsi` / `dso` | `dap.step_into()` / `step_out()` |
| n | `\` `dtb` | `dap.toggle_breakpoint()` |
| n | `\` `dsc` | `dap.ui.variables.scopes()` |
| n | `\` `dhh` | `dap.ui.variables.hover()` |
| v | `\` `dhv` | `dap.ui.variables.visual_hover()` |
| n | `\` `duh` | `dap.ui.widgets.hover()` |
| n | `\` `duf` | Centered float of `dap.ui.widgets.scopes` |
| n | `\` `dsbr` | Breakpoint with a condition prompt |
| n | `\` `dsbm` | Log-point breakpoint |
| n | `\` `dro` / `drl` | `dap.repl.open()` / `repl.run_last()` |
| n | `\` `dcc` / `dco` / `dlb` / `dv` / `dlf` | Telescope dap commands, configurations, breakpoints, variables, frames |
| n | `\` `dui` | `dapui.toggle()` |
| n | `\` `dsv` | `<Plug>(DapStepOver)`, which calls `dap.step_over()` and `repeat#set` |

The same file defines `:BreakpointToggle`, `:Debug`, and `:DapREPL`.

`lua/config/windows.lua` (after `require('windows').setup()`):

| Mode | Key | Action |
|---|---|---|
| n | `<C-w>z` | `:WindowsMaximize` |
| n | `<C-w>_` | `:WindowsMaximizeVertically` |
| n | `<C-w>\|` | `:WindowsMaximizeHorizontally` |
| n | `<C-w>=` | `:WindowsEqualize` |

`lua/config/org.lua` passes these to `require('orgmode').setup` and is not loaded. There is no `orgmode` spec in the lazy files.

| Key | orgmode mapping |
|---|---|
| `gA`, `<C-c>a` | `org_agenda` |
| `gC` | `org_capture` |
| `<C-c><C-c>` | `org_capture_finalize` |
| `<C-c><C-w>` | `org_capture_refile` |
| `<C-c><C-k>` | `org_capture_kill` |
| `<C-c>q` | `org_set_tags_command` |
| `+` / `<C-x>` | `org_timestamp_up` / `down` |
| `gK` / `gJ` | `org_move_subtree_up` / `down` |
| `<C-c><C-t>` | `org_todo` |
| `<C-c><C-d>` | `org_deadline` |
| `<C-c><C-s>` | `org_schedule` |
| `\` `oih` | `org_insert_heading_respect_content` |
| `\` `oiT` | `org_insert_todo_heading` |
| `\` `oit` | `org_insert_todo_heading_respect_content` |

It also maps `,,a` to a `<Plug>MyMap` that runs `orgmode.action('org_mappings.archive')`.

`lua/config/dirvish.lua` repeats the dirvish `t` map that `lua/plugins.lua` actually installs. `lua/config/multi.lua` repeats the visual-multi `<M-C-j>` / `<M-C-k>` maps. `lua/config/ultest.lua` and `lua/config/lualine.lua` set plugin options and do not define keymaps.
