local opt = vim.opt
local g = vim.g

-- Leader key
g.mapleader = " "
g.maplocalleader = " "

-- UI
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.showmode = false
opt.ruler = false
opt.laststatus = 3 -- global statusline
opt.termguicolors = true
opt.pumheight = 10
opt.pumblend = 10
opt.winblend = 10
opt.shortmess:append("sI")
opt.fillchars = { eob = " " }

-- Indentation
opt.expandtab = true
opt.shiftwidth = 2
opt.smartindent = true
opt.tabstop = 2
opt.softtabstop = 2

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- Editing
opt.clipboard = "unnamedplus"
opt.undofile = true
opt.undolevels = 10000
opt.updatetime = 250
opt.timeoutlen = 400
opt.mouse = "a"
opt.wrap = false
opt.scrolloff = 8
opt.sidescrolloff = 8

-- Split behavior
opt.splitbelow = true
opt.splitright = true

-- Completion
opt.completeopt = { "menu", "menuone", "noselect" }

-- File encoding
opt.fileencoding = "utf-8"

-- Backup
opt.backup = false
opt.writebackup = false
opt.swapfile = false

-- Disable providers
g.loaded_node_provider = 0
g.loaded_python3_provider = 0
g.loaded_perl_provider = 0
g.loaded_ruby_provider = 0
