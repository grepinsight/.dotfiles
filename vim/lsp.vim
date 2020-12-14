" Configure LSP
" https://github.com/neovim/nvim-lspconfig#rust_analyzer
lua <<EOF

-- nvim_lsp object
local nvim_lsp = require'nvim_lsp'

-- function to attach completion and diagnostics
-- when setting up lsp
local on_attach = function(client)
    require'completion'.on_attach(client)
    require'diagnostic'.on_attach(client)
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
