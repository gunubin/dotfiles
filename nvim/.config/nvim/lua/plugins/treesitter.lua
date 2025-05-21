return {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = {
        "nvim-treesitter/nvim-treesitter-textobjects",
    },
    config = function()
        require("nvim-treesitter.configs").setup({
            -- TreeSitterの構文解析用モジュールをインストール
            ensure_installed = {
                "lua", "vim", "vimdoc", "query", -- Neovim関連
                "bash", "fish", -- シェル
                "c", "cpp", "rust", "go", "python", "javascript", "typescript", -- 一般的なプログラミング言語
                "html", "css", "json", "yaml", "toml", "markdown", "markdown_inline", -- マークアップ/設定
                -- 必要に応じて他の言語を追加
            },

            -- モジュールの自動インストール
            auto_install = true,

            -- シンタックスハイライト設定
            highlight = {
                enable = true,
                additional_vim_regex_highlighting = false,
            },

            -- インデント設定
            indent = {
                enable = true,
            },

            -- インクリメンタル選択設定（Flash.nvimと連携する基本機能）
            incremental_selection = {
                enable = true,
                keymaps = {
                    init_selection = "<C-space>", -- 選択開始
                    node_incremental = "<C-space>", -- 選択拡大
                    scope_incremental = "<nop>", -- スコープ選択
                    node_decremental = "<bs>", -- 選択縮小
                },
            },

            -- テキストオブジェクト設定（Flash.nvimのTreeSitter機能向け）
            textobjects = {
                select = {
                    enable = true,
                    lookahead = true,
                    keymaps = {
                        -- 基本的なテキストオブジェクト
                        ["af"] = "@function.outer",
                        ["if"] = "@function.inner",
                        ["ac"] = "@class.outer",
                        ["ic"] = "@class.inner",
                        ["aa"] = "@parameter.outer",
                        ["ia"] = "@parameter.inner",
                        ["ab"] = "@block.outer",
                        ["ib"] = "@block.inner",
                        ["al"] = "@loop.outer",
                        ["il"] = "@loop.inner",
                        ["ai"] = "@conditional.outer",
                        ["ii"] = "@conditional.inner",
                        ["ak"] = "@comment.outer",
                        ["ik"] = "@comment.inner",
                    },
                },

                -- Flash.nvimで移動する際に便利なオプション
                move = {
                    enable = true,
                    set_jumps = true, -- jumplistに登録
                    goto_next_start = {
                        ["]m"] = "@function.outer",
                        ["]]"] = "@class.outer",
                    },
                    goto_next_end = {
                        ["]M"] = "@function.outer",
                        ["]["] = "@class.outer",
                    },
                    goto_previous_start = {
                        ["[m"] = "@function.outer",
                        ["[["] = "@class.outer",
                    },
                    goto_previous_end = {
                        ["[M"] = "@function.outer",
                        ["[]"] = "@class.outer",
                    },
                },
            },
        })

        -- TreeSitterフォールディング設定（オプション）
        vim.opt.foldmethod = "expr"
        vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
        vim.opt.foldenable = false -- 初期状態でフォールディングを無効化
    end,
}