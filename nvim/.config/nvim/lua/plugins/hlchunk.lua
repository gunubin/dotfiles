return {
    "shellRaining/hlchunk.nvim",
    event = { "UIEnter" },
    config = function()
        require("hlchunk").setup({
            -- デフォルト設定を使用するか、お好みに合わせてカスタマイズ
            chunk = {
                enable = true,
                style = {
                    { fg = "#86abdc" },
                },
            },
            indent = {
                enable = false, -- 既存のインデントラインがある場合はfalseに設定
            },
            line_num = {
                enable = true,
            },
            blank = {
                enable = false,
            },
        })
    end,
}