local o = vim.opt

-- Indentation and tabs
o.tabstop = 2
o.shiftwidth = 2
o.expandtab = true
o.autoindent = true
o.smarttab = true
o.shiftround = true

-- UI/UX
o.number = true
o.showmatch = true
o.laststatus = 2
o.ruler = true
o.showcmd = true
o.wildmenu = true
o.wildmode = "list:longest,full"
o.splitright = true
o.splitbelow = true
o.scrolloff = 1
o.sidescrolloff = 5
o.display:append("lastline")
o.wrap = false
o.list = false
o.listchars = {
  trail = "·",
  precedes = "«",
  extends = "»",
  tab = "▸·",
  eol = "¬",
}
o.showbreak = "↪"
o.guifont = "Hack:h13"

-- Searching
o.ignorecase = true
o.smartcase = true
o.incsearch = true
o.hlsearch = true

-- Use 'r', 'c', 'o' like in your vimrc
o.formatoptions:append("rco")
o.virtualedit = "block"

-- Performance / timeouts
o.timeoutlen = 1000
o.ttimeoutlen = 10
o.nrformats:remove("octal")

-- Persistent undo (use Neovim's state dir)
local undodir = vim.fn.stdpath("state") .. "/undo"
if vim.fn.isdirectory(undodir) == 0 then
  vim.fn.mkdir(undodir, "p")
end
o.undofile = true
o.undodir = undodir

-- Colors
o.termguicolors = true

-- Disable red/right margin column highlight
o.colorcolumn = ""
pcall(vim.api.nvim_set_hl, 0, "ColorColumn", { bg = "NONE" })
