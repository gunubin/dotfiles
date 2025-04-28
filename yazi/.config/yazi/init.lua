require("bunny"):setup({
  hops = {
    { key = { "h", "h" }, path = "~",              desc = "Home"         },
    { key = { "h", "d" }, path = "~/Documents",    desc = "Documents"    },
    { key = { "h", "k" }, path = "~/Desktop",      desc = "Desktop"      },
    { key = "c",          path = "~/.config",      desc = "Config files" },
    { key = "w",          path = "~/works",      desc = "Working Directory" },
    -- key and path attributes are required, desc is optional
  },
  desc_strategy = "path", -- If desc isn't present, use "path" or "filename", default is "path"
  notify = false, -- Notify after hopping, default is false
  fuzzy_cmd = "fzf", -- Fuzzy searching command, default is "fzf"
})
