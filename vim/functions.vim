function! BufferSmartDelete()
	let num_buf = len(filter(range(1, bufnr('$')), 'buflisted(v:val)'))

	if num_buf == 1
		bd
		return
	endif
	let diffbufnr = bufnr('^fugitive:')
    if diffbufnr > -1 && &diff
        diffoff | q
        if bufnr('%') == diffbufnr
            Gedit
        endif
        setlocal nocursorbind
        return
    endif

	bp
	bd #
	if winnr() == 2
		q
	endif
endfunction
command! BufferSmartDelete :call BufferSmartDelete()


function! ChooseTerm(termname, slider)
    let pane = bufwinnr(a:termname)
    let buf = bufexists(a:termname)
    if pane > 0
        " pane is visible
        if a:slider > 0
            :exe pane . "wincmd c"
        else
            :exe "e #"
        endif
        :exe "normal i"
    elseif buf > 0
        " buffer is not in pane
        if a:slider
            :exe "topleft split"
        endif
        :exe "buffer " . a:termname
        :exe "normal i"
    else
        " buffer is not loaded, create
        if a:slider
            :exe "topleft split"
        endif
        :terminal
        :exe "f " a:termname
    endif
endfunction


function! MoveLibrary()
    silent! let @a=''
    silent! g/^library/d A
    silent! normal gg"ap
endfunction
command! MoveLibrary :call MoveLibrary()



function! BlameToggle() abort
  let found = 0
  for winnr in range(1, winnr('$'))
    if getbufvar(winbufnr(winnr), '&filetype') ==# 'fugitiveblame'
      exe winnr . 'close'
      let found = 1
    endif
  endfor
  if !found
    Git blame
  endif
endfunction



function! ClearReg()
    let regs=split('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/-"', '\zs')
    for r in regs
      call setreg(r, [])
    endfor
endfunction

let g:detect_mod_reg_state = -1
function! DetectRegChangeAndUpdateMark()
    let current_small_register = getreg('"-')
    let current_mod_register = getreg('""')
    if g:detect_mod_reg_state != current_small_register ||
                \ g:detect_mod_reg_state != current_mod_register
        normal! mM
        let g:detect_mod_reg_state = current_small_register
    endif
endfunction


augroup insert_tracking
    autocmd!
    " Mark I at the position where the last Insert mode occured across the buffer
    autocmd InsertLeave * execute 'normal! mI'
    " Mark M at the position when any modification happened in the Normal or Insert mode
    autocmd CursorMoved * call DetectRegChangeAndUpdateMark()
    autocmd InsertLeave * execute 'normal! mM'
augroup END


function! OpenFileTypeSetting()
    let my_ft_file = "$HOME/.config/nvim/ftplugin/" . &filetype . ".vim"
    execute ":edit ". my_ft_file
endfunction

command! OpenFileTypeSetting :call OpenFileTypeSetting()
nnoremap <Leader>ft :call OpenFileTypeSetting()<CR>
