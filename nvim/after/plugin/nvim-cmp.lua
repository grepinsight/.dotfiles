local cmp = require 'cmp'
local lspkind = require('lspkind')

local fn = vim.fn

local function t(str)
    return vim.api.nvim_replace_termcodes(str, true, true, true)
end

local check_back_space = function()
    local col = vim.fn.col "." - 1
    return col == 0 or vim.fn.getline("."):sub(col, col):match "%s" ~= nil
end

local function tab(fallback)
    -- local luasnip = require "luasnip"
    if fn.pumvisible() == 1 then
        fn.feedkeys(t "<C-n>", "n")
    -- elseif luasnip.expand_or_jumpable() then
    --     fn.feedkeys(t "<Plug>luasnip-expand-or-jump", "")
    elseif check_back_space() then
        fn.feedkeys(t "<tab>", "n")
    else
        fallback()
    end
end

local function shift_tab(fallback)
    local luasnip = require "luasnip"
    if fn.pumvisible() == 1 then
        fn.feedkeys(t "<C-p>", "n")
    else
        fallback()
    end
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
    ["<Tab>"] = cmp.mapping(tab, { "i", "s" }),
    ["<S-Tab>"] = cmp.mapping(shift_tab, { "i", "s" }),
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
