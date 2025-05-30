return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    preset = "helix",
  },
  config = function(_, opts)
    require("which-key").setup(opts)

    local colors = {
      lavender = "#b4befe",
      green = "#a6e3a1",
      mauve = "#cba6f7",
      overlay = "#9399b2",
      surface2 = "#585b70",
      base = "#1e1e2e",
      subtext = "#a6adc8",
      sky = "#89dceb",
      red = "#f38ba8",
      peach = "#fab387",
      yellow = "#f9e2af",
      teal = "#94e2d5",
      blue = "#89b4fa",
    }

    local set = vim.api.nvim_set_hl
    local function hl(name, opts) set(0, name, opts) end

    hl("WhichKey",         { fg = colors.lavender, bold = true })
    hl("WhichKeyGroup",    { fg = colors.mauve, italic = true })
    hl("WhichKeyDesc",     { fg = colors.green })
    hl("WhichKeySeparator",{ fg = colors.overlay })
    hl("WhichKeyBorder",   { fg = colors.surface2 })
    hl("WhichKeyTitle",    { fg = colors.sky, bold = true })
    hl("WhichKeyNormal",   { bg = colors.base })
    hl("WhichKeyValue",    { fg = colors.subtext, italic = true })

    hl("WhichKeyIcon",        { fg = colors.blue })
    hl("WhichKeyIconAzure",   { fg = colors.sky })
    hl("WhichKeyIconGreen",   { fg = colors.green })
    hl("WhichKeyIconGrey",    { fg = colors.overlay })
    hl("WhichKeyIconOrange",  { fg = colors.peach })
    hl("WhichKeyIconPurple",  { fg = colors.mauve })
    hl("WhichKeyIconRed",     { fg = colors.red })
    hl("WhichKeyIconYellow",  { fg = colors.yellow })
  end,
}

