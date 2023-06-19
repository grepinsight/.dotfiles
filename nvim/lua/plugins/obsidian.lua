local M = {
        'epwalsh/obsidian.nvim',
        ft = {"markdown"},
        dependencies = {
            'nvim-lua/plenary.nvim'
        }
    }
function M.config()
    require("obsidian").setup({
      dir = "/Users/allee/Library/Mobile Documents/iCloud~md~obsidian/Documents/Thoughts",
      completion = {
        nvim_cmp = true, -- if using nvim-cmp, otherwise set to false
      },
      daily_notes = {
        folder = "02-Calendar/Daily",
      },
      use_advanced_uri = true,
      disable_frontmatter = true,
      note_id_func = function(title)
          return title
      end
    })

    vim.keymap.set(
      "n",
      "gf",
      function()
        if require('obsidian').util.cursor_on_markdown_link() then
          return "<cmd>ObsidianFollowLink<CR>"
        else
          return "gf"
        end
      end,
      { noremap = false, expr = true}
    )
end
return M
