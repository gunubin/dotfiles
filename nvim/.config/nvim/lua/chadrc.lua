-- This file needs to have same structure as nvconfig.lua 
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :( 

---@type ChadrcConfig
local M = {}

--   theme = "sweetpastel",
M.base46 = {
    theme = "sweetpastel",
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
    },
}

-- M.nvdash = { load_on_startup = true }
-- M.ui = {
--       tabufline = {
--          lazyload = false
--      }
-- }



return M
