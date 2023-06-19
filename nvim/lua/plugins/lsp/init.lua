local lsp_related_ui_adjust = function()
  require("lspconfig.ui.windows").default_options.border = "rounded"
  vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })
  vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" })

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
    local nvim_lsp = require('lspconfig')
    -- local navbuddy = require("nvim-navbuddy")
    local lsp = vim.lsp
    local handlers = lsp.handlers

    ---
    vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
            local bufnr = args.buf
            local client = vim.lsp.get_client_by_id(args.data.client_id)

            local opts = { buffer = bufnr }

            vim.keymap.set("n", "<leader>dn", vim.diagnostic.goto_next, opts)
            vim.keymap.set("n", "<leader>dp", vim.diagnostic.goto_prev, opts)
            vim.keymap.set("n", "<leader>dd", vim.diagnostic.open_float, opts)
            vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
            vim.keymap.set({ "i", "n" }, "<C-s>", vim.lsp.buf.signature_help, opts)
            vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
            vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)

            -- auto show diagnostic when cursor hold
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

    ----
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

    local setup_server = function(server, config)
        if not config then
            return
        end

        if type(config) ~= "table" then
            config = {}
        end

        config = vim.tbl_deep_extend("force", {
            capabilities = capabilities,
        }, config)

        require("lspconfig")[server].setup(config)
    end

    local servers = require("plugins.lsp.lsp_servers")
    for server, setting in pairs(servers) do
        if setting.disabled then
            goto continue
        end

        if setting.config ~= nil then
            setup_server(server, setting.config)
        else
            setup_server(server, {})
        end

        ::continue::
    end




    -- Hover doc popup
    local pop_opts = { border = "rounded", max_width = 80 }
    handlers["textDocument/hover"] = lsp.with(handlers.hover, pop_opts)
    handlers["textDocument/signatureHelp"] = lsp.with(handlers.signature_help, pop_opts)

    local on_attach = function(client, bufnr)
        -- navbuddy.attach(client, bufnr)

        -- setup aerial
        -- require('aerial').on_attach(client, bufnr)

        local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
        local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

        buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

        -- Mappings.
        local opts = { noremap=true, silent=true }
        buf_set_keymap('n', 'g0', '<Cmd>lua vim.lsp.buf.document_symbol()<CR>', opts)
        buf_set_keymap('n', 'gW', '<Cmd>lua vim.lsp.buf.workspace_symbol()<CR>', opts)
        buf_set_keymap('n', 'ga', '<Cmd>lua vim.lsp.buf.code_action()<CR>', opts)
        buf_set_keymap('n', 'gD', '<Cmd>lua vim.lsp.buf.declaration()<CR>', opts)
        buf_set_keymap('n', 'gd', '<Cmd>lua vim.lsp.buf.definition()<CR>', opts)
        buf_set_keymap('n', 'K', '<Cmd>lua vim.lsp.buf.hover()<CR>', opts)
        --buf_set_keymap('n', 'K', '<Cmd>lua require("lspsaga.hover").render_hover_doc()<CR>', opts)
        buf_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
        buf_set_keymap('n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
        buf_set_keymap('i', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
        buf_set_keymap('n', '<space>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
        buf_set_keymap('n', '<space>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
        buf_set_keymap('n', '<space>wl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
        buf_set_keymap('n', '<space>D', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
        buf_set_keymap('n', 'gN', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
        -- buf_set_keymap('n', 'gN', "<cmd>lua require('lspsaga.rename').rename()<CR>", opts)
        buf_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
        vim.keymap.set('n', '<space>e', vim.diagnostic.open_float, opts)

        buf_set_keymap('n', '[d', '<cmd>lua vim.diagnostic.goto_prev()<CR>', opts)

        buf_set_keymap('n', ']d', '<cmd>lua vim.diagnostic.goto_next()<CR>', opts)
        buf_set_keymap('n', '<space>q', '<cmd>lua vim.diagnostic.set_loclist()<CR>', opts)


        -- Set some keybinds conditional on server capabilities
        if client.server_capabilities.document_formatting then
            buf_set_keymap("n", "<space>f", "<cmd>lua vim.lsp.buf.formatting()<CR>", opts)
        elseif client.server_capabilities.document_range_formatting then
            buf_set_keymap("n", "<space>f", "<cmd>lua vim.lsp.buf.range_formatting()<CR>", opts)
        end

        -- Set autocommands conditional on server_capabilities
        if client.server_capabilities.document_highlight then
            vim.api.nvim_exec([[
            hi LspReferenceRead cterm=bold ctermbg=red guibg=LightYellow
            hi LspReferenceText cterm=bold ctermbg=red guibg=LightYellow
            hi LspReferenceWrite cterm=bold ctermbg=red guibg=LightYellow
            augroup lsp_document_highlight
            autocmd! * <buffer>
            autocmd CursorHold <buffer> lua vim.lsp.buf.document_highlight()
            autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()
            augroup END
            ]], false)
        end
    end


    local function organize_imports()
      local params = {
        command = "_typescript.organizeImports",
        arguments = {vim.api.nvim_buf_get_name(0)},
        title = ""
      }
      vim.lsp.buf.execute_command(params)
    end

    nvim_lsp.tsserver.setup {
        on_attach = on_attach,
        -- capabilities = capabilities,
        commands = {
            OrganizeImports = {
                organize_imports,
                description = "Organize Imports"
            }
        }
    }


    nvim_lsp.r_language_server.setup {
        on_attach = on_attach,
    }
    USER = vim.fn.expand('$USER')

    local sumneko_root_path = ""
    local sumneko_binary = ""

    if vim.fn.has("mac") == 1 then
        sumneko_root_path = "/Users/" .. USER .. "/.config/nvim/lua-language-server"
        sumneko_binary = "/Users/" .. USER .. "/.config/nvim/lua-language-server/bin/macOS/lua-language-server"
        sumneko_e_path = sumneko_root_path .. "/main.lua"
    elseif vim.fn.has("unix") == 1 then
        sumneko_root_path = "/home/" .. USER .. "/.config/nvim/lua-language-server"
        sumneko_binary = "/home/" .. USER .. "/.config/nvim/lua-language-server/bin/Linux/lua-language-server"
        sumneko_e_path = sumneko_root_path .. "/bin/Linux/main.lua"
    else
        print("Unsupported system for sumneko")
    end

    local runtime_path = vim.split(package.path, ';')
    table.insert(runtime_path, "lua/?.lua")
    table.insert(runtime_path, "lua/?/init.lua")


    -- require'lspconfig'.lua_ls.setup {
    --     cmd = {sumneko_binary, "-E", sumneko_e_path};
    --     on_attach=on_attach,
    --     settings = {
    --         Lua = {
    --             runtime = {
    --                 -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
    --                 version = 'LuaJIT',
    --                 -- Setup your lua path
    --                 path = runtime_path,
    --             },
    --             diagnostics = {
    --                 -- Get the language server to recognize the `vim` global
    --                 globals = {'vim'},
    --             },
    --             workspace = {
    --                 -- Make the server aware of Neovim runtime files
    --                 library = vim.api.nvim_get_runtime_file("", true),
    --             },
    --             -- Do not send telemetry data containing a randomized but unique identifier
    --             telemetry = {
    --                 enable = false,
    --             },
    --         },
    --     },
    -- }


    vim.g.diagnostics_active = true
    function _G.toggle_diagnostics()
      if vim.g.diagnostics_active then
        vim.g.diagnostics_active = false
        vim.diagnostic.disable()
      else
        vim.g.diagnostics_active = true
        vim.diagnostic.enable()
      end
    end

    vim.api.nvim_set_keymap('n', '<leader>tt', ':call v:lua.toggle_diagnostics()<CR>',  {noremap = true, silent = true})

    require'lspconfig'.svelte.setup{}
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
