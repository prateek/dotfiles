" vim:fdm=marker

set nocompatible               " be iMproved
filetype off                   " required!

call plug#begin('~/.vim/plugged')

" ColorSchemes
Plug 'sjl/badwolf'
Plug 'NLKNguyen/papercolor-theme'
Plug 'altercation/vim-colors-solarized'

Plug 'amix/vim-zenroom2'
Plug 'bling/vim-airline'
Plug 'christoomey/vim-tmux-navigator'

Plug 'junegunn/goyo.vim'
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

" Plug 'vim-scripts/maven-plugin'
" Plug 'wesQ3/vim-windowswap'
Plug 'tommcdo/vim-exchange'
Plug 'sjl/gundo.vim'

Plug 'luochen1990/rainbow'
Plug 'vim-syntastic/syntastic', { 'for': 'go' } " Syntax Error Checking

" Emacs bindings for Vim's CLI
Plug 'bruno-/vim-husk'
Plug 'mileszs/ack.vim'
Plug 'wincent/ferret'

Plug 'jiangmiao/auto-pairs'     " AutoPair Brackets
Plug 'wellle/targets.vim'       " TextObject Extensions
Plug 'wellle/tmux-complete.vim' " Auto complete across tmux panes

" Autocomplete
" Plug 'Valloric/YouCompleteMe', { 'do': './install.sh' , 'for': ['go', 'cpp']}
Plug 'Valloric/YouCompleteMe', { 'do': './install.sh' , 'for': 'cpp'}

" Snippets
Plug 'MarcWeber/vim-addon-mw-utils'
Plug 'tomtom/tlib_vim'
Plug 'SirVer/ultisnips'
Plug 'honza/vim-snippets'

Plug 'jpalardy/vim-slime'
Plug 'wincent/terminus'

" OS X Bindings
"" Reveal in finder
Plug 'henrik/vim-reveal-in-finder'
Plug 'itspriddle/vim-marked'

"" Dash.app integration - Mac Specific
" Plug 'rizzatti/funcoo.vim'
" Plug 'rizzatti/dash.vim'
Plug 'mattboehm/vim-unstack'
Plug 'tpope/vim-projectionist'

" Lisps
Plug 'wlangstroth/vim-racket'
Plug 'vim-scripts/scribble.vim'
Plug 'guns/vim-sexp' , { 'for': ['clojure', 'scheme']  }
Plug 'tpope/vim-sexp-mappings-for-regular-people', { 'for': ['clojure', 'scheme']  }

" Clojure
Plug 'tpope/vim-classpath', { 'for': 'clojure' }
Plug 'tpope/vim-salve', { 'for': 'clojure'  }
Plug 'tpope/vim-fireplace', { 'for': 'clojure'  }
Plug 'guns/vim-clojure-static', { 'for': 'clojure'  }
Plug 'guns/vim-clojure-highlight', { 'for': 'clojure'  }

" Golang
Plug 'fatih/vim-go', { 'for': 'go' }
Plug 'majutsushi/tagbar', { 'for': 'go' }
Plug 'godoctor/godoctor.vim', { 'for': 'go' }
Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins', 'for': 'go' }
Plug 'zchee/deoplete-go', { 'do': 'make', 'for': 'go' }
" remember to install gocode: ``go get -u github.com/nsf/gocode``

" vim-scripts repos
Plug 'L9'
Plug 'csexton/trailertrash.vim' " TrailerTrash

" Background vim compile
Plug 'tpope/vim-dispatch'

" ZoomWin
Plug 'vim-scripts/ZoomWin'

" syntax plugins
"" HOCON - aka morphlines
Plug 'GEverding/vim-hocon', { 'for': 'conf' }
Plug 'nathanaelkane/vim-indent-guides'

" Scala
" Based on: http://bleibinha.us/blog/2013/08/my-vim-setup-for-scala
" TODO: try this - https://github.com/mdr/scalariform
Plug 'derekwyatt/vim-scala', { 'for': 'scala' }
Plug 'kalmanb/sbt-ctags', { 'for': 'scala' }
Plug 'ktvoelker/sbt-vim', { 'for': 'scala' }

