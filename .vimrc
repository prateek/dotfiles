set nocompatible               " be iMproved
filetype off                   " required!

set rtp+=~/.vim/bundle/vundle/
call vundle#rc()

" let Vundle manage Vundle
" required!
Bundle 'gmarik/vundle'

" original repos on github
Bundle 'Lokaltog/vim-easymotion'
Bundle 'altercation/vim-colors-solarized'
Bundle 'bling/vim-airline'
Bundle 'christoomey/vim-tmux-navigator'
Bundle 'ervandew/supertab'
Bundle 'godlygeek/tabular'
Bundle 'hdima/python-syntax'
Bundle 'jeetsukumaran/vim-buffergator'
Bundle 'kien/ctrlp.vim'
Bundle 'mileszs/ack.vim'
Bundle 'rstacruz/sparkup', {'rtp': 'vim/'}
Bundle 'scrooloose/nerdtree'
Bundle 'sjl/clam.vim'
Bundle 'thinca/vim-visualstar'
Bundle 'tpope/vim-eunuch'
Bundle 'tpope/vim-fugitive'
Bundle 'tpope/vim-repeat'
Bundle 'tpope/vim-surround'
Bundle 'tpope/vim-unimpaired'
Bundle 'vim-scripts/ZoomWin.git'
Bundle 'vim-scripts/maven-plugin'
Bundle 'vimwiki/vimwiki'
Bundle 'wesQ3/vim-windowswap'
Bundle 'csexton/trailertrash.vim'

" vim-scripts repos
Bundle 'L9'
Bundle 'FuzzyFinder'
Bundle 'Align'
Bundle 'SQLUtilities'
Bundle 'snipMate'

filetype plugin indent on     " required!
filetype plugin on            " required for snipMate
syntax enable

" color scheme
" set t_Co=256
" let g:solarized_termcolors=256
colo desert
set bg=dark

" stole this from SamP originally
inoremap ii <Esc> " map ii to esc
" Removed to start using caps instead

" leader to , <-- godsend
let mapleader = " "

" Treat .hql files as SQL for syntax highlighting
au BufNewFile,BufRead *.hql set filetype=sql

" Tabs
set tabstop=2
set shiftwidth=2
set expandtab
" set smarttab

" NerdTreeToggle
nnoremap <silent> <leader>n :NERDTreeToggle<CR>

" C+hjkl instead of needing to use c+w
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" toggle hold with <S-Space> if over a fold
nnoremap <silent> <S-Space> @=(foldlevel('.')?'za':'l')<CR>

" vimrc tweaking -- from 'Instantly Better Vim'
nnoremap <silent> <leader>v :sp $MYVIMRC<CR>
augroup VimReload
  autocmd!
  autocmd BufWritePost $MYVIMRC source $MYVIMRC
augroup END

" persistent undo
set undofile
set undodir=$HOME/.VIM_UNDO_FILES
set undolevels=10000

" visual mode defaults
set virtualedit=block

" case and searching
set smartcase ignorecase
set incsearch
set hlsearch
nnoremap <DEL> :nohlsearch<CR>

" search and replace shortcut
nmap S :%s//g<LEFT><LEFT>
vmap S :s//g<LEFT><LEFT>

" toggle line wrapping
nnoremap <leader>w :set wrap!<CR>
set nowrap

" set current file's directory as the vim directory
nnoremap <leader>c :cd %:p:h<CR>
nnoremap <leader>r :NERDTreeFind<cr>

" line numbers
set nu

" swap colon and semicolon
noremap ; :
noremap : ;

" swap visual and block visual mode
noremap v <c-v>
noremap <c-v> v

" Vim EasyMotion trigger
let g:EasyMotion_leader_key = '<leader><leader>'

" buftabs
nnoremap <f1> :bprev<CR>
nnoremap <f2> :bnext<CR>

"make search results appear in middle of screen
nnoremap n nzz
nnoremap N Nzz
nnoremap * *zz
nnoremap # #zz
nnoremap g* g*zz
nnoremap g# g#zz

" make ctrl-p be regular p and otherwise use smart pasting
nnoremap <c-p> p
nnoremap p p=`]

" not sure what this does anymore, should investigate
set formatoptions+=rco

" always display status line
set laststatus=2

" font scheme
set guifont=Inconsolata:h16

" splits open to bottom and right
set splitright
set splitbelow

let g:airline_theme='solarized'
" clam in vim
nnoremap ! :Clam<space>
vnoremap ! :ClamVisual<space>

" window swap vim
" let g:windowswap_map_keys = 0 "prevent default bindings
nnoremap <silent> <leader>yw :call WindowSwap#MarkWindowSwap()<CR>
nnoremap <silent> <leader>pw :call WindowSwap#DoWindowSwap()<CR>

" nerdtree left
let g:NERDTreeWinPos = "left"

" bind K to grep word under cursor
nnoremap K :vimgrep "<C-R><C-W>" **/*.java<CR>
vnoremap K :vimgrep "<C-R><C-W>" **/*.java<CR>

" maven
nnoremap <silent> <leader>mp :Mvn package <bar> redr!<CR>
nnoremap <silent> <leader>mc :Mvn compile <bar> redr!<CR>

" Trailing whitespace removal
autocmd FileType c,python,cpp,java autocmd BufWritePre <buffer> :Trim<CR>

" execute workflow
" Premier specific
nnoremap <silent> <leader>rr :!/home/developer/workspace/distdata/src/scripts/helpers/copyOozieDeps.sh<CR>

" fugitive mappings
nnoremap <silent> <leader>gst :Gstatus<CR>
nnoremap <silent> <leader>gw :Gwrite<CR>
nnoremap <silent> <leader>gd :Gdiff<CR>
nnoremap <silent> <leader>ge :Gedit<CR>
nnoremap <silent> <leader>gc :Gcommit

" ctrl-p mappings
let g:ctrlp_map = '<c-f>'
let g:ctrlp_cmd = 'CtrlP'

" vimwiki item toggle
" TODO: fix this error
" nnoremap <leader>xx <Plug>VimwikiToggleListItem
