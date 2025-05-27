return {
  "folke/flash.nvim",
  event = "VeryLazy",

  opts = {
    label = {
      -- ラベルの外観設定
      current = true,     -- 現在位置のラベルを表示
      before = false,     -- カーソル前のラベル位置
      after = true,       -- カーソル後のラベル位置
      style = "overlay",  -- ラベルのスタイル: overlay | inline
    },
    --search = {
      -- 検索設定
      --wrap = true,        -- 検索時に折り返す
      --incremental = true, -- インクリメンタル検索を有効
    --},
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
    { "e", mode = { "n" }, function() require("flash").jump({
      search = {
        multi_window = false,
      },
    }) end, desc = "Flash" },
    { ";", mode = { "n" }, function() require("flash").jump({ continue = true }) end, desc = "Flash Continue" },
    { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
    { "t", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
    { "T", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },

  }
}
