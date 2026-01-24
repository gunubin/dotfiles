return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    signs = {
      add = { text = "│" },
      change = { text = "│" },
      delete = { text = "󰍵" },
      topdelete = { text = "‾" },
      changedelete = { text = "~" },
      untracked = { text = "│" },
    },
    signcolumn = true,
    numhl = false,
    linehl = false,
    word_diff = false,
    watch_gitdir = { interval = 1000 },
    attach_to_untracked = true,
    current_line_blame = false,
    current_line_blame_opts = {
      virt_text = true,
      virt_text_pos = "eol",
      delay = 1000,
      ignore_whitespace = false,
    },
    current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> - <summary>",
    sign_priority = 6,
    update_debounce = 100,
    status_formatter = nil,
    max_file_length = 40000,
    preview_config = {
      border = "rounded",
      style = "minimal",
      relative = "cursor",
      row = 0,
      col = 1,
    },
    on_attach = function(bufnr)
      local gs = package.loaded.gitsigns

      local function map(mode, l, r, opts)
        opts = opts or {}
        opts.buffer = bufnr
        vim.keymap.set(mode, l, r, opts)
      end

      -- Navigation
      map("n", "]g", function()
        if vim.wo.diff then
          return "]g"
        end
        vim.schedule(function()
          gs.next_hunk()
        end)
        return "<Ignore>"
      end, { expr = true, desc = "Next git hunk" })

      map("n", "[g", function()
        if vim.wo.diff then
          return "[g"
        end
        vim.schedule(function()
          gs.prev_hunk()
        end)
        return "<Ignore>"
      end, { expr = true, desc = "Previous git hunk" })

      -- Actions
      map("n", "<leader>gs", gs.stage_hunk, { desc = "Stage hunk" })
      map("n", "<leader>gr", gs.reset_hunk, { desc = "Reset hunk" })
      map("v", "<leader>gs", function()
        gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, { desc = "Stage hunk" })
      map("v", "<leader>gr", function()
        gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, { desc = "Reset hunk" })
      map("n", "<leader>gS", gs.stage_buffer, { desc = "Stage buffer" })
      map("n", "<leader>gu", gs.undo_stage_hunk, { desc = "Undo stage hunk" })
      map("n", "<leader>gR", gs.reset_buffer, { desc = "Reset buffer" })
      map("n", "<leader>gp", gs.preview_hunk, { desc = "Preview hunk" })
      map("n", "<leader>gb", function()
        gs.blame_line({ full = true })
      end, { desc = "Blame line" })
      map("n", "<leader>gd", gs.diffthis, { desc = "Diff this" })
      map("n", "<leader>gD", function()
        gs.diffthis("~")
      end, { desc = "Diff this ~" })

      -- Text object
      map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "Select git hunk" })
    end,
  },
}
