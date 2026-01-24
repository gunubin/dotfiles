return {
  -- hlchunk (indent guides)
  {
    "shellRaining/hlchunk.nvim",
    event = { "UIEnter" },
    config = function()
      require("hlchunk").setup({
        chunk = {
          enable = true,
          style = {
            { fg = "#86abdc" },
          },
        },
        indent = {
          enable = true,
          style = {
            { fg = "#47495B" },
          },
        },
        line_num = {
          enable = true,
          style = {
            { fg = "#8DBCC7" },
          },
        },
        blank = {
          enable = false,
        },
      })
    end,
  },

  -- vim-indent-object
  {
    "michaeljsmith/vim-indent-object",
    event = "VeryLazy",
  },

  -- Comment.nvim
  {
    "numToStr/Comment.nvim",
    keys = {
      { "gcc", mode = "n", desc = "Toggle comment line" },
      { "gc", mode = { "n", "v" }, desc = "Toggle comment" },
    },
    config = true,
  },

  -- Todo comments
  {
    "folke/todo-comments.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
  },
}
