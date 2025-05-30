return {
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
}