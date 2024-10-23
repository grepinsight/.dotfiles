local builtin = require("telescope.builtin")
local utils = require("telescope.utils")

-- nnoremap <silent> <C-p> <cmd>lua require('telescope.builtin').find_files()<cr>
vim.keymap.set("n", "<C-p>", function()
  builtin.find_files({ cwd = utils.buffer_dir() })
end, {})
