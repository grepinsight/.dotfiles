return {
    -- managing tool
    {
        "williamboman/mason.nvim",
        -- It's important that you set up the plugins in the following order:
        -- 1. mason.nvim
        -- 2. mason-lspconfig.nvim
        -- 3. Setup servers via lspconfig
        priority = 100,
        dependencies = {
            -- bridges mason with the lspconfig. NOTE: no `config` here on
            -- purpose -- lazy.nvim runs a dependency's `config` BEFORE its
            -- parent's, which would call mason-lspconfig.setup() before
            -- mason.setup() and trip the "mason.nvim has not been set up"
            -- error. We set it up from mason's own config below instead.
            { "williamboman/mason-lspconfig.nvim" },

            -- Install and upgrade third party tools automatically
            {
                "WhoIsSethDaniel/mason-tool-installer.nvim",
                priority = 90,
                config = function()
                    local langueage_servers = require("plugins.lsp.lsp_servers")
                    local formatters = require("plugins.formatting.formatters")
                    -- local adapters = require("plugins.dap.adapters")
                    local linters = require("plugins.linting.linters")
                    local tool_names = {}
                    for _, server in pairs(langueage_servers) do
                        -- if server has the field disabled and is true,
                        -- then don't include it
                        if server.disabled then
                            if server.disabled == true then
                                -- empty
                            else
                                table.insert(tool_names, server.name)
                            end
                        else
                            table.insert(tool_names, server.name)
                        end
                    end
                    for _, formatter in pairs(formatters) do
                        -- honor `disabled` (like the language_servers loop above)
                        -- and `mason = false` (tool isn't a Mason package); either
                        -- one keeps the formatter out of the installer
                        if formatter.disabled ~= true and formatter.mason ~= false then
                            table.insert(tool_names, formatter.name)
                        end
                    end
                    -- for _, adapter in pairs(adapters) do
                    --   table.insert(tool_names, adapter.name)
                    -- end
                    for _, linter in pairs(linters) do
                        if linter.disabled ~= true then
                            table.insert(tool_names, linter.name)
                        end
                    end
                    require("mason-tool-installer").setup({
                        ensure_installed = tool_names,
                    })
                end,
            },
        },
        config = function()
            require("mason").setup({
                providers = {
                    "mason.providers.registry-api", -- default
                    "mason.providers.client",
                },
                ui = {
                    height = 0.85,
                    border = "rounded",
                },
            })
            -- Set up mason-lspconfig AFTER mason (order matters). Keep
            -- automatic_enable off: servers are configured/enabled explicitly
            -- in plugins/lsp/init.lua, so letting mason-lspconfig auto-enable
            -- them too would double-start each language server.
            require("mason-lspconfig").setup({
                automatic_enable = false,
            })
        end,
    },
}
