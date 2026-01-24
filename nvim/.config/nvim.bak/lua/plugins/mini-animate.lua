return {
    "echasnovski/mini.animate",
    event = "VeryLazy",
    config = function()
        require('mini.animate').setup({
            cursor = {
                enable = true,
                timing = function(_, n) return 300 / n end,
                path = require('mini.animate').gen_path.line(),
            },
            scroll = {
                enable = false,
            }
        })
    end
}