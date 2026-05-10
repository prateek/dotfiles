return {
	-- Theme: vscode.nvim (dark)
	{
		"Mofiqul/vscode.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			require("vscode").setup({})
		end,
	},
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "vscode",
		},
	},

	-- Completion: only show the menu on explicit trigger (<C-space>)
	{
		"saghen/blink.cmp",
		opts = function(_, opts)
			opts.completion = opts.completion or {}
			opts.completion.menu = opts.completion.menu or {}
			opts.completion.menu.auto_show = false
		end,
	},

	-- Git tools similar to your setup
	{ "tpope/vim-fugitive" },
	{
		"NeogitOrg/neogit",
		cmd = "Neogit",
		keys = {
			{
				"<leader>gg",
				function()
					local neogit = require("neogit")
					local cwd = vim.fn.expand("%:p:h")
					if cwd == "" then
						cwd = vim.fn.getcwd()
					end
					neogit.open({ cwd = cwd })
				end,
				desc = "Neogit",
			},
			{ "<leader>gc", "<cmd>Neogit commit<cr>", desc = "Neogit commit" },
		},
		dependencies = {
			"nvim-lua/plenary.nvim",
			"sindrets/diffview.nvim",
		},
		opts = {
			integrations = {
				diffview = true,
			},
		},
	},

	-- Targets, Unimpaired, Repeat, Exchange like your vimrc
	{ "wellle/targets.vim" },
	{ "tpope/vim-unimpaired" },
	{ "tpope/vim-repeat" },
	{ "tommcdo/vim-exchange" },

	-- Text alignment (Tabular)
	{ "godlygeek/tabular", cmd = { "Tabularize", "Tab" } },

	-- Dispatch for quick runs
	{ "tpope/vim-dispatch" },

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

	-- Use the Snacks `advanced` dashboard example
	{
		"folke/snacks.nvim",
		opts = {
			dashboard = {
				sections = {
					{ section = "header" },
					{
						pane = 2,
						section = "terminal",
						cmd = "colorscript -e square",
						height = 5,
						padding = 1,
						enabled = function()
							return vim.fn.executable("colorscript") == 1
						end,
					},
					{ section = "keys", gap = 1, padding = 1 },
					{
						pane = 2,
						icon = " ",
						title = "Recent Files",
						section = "recent_files",
						indent = 2,
						padding = 1,
					},
					{ pane = 2, icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
					{
						pane = 2,
						icon = " ",
						title = "Git Status",
						section = "terminal",
						enabled = function()
							return Snacks.git.get_root() ~= nil
						end,
						cmd = "git status --short --branch --renames",
						height = 5,
						padding = 1,
						ttl = 5 * 60,
						indent = 3,
					},
					{ section = "startup" },
				},
			},
		},
	},
}
