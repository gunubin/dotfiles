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
    search = {
      -- 検索設定
      wrap = true,        -- 検索時に折り返す
      incremental = true, -- インクリメンタル検索を有効
    },
    jump = {
      -- ジャンプ設定
      autojump = true,    -- 一意のマッチに自動ジャンプ
    },
    modes = {
      char = {
        enabled = false,  -- デフォルトのfキー拡張を無効化
      },
    },
  },
  keys = {
    { "f", mode = { "n", "x", "o" }, function() require("flash").jump({
      search = {
        multi_window = false,
      },
    }) end, desc = "Flash" },
    { "t", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
    { "T", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },

  }
}
