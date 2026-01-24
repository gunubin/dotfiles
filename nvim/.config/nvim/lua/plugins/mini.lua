return {
  -- mini.ai
  {
    "echasnovski/mini.ai",
    version = false,
    event = "VeryLazy",
    config = function()
      require("mini.ai").setup({
        custom_textobjects = nil,
        mappings = {
          around = "a",
          inside = "i",
          around_next = "an",
          inside_next = "in",
          around_last = "al",
          inside_last = "il",
          goto_left = "g[",
          goto_right = "g]",
        },
        n_lines = 50,
        search_method = "cover_or_next",
        silent = false,
      })
    end,
  },

  -- mini.animate
  {
    "echasnovski/mini.animate",
    event = "VeryLazy",
    config = function()
      require("mini.animate").setup({
        cursor = {
          enable = true,
          timing = function(_, n)
            return 300 / n
          end,
          path = require("mini.animate").gen_path.line(),
        },
        scroll = {
          enable = false,
        },
      })
    end,
  },

  -- mini.surround
  {
    "echasnovski/mini.surround",
    event = "VeryLazy",
    opts = {
      mappings = {
        add = "sa",
        delete = "sd",
        find = "sf",
        find_left = "sF",
        highlight = "sh",
        replace = "sr",
        update_n_lines = "sn",
      },
    },
  },
}
