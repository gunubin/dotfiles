return {
  "folke/flash.nvim",
  event = "VeryLazy",

  opts = {
    label = {
      rainbow = {
        enabled = true,
        shade = 3,
      }
    },
    jump = {
      autojump = true,    -- 一意のマッチに自動ジャンプ
    },
    modes = {
      char = {
        enabled = true,   -- デフォルトのfキー拡張を有効化
        keys = { "f", "F" }, -- fとFのみを拡張対象にする
      },
    },
  },
  keys = {
    -- { "e", mode = { "n", "x", "o" }, function() require("flash").jump({
    { "s", mode = { "n" }, function() require("flash").jump({
      search = {
        multi_window = false,
      },
    }) end, desc = "Flash" },
    { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
    { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
    { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
    { "<c-r>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
    { ";", mode = { "n" }, function() require("flash").jump({ continue = true }) end, desc = "Flash Continue" },

    --{ "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
    --{ "t", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
    --{ "T", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
  }
}
