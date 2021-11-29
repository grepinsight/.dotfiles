require('telescope').load_extension('dap')
local map = require('config.utils').map

vim.cmd [[command! BreakpointToggle lua require('dap').toggle_breakpoint()]]
vim.cmd [[command! Debug lua require('dap').continue()]]
vim.cmd [[command! DapREPL lua require('dap').repl.open()]]

map('n', '<F5>', [[<cmd>lua require'dap'.continue()<CR>]])
map('n', '<F10>', [[<cmd>lua require'dap'.step_over()<CR>]])
map('n', '<F11>', [[<cmd>lua require'dap'.step_into()<CR>]])
map('n', '<F12>', [[<cmd>lua require'dap'.step_out()<CR>]])

map('n', '<leader>dct', '<cmd>lua require"dap".continue()<CR>')
-- map('n', '<leader>dsv', '<cmd>lua require"dap".step_over()<CR>')
map('n', '<leader>dsi', '<cmd>lua require"dap".step_into()<CR>')
map('n', '<leader>dso', '<cmd>lua require"dap".step_out()<CR>')
map('n', '<leader>dtb', '<cmd>lua require"dap".toggle_breakpoint()<CR>')

map('n', '<leader>dsc', '<cmd>lua require"dap.ui.variables".scopes()<CR>')
map('n', '<leader>dhh', '<cmd>lua require"dap.ui.variables".hover()<CR>')
map('v', '<leader>dhv',
    '<cmd>lua require"dap.ui.variables".visual_hover()<CR>')

map('n', '<leader>duh', '<cmd>lua require"dap.ui.widgets".hover()<CR>')
map('n', '<leader>duf',
    "<cmd>lua local widgets=require'dap.ui.widgets';widgets.centered_float(widgets.scopes)<CR>")

map('n', '<leader>dsbr',
    '<cmd>lua require"dap".set_breakpoint(vim.fn.input("Breakpoint condition: "))<CR>')
map('n', '<leader>dsbm',
    '<cmd>lua require"dap".set_breakpoint(nil, nil, vim.fn.input("Log point message: "))<CR>')
map('n', '<leader>dro', '<cmd>lua require"dap".repl.open()<CR>')
map('n', '<leader>drl', '<cmd>lua require"dap".repl.run_last()<CR>')


-- telescope-dap
map('n', '<leader>dcc',
    '<cmd>lua require"telescope".extensions.dap.commands{}<CR>')
map('n', '<leader>dco',
    '<cmd>lua require"telescope".extensions.dap.configurations{}<CR>')
map('n', '<leader>dlb',
    '<cmd>lua require"telescope".extensions.dap.list_breakpoints{}<CR>')
map('n', '<leader>dv',
    '<cmd>lua require"telescope".extensions.dap.variables{}<CR>')
map('n', '<leader>df',
          '<cmd>lua require"telescope".extensions.dap.frames{}<CR>')
map('n', '<leader>dui', '<cmd>lua require"dapui".toggle()<CR>')

require('dap-python').setup('python')
require("dapui").setup()

vim.fn.sign_define("DapBreakpoint", {text = '🛑', texthl = '', linehl = '', numhl = ''})
vim.g.dap_virtual_text = true


-- vim.cmd [[
-- nnoremap <silent> <Plug>TransposeCharacters xp
-- \:call repeat#set("\<Plug>TransposeCharacters")<CR>
-- nmap cp <Plug>TransposeCharacters
-- ]]
--
--
vim.cmd [[
  nnoremap <silent> <Plug>(DapStepOver) <cmd>lua require"dap".step_over()<CR>
  \:call repeat#set("\<Plug>(DapStepOver)")<CR>
  nmap <leader>dsv <Plug>(DapStepOver)
]]

require('config.dbg.lua')
