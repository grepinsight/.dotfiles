
local function nvim_gps()
    local gps = require("nvim-gps")
    gps.setup({
        languages = {
            ["org"] = false
        }
    })
    return gps.get_location()
    -- return
end

local function lualine_orgmode()
    local orgmode = require('orgmode')
	return orgmode.statusline()
end

require('lualine').setup {
	options = {theme = "auto"},
	sections = {
		lualine_b = {
				{ "branch" },
				{ "diff", colored = true, color_added = "#a7c080", color_modified = "#ffdf1b", color_removed = "#ff6666" },
                { "filename" }
		},
		lualine_c = {nvim_gps},
		lualine_x = {lualine_orgmode, 'encoding', 'fileformat', 'filetype'}
	}
}

