" vim:fdm=marker

set nocompatible " be iMproved
filetype off     " required!

call plug#begin('~/.vim/plugged')

" ColorSchemes
Plug 'sjl/badwolf'
Plug 'NLKNguyen/papercolor-theme'
Plug 'altercation/vim-colors-solarized'

Plug 'bling/vim-airline'
Plug 'vim-airline/vim-airline-themes'

Plug 'godlygeek/tabular'
Plug 'kien/ctrlp.vim'

" Gist.vim and it's dependency
Plug 'mattn/gist-vim' | Plug 'mattn/webapi-vim'

Plug 'scrooloose/nerdtree'
Plug 'sjl/clam.vim'

" Git Plugin
Plug 'tpope/vim-fugitive'
Plug 'bronson/vim-visual-star-search'

Plug 'tpope/vim-eunuch'
Plug 'tpope/vim-abolish'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-unimpaired'
Plug 'tpope/vim-commentary'

" Emacs bindings for Vim's CLI
Plug 'bruno-/vim-husk'
Plug 'mileszs/ack.vim'
Plug 'wincent/ferret'

Plug 'jiangmiao/auto-pairs'     " AutoPair Brackets
Plug 'wellle/targets.vim'       " TextObject Extensions
Plug 'wellle/tmux-complete.vim' " Auto complete across tmux panes

Plug 'jpalardy/vim-slime'

" OS X Bindings
"" Reveal in finder
Plug 'henrik/vim-reveal-in-finder'
Plug 'itspriddle/vim-marked'
Plug 'zephod/vim-iterm2-navigator'

" Lisps
Plug 'wlangstroth/vim-racket'
Plug 'vim-scripts/scribble.vim'
Plug 'guns/vim-sexp' , { 'for': ['clojure', 'scheme']  }
Plug 'tpope/vim-sexp-mappings-for-regular-people', { 'for': ['clojure', 'scheme']  }

" vim-scripts repos
Plug 'vim-scripts/L9'
Plug 'csexton/trailertrash.vim'

" Background vim compile
Plug 'tpope/vim-dispatch'

" BufferList plugin
Plug 'jeetsukumaran/vim-buffergator'

" Easy-Motion disabled for vim-smalls
Plug 'Lokaltog/vim-easymotion'

" ExtractLinks
Plug 'vim-scripts/ingo-library' | Plug 'vim-scripts/PatternsOnText' | Plug 'vim-scripts/ExtractMatches' | Plug 'vim-scripts/ExtractLinks'

" Transpose Tabular data
Plug 'salsifis/vim-transpose'

call plug#end()

" leader to <SPACE> <-- godsend
let mapleader = " "

" color scheme
syntax enable
let g:solarized_termcolors=256
let g:rehash256 = 1
set t_Co=256
" let g:airline_theme='solarized'
set bg=dark
" colorscheme solarized
colorscheme badwolf
" colorscheme PaperColor
" let g:airline_theme='PaperColor'

" Keep this below the colorschemes
filetype plugin indent on     " required!

" Vim EasyMotion trigger
let g:EasyMotion_leader_key = '<Leader><Leader>'
nmap <silent> <C-s> <Plug>(easymotion-w)
" EasyMotion Highlight
hi link EasyMotionTarget ErrorMsg
hi link EasyMotionShade  Comment

nnoremap <Leader>e :Reveal<CR>

" exchange vim
nmap cx <Plug>(Exchange)
vmap cx <Plug>(Exchange)
nmap cC <Plug>(ExchangeClear)
vmap cX <Plug>(ExchangeLine)
nmap cX <Plug>(ExchangeLine)

" Treat .hql files as SQL for syntax highlighting
au BufNewFile,BufRead *.hql set filetype=sql

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
" set esckeys
set ttimeoutlen=10
augroup FastEscape
    autocmd!
    au InsertEnter * set timeoutlen=0
    au InsertLeave * set timeoutlen=1000
augroup END

" incremental search
set incsearch

" NerdTreeToggle
nnoremap <silent> <Leader>n :NERDTreeToggle<CR>

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

" iTerm2 is remapping S-Space to C-U
" toggle hold with <S-Space> if over a fold
nnoremap <C-U> za

