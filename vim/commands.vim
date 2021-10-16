command! Focus             execute "normal! zMzvzz"
command! Focus2            execute "normal! zMzOzt"

command! InsightSystem     execute "normal! \<esc>:e  ~/Dropbox/vimwiki/shared/albert-s-system.org\<CR>"
command! InsightPrinciples execute "normal! \<esc>:e  ~/Dropbox/vimwiki/shared/principles.org\<CR>"
command! InsightTodo       execute "normal! \<esc>:e  ~/todo.org\<CR>"
command! InsightNotes      execute "normal! \<esc>:e  ~/notes.org\<CR>"
command! InsightScratch    execute "normal! \<esc>:e  ~/scratch.org\<CR>"
command! InsightThoughts   execute "normal! \<esc>:e  ~/thoughts.org\<CR>"
command! InsightOrg        execute "normal! \<esc>:e  ~/index.org\<CR>"
command! Kanban            execute "normal! \<esc>:e  ~/Dropbox/vimwiki/shared/kanban.org\<CR>"
command! Meeting           execute "normal! \<esc>:sp ~/Dropbox/vimwiki/shared/meeting--\<C-R>=strftime(\"%Y-%m-%d\")\<CR>.md\<CR>"
command! Month             execute "normal! \<esc>:e  ~/Dropbox/vimwiki/shared/diary/\<C-R>=strftime(\"%Y-%m\")\<CR>.md\<CR>"
command! Stats             execute "normal! \<esc>:e  ~/Dropbox/vimwiki/shared/statistics.org\<CR>"
command! Today             execute "normal! \<esc>:e  ~/Dropbox/vimwiki/shared/diary/\<C-R>=strftime(\"%Y-%m-%d\")\<CR>.md\<CR>"
command! Topics            execute "normal! \<esc>:e  ~/Dropbox/vimwiki/shared/topics.org\<CR>"
command! Week              execute "normal! \<esc>:e  ~/Dropbox/vimwiki/shared/diary/\<C-R>=strftime(\"%Y-week%V\")\<CR>.md\<CR>"
command! Work              execute "normal! \<esc>:e  ~/Dropbox/vimwiki/shared/work.org\<CR>"
command! Wq                execute "normal! \<esc>:wq<CR>"
command! Year              execute "normal! \<esc>:e ~/Dropbox/vimwiki/diary/\<C-R>=strftime(\"%Y\")\<CR>.md\<CR>"
command! Greview           :Git! diff --staged
command! MakeTags          !ctags -R .
command! Black             :Neoformat! python black
command! Yapf              :Neoformat! python yapf
