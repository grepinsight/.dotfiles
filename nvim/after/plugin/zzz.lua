function setup_due_nvim()
    require('due_nvim').setup({
        prescript = 'due: ',           -- prescript to due data
        prescript_hi = 'Comment',      -- highlight group of it
        due_hi = 'String',             -- highlight group of the data itself
        ft = '*.org,*.md',                   -- filename template to apply aucmds :)
        today = 'TODAY',               -- text for today's due
        today_hi = 'Character',        -- highlight group of today's due
        overdue = 'OVERDUE',           -- text for overdued
        overdue_hi = 'Error',          -- highlight group of overdued
        date_hi = 'Conceal',           -- highlight group of date string
        pattern_start = '<',           -- start for a date string pattern
        pattern_end = '>',             -- end for a date string pattern
        use_clock_time = false,        -- allow due.nvim to calculate hours, minutes, and seconds
        default_due_time = "midnight", -- if use_clock_time == true, calculate time until option on specified date.
        --   Accepts "midnight", for 23:59:59, or noon, for 12:00:00
    })

end
vim.cmd([[autocmd User due.nvim lua setup_due_nvim()]])
