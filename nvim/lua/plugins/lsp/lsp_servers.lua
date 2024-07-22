return {
    ruff_lsp = {
        name = "ruff-lsp", -- for mason installer
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
            on_new_config = function(new_config, root_dir)
                local pipfile_exists = require("lspconfig").util.search_ancestors(root_dir, function(path)
                    local pipfile = require("lspconfig").util.path.join(path, "Pipfile")
                    if require("lspconfig").util.path.is_file(pipfile) then
                        return true
                    else
                        return false
                    end
                end)

                if pipfile_exists then
                    new_config.cmd = { "pipenv", "run", "pyright-langserver", "--stdio" }
                end
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
                        loadOutDirsFromCheck = true
                    },
                    procMacro = {
                        enable = true
                    },
                }
            }
        }
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
    }


}
