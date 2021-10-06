 require('orgmode').setup({
  org_agenda_files = {'~/Dropbox/vimwiki/shared/*'},
  org_default_notes_file = '~/Dropbox/vimwiki/shared/notes.org',
})

require("org-bullets").setup {
  symbols = { "◉", "○", "✸", "✿" }
}
