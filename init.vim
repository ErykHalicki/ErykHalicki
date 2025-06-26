call plug#begin()
Plug 'scrooloose/nerdtree'
call plug#end()
autocmd VimEnter * NERDTree | wincmd p
autocmd TabNew * NERDTree | wincmd p
autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif
let g:NERDTreeDirArrowExpandable = '▸'
let g:NERDTreeDirArrowCollapsible = '▾'
set mouse=a
set clipboard=unnamedplus
set clipboard+=unnamed
set tabstop=4
set shiftwidth=4
set expandtab
set number
set nohlsearch
:tnoremap <Esc> <C-\><C-n>
