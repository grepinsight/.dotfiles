local actions = require "telescope.actions"
require("telescope").setup({
    defaults = {
        mappings = {
            i = {
              ["<C-j>"] = actions.move_selection_next,
              ["<C-k>"] = actions.move_selection_previous,
            },
        },
    },
    extensions = {
        fzy_native = {
            override_generic_sorter = false,
            override_file_sorter = true,
        },
    },

})

require("telescope").load_extension("git_worktree")
