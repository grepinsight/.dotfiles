" Zig quick-run loop (learning sessions).
"
" <F5>  save the buffer, then `zig run` it in a floating terminal.
"       Repeated <F5> kills the previous run window first, so runs never
"       stack. Dismiss the float with <F12> (the global Floaterm toggle).
"
" `zig run <file>` compiles + executes a single file, so this is aimed at the
" one-file scratch scripts used while learning. For a real multi-file project
" (build.zig present) use `:!zig build run` instead.

function! s:ZigRun() abort
  write
  " Reuse one named float so the loop doesn't pile up terminals.
  silent! FloatermKill zigrun
  " NOTE: no --title with a space here. Floaterm splits options on spaces and
  " does not honor a backslash-escaped space, so `--title=zig\ run` leaks a
  " stray `run` token into the command (zsh: command not found: run).
  execute 'FloatermNew --autoclose=0 --name=zigrun '
        \ . 'zig run ' . shellescape(expand('%:p'))
endfunction

nnoremap <buffer> <silent> <F5> :call <SID>ZigRun()<CR>
