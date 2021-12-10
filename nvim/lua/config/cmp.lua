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

-- Extra sources
require('config.cmp_sources.rst_glossary')

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
		--
		['<Tab>'] = cmp.mapping(function(fallback)
			-- if vim.fn.pumvisible() > 0 then
			print("pumvisible(): " .. vim.fn.pumvisible())
			-- cmp.mapping.select_next_item()
			-- else
			-- cmp.mapping.complete()
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, false, true), "n", true)
			-- end
		end, {"i", "s"}),
	},
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
				ultisnips = "[snip]",
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
        { name = 'nvim_lsp' },
        { name = 'ultisnips', keyword_length = 2 },
        { name = "path" },
        { name = "buffer",
        keyword_length = 3,
        get_bufnrs = function()
            local filter = vim.tbl_filter
            local bufnrs = filter(function(b)
                if 1 ~= vim.fn.buflisted(b) then
                    return false
                end
                if not vim.api.nvim_buf_is_loaded(b) then
                    return false
                end
                return true
            end, vim.api.nvim_list_bufs())
            return bufnrs
        end
    },
    },
	experimental = {
		-- I like the new menu better! Nice work hrsh7th
		native_menu = false,

		-- Let's play with this for a day or two
		ghost_text = true,
	},
}


