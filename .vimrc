set nocompatible               " be iMproved
filetype off                   " required!

set rtp+=~/.vim/bundle/vundle/
call vundle#rc()

" let Vundle manage Vundle
" required!
Bundle 'gmarik/vundle'

" original repos on github
Bundle 'Lokaltog/vim-easymotion'
Bundle 'MarcWeber/vim-addon-mw-utils'
Bundle 'altercation/vim-colors-solarized'
Bundle 'bling/vim-airline'
Bundle 'christoomey/vim-tmux-navigator'
Bundle 'csexton/trailertrash.vim'
Bundle 'ervandew/supertab'
Bundle 'garbas/vim-snipmate'
Bundle 'godlygeek/tabular'
Bundle 'hdima/python-syntax'
Bundle 'honza/vim-snippets'
Bundle 'jeetsukumaran/vim-buffergator'
Bundle 'junegunn/goyo.vim'
Bundle 'kablamo/vim-git-log'
Bundle 'kien/ctrlp.vim'
Bundle 'mileszs/ack.vim'
Bundle 'plasticboy/vim-markdown'

" TODO: use the master repo once it picks up your commit
Bundle 'prateek/QFGrep'

Bundle 'rstacruz/sparkup', {'rtp': 'vim/'}
Bundle 'scrooloose/nerdtree'
Bundle 'scrooloose/syntastic'
Bundle 'sjl/clam.vim'
Bundle 'thinca/vim-visualstar'
Bundle 'tomtom/tlib_vim'
Bundle 'tpope/vim-abolish'
Bundle 'tpope/vim-eunuch'
Bundle 'tpope/vim-fugitive'
Bundle 'tpope/vim-repeat'
Bundle 'tpope/vim-surround'
Bundle 'tpope/vim-unimpaired'
Bundle 'vim-scripts/ZoomWin.git'
Bundle 'vim-scripts/maven-plugin'
Bundle 'vimwiki/vimwiki'
Bundle 'wesQ3/vim-windowswap'
Bundle 'amix/vim-zenroom2'
Bundle 'tomasr/molokai'
Bundle 'mattn/gist-vim'
Bundle 'mattn/webapi-vim'
Bundle 'mattboehm/vim-accordion'

" TODO: use the master repo once it picks up your commit
Bundle 'prateek/vim-unstack'

" vim-scripts repos
Bundle 'L9'
Bundle 'SQLUtilities'

" color scheme
let g:solarized_termcolors=256
let g:rehash256 = 1
set t_Co=256
set bg=dark
colo molokai
let g:airline_theme='solarized'

" Keep this below the colorschemes
filetype plugin indent on     " required!
filetype plugin on            " required for snipMate
syntax enable

" stole this from SamP originally
" inoremap ii <Esc> " map ii to esc
" Removed to start using caps instead

" leader to <SPACE> <-- godsend
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
if ! has('gui_running')
    set ttimeoutlen=10
    augroup FastEscape
        autocmd!
        au InsertEnter * set timeoutlen=0
        au InsertLeave * set timeoutlen=1000
    augroup END
endif

" incremental search
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
let g:EasyMotion_leader_key = '<Leader><Leader>'
" EasyMotion Highlight
hi link EasyMotionTarget ErrorMsg
hi link EasyMotionShade  Comment

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
nnoremap <silent> <leader>mp :Mvn package -DskipTests<bar> redr! <bar> ccl <bar> copen<CR>
nnoremap <silent> <leader>mc :Mvn compile <bar> redr!<CR>

" fugitive mappings
nnoremap <silent> <leader>gs :Gstatus<CR>
nnoremap <silent> <leader>gw :Gwrite<CR>
nnoremap <silent> <leader>gd :Gdiff<CR>
nnoremap <silent> <leader>ge :Gedit<CR>
nnoremap <silent> <leader>gc :Gcommit<CR>

" Git log mappings
" nnoremap <silent> <leader>gl :sp <bar> GitLog<CR>

" ctrl-p mappings
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlPMixed'

" VimRoom Plugin
nnoremap <silent> <leader>z :Goyo<CR>

" QFGrep
let g:QFG_Grep = '<M-g>'
let g:QFG_GrepV = '<M-v>'
let g:QFG_Restore = '<M-r>'

" Gist plugin
let g:gist_post_private = 1
let g:gist_show_privates = 1

" Accordion
" set AccordionAll 4
nnoremap <leader>d :AccordionDiff<CR>
nnoremap <leader>i :AccordionZoomIn<CR>
nnoremap <leader>o :AccordionZoomOut<CR>

" vim-markdown
let g:vim_markdown_initial_foldlevel=1

" disable markdown folds at startup?
let g:vim_markdown_folding_disabled=1
