local M = {
    'simrat39/rust-tools.nvim', ft = {"rust"},
}

function M.config()
    require('rust-tools').setup()
end

return M
