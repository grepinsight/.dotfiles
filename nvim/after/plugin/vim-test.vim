let g:test_extra= '--pdb '
let test#python#pytest#options = g:test_extra . '-s -v'
