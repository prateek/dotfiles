return {
  -- Theme from your vimrc; set early
  {
    "sjl/badwolf",
    name = "badwolf",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("badwolf")
    end,
  },

  -- Git tools similar to your setup
  { "tpope/vim-fugitive" },

  -- Targets, Unimpaired, Repeat, Exchange like your vimrc
  { "wellle/targets.vim" },
  { "tpope/vim-unimpaired" },
  { "tpope/vim-repeat" },
  { "tommcdo/vim-exchange" },

  -- Text alignment (Tabular)
  { "godlygeek/tabular", cmd = { "Tabularize", "Tab" } },

  -- Dispatch for quick runs
  { "tpope/vim-dispatch" },

  -- Trailspace trimming (modern replacement for trailertrash)
  {
    "echasnovski/mini.trailspace",
    version = false,
    config = function()
      require("mini.trailspace").setup()
      vim.keymap.set("n", "<leader>t", function()
        pcall(function()
          require("mini.trailspace").trim()
        end)
      end, { desc = "Trim trailing whitespace" })
    end,
  },

  -- Slime for tmux REPLs
  {
    "jpalardy/vim-slime",
    ft = { "python", "r", "clojure", "scheme", "sh", "bash", "zsh" },
    init = function()
      vim.g.slime_target = "tmux"
    end,
  },

  -- macOS helpers
  { "henrik/vim-reveal-in-finder", cmd = "Reveal" },
  { "itspriddle/vim-marked", ft = { "markdown" } },
  {
    "zephod/vim-iterm2-navigator",
    cond = function()
      return vim.fn.has("macunix") == 1
    end,
  },

  -- Lisps (Clojure/Scheme/Racket)
  { "wlangstroth/vim-racket", ft = { "racket" } },
  { "vim-scripts/scribble.vim", ft = { "racket" } },
  { "guns/vim-sexp", ft = { "clojure", "scheme", "lisp" } },
  { "tpope/vim-sexp-mappings-for-regular-people", ft = { "clojure", "scheme", "lisp" } },
}

