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
Bundle 'amix/vim-zenroom2'
Bundle 'bling/vim-airline'
Bundle 'christoomey/vim-tmux-navigator'
Bundle 'csexton/trailertrash.vim'
Bundle 'fs111/pydoc.vim'
Bundle 'godlygeek/tabular'
Bundle 'hdima/python-syntax'
Bundle 'jeetsukumaran/vim-buffergator'
Bundle 'junegunn/goyo.vim'
Bundle 'kablamo/vim-git-log'
Bundle 'kien/ctrlp.vim'
Bundle 'mattn/gist-vim'
Bundle 'mattn/webapi-vim'
Bundle 'mileszs/ack.vim'
Bundle 'plasticboy/vim-markdown'
Bundle 'rstacruz/sparkup', {'rtp': 'vim/'}
Bundle 'scrooloose/nerdtree'
 Bundle 'scrooloose/syntastic'
Bundle 'sjl/clam.vim'
Bundle 'thinca/vim-visualstar'
Bundle 'tomasr/molokai'
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
Bundle 'tommcdo/vim-exchange'
Bundle 'lambdalisue/nose.vim'

" Auto-complete tab
Bundle 'ervandew/supertab'

" Snippets
Bundle "MarcWeber/vim-addon-mw-utils"
Bundle "tomtom/tlib_vim"
Bundle 'SirVer/ultisnips'
Bundle "honza/vim-snippets"

" TODO: use the master repo once it picks up your commit
Bundle 'prateek/QFGrep'
Bundle 'prateek/vim-unstack'
" Bundle 'mattboehm/vim-accordion'

" vim-scripts repos
Bundle 'L9'
Bundle 'SQLUtilities'

"" syntax plugins
" HOCON syntax files, used for morphlines
Bundle 'GEverding/vim-hocon'

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

" python nose compiling
au BufNewFile,BufRead *.py compiler nose

" markdown formatting
" autocmd bufnewfile * :set textwidth=80
augroup markdown
  autocmd bufnewfile * :set ai
  autocmd bufnewfile * :set formatoptions=tcroqn2
  autocmd bufnewfile * :set comments=n:>
  autocmd bufnewfile * :set wrap
  autocmd bufnewfile * :set linebreak
  autocmd bufnewfile * :set list
augroup end

" vim-markdown
let g:vim_markdown_initial_foldlevel=1
" disable markdown folds at startup?
let g:vim_markdown_folding_disabled=1

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

" smart column moving
" TODO: these break with C+hjkl, find fix
nnoremap j gj
nnoremap k gk
nnoremap gk k
nnoremap gj j

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

" exchange vim
nnoremap cx <Plug>(Exchange)
vnoremap cx <Plug>(Exchange)
nnoremap cC <Plug>(ExchangeClear)
vnoremap cX <Plug>(ExchangeLine)
nnoremap cX <Plug>(ExchangeLine)

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

" Use a bar-shaped cursor for insert mode, even through tmux.
if exists('$TMUX')
    let &t_SI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=1\x7\<Esc>\\"
    let &t_EI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=0\x7\<Esc>\\"
else
    let &t_SI = "\<Esc>]50;CursorShape=1\x7"
    let &t_EI = "\<Esc>]50;CursorShape=0\x7"
endif

" Marked binding
nnoremap <leader>mm :silent !open -a Marked.app '%:p' <bar> redr! <CR>

" TrailerTrash trim binding
nnoremap <leader>t :silent Trim<bar>w<CR>