" markdown
Plug 'tpope/vim-markdown', { 'for': 'markdown' }

" writing
Plug 'prateek/vim-writingsyntax', {'for': ['markdown', 'text'] } " Writing-Syntax Checker
Plug 'reedes/vim-textobj-quote', {'for': ['markdown', 'text'] }
Plug 'reedes/vim-litecorrect', {'for': ['markdown', 'text'] }    " light weight autocorrect
" Plug 'reedes/vim-pencil', {'for': ['markdown', 'text'] }    " light weight autocorrect
" TODO: https://github.com/reedes/vim-lexical

" logs
Plug 'dzeban/vim-log-syntax', { 'for': 'log' }

" octave
Plug 'jvirtanen/vim-octave', { 'for': 'octave' }

" python
" Plug 'hdima/python-syntax', { 'for': 'python' }

" BufferList plugin
Plug 'jeetsukumaran/vim-buffergator'

" Easy-Motion disabled for vim-smalls
Plug 'Lokaltog/vim-easymotion'

" ExtractLinks
Plug 'ingo-library' | Plug 'PatternsOnText' | Plug 'ExtractMatches' | Plug 'ExtractLinks'

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
let g:airline_theme='PaperColor'

" Keep this below the colorschemes
filetype plugin indent on     " required!

" Ack.vim
nnoremap <Leader>a :Ack
let g:ack_use_dispatch=1
let g:ack_qhandler = "botright copen 5"

" Dispatch.vim
autocmd FileType java let b:dispatch = 'mvn package'

" Slime
" TODO: try: https://github.com/epeli/slimux
let g:slime_target = "tmux"
let g:slime_paste_file = "$HOME/.slime_paste"
let g:slime_no_mappings = 1
xmap <c-d> <Plug>SlimeRegionSend
nmap <c-d> <Plug>SlimeParagraphSend

" Sexp
let g:sexp_filetypes = 'clojure,scheme,lisp,timl,scala'
let g:sexp_enable_insert_mode_mappings = 0

" ExtractLinks
nnoremap <Leader>x :ExtractLinks<bar>:$put<CR>

" ZoomWin.vim
nnoremap <silent> <Leader>z :ZoomWin<CR>

" TabCompletion - YCM + UtilSnips
let g:ycm_collect_identifiers_from_tags_files = 1
let g:ycm_auto_trigger = 1
let g:ycm_autoclose_preview_window_after_insertion=1
" iTerm2 is taking care of the S-space -> C-U mapping
" let g:ycm_key_invoke_completion = '<C-U>'

"  syntax
"" markdown
" augroup markdown
"   autocmd BufNewFile * :set ai
"   autocmd BufNewFile * :set formatoptions=tcroqn2
"   autocmd BufNewFile * :set comments=n:>
"   autocmd BufNewFile * :set wrap
"   autocmd BufNewFile * :set linebreak
"   autocmd BufNewFile * :set list
" augroup end

" augroup pencil
"   autocmd!
"   autocmd FileType markdown,mkd,text call pencil#init({'wrap': 'hard'})
"                                  \ | call litecorrect#init()
"   autocmd FileType markdown,mkd,text :let g:pencil#textwidth=74 " 1/2 screen width of my rMbp
"   autocmd FileType markdown,mkd,text :let g:airline_section_x='%{PencilMode()}'
" augroup END

"" fenced code-blocks within markdown
let g:markdown_fenced_languages = ['html', 'python', 'bash=sh']
"" vim-markdown
let g:vim_markdown_initial_foldlevel=1
"" disable markdown folds at startup
let g:vim_markdown_folding_disabled=1

" writing plugins
let g:buffergator_suppress_keymaps=1
nnoremap <silent> <leader>b :BuffergatorOpen<CR>
nnoremap <silent> [b :BuffergatorMruCyclePrev<CR>
nnoremap <silent> ]b :BuffergatorMruCycleNext<CR>

" nmap <silent> K <Plug>DashSearch
" vmap <silent> K <Plug>DashSearch
" nmap <silent> <leader>K :DashSearch

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

