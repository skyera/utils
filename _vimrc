set nocompatible
filetype off

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

Plugin 'VundleVim/Vundle.vim'
Plugin 'flazz/vim-colorschemes'
Plugin 'kien/ctrlp.vim'
Plugin 'scrooloose/nerdtree'
Plugin 'genutils'
Plugin 'lookupfile'
Plugin 'gnattishness/cscope_maps'
Plugin 'jlanzarotta/bufexplorer'
Plugin 'vim-scripts/taglist.vim'
Plugin 'vim-scripts/Color-Scheme-Explorer'
Plugin 'yegappan/mru'
Plugin 'a.vim'
Plugin 'majutsushi/tagbar'
Plugin 'preservim/nerdcommenter'
Plugin 'vimwiki'
Plugin 'itchyny/lightline.vim'
Plugin 'mileszs/ack.vim'
Plugin 'mhinz/vim-grepper'
Plugin 'rafi/awesome-vim-colorschemes'
Plugin 'jiangmiao/auto-pairs'
Plugin 'jremmen/vim-ripgrep'
Plugin 'tpope/vim-surround'
Plugin 'tpope/vim-commentary'
Plugin 'tpope/vim-unimpaired'
call vundle#end()

set backspace=indent,eol,start
set history=200
set ruler
set showcmd
set incsearch
set hlsearch
set mouse=a
set swapfile
set tabstop=4
set shiftwidth=4
set expandtab
set nu
set ai
filetype plugin indent on
syntax on
syntax enable
set nobackup
set noswapfile
set showmode
"set path+=.\**
set completeopt=menu
set go=a
set cscopequickfix=s-,c-,d-,i-,t-,e-
set printoptions=paper:letter,left:5mm,right:8mm,top:5mm,bottom:3mm,syntax:n,number:y 
set ignorecase
"set guifont=Terminal:h8:cOEM
"set guifont=Courier:h8:cANSI
"set guifont=Consolas:h10:cDEFAULT
set cursorline
set ci
set shiftround
set smartcase
set encoding=utf-8
autocmd BufReadPost *
    \ if line("'\"") > 1 && line("'\"") <= line("$") |
    \   exe "normal! g`\"" |
    \ endif

let g:winManagerWindowLayout='FileExplorer|TagList'
let Tlist_Show_One_File=1
map <F2> <Esc>:1,$!xmllint --format -<CR>

nmap <silent> <leader>ll :LUBufs<cr>

let g:LookupFile_MinPatLength = 3
let g:LookupFile_PreserveLastPattern = 0
let g:LookupFile_PreservePatternHistory = 1
let g:LookupFile_AlwaysAcceptFirst = 1
let g:LookupFile_AllowNewFiles = 0
let g:LookupFile_smartcase = 1
let g:LookupFile_EscCancelsPopup = 1
let g:LookupFile_ignorecase = 1
let g:LookupFile_EnableRemapCmd = 0

"if filereadable("./filenametags")
let g:LookupFile_TagExpr = '"filenametags"'
"endif

nmap <F6> :cn<cr>
nmap <F7> :cp<cr>
nmap <F8> :bn<cr>
nmap <F9> :bp<cr>
nmap <F10> :tn<cr>
nmap <C-F10> :tp<cr>

set errorformat=\ %#%f(%l\\\,%c):\ %m
map <F4> :execute "vimgrep /" . expand("<cword>") . "/j **" <Bar> cw<CR>
nmap <F11> :silent !start explorer /select,%:p<CR>

" Convert slashes to backslashes for Windows.
if has('win32')
  nmap ,cs :let @*=substitute(expand("%"), "/", "\\", "g")<CR>
  nmap ,cl :let @*=substitute(expand("%:p"), "/", "\\", "g")<CR>

  " This will copy the path in 8.3 short format, for DOS and Windows 9x
  nmap ,c8 :let @*=substitute(expand("%:p:8"), "/", "\\", "g")<CR>
else
  nmap ,cs :let @*=expand("%")<CR>
  nmap ,cl :let @*=expand("%:p")<CR>
endif
"map <C-F12> :!ctags -R --c++-kinds=+p --fields=+iaS --extra=+q .<CR>
"let g:CCTreeDbFileMaxSize = 400000000
set browsedir=buffer
nmap <C-F2> :browse edit<cr>
set laststatus=2
set statusline=%t[%{strlen(&fenc)?&fenc:'none'},%{&ff}]%h%m%r%y%=%c,%l/%L\ %P
set scrolljump=5
set scrolloff=3
"set patchmode=.patch
runtime macros/matchit.vim

let g:ctrlp_max_files = 0
let g:ctrlp_clear_cache_on_exit=0

let g:ctrlp_custom_ignore = {
  \ 'dir':  '\v(Debug|Release|lost+found|ucm_components|ThirdParty|omniORB|.jazz5|.jazzShed)$',
  \ 'file': '\v\.(exe|obj|dll|lib|exp|o|pdb|xml|log|png|bmp|resx|pyc|a|txt)$',
  \ 'link': 'some_bad_symbolic_links',
  \ }
"let g:ctrlp_user_command = 'dir %s /-n /b /s /a-d'
"let g:ctrlp_custom_ignore = 'obj'
let g:ctrlp_regexp = 1
let g:ctrlp_by_filename = 1

"set nowrapscan
set cindent
set cinoptions=g-1
colorscheme gruvbox
set background=dark
set directory^=$HOME/.vim/tmp//
noremap <F12> <Esc>:syntax sync fromstart<CR>
autocmd FileType javascript setlocal shiftwidth=2 tabstop=2
autocmd FileType html setlocal shiftwidth=2 tabstop=2
set cscopetagorder=1
"let g:pydoc_cmd = 'python -m pydoc'
let g:pydoc_cmd = 'c:\app\anaconda3\Scripts\pydoc'
set nocst
nmap cp :let @* = expand("%") <cr>

let g:tagbar_type_typescript = {
  \ 'ctagstype': 'typescript',
  \ 'kinds': [
    \ 'c:classes',
    \ 'n:modules',
    \ 'f:functions',
    \ 'v:variables',
    \ 'v:varlambdas',
    \ 'm:members',
    \ 'i:interfaces',
    \ 'e:enums',
  \ ]
\ }

"set grepprg=grep\ -nH
