local builtin = require("telescope.builtin")
local utils = require("telescope.utils")

-- nnoremap <silent> <C-p> <cmd>lua require('telescope.builtin').find_files()<cr>
vim.keymap.set("n", "<C-p>", function()
  builtin.find_files({ cwd = utils.buffer_dir() })
end, {})

-- Move selected lines with shift+j or shift+k
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- Duplicate a line and comment out the first line
vim.keymap.set("n", "yc", "yygccp")

-- it inserts => (surrounded by spaces)
vim.keymap.set("i", "<C-l>", "<space>=><space>")