" vim-go golang
let g:go_highlight_functions = 1
let g:go_highlight_methods = 1
let g:go_highlight_fields = 1
let g:go_highlight_types = 1
let g:go_highlight_operators = 1
let g:go_highlight_build_constraints = 1
let g:go_fmt_command = "goimports"
let g:go_info_mode = 'gocode'

nnoremap <Leader>t :TagbarToggle<CR>

au FileType go nnoremap <Leader>i :GoInfo<CR>

" ack.vim -> ag
let g:ackprg = 'ag --nogroup --nocolor --column'
" let g:ackprg = 'ag --vimgrep' " include multiple matches per line

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
" nnoremap <Leader>t :TrailerTrim<CR>

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

" window swap vim
" let g:windowswap_map_keys = 0 "prevent default bindings
" nnoremap <silent> <Leader>yw :call WindowSwap#MarkWindowSwap()<CR>
" nnoremap <silent> <Leader>pw :call WindowSwap#DoWindowSwap()<CR>

" nerdtree left
let g:NERDTreeWinPos = "left"

" maven
nnoremap <silent> <Leader>mp :Mvn package<bar>:redr!<bar>:ccl<bar>:copen<CR>
nnoremap <silent> <Leader>mc :Mvn compile<bar>:redr!<bar>:ccl<bar>:copen<CR>

" fugitive mappings
nnoremap <silent> <Leader>gs :Gstatus<CR>
nnoremap <silent> <Leader>gw :Gwrite<CR>
nnoremap <silent> <Leader>gd :Gdiff<CR>
nnoremap <silent> <Leader>ge :Gedit<CR>
nnoremap <silent> <Leader>gc :Gcommit<CR>

" ctrl-p mappings
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'
" nnoremap <C-P>. :CtrlPTag<cr>
let g:ctrlp_working_path_mode = 'ra'
" let g:ctrlp_user_command = ['.git', 'cd %s && git ls-files']
let g:ctrlp_user_command = ['.git', 'cd %s && git ls-files . -co --exclude-standard']

" VimRoom Plugin
nnoremap <silent> <Leader>wr :Goyo<CR>

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
nnoremap <silent> <Leader>ma :MarkedOpen<bar>:redr!<cr>

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
let g:rainbow_guifgs = ['RoyalBlue3', 'DarkOrange3', 'DarkOrchid3', 'FireBrick']
let g:rainbow_ctermfgs = ['lightblue', 'lightgreen', 'yellow', 'red', 'magenta']

" YCM with UltiSnips
  " https://github.com/Valloric/YouCompleteMe/issues/36#issuecomment-15722669
" let g:UltiSnipsExpandTrigger       = "<tab>"
" let g:UltiSnipsJumpForwardTrigger  = "<tab>"
" let g:UltiSnipsJumpBackwardTrigger = "<s-tab>"

" function! g:UltiSnips_Complete()
"     call UltiSnips#ExpandSnippet()
"     if g:ulti_expand_res == 0
"         if pumvisible()
"             return "\<C-n>"
"         else
"           call UltiSnips#JumpForwards()
"           if g:ulti_jump_forwards_res == 0
"             return "\<TAB>"
"           endif
"         endif
"     endif
"     return ""
" endfunction

" au InsertEnter * exec "inoremap <silent> " . g:UltiSnipsExpandTrigger . " <C-R>=g:UltiSnips_Complete()<cr>"

" IndentGuides
nnoremap coi :IndentGuidesToggle<CR>
let g:indent_guides_start_level=1
let g:indent_guides_guide_size=1

" Block Visual Move
" via http://vimrcfu.com/snippet/77
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv"

" Alternate line colors
" via http://stackoverflow.com/questions/26611851/set-alternating-highlight-colors-to-text-in-vim
" syn match Oddlines "^.*$" contains=ALL nextgroup=Evenlines skipnl
" syn match Evenlines "^.*$" contains=ALL nextgroup=Oddlines skipnl
" hi Oddlines ctermbg=yellow guibg=#FFFF99
" hi Evenlines ctermbg=magenta guibg=#FFCCFF

" Uncomment the following to have Vim jump to the last position when reopening a file
" via http://askubuntu.com/questions/223018/vim-is-not-remembering-last-position
if has("autocmd")
  au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
endif
