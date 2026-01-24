return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  lazy = false,
  opts = {
    flavour = "mocha",
    transparent_background = true,
    term_colors = true,
    styles = {
      comments = { "italic" },
      conditionals = { "italic" },
    },
    integrations = {
      cmp = true,
      gitsigns = true,
      nvimtree = true,
      treesitter = true,
      notify = true,
      mini = true,
      flash = true,
      indent_blankline = { enabled = true },
      native_lsp = {
        enabled = true,
        underlines = {
          errors = { "undercurl" },
          hints = { "undercurl" },
          warnings = { "undercurl" },
          information = { "undercurl" },
        },
      },
      telescope = { enabled = true },
      which_key = true,
    },
    custom_highlights = function(colors)
      return {
        Visual = { bg = "#4F5168" },
        Comment = { fg = "#666775", style = { "italic" } },
        ["@comment"] = { fg = "#666775", style = { "italic" } },
        NvimTreeWinSeparator = { fg = "#4B6076" },
        WinSeparator = { fg = "#4B6076" },
        LineNr = { fg = "#686a82" },
        CursorLine = { bg = "#52546a" },
        CursorLineNr = { fg = "#ffb7ff", style = { "bold" } },

        -- nvim-cmp
        CmpBorder = { fg = "#6ADFEE" },
        CmpDocBorder = { fg = "#6ADFEE" },

        -- Pmenu (built-in completion)
        Pmenu = { bg = "#2a2a2a", fg = "#ffffff" },
        PmenuSel = { bg = "#4F5168", fg = "#ffffff" },
        PmenuSbar = { bg = "#3a3a3a" },
        PmenuThumb = { bg = "#6ADFEE" },
        FloatBorder = { fg = "#6ADFEE" },
      }
    end,
  },
  config = function(_, opts)
    require("catppuccin").setup(opts)
    vim.cmd.colorscheme("catppuccin")
  end,
}
