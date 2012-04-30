syntax on
filetype plugin on
filetype indent on
set nocompatible
set number
set autoindent
set smartindent
set ruler
set ts=2
set sts=2
set sw=2

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
autocmd FileType java    set sts=4
autocmd FileType java    set sw=4

" seta o expandtab para esses tipos de arquivo
au FileType ruby,javascript,python,html,erb set expandtab

" seta todos os tabs para espaço ao abrir ou salvar
au BufRead,BufWrite *.rb,*.js,*[rR]akefile,*.py retab

" name  fun<enter> => function name()
" name a,b,c fun<enter> => function name(a,b,c)
au FileType javascript,html iab fun <esc>Ifunction <esc>f s(<esc>$i) {<return>}<esc>kA

" name  tfun<enter> => this.name = function()
" name a,b,c tfun<enter> => this.name = function(a,b,c)
au FileType javascript,html iab tfun <esc>Ithis.<esc>f s = function(<esc>$i) {<return>}<esc>kA

" SomeFuncion desc<enter> => describe("SomeFunction", function(){});
au FileType javascript,html iab desc <esc>Idescribe("<esc>$s", function() {<return>});<esc>kA

" should do something it<enter> => describe("should do something", function(){});
au FileType javascript,html iab it <esc>Iit("<esc>$s", function() {<return>});<esc>kA

" carros each => for(var i = 0; i<carros.length; i++){var carro = carros[i];}
au FileType javascript,html iab each <esc>v_yIfor(var i = 0; i<<esc>$a<backspace>.length; i++) {<return>var <esc>pi<backspace> = <esc>pi[i];<return>}<esc>kA

"i 0 10 upto => for(var i = 0; i<=10; i++){}
au FileType javascript,html iab upto <esc>_vt yifor(var <esc>f i =<esc>lf i<delete>;  <esc>hpf i<delete> <= <esc>$i<delete>;  <esc>hpf i<delete>++)<return>{<return>}<esc>kA

" carros each => for(int i = 0; i<carros.length; i++){int carro = carros[i];}
au FileType c,cpp iab each <esc>v_yOint i;<esc>jIfor(i = 0; i<<esc>$a<backspace>.length; i++)<return>{<return>int <esc>pi<backspace> = <esc>pi[i];<return>}<esc>kA

"i 0 10 upto => int i;for(i = 0; i<=10; i++){}
au FileType c,cpp iab upto <esc>_vt yiint <esc>f i;<return>for( <esc>hpf i<delete> = <esc>f i<delete>;  <esc>hpf i<delete> <= <esc>$i<delete>;  <esc>hpf i<delete>++)<return>{<return>}<esc>kA


" Skeletons
au BufNewFile  *.html,*.erb  0r ~/.vim/skeletons/html
au BufNewFile  *.c,*.cpp  0r ~/.vim/skeletons/c

" caracteres em branco no final aparecem em vermelho
syn match brancomala '\s\+$' | hi brancomala ctermbg=red

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

