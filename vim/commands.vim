command! Focus execute "normal! zMzvzz"
command! Focus2 execute "normal! zMzOzt"
command! Kanban execute "normal! \<esc>:e ~/Dropbox/vimwiki/kanban.org\<CR>"
command! MakeTags !ctags -R .
command! Meeting execute "normal! \<esc>:sp ~/Dropbox/vimwiki/meeting--\<C-R>=strftime(\"%Y-%m-%d\")\<CR>.md\<CR>"
command! Month execute "normal! \<esc>:e ~/Dropbox/vimwiki/diary/\<C-R>=strftime(\"%Y-%m\")\<CR>.md\<CR>"
command! Stats execute "normal! \<esc>:e ~/Dropbox/vimwiki/statistics.org\<CR>"
command! Today execute "normal! \<esc>:e ~/Dropbox/vimwiki/diary/\<C-R>=strftime(\"%Y-%m-%d\")\<CR>.md\<CR>"
command! Topics execute "normal! \<esc>:e ~/Dropbox/vimwiki/topics.org\<CR>"
command! Week execute "normal! \<esc>:e ~/Dropbox/vimwiki/diary/\<C-R>=strftime(\"%Y-week%V\")\<CR>.md\<CR>"
command! Work execute "normal! \<esc>:e ~/Dropbox/vimwiki/work.org\<CR>"
command! Wq execute "normal! \<esc>:wq<CR>"
command! Year execute "normal! \<esc>:e ~/Dropbox/vimwiki/diary/\<C-R>=strftime(\"%Y\")\<CR>.md\<CR>"
command! Greview :Git! diff --staged
