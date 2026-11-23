" The app's Organize and Move menus, as keys.
"
" The app's own shortcuts are Cmd-based (Ctrl-Cmd-Arrow to move an item, Cmd-\ to move
" it to a project) and a terminal cannot deliver Cmd at all, so the bindings below are
" the adaptation: <localleader> plus a direction, which works everywhere, with <M-hjkl>
" alongside it for terminals that send Alt, because that keeps the app's shape of
" "modifier plus direction".
"
" The Expand/Collapse half of that menu is deliberately absent from this file. Measured
" 2026-09-17: nvim-ufo's indent provider already returns heading-inclusive fold ranges
" here, so the app's eight expand and collapse items are the native fold keys and need
" no binding at all:
"
"   Expand Items zo          Collapse Items zc          (Completely: zO / zC)
"   Expand All By Level zr   Collapse All By Level zm   (Completely: zR / zM)
"
" tests/taskpaper/fold_spec.lua pins the one setting that holds that up. Focus In,
" Focus Out, and Go Home have no fold equivalent, so those three are built.

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

" The sample file on disk is indented with one hard tab per level, so these settings
" exist to keep a move emitting exactly one tab. A space-indented file still reads fine
" here, but it stops round-tripping through the app, which is the whole point.
setlocal noexpandtab
setlocal tabstop=4
setlocal shiftwidth=4
setlocal softtabstop=0
setlocal autoindent

command! -buffer TaskPaperMoveRight     lua require("taskpaper.move").right()
command! -buffer TaskPaperMoveLeft      lua require("taskpaper.move").left()
command! -buffer TaskPaperMoveUp        lua require("taskpaper.move").up()
command! -buffer TaskPaperMoveDown      lua require("taskpaper.move").down()
command! -buffer TaskPaperMoveToProject lua require("taskpaper.move").to_project()
command! -buffer -range TaskPaperToggleDone
      \ lua require("taskpaper.done").toggle_range(<line1>, <line2>)
command! -buffer TaskPaperFocusIn  lua require("taskpaper.focus").focus_in()
command! -buffer TaskPaperFocusOut lua require("taskpaper.focus").focus_out()
" -bang, because a view whose source was edited from another window cannot write
" itself back, and without an escape the only way out of it is :bd!.
"
" v:lua rather than :lua, and v:true/v:false rather than <bang>0, for two reasons that
" both look fine until they run. <bang> expands to a literal `!`, so `<bang>0` on a :lua
" line is the Lua syntax error `!0`; it reads as valid only because `!0` is vimscript's
" own logical not. And once that is fixed, `<bang>0` is 0 or 1, and Lua counts 0 as
" true, so the unbanged command would force the discard it exists to prevent.
command! -buffer -bang TaskPaperHome
      \ call v:lua.require('taskpaper.focus').home(<bang>0 ? v:true : v:false)

" Not >> and <<: an outline move carries the item's children with it, so indenting a
" project by one level has to take its whole subtree or the file stops parsing as the
" outline it looked like. Insert mode is left alone, because completion owns Tab there.
" The cost is that <C-i> loses its jumplist jump in these buffers, since Tab and <C-i>
" are one keycode in a terminal.
nnoremap <buffer> <Tab>   <Cmd>TaskPaperMoveRight<CR>
nnoremap <buffer> <S-Tab> <Cmd>TaskPaperMoveLeft<CR>

nnoremap <buffer> <localleader>l <Cmd>TaskPaperMoveRight<CR>
nnoremap <buffer> <localleader>h <Cmd>TaskPaperMoveLeft<CR>
nnoremap <buffer> <localleader>k <Cmd>TaskPaperMoveUp<CR>
nnoremap <buffer> <localleader>j <Cmd>TaskPaperMoveDown<CR>
nnoremap <buffer> <localleader>\ <Cmd>TaskPaperMoveToProject<CR>
nnoremap <buffer> <localleader>d <Cmd>TaskPaperToggleDone<CR>

" Focus In and Focus Out are Opt-Cmd-Arrow in the app and Go Home is Shift-Cmd-H, so
" none of the three survives a terminal. f/F is Vim's own shape for a motion and its
" opposite, and H keeps the app's letter for Home. No <M-...> pair here, unlike the
" moves above: the app pairs focus with arrows and there is no direction key left that
" does not already mean a move.
nnoremap <buffer> <localleader>f <Cmd>TaskPaperFocusIn<CR>
nnoremap <buffer> <localleader>F <Cmd>TaskPaperFocusOut<CR>
nnoremap <buffer> <localleader>H <Cmd>TaskPaperHome<CR>

nnoremap <buffer> <M-l> <Cmd>TaskPaperMoveRight<CR>
nnoremap <buffer> <M-h> <Cmd>TaskPaperMoveLeft<CR>
nnoremap <buffer> <M-k> <Cmd>TaskPaperMoveUp<CR>
nnoremap <buffer> <M-j> <Cmd>TaskPaperMoveDown<CR>

" Visual mode keeps plain shifts. The selection is already explicit, so there is no
" subtree to infer, and inferring one would move lines the user did not select.
xnoremap <buffer> <Tab>   >gv
xnoremap <buffer> <S-Tab> <gv
" Plain `:` here rather than <Cmd>, because visual mode prefills the '<,'> range and
" <Cmd> would run before the marks were set.
xnoremap <buffer> <localleader>d :TaskPaperToggleDone<CR>

let b:undo_ftplugin = "setlocal expandtab< tabstop< shiftwidth< softtabstop< autoindent<"
      \ . " | silent! nunmap <buffer> <Tab>"
      \ . " | silent! nunmap <buffer> <S-Tab>"
      \ . " | silent! nunmap <buffer> <localleader>l"
      \ . " | silent! nunmap <buffer> <localleader>h"
      \ . " | silent! nunmap <buffer> <localleader>k"
      \ . " | silent! nunmap <buffer> <localleader>j"
      \ . " | silent! nunmap <buffer> <localleader>\\"
      \ . " | silent! nunmap <buffer> <localleader>d"
      \ . " | silent! nunmap <buffer> <localleader>f"
      \ . " | silent! nunmap <buffer> <localleader>F"
      \ . " | silent! nunmap <buffer> <localleader>H"
      \ . " | silent! nunmap <buffer> <M-l> | silent! nunmap <buffer> <M-h>"
      \ . " | silent! nunmap <buffer> <M-k> | silent! nunmap <buffer> <M-j>"
      \ . " | silent! xunmap <buffer> <Tab>"
      \ . " | silent! xunmap <buffer> <S-Tab>"
      \ . " | silent! xunmap <buffer> <localleader>d"
      \ . " | silent! delcommand TaskPaperMoveRight"
      \ . " | silent! delcommand TaskPaperMoveLeft"
      \ . " | silent! delcommand TaskPaperMoveUp"
      \ . " | silent! delcommand TaskPaperMoveDown"
      \ . " | silent! delcommand TaskPaperMoveToProject"
      \ . " | silent! delcommand TaskPaperToggleDone"
      \ . " | silent! delcommand TaskPaperFocusIn"
      \ . " | silent! delcommand TaskPaperFocusOut"
      \ . " | silent! delcommand TaskPaperHome"
