return {
    "gen740/SmoothCursor.nvim",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
        require("smoothcursor").setup({
            type = "default",           -- カーソルタイプ（default/exp/matrix）
            autostart = true,           -- 自動的に開始
            cursor = "█",               -- カーソルの文字
            intervals = 35,             -- アニメーション間隔
            linehl = nil,               -- ラインハイライト名
            priority = 10,              -- ハイライト優先度
            speed = 25,                 -- カーソル移動の速度
            threshold = 3,              -- カーソル移動の閾値
            texthl = "SmoothCursor",    -- テキストハイライト名
            fancy = {
                enable = true,            -- enable fancy mode
                head = { cursor = "▷", texthl = "SmoothCursor", linehl = nil }, -- false to disable fancy head
                body = {
                    { cursor = "󰝥", texthl = "SmoothCursorPastelRed" },
                    { cursor = "󰝥", texthl = "SmoothCursorPastelOrange" },
                    { cursor = "●", texthl = "SmoothCursorPastelYellow" },
                    { cursor = "●", texthl = "SmoothCursorPastelGreen" },
                    { cursor = "•", texthl = "SmoothCursorPastelAqua" },
                    { cursor = ".", texthl = "SmoothCursorPastelBlue" },
                    { cursor = ".", texthl = "SmoothCursorPastelPurple" },
                },
            },
            flyin_effect = nil,         -- フライインエフェクト（none/top/bottom/left/right）
            matrix = {
                head = {
                    fg = "#8ced72",         -- マトリックスヘッド色
                    bold = true,
                },
                body = {
                    fg = "#8ced72",         -- マトリックスボディ色
                    blend = 50,
                },
            },
        })

        -- パステルカラーのハイライトグループを設定
        vim.api.nvim_set_hl(0, 'SmoothCursor', { fg = '#9bd5f2' })          -- sapphire
        vim.api.nvim_set_hl(0, 'SmoothCursorPastelRed', { fg = '#f485ad' })  -- red
        vim.api.nvim_set_hl(0, 'SmoothCursorPastelOrange', { fg = '#fabeab' }) -- peach
        vim.api.nvim_set_hl(0, 'SmoothCursorPastelYellow', { fg = '#f9e1aa' }) -- yellow
        vim.api.nvim_set_hl(0, 'SmoothCursorPastelGreen', { fg = '#bfe7bb' }) -- green
        vim.api.nvim_set_hl(0, 'SmoothCursorPastelAqua', { fg = '#ace7e0' })  -- teal
        vim.api.nvim_set_hl(0, 'SmoothCursorPastelBlue', { fg = '#b0cbfa' })  -- blue
        vim.api.nvim_set_hl(0, 'SmoothCursorPastelPurple', { fg = '#c8d1fa' }) -- lavender
    end,
}