set nocompatible               " be iMproved
filetype off                   " required!

set rtp+=~/.vim/bundle/vundle/
call vundle#rc()

" let Vundle manage Vundle
" required!
Bundle 'gmarik/vundle'

filetype plugin indent on     " required!
filetype plugin on            " required for snipMate
syntax enable

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
Bundle 'junegunn/goyo.vim'
Bundle 'amix/vim-zenroom2'
Bundle 'MarcWeber/vim-addon-mw-utils'
Bundle 'tomtom/tlib_vim'
Bundle 'garbas/vim-snipmate'
Bundle 'honza/vim-snippets'
Bundle 'scrooloose/syntastic'
Bundle 'sk1418/QFGrep'
Bundle 'tpope/vim-markdown'

" vim-scripts repos
Bundle 'L9'
Bundle 'SQLUtilities'

" color scheme
let g:solarized_termcolors=256
set t_Co=256
set bg=light
colo solarized

" stole this from SamP originally
inoremap ii <Esc> " map ii to esc
" Removed to start using caps instead

" leader to , <-- godsend
let mapleader = " "

" Treat .hql files as SQL for syntax highlighting
au BufNewFile,BufRead *.hql set filetype=sql

" markdown formatting
augroup markdown
  autocmd BufNewFile * :set ai
  autocmd BufNewFile * :set formatoptions=tcroqn2 
  autocmd BufNewFile * :set comments=n:> 
  autocmd BufNewFile * :set textwidth=80
  autocmd BufNewFile * :set wrap
  autocmd BufNewFile * :set linebreak
  autocmd BufNewFile * :set list
augroup END

" Tabs
set tabstop=2
set shiftwidth=2
set expandtab
set autoindent
set backspace=indent,eol,start
set complete-=i
set showmatch
set smarttab

set nrformats-=octal
set shiftround

" timeout fixes
set esckeys
set timeoutlen=1000
set ttimeoutlen=50
set incsearch

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
nnoremap \ :nohlsearch<CR>

" search and replace shortcut
nmap S :%s//g<LEFT><LEFT>
vmap S :s//g<LEFT><LEFT>

" toggle line wrapping
nnoremap <leader>w :set wrap!<CR>
set nowrap

" toggle list chars
nnoremap <leader>l :set list!<CR>
set nolist

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

" not sure what this does anymore, should investigate
set formatoptions+=rco

" always display status line
set laststatus=2
set ruler
set showcmd
set wildmenu

" scrolloff f
if !&scrolloff
  set scrolloff=1
endif
if !&sidescrolloff
  set sidescrolloff=5
endif
set display+=lastline

" Use the same symbols as TextMate for tabstops and EOLs
set listchars=trail:·,precedes:«,extends:»,tab:▸\ ,eol:¬

" Break character
set showbreak=↪

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
nnoremap <silent> <leader>mp :Mvn package <bar> redr! <bar> ccl <bar> copen<CR>
nnoremap <silent> <leader>mc :Mvn compile <bar> redr!<CR>

" Trailing whitespace removal
" autocmd FileType c,python,cpp,java autocmd BufWritePre <buffer> :Trim<CR>

" execute workflow
" Premier specific
nnoremap <silent> <leader>rr :!/home/developer/workspace/distdata/src/scripts/helpers/copyOozieDeps.sh<CR>

" fugitive mappings
nnoremap <silent> <leader>gst :Gstatus<CR>
nnoremap <silent> <leader>gw :Gwrite<CR>
nnoremap <silent> <leader>gd :Gdiff<CR>
nnoremap <silent> <leader>ge :Gedit<CR>
nnoremap <silent> <leader>gc :Gcommit

" make ctrl-p be regular p and otherwise use smart pasting
" nnoremap <c-p> p
" nnoremap p p=`]

" ctrl-p mappings
let g:ctrlp_map = '<c-f>'
let g:ctrlp_cmd = 'CtrlPMixed'

" vimwiki item toggle
" TODO: fix this error
" nnoremap <leader>xx <Plug>VimwikiToggleListItem

" VimRoom Plugin
nnoremap <silent> <leader>z :Goyo<CR>

" QFGrep
let g:QFG_Grep = '<M-g>'
let g:QFG_GrepV = '<M-v>'
let g:QFG_Restore = '<M-r>'
