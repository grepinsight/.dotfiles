" Configure LSP
" https://github.com/neovim/nvim-lspconfig#rust_analyzer
lua <<EOF

-- nvim_lsp object
local nvim_lsp = require'lspconfig'

-- function to attach completion and diagnostics
-- when setting up lsp
local on_attach = function(client)
    require'completion'.on_attach(client)
--    require'diagnostic'.on_attach(client)
end

-- Enable ccls for C++
nvim_lsp.ccls.setup({ on_attach=on_attach })
--nvim_lsp.clangd.setup({on_attach=on_attach})

-- Enable rust_analyzer
nvim_lsp.rust_analyzer.setup({
    on_attach=on_attach,
    settings = {
          ["rust-analyzer"] = {}
        }
})

-- Enable bash language server

nvim_lsp.bashls.setup({ on_attach=on_attach })

-- R Language Server
nvim_lsp.r_language_server.setup({ on_attach=on_attach })

-- Microsoft Python LSP
nvim_lsp.pyls_ms.setup({ on_attach=on_attach,
      interpreter = {
        properties = {
          InterpreterPath = "/Users/allee/.pyenv/shims/python",
          Version = "3.7"
        }
      }
})


EOF


" Trigger completion with <Tab>
inoremap <silent><expr> <TAB>
  \ pumvisible() ? "\<C-n>" :
  \ <SID>check_back_space() ? "\<TAB>" :
  \ completion#trigger_completion()


lua <<EOF
vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
  vim.lsp.diagnostic.on_publish_diagnostics, {
    -- Enable underline, use default values
    underline = true,
    -- Enable virtual text, override spacing to 4
    virtual_text = {
      spacing = 4,
      prefix = '~',
    },
    -- Use a function to dynamically turn signs off
    -- and on, using buffer local variables
    signs = function(bufnr, client_id)
      local ok, result = pcall(vim.api.nvim_buf_get_var, bufnr, 'show_signs')
      -- No buffer local variable set, so just enable by default
      if not ok then
        return true
      end

      return result
    end,
    -- Disable a feature
    update_in_insert = true,
  }
)
EOF
autocmd CursorHold * lua vim.lsp.diagnostic.show_line_diagnostics()
