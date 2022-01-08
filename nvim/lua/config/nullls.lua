local null_ls = require("null-ls")

local sources = {
    null_ls.builtins.diagnostics.write_good,
    null_ls.builtins.code_actions.gitsigns,
}

null_ls.setup({ sources = sources })

local api = vim.api

local no_really = {
    method = null_ls.methods.DIAGNOSTICS,
    filetypes = { "markdown", "txt" },
    generator = {
        fn = function(params)
            local diagnostics = {}
            -- sources have access to a params object
            -- containing info about the current file and editor state
            for i, line in ipairs(params.content) do
                local col, end_col = line:find("really")
                if col and end_col then
                    -- null-ls fills in undefined positions
                    -- and converts source diagnostics into the required format
                    table.insert(diagnostics, {
                        row = i,
                        col = col,
                        end_col = end_col,
                        source = "no-really",
                        message = "Don't use 'really!'",
                        severity = 2,
                    })
                end
            end
            return diagnostics
        end,
    },
}

null_ls.register(no_really)
