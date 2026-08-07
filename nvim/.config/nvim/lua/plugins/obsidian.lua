local M = {
  "epwalsh/obsidian.nvim",
  version = "*",
  ft = { "markdown" },
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
}
function M.config()
  require("obsidian").setup({
    dir = require("util.vault").root(),
    mappings = {
      -- Deliberately not util.smart_action(): when the cursor is not on a link
      -- it falls straight through to ObsidianToggleCheckbox, which prepends
      -- "- [ ] " to whatever line you happen to be on -- a heading, prose, even
      -- frontmatter. One stray <CR> (a second Enter after `:Yesterday`, say)
      -- silently edits the note. So only act on something that already exists:
      -- a link, an existing checkbox, or a real list item. Anything else falls
      -- through to a plain <CR>.
      ["<cr>"] = {
        action = function()
          local util = require("obsidian").util
          if util.cursor_on_markdown_link(nil, nil, true) then
            return "<cmd>ObsidianFollowLink<CR>"
          end
          -- Toggle only a checkbox that is already there. Deliberately NOT the
          -- bullet -> checkbox conversion: daily notes are mostly bullets, so a
          -- stray <CR> would still rewrite a line. That conversion is still one
          -- keypress away via <C-Space> or <leader>tc below.
          -- Pattern mirrors util.toggle_checkbox so this cannot disagree with it.
          if vim.api.nvim_get_current_line():match("^%s*- %[.%] ") then
            return "<cmd>ObsidianToggleCheckbox<CR>"
          end
          return "<CR>"
        end,
        opts = { buffer = true, expr = true },
      },
    },
    completion = {
      nvim_cmp = true, -- if using nvim-cmp, otherwise set to false
      min_chars = 2,
    },
    daily_notes = {
      folder = "02-Calendar/Daily",
    },
    use_advanced_uri = true,
    disable_frontmatter = true,
    note_id_func = function(title)
      return title
    end,

    ui = {
      enable = true, -- set to false to disable all additional syntax features
      update_debounce = 200, -- update delay after a text change (in milliseconds)
      max_file_length = 5000, -- disable UI features for files with more than this many lines
      -- Define how various check-boxes are displayed
      checkboxes = {
        -- NOTE: the 'char' value has to be a single character, and the highlight groups are defined below.
        [" "] = { char = "󰄱", hl_group = "ObsidianTodo" },
        ["x"] = { char = "", hl_group = "ObsidianDone" },
        [">"] = { char = "", hl_group = "ObsidianRightArrow" },
        ["~"] = { char = "󰰱", hl_group = "ObsidianTilde" },
        ["!"] = { char = "", hl_group = "ObsidianImportant" },
        ["/"] = { char = "🏗️", hl_group = "ObsidianImportant" },
        -- Replace the above with this if you don't have a patched font:
        -- [" "] = { char = "☐", hl_group = "ObsidianTodo" },
        ["u"] = { char = "", hl_group = "ObsidianDone" },
        ["w"] = { char = "🏆", hl_group = "ObsidianDone" },
        ["*"] = { char = "⭐", hl_group = "ObsidianDone" },
        ['"'] = { char = "🗣️", hl_group = "ObsidianDone" },

        -- You can also add more custom ones...
      },
      -- Use bullet marks for non-checkbox lists.
      bullets = { char = "•", hl_group = "ObsidianBullet" },
      external_link_icon = { char = "", hl_group = "ObsidianExtLinkIcon" },
      -- Replace the above with this if you don't have a patched font:
      -- external_link_icon = { char = "", hl_group = "ObsidianExtLinkIcon" },
      reference_text = { hl_group = "ObsidianRefText" },
      highlight_text = { hl_group = "ObsidianHighlightText" },
      tags = { hl_group = "ObsidianTag" },
      block_ids = { hl_group = "ObsidianBlockID" },
      hl_groups = {
        -- The options are passed directly to `vim.api.nvim_set_hl()`. See `:help nvim_set_hl`.
        ObsidianTodo = { bold = true, fg = "#f78c6c" },
        ObsidianDone = { bold = true, fg = "#89ddff" },
        ObsidianRightArrow = { bold = true, fg = "#f78c6c" },
        ObsidianTilde = { bold = true, fg = "#ff5370" },
        ObsidianImportant = { bold = true, fg = "#d73128" },
        ObsidianBullet = { bold = true, fg = "#89ddff" },
        ObsidianRefText = { underline = true, fg = "#c792ea" },
        ObsidianExtLinkIcon = { fg = "#c792ea" },
        ObsidianTag = { italic = true, fg = "#89ddff" },
        ObsidianBlockID = { italic = true, fg = "#89ddff" },
        ObsidianHighlightText = { bg = "#75662e" },
      },
    },
  })

  vim.keymap.set("n", "gf", function()
    if require("obsidian").util.cursor_on_markdown_link() then
      return "<cmd>ObsidianFollowLink<CR>"
    else
      return "gf"
    end
  end, { noremap = false, expr = true })

  -- Toggle checkbox with <C-Space> in normal mode
  vim.keymap.set("n", "<C-Space>", "<cmd>ObsidianToggleCheckbox<CR>", { desc = "Toggle checkbox" })
  -- Alternative: use <leader>tc
  vim.keymap.set("n", "<leader>tc", "<cmd>ObsidianToggleCheckbox<CR>", { desc = "Toggle checkbox" })
  vim.keymap.set("n", "<leader>s", "<cmd>ObsidianQuickSwitch<CR>", { desc = "ObsidianQuickSwitch" })
  vim.keymap.set("n", "<leader>b", "<cmd>ObsidianBacklinks<CR>", { desc = "ObsidianBacklinks" })
  vim.keymap.set("n", "<leader>o", "<cmd>ObsidianTOC<CR>", { desc = "ObsidianTOC" })
  vim.keymap.set("n", "<leader>y", "<cmd>ObsidianYesterday<CR>", { desc = "ObsidianYesterday" })
end
return M
