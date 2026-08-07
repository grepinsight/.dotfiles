local lsp_related_ui_adjust = function()
  require("lspconfig.ui.windows").default_options.border = "rounded"
  -- NOTE: vim.lsp.with()/vim.lsp.handlers[...] overrides are deprecated in nvim 0.11+.
  -- Rounded borders for hover/signature are now passed per-call in the LspAttach
  -- keymaps (see lsp_config_setup); diagnostic floats get theirs from vim.diagnostic.config.

  local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
  for type, icon in pairs(signs) do
    local hl = "DiagnosticSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
  end

  vim.diagnostic.config({
    virtual_text = {
      prefix = "●",
      severity_sort = true,
    },
    float = {
      border = "rounded",
      source = "always", -- Or "if_many"
      prefix = " - ",
    },
    severity_sort = true,
  })
end

local lsp_config_setup = function()
    -- Capabilities advertised to every server (nvim-cmp completion support).
    local capabilities = require("cmp_nvim_lsp").default_capabilities(
        vim.lsp.protocol.make_client_capabilities()
    )

    -- Organize-imports handler for ts_ls; registered as a buffer command in the
    -- LspAttach autocmd below (only when ts_ls attaches).
    local function ts_organize_imports()
        vim.lsp.buf.execute_command({
            command = "_typescript.organizeImports",
            arguments = { vim.api.nvim_buf_get_name(0) },
            title = "",
        })
    end

    -- Buffer-local keymaps + behaviors applied to EVERY attached server. This
    -- runs in addition to (not instead of) the native per-server on_attach that
    -- nvim-lspconfig ships in lsp/<server>.lua.
    vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
            local bufnr = args.buf
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            local opts = { buffer = bufnr, silent = true }

            vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"

            -- navigation
            vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
            vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
            vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
            vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
            vim.keymap.set("n", "ga", vim.lsp.buf.code_action, opts)
            vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
            vim.keymap.set("n", "g0", vim.lsp.buf.document_symbol, opts)
            vim.keymap.set("n", "gW", vim.lsp.buf.workspace_symbol, opts)
            vim.keymap.set("n", "<space>D", vim.lsp.buf.type_definition, opts)

            -- hover / signature (rounded borders passed per-call, replacing the
            -- deprecated vim.lsp.with() handler overrides)
            vim.keymap.set("n", "K", function()
                vim.lsp.buf.hover({ border = "rounded" })
            end, opts)
            vim.keymap.set({ "i", "n" }, "<C-s>", function()
                vim.lsp.buf.signature_help({ border = "rounded" })
            end, opts)
            vim.keymap.set({ "i", "n" }, "<C-k>", function()
                vim.lsp.buf.signature_help({ border = "rounded" })
            end, opts)
            vim.keymap.set("i", "<S-C-k>", function()
                vim.lsp.buf.signature_help({ border = "rounded" })
            end, opts)

            -- rename
            vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
            vim.keymap.set("n", "gN", vim.lsp.buf.rename, opts)

            -- diagnostics
            vim.keymap.set("n", "<leader>dn", vim.diagnostic.goto_next, opts)
            vim.keymap.set("n", "<leader>dp", vim.diagnostic.goto_prev, opts)
            vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
            vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
            vim.keymap.set("n", "<leader>dd", vim.diagnostic.open_float, opts)
            vim.keymap.set("n", "<space>e", vim.diagnostic.open_float, opts)
            vim.keymap.set("n", "<space>q", vim.diagnostic.setloclist, opts)

            -- workspace folders
            vim.keymap.set("n", "<space>wa", vim.lsp.buf.add_workspace_folder, opts)
            vim.keymap.set("n", "<space>wr", vim.lsp.buf.remove_workspace_folder, opts)
            vim.keymap.set("n", "<space>wl", function()
                print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
            end, opts)

            -- Copilot ghost text, via nvim 0.12's native vim.lsp.inline_completion.
            -- Keys match what copilot.lua used (lua/copilot/config/suggestion.lua:30)
            -- so the migration costs no muscle memory. <Tab> stays owned by nvim-cmp.
            if
                client
                and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlineCompletion, bufnr)
            then
                vim.lsp.inline_completion.enable(true, { bufnr = bufnr })
                vim.keymap.set("i", "<M-l>", vim.lsp.inline_completion.get, {
                    buffer = bufnr,
                    silent = true,
                    desc = "Accept inline completion",
                })
                vim.keymap.set("i", "<M-]>", function()
                    vim.lsp.inline_completion.select({ count = 1 })
                end, { buffer = bufnr, silent = true, desc = "Next inline completion" })
                vim.keymap.set("i", "<M-[>", function()
                    vim.lsp.inline_completion.select({ count = -1 })
                end, { buffer = bufnr, silent = true, desc = "Previous inline completion" })
            end

            -- ts_ls: preserve the :OrganizeImports command the old config exposed
            if client and client.name == "ts_ls" then
                vim.api.nvim_buf_create_user_command(
                    bufnr,
                    "OrganizeImports",
                    ts_organize_imports,
                    { desc = "Organize Imports" }
                )
            end

            -- auto show diagnostic float when the cursor holds
            vim.api.nvim_create_autocmd("CursorHold", {
                buffer = bufnr,
                callback = function()
                    local float_opts = {
                        focusable = false,
                        close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
                    }
                    if not vim.b.diagnostics_pos then
                        vim.b.diagnostics_pos = { nil, nil }
                    end
                    local cursor_pos = vim.api.nvim_win_get_cursor(0)
                    if
                        (cursor_pos[1] ~= vim.b.diagnostics_pos[1] or cursor_pos[2] ~= vim.b.diagnostics_pos[2])
                        and #vim.diagnostic.get() > 0
                    then
                        vim.diagnostic.open_float(nil, float_opts)
                    end
                    vim.b.diagnostics_pos = cursor_pos
                end,
            })
        end,
    })

    -- nvim 0.11+ native LSP: configure with vim.lsp.config() and turn servers on
    -- with vim.lsp.enable(). nvim-lspconfig now only ships per-server defaults in
    -- lsp/<name>.lua; the deprecated require('lspconfig')[name].setup{} framework
    -- (the old stack-traceback warning) is no longer used.

    -- Global defaults merged into every server config.
    vim.lsp.config("*", { capabilities = capabilities })

    -- Per-server overrides from lsp_servers.lua, then enable each enabled server.
    local servers = require("plugins.lsp.lsp_servers")
    for server, setting in pairs(servers) do
        if not setting.disabled then
            if type(setting.config) == "table" then
                vim.lsp.config(server, setting.config)
            end
            vim.lsp.enable(server)
        end
    end

    -- Servers set up directly before (not listed in lsp_servers.lua). They inherit
    -- cmd/filetypes/root_markers from nvim-lspconfig's shipped configs; ts_ls
    -- keymaps/commands come from the LspAttach autocmd above.
    -- (r_language_server is intentionally omitted -- it is disabled in lsp_servers.lua.)
    vim.lsp.enable("ts_ls")
    vim.lsp.enable("svelte")

    -- Copilot. nvim-lspconfig ships lsp/copilot.lua with the cmd, root_markers and
    -- the :LspCopilotSignIn command, so we only override what we disagree with.
    --
    -- UI-gated deliberately. copilot declares no filetypes, so it attaches to any
    -- buffer inside a git repo -- including under `nvim --headless`, where its node
    -- server outlives the process as an orphan. That leak is what replaced the
    -- copilot.lua plugin with this block. See lua/util/headless.lua.
    if require("util.headless").has_ui() then
        vim.lsp.config("copilot", {
            -- Neovim defaults exit_timeout to false, so VimLeavePre waits 0ms for a
            -- graceful shutdown and a still-booting server is never reaped. A number
            -- makes Neovim force-stop the client instead of walking away from it.
            exit_timeout = 500,
            -- The shipped config sets telemetryLevel = "all". Opt out.
            settings = { telemetry = { telemetryLevel = "off" } },
        })
        vim.lsp.enable("copilot")
    end

    -- Toggle diagnostics with <leader>tt.
    vim.g.diagnostics_active = true
    function _G.toggle_diagnostics()
        vim.g.diagnostics_active = not vim.g.diagnostics_active
        vim.diagnostic.enable(vim.g.diagnostics_active)
    end
    vim.keymap.set("n", "<leader>tt", _G.toggle_diagnostics, { noremap = true, silent = true })
end



local M = {
        -- LSP
		'neovim/nvim-lspconfig',
        ft = {"python", "cpp", "lua", "rust", "vue", "typescriptreact", "htmldjango", "css", "svelte", "rmd", "r", "go", "markdown"},
        lazy = false,
        dependencies = {
            {
                "SmiteshP/nvim-navbuddy",
                dependencies = {
                    "SmiteshP/nvim-navic",
                    "MunifTanjim/nui.nvim"
                },
                opts = { lsp = { auto_attach = true } }
            },
          -- managing tool
              { "williamboman/mason.nvim" },

              -- bridges mason with the lspconfig
              { "williamboman/mason-lspconfig.nvim" },

              -- nvim-cmp source for neovim's built-in LSP
              { "hrsh7th/cmp-nvim-lsp" },
        },
	}
function M.config()
    lsp_related_ui_adjust()
    lsp_config_setup()
end

return M
