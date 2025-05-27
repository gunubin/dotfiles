-- This file needs to have same structure as nvconfig.lua 
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :( 

---@type ChadrcConfig
 local M = {}

--   theme = "sweetpastel",
M.base46 = {
  theme = "sweetpastel",
  transparency = false,

	 hl_override = {
	 	--Comment = { italic = true, fg ="#7e8092" },
	 	--["@comment"] = { italic = true, fg ="#7e8092" },
        Visual = { bg = "#686a82" },
        --- `LineNr` - 通常の行番号の色
        --- `CursorLineNr` - カーソルがある行の行番号の色
        --- `LineNrAbove` - カーソル行より上の行番号の色（オプション）
        --- `LineNrBelow` - カーソル行より下の行番号の色（オプション）
        --LineNr = { fg = "#686a82" },
        --CursorLineNr = { bold = true },
    },
}

-- M.nvdash = { load_on_startup = true }
-- M.ui = {
--       tabufline = {
--          lazyload = false
--      }
-- }



return M
