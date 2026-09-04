" Classic-Vim-only plugin declarations (vim-plug). Never sourced by Neovim,
" which manages its own plugins via lazy.nvim (see nvim/lua/user/plugins/).

if has('win32') || has('win64')
  call plug#begin('~/vimfiles/plugged')
else
  call plug#begin('~/.vim/plugged')
endif

Plug 'ctrlpvim/ctrlp.vim'
Plug 'menisadi/kanagawa.vim'
Plug 'mg979/vim-visual-multi'
Plug 'dense-analysis/ale'

call plug#end()

" Ctrl+P: also show hidden (dotfile) files, but always exclude .git/
let g:ctrlp_show_hidden = 1
set wildignore+=*/node_modules/*,*.so,*.swp,*.pyc,*.jpg,*.png,*.jpeg,*.gif,*.zip,*/deps/*,*/_build/*,*/frameworks/*,*/tmp/cache/*,*/dist/*,*/_old/*,*/vendor/ruby/*,*/coverage/*,*/.git/*
let g:ctrlp_custom_ignore = 'node_modules/.*,deps/.*,_build/.*,frameworks/.*,tmp/cache/.*,dist/.*,_old/.*,vendor/ruby/.*,coverage/.*,.git/.*'
" sudo apt-get install ripgrep
if executable('rg')
  set grepprg=rg\ --color=never
  let g:ctrlp_user_command = 'rg %s -i --files --no-heading --hidden --color=never --glob "!.git/"'
  let g:ctrlp_use_caching = 0
else
  let g:ctrlp_clear_cache_on_exit = 0
endif

colorscheme kanagawa
