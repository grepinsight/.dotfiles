-- local gps = require("nvim-gps")
-- gps.setup()

local function lualine_orgmode()
	return orgmode.statusline()
end

require('lualine').setup {
	options = {theme = 'gruvbox'},
	sections = {
		lualine_b = {
				{ "branch" },
				{ "diff", colored = true, color_added = "#a7c080", color_modified = "#ffdf1b", color_removed = "#ff6666" },
		},
		-- lualine_c = {gps.get_location, condition=gps.is_available},
		lualine_x = {lualine_orgmode}
	}
}

