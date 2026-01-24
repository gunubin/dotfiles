return {
    "b0o/incline.nvim",
    event = "VeryLazy",
    dependencies = {
        "nvim-tree/nvim-web-devicons",
        "lewis6991/gitsigns.nvim",
    },
    config = function()
        local devicons = require("nvim-web-devicons")

        -- アイコンが確実に読み込まれているか確認
        if not devicons.has_loaded() then
            devicons.setup()
        end

        require("incline").setup({
            window = {
                margin = { vertical = 0, horizontal = 1 },
                padding = { left = 1, right = 1 },
                placement = { vertical = "top", horizontal = "right" },
                zindex = 50,
            },
            render = function(props)
                local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ":t")
                local ft_icon, ft_color = devicons.get_icon_color(filename)
                local modified = vim.bo[props.buf].modified and 'bold,italic' or 'bold'

                local function get_git_diff()
                    local icons = { removed = "", changed = "", added = "" }
                    icons["changed"] = icons.modified
                    local signs = vim.b[props.buf].gitsigns_status_dict
                    local labels = {}
                    if signs == nil then return labels end
                    for name, icon in pairs(icons) do
                        if tonumber(signs[name]) and signs[name] > 0 then
                            table.insert(labels, { icon .. signs[name] .. " ", group = "Diff" .. name })
                        end
                    end
                    if #labels > 0 then table.insert(labels, { "┊ " }) end
                    return labels
                end

                local function get_diagnostic_label()
                    local icons = { error = '', warn = '', info = '', hint = '󰌵' }
                    local label = {}

                    for severity, icon in pairs(icons) do
                        local n = #vim.diagnostic.get(
                                props.buf,
                                { severity = vim.diagnostic.severity[string.upper(severity)] }
                        )
                        if n > 0 then
                            table.insert(label, { icon .. n .. " ", group = "DiagnosticSign" .. severity })
                        end
                    end
                    if #label > 0 then table.insert(label, { "┊ " }) end
                    return label
                end

                -- アイコンが見つからない場合のフォールバック
                if not ft_icon then
                    -- 拡張子に基づいてデフォルトのアイコンを設定
                    local ext = vim.fn.fnamemodify(filename, ":e")
                    if ext and ext ~= "" then
                        ft_icon, ft_color = devicons.get_icon_color_by_extension(ext)
                    end

                    -- それでも見つからない場合はデフォルトアイコンを設定
                    if not ft_icon then
                        ft_icon = ""
                        ft_color = "#6d8086"  -- デフォルトの灰色
                    end
                end

                local buffer = {
                    { get_diagnostic_label() },
                    { get_git_diff() },
                    { (ft_icon or "") .. " ", guifg = ft_color, guibg = "none" },
                    { filename .. " ", gui = modified },
                    --{ "┊   " .. vim.api.nvim_win_get_number(props.win), group = "DevIconWindows" },
                }
                return buffer
            end,
            hide = {
                cursorline = true,
                focused_win = false,
                only_win = false,
            },
        })

        -- DevIconWindows用のハイライトグループ定義
        vim.api.nvim_set_hl(0, "DevIconWindows", { fg = "#7aa2f7", bold = true })
    end,
}