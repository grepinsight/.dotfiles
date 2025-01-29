vim.cmd [[
    let g:rooter_silent_chdir = 1
    let g:startify_change_to_dir = 0
    let g:rooter_change_directory_for_non_project_files = "current"
    let g:rooter_patterns = [".git", "Makefile", ".prjroot", ".hg", "justfile"]
]]

