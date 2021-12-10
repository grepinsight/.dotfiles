-- rg '^[^\tA-Za-z.]{3}[A-Za-z]' docs/glossary.rst
local Job = require "plenary.job"

local source = {}

source.new = function()
    local self = setmetatable({ cache = {} }, { __index = source })

    return self
end

source.complete = function(self, _, callback)
    local bufnr = vim.api.nvim_get_current_buf()

    -- This just makes sure that we only hit the GH API once per session.
    --
    -- You could remove this if you wanted, but this just makes it so we're
    -- good programming citizens.
    if not self.cache[bufnr] then
        Job
        :new({
            -- Uses `gh` executable to request the issues from the remote repository.
            "rg",
            "^[^\tA-Za-z.]{3}[A-Za-z]",
            "docs/glossary.rst",

            on_exit = function(job)
                local parsed = job:result()
                -- local ok, parsed = pcall(vim.json.decode, table.concat(result, ""))
                -- if not ok then
                --     vim.notify "Failed to parse gh result"
                --     return
                -- end

                local items = {}
                for _, glossary_item in ipairs(parsed) do
                    glossary_item = string.gsub(glossary_item, "^%s+", "")

                    table.insert(items, {
                        label = string.format(":term:`%s`", glossary_item),
                        documentation = {
                            kind = "markdown",
                            value = "blank"
                        },
                    })
                end

                callback { items = items, isIncomplete = false }
                self.cache[bufnr] = items
            end,
        })
        :start()
    else
        callback { items = self.cache[bufnr], isIncomplete = false }
    end
end

source.get_trigger_characters = function()
    return { ":term:" }
end

source.is_available = function()
    return vim.bo.filetype == "python" or vim.bo.filetype == "rst"
end

require("cmp").register_source("rst_glossary", source.new())

