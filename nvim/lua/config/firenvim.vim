" Setup a shortcut variable to the per site settings array
let s:fc = {}
let g:firenvim_config = { 'localSettings': s:fc }

" Configure all sites
let s:fc['.*'] = { 'selector': 'textarea, div[role="textbox"]', 'priority': 0, 'takeover': 'never' }


if exists('g:started_by_firenvim')
    " autocmd vimenter * ++nested colorscheme tokyonight
    echom("Reloaded")
    echom("Current time: " . strftime("%H:%M:%S"))
    echom(strftime("%A, %I:%M%p, %Y-%m-%d"))
    " colorscheme tokyonight


    " set background=light
    " colorscheme PaperColor
    let g:startify_disable_at_vimenter = 1
    let g:airline_extensions = []
    set guifont=Monaco:h15
    set lines=30
    set columns=110
    augroup firenvim_setting
      autocmd!
      autocmd BufEnter dbc*. nnoremap ZZ :wq!
      autocmd BufEnter dbc*. set lines=10
      autocmd BufEnter dbc*. ALEDisable
      autocmd BufEnter *cloud.databricks.com* set ft=python
      autocmd BufEnter *firenvim*ana* set ft=python
      autocmd BufEnter *cloud.databricks.com* nnoremap <C-c><C-c> :wq!<CR>

      " autocmd BufEnter dbc* set updatetime=500
      " autocmd CursorHold dbc* set lines=10
    augroup END
endif
