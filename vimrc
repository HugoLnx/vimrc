set nocompatible

filetype off
set rtp+=~/.vim/bundle/Vundle.vim

call vundle#begin()
Plugin 'gmarik/Vundle.vim'
Plugin 'ctrlpvim/ctrlp.vim'
Plugin 'altercation/vim-colors-solarized'
"Plugin 'elixir-lang/vim-elixir'
Plugin 'fatih/vim-go'
Plugin 'terryma/vim-multiple-cursors'
Plugin 'scrooloose/syntastic'
Plugin 'christoomey/vim-tmux-navigator'
Plugin 'digitaltoad/vim-pug'
Plugin 'ekalinin/dockerfile.vim'
call vundle#end()
filetype on

"Ctrl+P ignore those files
set wildignore+=*/node_modules/*,*.so,*.swp,*.pyc,*.jpg,*.png,*.jpeg,*.gif,*.zip,*/deps/*,*/_build/*,*/frameworks/*,*/tmp/cache/*,*/dist/*,*/_old/*,*/vendor/ruby/*,*/coverage/*
let g:ctrlp_custom_ignore = 'node_modules/.*,deps/.*,_build/.*,frameworks/.*,tmp/cache/.*,dist/.*,_old/.*,vendor/ruby/.*,coverage/.*'
" sudo apt-get install ripgrep
if executable('rg')
  set grepprg=rg\ --color=never
  let g:ctrlp_user_command = 'rg %s -i --files --no-heading --color=never --glob ""'
  let g:ctrlp_use_caching = 0
else
  let g:ctrlp_clear_cache_on_exit = 0
endif

syntax on
filetype plugin indent on
set number
set nocursorline
set autoindent
set smartindent
set ruler
set ts=2 sts=2 sw=2 bs=2
set backspace=indent,eol,start

set backup
set backupdir=~/.vim/backup
set directory=~/.vim/tmp

nmap H :tabp<enter>
nmap L :tabn<enter>
nmap <c-o> o<esc>
map J 10j
map K 10k
" map W 3w
" map B 3b

" clear last search
nmap <C-n> :let @/ = ""<enter>

" format code of the current file
nmap X mzgggqG`z

hi RubySymbol term=none cterm=none ctermfg=darkYellow

autocmd FileType java    set ts=4
autocmd FileType java    set sts=4
autocmd FileType java    set sw=4
autocmd FileType java    set bs=4

" Renomeia arquivo atual
command -nargs=+ -complete=file To let originalfilename = expand('%:q')|f <args>/%:t|w|exec "!rm ".originalfilename

" Deleta arquivo atual
command -nargs=0 Del let nothing = system("rm ".expand('%:p'))|q

" Corridingo os malditos 'ht's
iab lenght length
iab widht width
iab heigth height

" seta o expandtab para esses tipos de arquivo
au FileType ruby,javascript,python,html,erb,yaml,yml,playbook,lua,eruby,elixir,pub,hbs,handlebars set expandtab

" seta todos os tabs para espaço ao abrir ou salvar
au BufRead,BufWrite *.rb,*.js,*[rR]akefile,*.py,*.yml,*.playbook,*.lua,*.html*,*.erb*,*.ex,*.exs,*.eex,*.pub retab

" name  fun<enter> => function name()
" name a,b,c fun<enter> => function name(a,b,c)
au FileType javascript,html iab mfun <esc>Ifunction <esc>f s(<esc>$i) {<return>}<esc>kA

" name  tfun<enter> => this.name = function()
" name a,b,c tfun<enter> => this.name = function(a,b,c)
au FileType javascript,html iab mtfun <esc>Ithis.<esc>f s = function(<esc>$i) {<return>}<esc>kA

" SomeFuncion desc<enter> => describe("SomeFunction", function(){});
au FileType javascript,html iab mdesc <esc>Idescribe("<esc>$s", function() {<return>});<esc>kA

" should do something it<enter> => describe("should do something", function(){});
au FileType javascript,html iab mit <esc>Iit("<esc>$s", function() {<return>});<esc>kA

" mbeach => beforeEach(function(){});
au FileType javascript,html iab mbeach <esc>IbeforeEach(function() {<return>});<esc>kA

" carros each => for(var i = 0; i<carros.length; i++){var carro = carros[i];}
au FileType javascript,html iab meach <esc>v_yIfor(var i = 0; i<<esc>$a<backspace>.length; i++) {<return>var <esc>pi<backspace> = <esc>pi[i];<return>}<esc>kA

"i 0 10 upto => for(var i = 0; i<=10; i++){}
au FileType javascript,html iab mupto <esc>_vt yifor(var <esc>f i =<esc>lf i<delete>;  <esc>hpf i<delete> <= <esc>$i<delete>;  <esc>hpf i<delete>++) {<return>}<esc>kA

"i 10 times => int i;for(i = 0; i<10; i++){}
au FileType javascript,html iab mtimes <esc>_vt yiint <esc>f i;<return>for( <esc>hpf i<delete> = 0;  <esc>hpf i<delete> < <esc>$i<delete>;  <esc>hpf i<delete>++)<return>{<return>}<esc>kA

" hugo mgt => this.hugo = function(){return _hugo};
au FileType javascript,html iab mgt <esc>v_yIthis.<esc>f i<delete> = function() {<return>return this._<esc>pi;<return>};

" hugo mst => this.hugo = function(hugo){_hugo = hugo};
au FileType javascript,html iab mst <esc>v_yIthis.<esc>f i<delete> = function(value) {<return>if (value !== undefined) this._<esc>pi = value;<return>};

" hugo mgst => this.hugo = function(hugo){if (hugo){return _hugo} else {_hugo = hugo}};
au FileType javascript,html iab mgst <esc>v_yIthis.<esc>f i<delete> = function(value) {<return>if (value !== undefined) this._<esc>pi = value;<return><delete><tab>return this._<esc>pi;<return>};

" carros each => for(int i = 0; i<carros.length; i++){int carro = carros[i];}
au FileType c,cpp iab meach <esc>v_yOint i;<esc>jIfor(i = 0; i<<esc>$a<backspace>.length; i++)<return>{<return>int <esc>pi<backspace> = <esc>pi[i];<return>}<esc>kA

"i 0 10 upto => int i;for(i = 0; i<=10; i++){}
au FileType c,cpp iab mupto <esc>_vt yiint <esc>f i;<return>for( <esc>hpf i<delete> = <esc>f i<delete>;  <esc>hpf i<delete> <= <esc>$i<delete>;  <esc>hpf i<delete>++)<return>{<return>}<esc>kA

"def xpto do end
au FileType elixir iab mdef <esc>x_Cdef <esc>pA do<esc>oend<esc>kA

"defp xpto do end
au FileType elixir iab mdefp <esc>x_Cdefp <esc>pA do<esc>oend<esc>kA

"defm xpto do end
au FileType elixir iab mdefm <esc>x_Cdefmodule <esc>pA do<esc>oend<esc>kA

" Skeletons
au BufNewFile  *.html,*.erb  0r ~/.vim/skeletons/html
au BufNewFile  *.c  0r ~/.vim/skeletons/c
au BufNewFile  *.cpp  0r ~/.vim/skeletons/cpp

" caracteres em branco no final aparecem em vermelho
au BufNewFile,BufRead * syn match brancomala '\s\+$' | hi brancomala ctermbg=red

"  In visual mode when you press * or # to search for the current selection
vnoremap <silent> * :call VisualSearch('f')<CR>
vnoremap <silent> # :call VisualSearch('b')<CR>

" From an idea by Michael Naumann
function! VisualSearch(direction) range
    let l:saved_reg = @"
    execute "normal! vgvy"

    let l:pattern = escape(@", '\\/.*$^~[]')
    let l:pattern = substitute(l:pattern, "\n$", "", "")

    if a:direction == 'b'
        execute "normal ?" . l:pattern . "^M"
    elseif a:direction == 'gv'
        call CmdLine("vimgrep " . '/'. l:pattern . '/' . ' **/*.')
    elseif a:direction == 'f'
        execute "normal /" . l:pattern . "^M"
    endif

    let @/ = l:pattern
    let @" = l:saved_reg
endfunction
