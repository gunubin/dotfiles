local map = vim.keymap.set
local nomap = vim.keymap.del

-- Mode shortcuts: n = normal, i = insert, v = visual, x = visual block, t = terminal, o = operator

-- Remove default mappings
pcall(nomap, "n", "<tab>") -- Unmap tab to enable Ctrl+i
pcall(nomap, "n", "<Leader>v") -- Unmap Leader v

-- General
map({ "n", "v" }, "<C-a>", "^", { desc = "Move to line start" })
map({ "n", "v" }, "<C-e>", "$", { desc = "Move to line end" })
map({ "n", "v" }, "H", "^", { desc = "Move to line start" })
map({ "n", "v" }, "L", "$", { desc = "Move to line end" })

-- Normal mode
map("n", "vv", "V", { desc = "Select whole line" })
map("n", "<CR>", "i<CR><ESC>", { desc = "Insert new line" })
map("n", "+", "<C-a>", { desc = "Increment number" })
map("n", "-", "<C-x>", { desc = "Decrement number" })
map("n", "x", '"_x', { desc = "Delete without yanking" })

-- Buffer navigation
map("n", "<C-j>", "<cmd>bn<CR>", { desc = "Next buffer" })
map("n", "<C-k>", "<cmd>bp<CR>", { desc = "Previous buffer" })
map("n", "<C-l>", "<cmd>bdelete<CR>", { desc = "Close buffer" })
map("n", "<Leader>.", "<cmd>BufferLineCycleNext<CR>", { desc = "Buffer goto next" })
map("n", "<Leader>,", "<cmd>BufferLineCyclePrev<CR>", { desc = "Buffer goto prev" })

-- Scrolling
map("n", "<C-d>", "<C-d>zz", { desc = "Scroll half-page down and center" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll half-page up and center" })
map("n", "<C-f>", "<C-f>zz", { desc = "Scroll page down and center" })

-- Clear search highlight
map("n", "<Esc><Esc>", "<cmd>nohl<CR>", { desc = "Clear search highlight", silent = true })

-- NvimTree escape
map("n", "<Esc>", function()
  if vim.bo.filetype == "NvimTree" then
    vim.cmd("wincmd l")
  end
end, { desc = "Exit NvimTree to main pane", silent = true })

-- Save and quit
map("n", "<Leader>w", "<cmd>w<CR>", { desc = "Save file" })
map("n", "<Leader>l", "<cmd>bdelete<CR>", { desc = "Close buffer" })
map("n", "<Leader>x", "<cmd>bdelete<CR>", { desc = "Close buffer" })
map("n", "<Leader>q", "<cmd>quit<CR>", { desc = "Quit" })
map("n", "<Leader>qq", "<cmd>qa!<CR>", { desc = "Force quit all" })

-- Telescope
map("n", "<Leader>ff", "<cmd>Telescope find_files<CR>", { desc = "Telescope find files" })
map("n", "<Leader>fa", "<cmd>Telescope find_files follow=true no_ignore=true hidden=true<CR>", { desc = "Telescope find all files" })
map("n", "<Leader>fw", "<cmd>Telescope live_grep<CR>", { desc = "Telescope live grep" })
map("n", "<Leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Telescope find buffers" })
map("n", "<Leader>fh", "<cmd>Telescope help_tags<CR>", { desc = "Telescope help page" })
map("n", "<Leader>fo", "<cmd>Telescope oldfiles<CR>", { desc = "Telescope find oldfiles" })
map("n", "<Leader>fz", "<cmd>Telescope current_buffer_fuzzy_find<CR>", { desc = "Telescope find in current buffer" })
map("n", "<Leader>cm", "<cmd>Telescope git_commits<CR>", { desc = "Telescope git commits" })
map("n", "<Leader>gt", "<cmd>Telescope git_status<CR>", { desc = "Telescope git status" })
map("n", "<Leader>ma", "<cmd>Telescope marks<CR>", { desc = "Telescope find marks" })

-- File and buffer operations
map("n", "<Leader>n", "<cmd>Telescope find_files<CR>", { desc = "Telescope find files" })

-- NvimTree
map("n", "<C-n>", "<cmd>NvimTreeToggle<CR>", { desc = "NvimTree toggle" })
map("n", "<Leader>e", "<cmd>NvimTreeFocus<CR>", { desc = "NvimTree focus" })

-- Comment
map("n", "<Leader>/", "gcc", { desc = "Toggle comment", remap = true })
map("v", "<Leader>/", "gc", { desc = "Toggle comment", remap = true })

-- Format
map({ "n", "x" }, "<Leader>fm", function()
  require("conform").format({ lsp_fallback = true })
end, { desc = "Format file" })

-- Split operations
map("n", "ts", "<cmd>split<CR>", { desc = "Horizontal split" })
map("n", "tv", "<cmd>vsplit<CR>", { desc = "Vertical split" })
map("n", "th", "<cmd>wincmd h<CR>", { desc = "Move to left split" })
map("n", "tl", "<cmd>wincmd l<CR>", { desc = "Move to right split" })
map("n", "tk", "<cmd>wincmd k<CR>", { desc = "Move to upper split" })
map("n", "tc", "<cmd>wincmd c<CR>", { desc = "Close current split" })
map("n", "tq", "<cmd>quit<CR>", { desc = "Quit split" })
map("n", "tx", "<cmd>quit<CR>", { desc = "Quit split" })

-- Config operations
map("n", "<Leader>vr", function()
  vim.cmd("source ~/.config/nvim/init.lua")
  print("Config reloaded!")
end, { noremap = true, silent = true, desc = "Reload config" })

map("n", "<Leader>vv", "<cmd>edit ~/.config/nvim/lua/config/keymaps.lua<CR>", { noremap = true, silent = true, desc = "Edit keymaps" })

-- LSP
map("n", "<Leader>b", "<cmd>lua vim.lsp.buf.definition()<CR>", { noremap = true, silent = true, desc = "Go to definition" })

-- Insert mode
map("i", "jk", "<ESC>", { desc = "Escape insert mode" })
map("i", "jj", "<ESC>", { desc = "Escape insert mode" })

-- Visual mode
map("v", "x", '"_x', { desc = "Delete without yanking" })
map("v", "p", '"_dP', { desc = "Paste without overwriting yank" })
