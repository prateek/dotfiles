set nocompatible               " be iMproved
filetype off                   " required!

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" let Vundle manage Vundle
" required!
Plugin 'gmarik/Vundle.vim'

" original repos on github
Plugin 'Lokaltog/vim-easymotion'
Plugin 'altercation/vim-colors-solarized'
Plugin 'amix/vim-zenroom2'
Plugin 'bling/vim-airline'
Plugin 'christoomey/vim-tmux-navigator'
Plugin 'csexton/trailertrash.vim'
Plugin 'fs111/pydoc.vim'
Plugin 'godlygeek/tabular'
Plugin 'hdima/python-syntax'
Plugin 'jeetsukumaran/vim-buffergator'
Plugin 'junegunn/goyo.vim'
Plugin 'kablamo/vim-git-log'
Plugin 'kien/ctrlp.vim'
Plugin 'mattn/gist-vim'
Plugin 'mattn/webapi-vim'
Plugin 'mileszs/ack.vim'
Plugin 'plasticboy/vim-markdown'
Plugin 'rstacruz/sparkup', {'rtp': 'vim/'}
Plugin 'scrooloose/nerdtree'
Plugin 'sjl/clam.vim'
Plugin 'thinca/vim-visualstar'
Plugin 'tomasr/molokai'
Plugin 'tpope/vim-abolish'
Plugin 'tpope/vim-eunuch'
Plugin 'tpope/vim-fugitive'
Plugin 'tpope/vim-repeat'
Plugin 'tpope/vim-surround'
Plugin 'tpope/vim-unimpaired'
Plugin 'vim-scripts/maven-plugin'
Plugin 'vimwiki/vimwiki'
Plugin 'wesQ3/vim-windowswap'
Plugin 'tommcdo/vim-exchange'
Plugin 'lambdalisue/nose.vim'

" Plugin 'scrooloose/syntastic' " Syntax Error Checking
Plugin 'jiangmiao/auto-pairs' " AutoPair Brackets
Plugin 'wellle/targets.vim' " TextObject Extensions
Plugin 'wellle/tmux-complete.vim' " Auto complete across tmux panes

" Auto-complete tab
Plugin 'ervandew/supertab'

" Snippets
Plugin 'MarcWeber/vim-addon-mw-utils'
Plugin 'tomtom/tlib_vim'
Plugin 'SirVer/ultisnips'
Plugin 'honza/vim-snippets'

" Sessions
" Plugin 'xolox/vim-misc'
" Plugin 'xolox/vim-session'

" TODO: use the master repo once it picks up your commit
Plugin 'prateek/QFGrep'
Plugin 'prateek/vim-unstack'

" vim-scripts repos
Plugin 'L9'
Plugin 'SQLUtilities'

" ZoomWin
Plugin 'vim-scripts/ZoomWin'
nnoremap <silent> <leader>z :ZoomWin<CR>

" Damian Conway's piece de resistance
"vnoremap <expr> <LEFT> DVB_Drag('left')
"vnoremap <expr> <RIGHT> DVB_Drag('right')
"vnoremap <expr> <DOWN> DVB_Drag('down')
"vnoremap <expr> <UP> DVB_Drag('up')

"" syntax plugins
" HOCON syntax files, used for morphlines
Plugin 'GEverding/vim-hocon'

" Dash.app integration - Mac Specific
Plugin 'rizzatti/funcoo.vim'
Plugin 'rizzatti/dash.vim'
nmap <silent> K <Plug>DashSearch
vmap <silent> K <Plug>DashSearch
nnoremap <silent> <leader>K :DashSearch 

" all plugins finished
call vundle#end()            " required
filetype plugin indent on    " required

" exchange vim
nmap cx <Plug>(Exchange)
vmap cx <Plug>(Exchange)
nmap cC <Plug>(ExchangeClear)
vmap cX <Plug>(ExchangeLine)
nmap cX <Plug>(ExchangeLine)

" color scheme
let g:solarized_termcolors=256
let g:rehash256 = 1
set t_Co=256
set bg=dark
colo molokai
let g:airline_theme='solarized'

" Keep this below the colorschemes
filetype plugin indent on     " required!
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
set ttimeoutlen=10
augroup FastEscape
    autocmd!
    au InsertEnter * set timeoutlen=0
    au InsertLeave * set timeoutlen=1000
augroup END

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
nnoremap <F1> :bprev<CR>
nnoremap <F2> :bnext<CR>

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
set wildmode=list:longest,full      " Show list of completions
                                    " and complete as much as possible,
                                    " then iterate full completions
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
let g:windowswap_map_keys = 0 "prevent default bindings
nnoremap <silent> <leader>yw :call WindowSwap#MarkWindowSwap()<CR>
nnoremap <silent> <leader>pw :call WindowSwap#DoWindowSwap()<CR>

" nerdtree left
let g:NERDTreeWinPos = "left"

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
nnoremap <silent> <leader>wr :Goyo<CR>

" QFGrep
let g:QFG_Grep = '<M-g>'
let g:QFG_GrepV = '<M-v>'
let g:QFG_Restore = '<M-r>'

" Gist plugin
let g:gist_post_private = 1
let g:gist_show_privates = 1

" Use a bar-shaped cursor for insert mode, even through tmux.
if exists('$TMUX')
    let &t_SI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=1\x7\<Esc>\\"
    let &t_EI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=0\x7\<Esc>\\"
else
    let &t_SI = "\<Esc>]50;CursorShape=1\x7"
    let &t_EI = "\<Esc>]50;CursorShape=0\x7"
endif

" TrailerTrash trim binding
nnoremap <leader>t :Trim<bar>w<CR>

"====[ I'm sick of typing :%s/.../.../g ]=======
nnoremap S :%s//g<LEFT><LEFT>
vnoremap S :s//g<LEFT><LEFT>

" Marked binding
" nnoremap <leader>ma :!open -a Marked.app '%:p' <bar> redr! <CR>
