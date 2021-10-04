local cmp = require 'cmp'
local lspkind = require('lspkind')

local check_back_space = function()
    local col = vim.fn.col '.' - 1
    return col == 0 or vim.fn.getline('.'):sub(col, col):match '%s' ~= nil
end

cmp.setup {
  snippet = {
    expand = function(args)
      vim.fn["UltiSnips#Anon"](args.body)
    end,
  },
  mapping = {
    ['<C-k>'] = cmp.mapping.select_prev_item(),
    ['<C-j>'] = cmp.mapping.select_next_item(),
    ['<C-d>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.close(),
    ['<CR>'] = cmp.mapping.confirm {
      behavior = cmp.ConfirmBehavior.Replace,
      select = true,
    },
    -- ['<Tab>'] = cmp.mapping(function(fallback)
    --     --if vim.fn.pumvisible() == 1 then
    --     --    cmp.mapping.select_next_item()
    --     if vim.fn.pumvisible() == 1 then
    --         vim.fn.feedkeys(vim.api.nvim_replace_termcodes('<C-n>', true, true, true), 'n')
    --     else
    --         vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, false, true), "n", true)
    --     end
    -- end, {"i", "s"}),
    -- ['<S-Tab>'] = function(fallback)
    --   if vim.fn.pumvisible() == 1 then
    --     vim.fn.feedkeys(vim.api.nvim_replace_termcodes('<C-p>', true, true, true), 'n')
    --   -- elseif luasnip.jumpable(-1) then
    --   --   vim.fn.feedkeys(vim.api.nvim_replace_termcodes('<Plug>luasnip-jump-prev', true, true, true), '')
    --   else
    --     vim.cmd(':<')
    --   end
    -- end,
    -- ['<Tab>'] = function(core, fallback)
    --   if vim.fn.pumvisible() == 1 then
    --     vim.fn.feedkeys(vim.api.nvim_replace_termcodes('<C-j>', true, true, true), 'n')
    --   -- elseif luasnip.expand_or_jumpable() then
    --   --   vim.fn.feedkeys(vim.api.nvim_replace_termcodes('<Plug>luasnip-expand-or-jump', true, true, true), '')
    --   -- elseif not check_back_space() then
    --   --   cmp.mapping.complete()(core, fallback)
    --   else
    --     vim.cmd(':>')
    --   end
    -- end,
  },
  formatting = {
    format = function(entry, vim_item)
      vim_item.kind = lspkind.presets.default[vim_item.kind] .. ' ' .. vim_item.kind
      return vim_item
    end
  },
  sources = {
    { name = 'nvim_lsp' },
    { name = 'ultisnips' },
    -- { name = 'look', keyword_length = 2},
    { name = 'orgmode' },
    { name = 'buffer' },
    { name = "path" },
  },
}
