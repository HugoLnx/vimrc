syntax on
set nocompatible
set number
set autoindent
set smartindent
set ruler
set ts=2
set sts=2
set sw=2
set expandtab

set backup
set backupdir=~/.vim/backup
set directory=~/.vim/tmp

nmap H :tabp<enter>
nmap L :tabn<enter>
nmap <c-o> o<esc>
map J 5j
map K 5k
map W 3w
map B 3b

hi CursorLine term=none cterm=none ctermbg=0
hi RubySymbol term=none cterm=none ctermfg=darkYellow

autocmd FileType java    set ts=4
