" vim:fdm=marker

" Vundle Plugin List
set nocompatible               " be iMproved
filetype off                   " required!

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" let Vundle manage Vundle, it's required
Plugin 'gmarik/Vundle.vim'

" original repos on github
Plugin 'sjl/badwolf'
Plugin 'amix/vim-zenroom2'
Plugin 'bling/vim-airline'
Plugin 'christoomey/vim-tmux-navigator'

Plugin 'junegunn/goyo.vim'
Plugin 'godlygeek/tabular'
Plugin 'kien/ctrlp.vim'

" Gist.vim and it's dependency
Plugin 'mattn/gist-vim'
Plugin 'mattn/webapi-vim'

Plugin 'scrooloose/nerdtree'
Plugin 'sjl/clam.vim'

" Git Plugin
Plugin 'tpope/vim-fugitive'

Plugin 'bronson/vim-visual-star-search'

Plugin 'tpope/vim-eunuch'
Plugin 'tpope/vim-abolish'
Plugin 'tpope/vim-repeat'
Plugin 'tpope/vim-surround'
Plugin 'tpope/vim-unimpaired'
Plugin 'tpope/vim-commentary'
Plugin 'vim-scripts/maven-plugin'

Plugin 'wesQ3/vim-windowswap'
Plugin 'tommcdo/vim-exchange'
Plugin 'sjl/gundo.vim'
Plugin 'vim-scripts/YankRing.vim'

" Plugin 'tpope/vim-vinegar'
" Plugin 'tpope/vim-classpath'

Plugin 'luochen1990/rainbow'
" Plugin 'scrooloose/syntastic' " Syntax Error Checking

" Emacs bindings for Vim's CLI
Plugin 'bruno-/vim-husk'

Plugin 'mileszs/ack.vim'

Plugin 'jiangmiao/auto-pairs'     " AutoPair Brackets
Plugin 'wellle/targets.vim'       " TextObject Extensions
Plugin 'wellle/tmux-complete.vim' " Auto complete across tmux panes

" Autocomplete
Plugin 'Valloric/YouCompleteMe'
" Snippets
Plugin 'MarcWeber/vim-addon-mw-utils'
Plugin 'tomtom/tlib_vim'
Plugin 'SirVer/ultisnips'
Plugin 'honza/vim-snippets'

Plugin 'jpalardy/vim-slime'

" OS X Bindings
"" Reveal in finder
Plugin 'henrik/vim-reveal-in-finder'
"" Dash.app integration - Mac Specific
Plugin 'rizzatti/funcoo.vim'
Plugin 'rizzatti/dash.vim'

" TODO: use the master repo once it picks up your commit
Plugin 'prateek/QFGrep'
Plugin 'mattboehm/vim-unstack'

" Clojure(! s/.*/Lisp)
Plugin 'guns/vim-sexp'
Plugin 'tpope/vim-sexp-mappings-for-regular-people'
Plugin 'tpope/vim-leiningen'
Plugin 'tpope/vim-projectionist'
Plugin 'tpope/vim-fireplace'
Plugin 'guns/vim-clojure-static'
Plugin 'guns/vim-clojure-highlight'

" vim-scripts repos
Plugin 'L9'
Plugin 'csexton/trailertrash.vim' " TrailerTrash

" Background vim compile
Plugin 'tpope/vim-dispatch'

" ZoomWin
Plugin 'vim-scripts/ZoomWin'

" syntax plugins
"" HOCON - aka morphlines
Plugin 'GEverding/vim-hocon'
" Scala
" Based on: http://bleibinha.us/blog/2013/08/my-vim-setup-for-scala
" TODO: try this - https://github.com/mdr/scalariform
Plugin 'nathanaelkane/vim-indent-guides'
Plugin 'derekwyatt/vim-scala'
Plugin 'kalmanb/sbt-ctags'
Plugin 'ktvoelker/sbt-vim'
"" markdown
Plugin 'prateek/vim-writingsyntax' " Writing-Syntax Checker
Plugin 'plasticboy/vim-markdown'
" logs
Plugin 'dzeban/vim-log-syntax'

