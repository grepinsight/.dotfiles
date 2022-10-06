local luasnip = require("luasnip")

local has_words_before = function()
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end


vim.cmd [[
" gray
highlight! CmpItemAbbrDeprecated guibg=NONE gui=strikethrough guifg=#808080
" blue
highlight! CmpItemAbbrMatch guibg=NONE guifg=#569CD6
highlight! CmpItemAbbrMatchFuzzy guibg=NONE guifg=#569CD6
" light blue
highlight! CmpItemKindVariable guibg=NONE guifg=#9CDCFE
highlight! CmpItemKindInterface guibg=NONE guifg=#9CDCFE
highlight! CmpItemKindText guibg=NONE guifg=#9CDCFE
" pink
highlight! CmpItemKindFunction guibg=NONE guifg=#C586C0
highlight! CmpItemKindMethod guibg=NONE guifg=#C586C0
" front
highlight! CmpItemKindKeyword guibg=NONE guifg=#D4D4D4
highlight! CmpItemKindProperty guibg=NONE guifg=#D4D4D4
highlight! CmpItemKindUnit guibg=NONE guifg=#D4D4D4
]]

local cmp_kinds = {
  Text = 'ﭨ ',
  Method = '  ',
  Function = ' ',
  Constructor = '  ',
  Field = '  ',
  Variable = ' ',
  Class = 'פּ ',
  Interface = 'ﳤ ',
  Module = ' ',
  Property = ' ',
  Unit = '  ',
  Value = '  ',
  Enum = '  ',
  Keyword = '  ',
  Snippet = ' ',
  Color = ' ',
  File = ' ',
  Reference = '  ',
  Folder = '  ',
  EnumMember = '  ',
  Constant = '  ',
  Struct = '  ',
  Event = ' ',
  Operator = '  ',
  TypeParameter = '  ',
}

local cmp = require 'cmp'
local lspkind = require('lspkind')
lspkind.init()

vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.shortmess:append "c"

-- Complextras.nvim configuration
local keymap = vim.api.nvim_set_keymap
keymap("i",
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

-- Extra sources
require('config.cmp_sources.rst_glossary')


local my_mapping = cmp.mapping.preset.insert({
		['<C-k>'] = cmp.mapping.select_prev_item(),
		['<C-j>'] = cmp.mapping.select_next_item(),
		['<C-d>'] = cmp.mapping.scroll_docs(-4),
		['<C-f>'] = cmp.mapping.scroll_docs(4),
		["<C-y>"] = cmp.mapping.confirm {
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
		['<CR>'] = cmp.mapping.confirm(),

         ["<Tab>"] = cmp.mapping(function(fallback)
              if cmp.visible() then
                cmp.select_next_item()
              elseif luasnip.expand_or_jumpable() then
                luasnip.expand_or_jump()
              elseif has_words_before() then
                cmp.complete()
              else
                fallback()
              end
            end, { "i", "s" }),
        ["<S-Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          elseif luasnip.jumpable(-1) then
            luasnip.jump(-1)
          else
            fallback()
          end
        end, { "i", "s" }),
---



})
cmp.setup {
	snippet = {
		expand = function(args)
			-- vim.fn["UltiSnips#Anon"](args.body)
            --            local luasnip = prequire("luasnip")
            if not luasnip then
                return
            end
            luasnip.lsp_expand(args.body)
		end,
	},
	mapping = my_mapping,
	-- formatting = {
	--   format = function(entry, vim_item)
	--     vim_item.kind = lspkind.presets.default[vim_item.kind] .. ' ' .. vim_item.kind
	--     return vim_item
	--   end
	-- },
    -- formatting = {
    -- format = function(_, vim_item)
    --   vim_item.kind = (cmp_kinds[vim_item.kind] or '') .. vim_item.kind
    --   return vim_item
    -- end,
    -- },
	formatting = {
		-- Youtube: How to set up nice formatting for your sources.
		format = lspkind.cmp_format {
			with_text = true,
			menu = {
				nvim_lsp = "[LSP]",
				copilot = "[copilot]",
				-- ultisnips = "[snip]",
				path = "[path]",
				buffer = "[buf]",
				gh_issues = "[issues]",
				orgmode = "[orgmode]",
				rst_glossary = "[glossary]",
			},
		},
	},
    sources = {
        { name = "gh_issues" },
        { name = "rst_glossary" },
        { name = 'orgmode' },
        { name = 'nvim_lsp', keyword_length = 2,},
        -- { name = 'ultisnips', keyword_length = 2 },
        { name = 'luasnip', keyword_length = 2},
        { name = 'copilot' },
        { name = "path" },
        { name = "buffer",
          option = {
              get_bufnrs = function()
                  local bufs = {}
                  for _, win in ipairs(vim.api.nvim_list_wins()) do
                      bufs[vim.api.nvim_win_get_buf(win)] = true
                  end
                  return vim.tbl_keys(bufs)
              end
           }
        },

    },
	experimental = {
		-- I like the new menu better! Nice work hrsh7th
		native_menu = false,

		-- Let's play with this for a day or two
		ghost_text = true,
	},
}

require'cmp'.setup.cmdline(':', {
    mapping = cmp.mapping.preset.cmdline(),
  sources = {
    { name = 'cmdline' }
  }
})
require'cmp'.setup.cmdline('/', {
    mapping = cmp.mapping.preset.cmdline(),
  sources = {
    { name = 'buffer' }
  }
})


