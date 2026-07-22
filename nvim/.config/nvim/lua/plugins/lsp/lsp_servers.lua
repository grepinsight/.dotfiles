return {
	ruff = {
		name = "ruff", -- for mason installer
		disabled = false,
	},
	html = {
		name = "html-lsp", -- for mason installer
		disabled = false,
	},
	pyright = {
		name = "pyright",
		disabled = false,
		config = {
			settings = {
				python = {
					analysis = {
						diagnosticMode = "openFilesOnly",
						extraPaths = { "third_party" },
						typeCheckingMode = "off",
					},
				},
			},
			-- Run pyright through `pipenv run` when the project has a Pipfile so the
			-- correct virtualenv is used. Native replacement for the old lspconfig
			-- `on_new_config` hook (removed with the deprecated framework); nvim calls
			-- this cmd function per client with the resolved config (incl. root_dir).
			cmd = function(dispatchers, config)
				local root = (config and config.root_dir) or vim.fn.getcwd()
				local has_pipfile = vim.fs.find("Pipfile", { path = root, upward = true, type = "file" })[1] ~= nil
				local exe = has_pipfile and { "pipenv", "run", "pyright-langserver", "--stdio" }
					or { "pyright-langserver", "--stdio" }
				return vim.lsp.rpc.start(exe, dispatchers)
			end,
		},
	},
	-- pylsp = {
	--     name = "python-lsp-server",
	--     disabled = false,
	--     config = {
	--         settings = {
	--             pylsp = {
	--                 configurationSources = {"flake8"},
	--                 plugins = {
	--                     pylint = {
	--                         enabled = true,
	--                         -- args={'--rcfile ' .. os.getenv( "HOME" ) .. '/.dotfiles/pylintrc'}
	--                     },
	--                     flake8 = {
	--                         enabled = true,
	--                         ignore = {"W503", "E221"}
	--                     },
	--                     jedi_completion = {enabled = true},
	--                     jedi_hover = {enabled = true},
	--                     jedi_references = {enabled = true},
	--                     jedi_signature_help = {enabled = true},
	--                     jedi_symbols = {enabled = true, all_scopes = true},
	--                     mypy_ls = {
	--                         enabled = true,
	--                         live_mode = true,
	--                     },
	--                     isort = {enabled = true},
	--                     pycodestyle = {enabled = false},
	--                     yapf = {enabled = false},
	--                     pydocstyle = {enabled = false},
	--                     mccabe = {enabled = false},
	--                     preload = {enabled = false},
	--                     rope_completion = {enabled = false}
	--                 }
	--             }
	--         },
	--     }
	--
	-- },
	rust_analyzer = {
		name = "rust-analyzer",
		disabled = false,
		config = {
			settings = {
				["rust-analyzer"] = {
					assist = {
						importGranularity = "module",
						importPrefix = "self",
					},
					cargo = {
						loadOutDirsFromCheck = true,
					},
					procMacro = {
						enable = true,
					},
				},
			},
		},
	},
	r_language_server = {
		name = "r-languageserver",
		disabled = true,
	},
	tailwindcss = {
		name = "tailwindcss-language-server",
		disabled = false,
	},
	lua_ls = {
		name = "lua-language-server",
		config = {
			settings = {
				Lua = {
					diagnostics = {
						-- Get the language server to recognize the `vim` global
						globals = { "vim" },
					},
					workspace = {
						-- Make the server aware of Neovim runtime files
						-- library = vim.api.nvim_get_runtime_file("", true),
						library = {
							vim.fn.stdpath("config"),
						},
						checkThirdParty = false,
					},
					-- Do not send telemetry data containing a randomized but unique identifier
					telemetry = {
						enable = false,
					},
				},
			},
		},
	},
	gopls = {
		name = "gopls",
	},
	bashls = {
		name = "bash-language-server",
	},
	zls = {
		-- Zig language server. `name` is the mason package mason-tool-installer
		-- auto-installs; the lsp_config_setup loop then wires it through lspconfig
		-- with cmp capabilities + the shared LspAttach keymaps. zls implements
		-- textDocument/formatting (it shells out to `zig fmt`), so format-on-save
		-- comes for free via the LspFormatting autocmd in plugins/formatting/init.lua.
		name = "zls",
		disabled = false,
	},
}
