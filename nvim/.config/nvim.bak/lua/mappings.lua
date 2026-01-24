require "nvchad.mappings"

local map = vim.keymap.set
local nomap = vim.keymap.del

-- 標準設定変更・削除
nomap("n", "<tab>") -- <tab>解除（Ctrl+i有効化）

-- モード共通のマッピング
map({ "n", "v" }, "<C-a>", "^", { desc = "Move to line start" })
map({ "n", "v" }, "<C-e>", "$", { desc = "Move to line end" })
map({ "n", "v" }, "H", "^", { desc = "Move to line start" })
map({ "n", "v" }, "L", "$", { desc = "Move to line end" })

-- ノーマルモード
map("n", "vv", "V", { desc = "Select whole line" })
map("n", "<CR>", "i<CR><ESC>", { desc = "Insert new line" })
map("n", "+", "<C-a>", { desc = "Increment number" })
map("n", "-", "<C-x>", { desc = "Decrement number" })
map("n", "x", '"_x', { desc = "Delete without yanking" })
map("n", "<C-j>", ":bn<CR>", { desc = "Next buffer" })
map("n", "<C-k>", ":bp<CR>", { desc = "Previous buffer" })
map("n", "<C-l>", ":bd<CR>", { desc = "Close buffer" })

map("n", "<C-d>", "<C-d>zz", { desc = "Scroll half-page down and center" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll half-page up and center" })
map("n", "<C-f>", "<C-f>zz", { desc = "Scroll half-page down and center" })

-- Escキー2回押しで検索ハイライトを消す
map("n", "<Esc><Esc>", ":nohl<CR>", { desc = "Clear search highlight", silent = true })

-- NvimTreeがロードされた後にグローバルEscマッピングも設定
map("n", "<Esc>", function()
  if vim.bo.filetype == "NvimTree" then
    vim.cmd("wincmd l")
  end
end, { desc = "Exit NvimTree to main pane", silent = true })

-- 保存・終了
map("n", "<Leader>w", ":w<CR>", { desc = "Save file" })
map("n", "<Leader>l", ":bd<CR>", { desc = "Close buffer" })
map("n", "<Leader>x", ":x<CR>", { desc = "Save and quit" })
map("n", "<Leader>q", ":quit<CR>", { desc = "Quit" })
map("n", "<Leader>qq", ":qa!<CR>", { desc = "Force quit all" })

-- ファイル・バッファ操作
map("n", "<Leader>n", "<cmd>Telescope find_files<cr>", { desc = "Telescope find files" })
map("n", "<Leader>.", function()
  require("nvchad.tabufline").next()
end, { desc = "Buffer goto next" })
map("n", "<Leader>,", function()
  require("nvchad.tabufline").prev()
end, { desc = "Buffer goto prev" })
map("n", "<Leader>x", function()
  require("nvchad.tabufline").close_buffer()
end, { desc = "Buffer close" })

-- スプリット操作
map("n", "ts", "<cmd>split<CR>", { desc = "Horizontal split" })
map("n", "tv", "<cmd>vsplit<CR>", { desc = "Vertical split" })
map("n", "th", "<cmd>wincmd h<CR>", { desc = "Move to left split" })
map("n", "tl", "<cmd>wincmd l<CR>", { desc = "Move to right split" })
map("n", "tk", "<cmd>wincmd k<CR>", { desc = "Move to upper split" })
map("n", "tc", "<cmd>wincmd c<CR>", { desc = "Close current split" })
map("n", "tq", "<cmd>quit<CR>", { desc = "Quit split" })
map("n", "tx", "<cmd>quit<CR>", { desc = "Quit split" })

-- コンフィグ操作
map("n", "<Leader>vr", function()
  vim.cmd("source ~/.config/nvim/init.lua")
  print("✅ config reloaded!")
  require('base46').load_all_highlights()
end, { noremap = true, silent = true, desc = "Reload config" })

nomap("n", "<Leader>v") -- 既存の <Leader>v を削除
map("n", "<Leader>vv", "<cmd>edit ~/.config/nvim/lua/mappings.lua<CR>", { noremap = true, silent = true, desc = "Edit mappings" })

-- LSP 定義ジャンプ
map("n", "<Leader>b", "<cmd>lua vim.lsp.buf.definition()<CR>", { noremap = true, silent = true, desc = "Go to definition" })

-- インサートモード
map("i", "jk", "<ESC>", { desc = "Escape insert mode" })
map("i", "jj", "<ESC>", { desc = "Escape insert mode" })

-- ビジュアルモード
map("v", "x", '"_x', { desc = "Delete without yanking" })
map("v", "p", '"_dP', { desc = "Paste without overwriting yank" })