-- This file needs to have same structure as nvconfig.lua 
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :( 

---@type ChadrcConfig
local M = {}

--   theme = "catppuccin",
M.base46 = {
    theme = "catppuccin",
    transparency = true,

    hl_override = {
        Visual = { bg = "#4F5168" },
        Comment = { italic = true, fg = "#666775" },
        ["@comment"] = { italic = true, fg = "#666775" },
        NvimTreeWinSeparator = { fg = "#4B6076" },
        WinSeparator = { fg = "#4B6076" },
        LineNr = { fg = "#686a82" },
        CursorLine = { bg = "#52546a" },
        CursorLineNr = { fg = "#ffb7ff", bold = true },

        -- nvim-comp
        CmpBorder = { fg = "#6ADFEE" },
        CmpDocBorder = { fg = "#6ADFEE" },

        -- Ctrl+N/Ctrl+Pの組み込み補完メニューのborder
        Pmenu = { bg = "#2a2a2a", fg = "#ffffff" },  -- メニューの背景と文字色
        PmenuSel = { bg = "#4F5168", fg = "#ffffff" },  -- 選択項目の背景と文字色
        PmenuSbar = { bg = "#3a3a3a" },  -- スクロールバーの背景
        PmenuThumb = { bg = "#6ADFEE" },  -- スクロールバーのつまみ
        FloatBorder = { fg = "#6ADFEE" },  -- フローティングウィンドウのborder（組み込み補完用）

    },
}

-- M.nvdash = { load_on_startup = true }
-- M.ui = {
--       tabufline = {
--          lazyload = false
--      }
-- }



return M
