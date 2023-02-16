local ls = require("luasnip") -- {{{
local s = ls.s
local i = ls.i
local t = ls.t

local d = ls.dynamic_node
local c = ls.choice_node
local f = ls.function_node
local sn = ls.snippet_node

local fmt = require("luasnip.extras.fmt").fmt
local rep = require("luasnip.extras").rep

local snippets, autosnippets = {}, {} -- }}}

local group = vim.api.nvim_create_augroup("Lua Snippets", {clear = true})
local file_pattern = "*.lua"

local function cs(trigger, nodes, opts) -- {{{
    local snippet = s(trigger, nodes)
    local target_table = snippets

    local pattern = file_pattern
    local keymaps = {}

    if opts ~= nil then
        -- check for custom pattern
        if opts.pattern then pattern = opts.pattern end

        -- if opts is a string
        if type(opts) == "string" then
            if opts == "auto" then
                target_table = autosnippets
            else
                table.insert(keymaps, {"i", opts})
            end
        end

        -- if opts is a table
        if opts ~= nil and type(opts) == "table" then
            for _, keymap in ipairs(opts) do
                if type(keymap) == "string" then
                    table.insert(keymaps, {"i", keymap})
                else
                    table.insert(keymaps, keymap)
                end
            end
        end

        -- set autocmd for each keymap
        if opts ~= "auto" then
            for _, keymap in ipairs(keymaps) do
                vim.api.nvim_create_autocmd("BufEnter", {
                    pattern = pattern,
                    group = group,
                    callback = function()
                        vim.keymap.set(keymap[1], keymap[2],
                                       function()
                            ls.snip_expand(snippet)
                        end, {noremap = true, silent = true, buffer = true})
                    end
                })
            end
        end
    end

    table.insert(target_table, snippet) -- insert snippet into appropriate table
end -- }}}

-- Start Refactoring --
local my_snippets = s("wowzi", {t("WWWZZZZHOW THE HELL")})

table.insert(snippets, my_snippets)

local wo = s({trig = "wo", namr = "with open", desc = "with open"}, fmt([[
        with open({}, "r") as f:
            {}
          ]], {c(1, {t "\"file\"", t "file"}), i(2, "body")}))
table.insert(snippets, wo)

local watermark = s("watermark", fmt([[
%load_ext watermark
%watermark -n -u -v -iv -w
]], {}))
table.insert(snippets, watermark)

local po= s(";po", fmt([[
plotly.offline.init_notebook_mode(connected=True)
]], {}))
table.insert(snippets, po)


-- For Plotly
local for_each_annotation = s("fea", fmt([[
for_each_annotation(lambda a: a.update(text=a.text.split("=")[-1]))
]], {}))
table.insert(snippets, for_each_annotation)

local toy_data = s("toy", fmt([[
import pandas as pd
df = pd.DataFrame({{'a': [1, 2,3]}})
]], {}))
table.insert(snippets, toy_data)

local sci = s("sci", fmt([[
%reload_ext lab_black
%reload_ext autoreload
%autoreload 2

# Base
from pathlib import Path

# Science
import numpy as np
import pandas as pd
from scipy.special import logit

# Plots
import plotly.express as px

]], {}))
table.insert(snippets, sci)

local start = s("start", fmt([[
---
title: "title"
author: "Albert Lee"
date: ""
categories:
  - quarto
  - visualization
execute:
  echo: true
format:
  html:
    theme: cyborg
    page-layout: full
    toc: true
    toc-depth: 5
    number-sections: true
    self-contained: true
    smooth-scroll: true
    smooth-scroll: true
    code-line-numbers: true
    #code-fold: true
    #code-tools: true
---
]], {}))
table.insert(snippets, start)


-- End Refactoring --

return snippets, autosnippets
