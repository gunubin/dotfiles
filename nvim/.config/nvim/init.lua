-- Load options first
require("config.options")

-- Bootstrap lazy.nvim and get config
local lazy_config = require("config.lazy")
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system({ "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- Setup lazy.nvim with plugins
require("lazy").setup({
  { import = "plugins" },
}, lazy_config)

-- Load autocmds
require("config.autocmds")

-- Load keymaps after plugins (deferred)
vim.schedule(function()
  require("config.keymaps")
end)
