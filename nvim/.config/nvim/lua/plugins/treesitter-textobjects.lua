return {
    "nvim-treesitter/nvim-treesitter-textobjects",
    dependencies = {
        "nvim-treesitter/nvim-treesitter",
    },
    event = { "BufReadPost", "BufNewFile" },
    config = function()
        require("nvim-treesitter.configs").setup({
            textobjects = {
                select = {
                    enable = true,
                    lookahead = true, -- 自動で次の一致へ移動する
                    keymaps = {
                        -- 以下のキーマップはa(round)/i(nner)の規則に従います
                        ["af"] = "@function.outer",
                        ["if"] = "@function.inner",
                        ["ac"] = "@class.outer",
                        ["ic"] = "@class.inner",
                        ["aa"] = "@parameter.outer",
                        ["ia"] = "@parameter.inner",
                        ["av"] = "@variable.outer",
                        ["iv"] = "@variable.inner",
                        ["ai"] = "@conditional.outer",
                        ["ii"] = "@conditional.inner",
                        ["al"] = "@loop.outer",
                        ["il"] = "@loop.inner",
                        --["ab"] = "@block.outer",
                        --["ib"] = "@block.inner",
                        ["as"] = "@statement.outer",
                        ["is"] = "@statement.inner",
                        ["am"] = "@comment.outer",
                        ["im"] = "@comment.inner",
                        ["ar"] = "@return.outer",
                        ["ir"] = "@return.inner",
                    },
                    selection_modes = {
                        ['@parameter.outer'] = 'v', -- charwise
                        ['@function.outer'] = 'V', -- linewise
                        ['@class.outer'] = 'V', -- linewise
                    },
                    include_surrounding_whitespace = false,
                },
                swap = {
                    enable = true,
                    swap_next = {
                        ["<leader>a"] = "@parameter.inner",
                        ["<leader>f"] = "@function.outer",
                        ["<leader>b"] = "@block.outer",
                    },
                    swap_previous = {
                        ["<leader>A"] = "@parameter.inner",
                        ["<leader>F"] = "@function.outer",
                        ["<leader>B"] = "@block.outer",
                    },
                },
                move = {
                    enable = true,
                    set_jumps = true, -- jumplistに追加する
                    goto_next_start = {
                        ["]f"] = "@function.outer",
                        ["]c"] = "@class.outer",
                        ["]i"] = "@conditional.outer",
                        ["]l"] = "@loop.outer",
                        ["]b"] = "@block.outer",
                        ["]a"] = "@parameter.inner",
                        ["]m"] = "@comment.outer",
                    },
                    goto_next_end = {
                        ["]F"] = "@function.outer",
                        ["]C"] = "@class.outer",
                        ["]I"] = "@conditional.outer",
                        ["]L"] = "@loop.outer",
                        ["]B"] = "@block.outer",
                        ["]M"] = "@comment.outer",
                    },
                    goto_previous_start = {
                        ["[f"] = "@function.outer",
                        ["[c"] = "@class.outer",
                        ["[i"] = "@conditional.outer",
                        ["[l"] = "@loop.outer",
                        ["[b"] = "@block.outer",
                        ["[a"] = "@parameter.inner",
                        ["[m"] = "@comment.outer",
                    },
                    goto_previous_end = {
                        ["[F"] = "@function.outer",
                        ["[C"] = "@class.outer",
                        ["[I"] = "@conditional.outer",
                        ["[L"] = "@loop.outer",
                        ["[B"] = "@block.outer",
                        ["[M"] = "@comment.outer",
                    },
                },
                lsp_interop = {
                    enable = true,
                    border = 'rounded',
                    floating_preview_opts = {},
                    peek_definition_code = {
                        ["<leader>df"] = "@function.outer",
                        ["<leader>dF"] = "@class.outer",
                    },
                },
            },
        })
    end,
}