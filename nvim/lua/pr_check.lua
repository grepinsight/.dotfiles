M = {}
vim.notify = require("notify")
local Job = require "plenary.job"
local function callback(result)
    if #result[1] > 0 then
        vim.notify(result[1])
    end
end


local function pr_check()
    Job
    :new({
        "gh",
        "pr",
        "checks",
        on_exit = function(job)
            local result = job:result()
            callback {result}
        end,
    })
    :start()
end

M.pr_check = pr_check
return M
