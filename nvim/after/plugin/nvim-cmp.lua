-- local cmp = require 'cmp'
-- local lspkind = require('lspkind')

-- local fn = vim.fn

-- local function t(str)
--     return vim.api.nvim_replace_termcodes(str, true, true, true)
-- end

-- local check_back_space = function()
--     local col = vim.fn.col "." - 1
--     return col == 0 or vim.fn.getline("."):sub(col, col):match "%s" ~= nil
-- end

-- local function tab(fallback)
--     -- local luasnip = require "luasnip"
--     if fn.pumvisible() == 1 then
--         fn.feedkeys(t "<C-n>", "n")
--     -- elseif luasnip.expand_or_jumpable() then
--     --     fn.feedkeys(t "<Plug>luasnip-expand-or-jump", "")
--     elseif check_back_space() then
--         fn.feedkeys(t "<tab>", "n")
--     else
--         fallback()
--     end
-- end

-- local function shift_tab(fallback)
--     if fn.pumvisible() == 1 then
--         fn.feedkeys(t "<C-p>", "n")
--     else
--         fallback()
--     end
-- end


-- cmp.setup {
--   snippet = {
--     expand = function(args)
--       vim.fn["UltiSnips#Anon"](args.body)
--     end,
--   },
--   mapping = {
--     ['<C-k>'] = cmp.mapping.select_prev_item(),
--     ['<C-j>'] = cmp.mapping.select_next_item(),
--     ['<C-d>'] = cmp.mapping.scroll_docs(-4),
--     ['<C-f>'] = cmp.mapping.scroll_docs(4),
--     ['<C-Space>'] = cmp.mapping.complete(),
--     ['<C-e>'] = cmp.mapping.close(),
--     ['<CR>'] = cmp.mapping.confirm {
--       behavior = cmp.ConfirmBehavior.Replace,
--       select = true,
--     },
--     ["<Tab>"] = cmp.mapping(tab, { "i", "s" }),
--     ["<S-Tab>"] = cmp.mapping(shift_tab, { "i", "s" }),
--   },
--   formatting = {
--     format = function(entry, vim_item)
--       vim_item.kind = lspkind.presets.default[vim_item.kind] .. ' ' .. vim_item.kind
--       return vim_item
--     end
--   },
--   sources = {
--     { name = 'nvim_lsp' },
--     { name = 'ultisnips' },
--     -- { name = 'look', keyword_length = 2},
--     { name = 'orgmode' },
--     { name = 'buffer' },
--     { name = "path" },
--   },
-- }

local cmp = require 'cmp'
local lspkind = require('lspkind')
lspkind.init()

vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.shortmess:append "c"

-- Complextras.nvim configuration
vim.api.nvim_set_keymap(
  "i",
  "<C-x><C-m>",
  [[<c-r>=luaeval("require('complextras').complete_matching_line()")<CR>]],
  { noremap = true }
)

vim.api.nvim_set_keymap(
  "i",
  "<C-x><C-d>",
  [[<c-r>=luaeval("require('complextras').complete_line_from_cwd()")<CR>]],
  { noremap = true }
)

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
    ["<c-y>"] = cmp.mapping.confirm {
      behavior = cmp.ConfirmBehavior.Insert,
      select = true,
    },
    ["<c-q>"] = cmp.mapping.confirm {
      behavior = cmp.ConfirmBehavior.Replace,
      select = true,
    },
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.close(),
    ['<CR>'] = cmp.mapping.confirm {
      behavior = cmp.ConfirmBehavior.Replace,
      select = true,
    },
    -- ['<CR>'] = cmp.mapping.confirm(),
    ['<Tab>'] = cmp.mapping(function(fallback)
        --if vim.fn.pumvisible() == 1 then
        --    cmp.mapping.select_next_item()
        --else
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, false, true), "n", true)
        --end
    end, {"i", "s"}),
  },
  -- formatting = {
  --   format = function(entry, vim_item)
  --     vim_item.kind = lspkind.presets.default[vim_item.kind] .. ' ' .. vim_item.kind
  --     return vim_item
  --   end
  -- },
  formatting = {
    -- Youtube: How to set up nice formatting for your sources.
    format = lspkind.cmp_format {
      with_text = true,
      menu = {
        nvim_lsp = "[LSP]",
        ultisnips = "[snip]",
        path = "[path]",
        buffer = "[buf]",
      },
    },
  },
  sources = {
    { name = 'nvim_lsp' },
    { name = 'ultisnips', keyword_length = 2 },
    { name = "path" },
    { name = "buffer", keyword_length = 5 },
  },
  experimental = {
    -- I like the new menu better! Nice work hrsh7th
    native_menu = false,

    -- Let's play with this for a day or two
    ghost_text = true,
  },
}