" vimrc tweaking -- from 'Instantly Better Vim'
nnoremap <silent> cv :sp $MYVIMRC<CR>

augroup VimReload
  autocmd!
  autocmd BufWritePost $MYVIMRC source $MYVIMRC
augroup END

" persistent undo
if !isdirectory($HOME . "/.vim/undo")
    call mkdir($HOME . "/.vim/undo", "p")
endif
set undofile
set undodir=$HOME/.vim/undo " directory needs to exist(!)
set undolevels=10000
set undoreload=10000        " number of lines to save for undo

" visual mode defaults
set virtualedit=block

" case and searching
set smartcase ignorecase
set incsearch
set hlsearch

" clear search with ENTER
nnoremap <CR> :nohlsearch<CR>

" search and replace shortcut
nnoremap S :%s//g<LEFT><LEFT>
vnoremap S :s//g<LEFT><LEFT>

" toggle line wrapping
set nowrap

" toggle list chars
set nolist

" TrailerTrash Trim
" nnoremap cot :Trim<bar>w<CR>
nnoremap <Leader>t :TrailerTrim<CR>

" set current file's directory as the vim directory
nnoremap <Leader>c :cd %:p:h<CR>
nnoremap <Leader>r :NERDTreeFind<cr>

" line numbers
" all surrounding lines have relative numbers
" set relativenumber
" current line has absolute numbering
" set number

" swap colon and semicolon
noremap ; :
noremap : ;

" swap visual and block visual mode
noremap v <c-v>
noremap <c-v> v

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
" Show list of completions, and complete as much as possible, then iterate full completions
set wildmode=list:longest,full

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
set guifont=Hack:h13
" set guifont=Inconsolata:h16
" set guifont=Monaco:h16

" splits open to bottom and right
set splitright
set splitbelow

" clam in vim
nnoremap ! :Clam<space>
vnoremap ! :ClamVisual<space>

" nerdtree left
let g:NERDTreeWinPos = "left"

" ctrl-p mappings
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'
" nnoremap <C-P>. :CtrlPTag<cr>
let g:ctrlp_working_path_mode = 'ra'
" let g:ctrlp_user_command = ['.git', 'cd %s && git ls-files']
let g:ctrlp_user_command = ['.git', 'cd %s && git ls-files . -co --exclude-standard']

"====[ I'm sick of typing :%s/.../.../g ]=======
nnoremap S :%s//g<LEFT><LEFT>
vnoremap S :s//g<LEFT><LEFT>

" Visually select last edited/pasted text
" http://vimcasts.org/episodes/bubbling-text/
nnoremap gp `[v`]

" Run quick scripts
" Adapted from: http://oinksoft.com/blog/view/6/
let ft_stdout_mappings = {
      \'bash':        'bash',
      \'javascript':  'node',
      \'nodejs':      'node',
      \'perl':        'perl',
      \'php':         'php',
      \'python':      'python',
      \'ruby':        'ruby',
      \'sh':          'sh',
      \}
let ft_execute_mappings = {
      \'c': 'gcc -o %:r -Wall -std=c99 % && ./%:r',
      \'md': 'open -app Marked2.app %',
      \'markdown': 'open -app Marked2.app %',
      \'applescript': 'osascript %',
      \}

for ft_name in keys(ft_stdout_mappings)
  execute 'autocmd Filetype ' . ft_name . ' nnoremap <buffer> <C-e> :Dispatch '
          \. ft_stdout_mappings[ft_name] . ' % <CR>'
endfor

for ft_name in keys(ft_execute_mappings)
  execute 'autocmd FileType ' . ft_name
          \. ' nnoremap <buffer> <C-e> :Dispatch '
          \. ft_execute_mappings[ft_name] . '<CR>'
endfor

nnoremap <Leader>pi :PlugInstall<CR>
nnoremap <Leader>pu :PlugUpdate!<CR>
nnoremap <Leader>pc :PlugClean<CR>

" IndentGuides
nnoremap coi :IndentGuidesToggle<CR>
let g:indent_guides_start_level=1
let g:indent_guides_guide_size=1