" BufferList plugin
Plugin 'jeetsukumaran/vim-buffergator'
" Easy-Motion disabled for vim-smalls
Plugin 'Lokaltog/vim-easymotion'

" ExtractLinks
Plugin 'ingo-library'
Plugin 'PatternsOnText'
Plugin 'ExtractMatches'
Plugin 'ExtractLinks'

call vundle#end()            " required

" color scheme
let g:solarized_termcolors=256
let g:rehash256 = 1
set t_Co=256
set bg=dark
let g:airline_theme='solarized'
colorscheme badwolf

" Keep this below the colorschemes
filetype plugin indent on     " required!
syntax enable

" Ack.vim
nnoremap <Leader>a :Ack
let g:ack_use_dispatch=1
let g:ack_qhandler = "botright copen 5"

" Dispatch.vim
autocmd FileType java let b:dispatch = 'mvn package'

" Slime
" TODO: try: https://github.com/epeli/slimux
let g:slime_target = "tmux"
" let g:slime_paste_file = "$HOME/.slime_paste"
let g:slime_no_mappings = 1
xmap <c-d> <Plug>SlimeRegionSend
nmap <c-d> <Plug>SlimeParagraphSend

" Sexp
let g:sexp_filetypes = 'clojure,scheme,lisp,timl,scala'
let g:sexp_enable_insert_mode_mappings = 0

nnoremap cot :Trim<bar>w<CR>

" ExtractLinks
nnoremap <leader>x :ExtractLinks<bar>:$put<CR>

" ZoomWin.vim
nnoremap <silent> <leader>z :ZoomWin<CR>

" TabCompletion - YCM + UtilSnips
let g:ycm_collect_identifiers_from_tags_files = 1
let g:ycm_auto_trigger = 1
let g:ycm_autoclose_preview_window_after_insertion=1
" iTerm2 is taking care of the S-space -> C-U mapping
" let g:ycm_key_invoke_completion = '<C-U>'

let g:indent_guides_start_level=1
let g:indent_guides_guide_size=1

"  syntax
"" markdown
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

let g:buffergator_suppress_keymaps=1
nnoremap <silent> <leader>b :BuffergatorOpen<CR>
nnoremap <silent> [b :BuffergatorMruCyclePrev<CR>
nnoremap <silent> ]b :BuffergatorMruCycleNext<CR>

nmap <silent> K <Plug>DashSearch
vmap <silent> K <Plug>DashSearch
nmap <silent> <leader>K :DashSearch

" Vim EasyMotion trigger
let g:EasyMotion_leader_key = '<Leader><Leader>'
nmap <silent> <C-s> <Plug>(easymotion-w)
" EasyMotion Highlight
hi link EasyMotionTarget ErrorMsg
hi link EasyMotionShade  Comment

nnoremap <leader>e :Reveal<CR>

" exchange vim
nmap cx <Plug>(Exchange)
vmap cx <Plug>(Exchange)
nmap cC <Plug>(ExchangeClear)
vmap cX <Plug>(ExchangeLine)
nmap cX <Plug>(ExchangeLine)

" leader to <SPACE> <-- godsend
let mapleader = " "

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
set nowrap

" toggle list chars
set nolist

" set current file's directory as the vim directory
nnoremap <leader>c :cd %:p:h<CR>
nnoremap <leader>r :NERDTreeFind<cr>

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
nnoremap <silent> <leader>mc :Mvn compile <bar> redr! <bar> ccl <bar> copen<CR>

" fugitive mappings
nnoremap <silent> <leader>gs :Gstatus<CR>
nnoremap <silent> <leader>gw :Gwrite<CR>
nnoremap <silent> <leader>gd :Gdiff<CR>
nnoremap <silent> <leader>ge :Gedit<CR>
nnoremap <silent> <leader>gc :Gcommit<CR>

