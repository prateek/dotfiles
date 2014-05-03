" vim:fdm=marker

" Vundle Plugin List {{{
set nocompatible               " be iMproved
filetype off                   " required!

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" let Vundle manage Vundle, it's required 
Plugin 'gmarik/Vundle.vim'

" original repos on github
Plugin 'altercation/vim-colors-solarized'
Plugin 'amix/vim-zenroom2'
Plugin 'bling/vim-airline'
Plugin 'christoomey/vim-tmux-navigator'
Plugin 'fs111/pydoc.vim'
Plugin 'godlygeek/tabular'
Plugin 'hdima/python-syntax'
Plugin 'junegunn/goyo.vim'
Plugin 'kablamo/vim-git-log'
Plugin 'kien/ctrlp.vim'
Plugin 'mattn/gist-vim'
Plugin 'mattn/webapi-vim'
Plugin 'mileszs/ack.vim'
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

Plugin 'jiangmiao/auto-pairs'     " AutoPair Brackets
Plugin 'wellle/targets.vim'       " TextObject Extensions
Plugin 'wellle/tmux-complete.vim' " Auto complete across tmux panes

" Auto-complete tab
Plugin 'ervandew/supertab'

" Snippets
Plugin 'MarcWeber/vim-addon-mw-utils'
Plugin 'tomtom/tlib_vim'
Plugin 'SirVer/ultisnips'
Plugin 'honza/vim-snippets'

" Background vim compile
Plugin 'tpope/vim-dispatch'
autocmd FileType java let b:dispatch = 'mvn package'

" Slime
Plugin 'jpalardy/vim-slime'
let g:slime_target = "tmux"
" let g:slime_paste_file = "$HOME/.slime_paste"
let g:slime_no_mappings = 1
xmap <c-x> <Plug>SlimeRegionSend
nmap <c-x> <Plug>SlimeParagraphSend

" Reveal in finder
Plugin 'henrik/vim-reveal-in-finder'
nnoremap <leader>e :Reveal<CR>

" Sessions
" Plugin 'xolox/vim-misc'
" Plugin 'xolox/vim-session'

" TODO: use the master repo once it picks up your commit
Plugin 'prateek/QFGrep'
Plugin 'prateek/vim-unstack'

" vim-scripts repos
Plugin 'L9'

Plugin 'csexton/trailertrash.vim' " TrailerTrash
nnoremap <leader>t :Trim<bar>w<CR>

" ExtractLinks {{{
Plugin 'ingo-library'
Plugin 'PatternsOnText'
Plugin 'ExtractMatches'
Plugin 'ExtractLinks'
nnoremap <leader>x :ExtractLinks<bar>:$put<CR>
" }}}

" ZoomWin
Plugin 'vim-scripts/ZoomWin'
nnoremap <silent> <leader>z :ZoomWin<CR>

" Damian Conway's piece de resistance
"vnoremap <expr> <LEFT> DVB_Drag('left')
"vnoremap <expr> <RIGHT> DVB_Drag('right')
"vnoremap <expr> <DOWN> DVB_Drag('down')
"vnoremap <expr> <UP> DVB_Drag('up')

" syntax plugins {{{
Plugin 'GEverding/vim-hocon' " HOCON syntax files, used for morphlines

" }}} syntax

"" markdown  {{{
Plugin 'prateek/vim-writingsyntax' " Writing-Syntax Checker
" autocmd BufNewFile * :setf writing

Plugin 'plasticboy/vim-markdown'
" autocmd bufnewfile * :set textwidth=80
augroup markdown
  autocmd BufNewFile * :set ai
  autocmd BufNewFile * :set formatoptions=tcroqn2
  autocmd BufNewFile * :set comments=n:>
  autocmd BufNewFile * :set wrap
  autocmd BufNewFile * :set linebreak
  autocmd BufNewFile * :set list
augroup end

" vim-markdown
let g:vim_markdown_initial_foldlevel=1

" disable markdown folds at startup
let g:vim_markdown_folding_disabled=1
" }}}

" BufferList plugin {{{
Plugin 'jeetsukumaran/vim-buffergator'
let g:buffergator_suppress_keymaps=1
nnoremap <silent> <leader>b :BuffergatorOpen<CR>
nnoremap <silent> [b :BuffergatorMruCyclePrev<CR>
nnoremap <silent> ]b :BuffergatorMruCycleNext<CR>
" }}}

" Dash.app integration - Mac Specific {{{
Plugin 'rizzatti/funcoo.vim'
Plugin 'rizzatti/dash.vim'
nnoremap <silent> K <Plug>DashSearch
vnoremap <silent> K <Plug>DashSearch
nnoremap <silent> <leader>K :DashSearch
" }}}

" Easy-Motion disabled for vim-smalls {{{
Plugin 'Lokaltog/vim-easymotion'
" Vim EasyMotion trigger
let g:EasyMotion_leader_key = '<Leader><Leader>'
" EasyMotion Highlight
hi link EasyMotionTarget ErrorMsg
hi link EasyMotionShade  Comment
" }}}

" all plugins finished
call vundle#end()            " required
filetype plugin indent on    " required
" }}}

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
nnoremap <S-Space> za

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

" clear search with ENTER
nnoremap <CR> :nohlsearch<CR>

" search and replace shortcut
nnoremap S :%s//g<LEFT><LEFT>
vnoremap S :s//g<LEFT><LEFT>

" toggle line wrapping
" nnoremap <leader>w :set wrap!<CR>
set nowrap

" toggle list chars
" nnoremap <leader>l :set list!<CR>
set nolist

" set current file's directory as the vim directory
nnoremap <leader>c :cd %:p:h<CR>
nnoremap <leader>r :NERDTreeFind<cr>

" line numbers
" all surrounding lines have relative numbers
" set relativenumber
" current line has absolute numbering
set number

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

"====[ I'm sick of typing :%s/.../.../g ]=======
nnoremap S :%s//g<LEFT><LEFT>
vnoremap S :s//g<LEFT><LEFT>

" Marked binding
" nnoremap <leader>ma :!open -a Marked.app '%:p' <bar> redr! <CR>

" Visually select last edited/pasted text
" http://vimcasts.org/episodes/bubbling-text/
nnoremap gp `[v`]

" Run quick scripts {{{
" Adapted from: http://oinksoft.com/blog/view/6/
" <Command-R> mapped to execute script
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
      \}

for ft_name in keys(ft_stdout_mappings)
  execute 'autocmd Filetype ' . ft_name . ' nnoremap <buffer> <D-R> :write !'
          \. ft_stdout_mappings[ft_name] . '<CR>'
endfor

for ft_name in keys(ft_execute_mappings)
  execute 'autocmd FileType ' . ft_name
          \. ' nnoremap <buffer> <C-P> :write \| !'
          \. ft_execute_mappings[ft_name] . '<CR>'
endfor
" }}}

nnoremap <Leader>pi :PluginInstall<CR>
nnoremap <Leader>pu :PluginUpdate<CR>
nnoremap <Leader>pc :PluginClean<CR>