" ctrl-p mappings
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'
" nnoremap <C-P>. :CtrlPTag<cr>
let g:ctrlp_working_path_mode = 'ra'
" let g:ctrlp_user_command = ['.git', 'cd %s && git ls-files']
let g:ctrlp_user_command = ['.git', 'cd %s && git ls-files . -co --exclude-standard']

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
nnoremap <silent> <leader>ma :!open -a Marked\ 2.app '%:p'<CR>

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

nnoremap <Leader>pi :PluginInstall<CR>
nnoremap <Leader>pu :PluginUpdate<CR>
nnoremap <Leader>pc :PluginClean<CR>

" Gundo
let g:gundo_auto_preview=0
let g:gundo_playback_delay=30
nnoremap <Leader>gu :GundoToggle<CR>

" YankRing
nnoremap <silent> <Leader>y :YRShow<CR>
let g:yankring_replace_n_pkey = '<D-p>'
let g:yankring_replace_n_nkey = '<D-n>'
let g:yankring_history_file='.yankring_history_'

" vim paste for OS-X
" inoremap <D-v> :set paste<CR>:put  *<CR>:set nopaste<CR>
" inoremap <D-V> :set paste<CR>:put  *<CR>:set nopaste<CR>

" Rainbow
nnoremap cr :RainbowToggle<CR>
let g:rainbow_active = 1
let g:rainbow_conf = {
\   'guifgs': ['royalblue3', 'darkorange3', 'seagreen3', 'firebrick'],
\   'ctermfgs': ['lightblue', 'lightyellow', 'lightcyan', 'lightmagenta'],
\   'operators': '_,_',
\   'parentheses': ['start=/(/ end=/)/ fold', 'start=/\[/ end=/\]/ fold', 'start=/{/ end=/}/ fold'],
\   'separately': {
\       '*': {},
\       'tex': {
\           'parentheses': ['start=/(/ end=/)/', 'start=/\[/ end=/\]/'],
\       },
\       'lisp': {
\           'guifgs': ['royalblue3', 'darkorange3', 'seagreen3', 'firebrick', 'darkorchid3'],
\       },
\       'vim': {
\           'parentheses': ['start=/(/ end=/)/', 'start=/\[/ end=/\]/', 'start=/{/ end=/}/ fold', 'start=/(/ end=/)/ containedin=vimFuncBody', 'start=/\[/ end=/\]/ containedin=vimFuncBody', 'start=/{/ end=/}/ fold containedin=vimFuncBody'],
\       },
\       'html': {
\           'parentheses': ['start=/\v\<((area|base|br|col|embed|hr|img|input|keygen|link|menuitem|meta|param|source|track|wbr)[ >])@!\z([-_:a-zA-Z0-9]+)(\s+[-_:a-zA-Z0-9]+(\=("[^"]*"|'."'".'[^'."'".']*'."'".'|[^ '."'".'"><=`]*))?)*\>/ end=#</\z1># fold'],
\       },
\       'css': 0,
\   }
\}

" YCM with UltiSnips
  " https://github.com/Valloric/YouCompleteMe/issues/36#issuecomment-15722669
let g:UltiSnipsExpandTrigger       = "<tab>"
let g:UltiSnipsJumpForwardTrigger  = "<tab>"
let g:UltiSnipsJumpBackwardTrigger = "<s-tab>"

function! g:UltiSnips_Complete()
    call UltiSnips#ExpandSnippet()
    if g:ulti_expand_res == 0
        if pumvisible()
            return "\<C-n>"
        else
            call UltiSnips#JumpForwards()
            if g:ulti_jump_forwards_res == 0
               return "\<TAB>"
            endif
        endif
    endif
    return ""
endfunction

au InsertEnter * exec "inoremap <silent> " . g:UltiSnipsExpandTrigger . " <C-R>=g:UltiSnips_Complete()<cr>"
