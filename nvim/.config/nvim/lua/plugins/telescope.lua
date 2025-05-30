return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "MunifTanjim/nui.nvim", -- Layout/Popup 用
  },
  cmd = "Telescope", -- コマンド使用時に読み込む
  config = function()

    vim.api.nvim_set_hl(0, "TelescopePromptTitle", { fg = "#6ADFEE", bg = "" })
    vim.api.nvim_set_hl(0, "TelescopePromptCounter", { fg = "#686a82" })
    vim.api.nvim_set_hl(0, "TelescopePreviewTitle", { fg = "#93E59A" })
    vim.api.nvim_set_hl(0, "TelescopePreviewBorder", { fg = "#ff00ff", bg = "#123456" })

    local Layout = require("nui.layout")
    local Popup = require("nui.popup")
    local telescope = require("telescope")
    local TSLayout = require("telescope.pickers.layout")

    local function make_popup(options)
      local popup = Popup(options)
      function popup.border:change_title(title)
        local filename = title:match("([^/]+)$")
        if filename then
          popup.border.set_text(popup.border, "top", " " .. filename .. " ")
        else
          popup.border.set_text(popup.border, "top", title)
        end
      end
      return TSLayout.Window(popup)
    end

    local actions = require("telescope.actions")

    telescope.setup({
      defaults = {
        dynamic_preview_title = true,
        --layout_strategy = "flex",
        layout_strategy = "vertical",
        sorting_strategy = "ascending",
        prompt_prefix = " 󰍉 ",
        --selection_caret = " 󰁔 ",
        selection_caret = " 󰄾 ",
        entry_prefix = "　　",
        layout_config = {
          horizontal = {
            size = {
              width = "80%",
              height = "60%",
            },
          },
          vertical = {
            size = {
              width = "50%",
              height = "80%",
            },
          },
        },
        mappings = {
          i = {
            ["<Esc>"] = actions.close,
          },
          n = {
            ["<Esc>"] = actions.close,
          },
        },
        create_layout = function(picker)
          local border = {
            results = {
              top_left = "╭",
              top = "─",
              top_right = "┬",
              right = "│",
              bottom = "",
              bottom_right = "",
              bottom_left = "",
              left = "│",
            },
            results_patch = {
              minimal = { top_left = "╭", top_right = "╮" },
              horizontal = { top_left = "╭", top_right = "┬" },
              --vertical = { top_left = "├", top_right = "┤" },
              vertical = {
                top = "",
                top_left = "│",
                top_right = "│",
                bottom = "─",
                bottom_right = "╯",
                bottom_left = "╰",
              },
            },
            prompt = {
              top_left = "├",
              top = "─",
              top_right = "┤",
              right = "│",
              bottom = "─",
              bottom_right = "╯",
              bottom_left = "╰",
              left = "│",
            },
            prompt_patch = {
              minimal = { bottom_right = "╯" },
              horizontal = { bottom_right = "┴" },
              --vertical = { bottom_right = "╯" },
              vertical = {
                top_left = "╭",
                top = "─",
                top_right = "╮",
                right = "│",
                bottom_right = "",
                bottom = "",
                bottom_left = "",
                left = "│",
              },
            },
            preview = {
              top_left = "╭",
              top = "─",
              top_right = "╮",
              right = "│",
              bottom_right = "╯",
              bottom = "─",
              bottom_left = "╰",
              left = "│",
            },
            preview_patch = {
              minimal = {},
              horizontal = {
                bottom = "─",
                bottom_left = "",
                bottom_right = "╯",
                left = "",
                top_left = "",
              },
              vertical = {
                bottom = "─",
                bottom_left = "╰",
                bottom_right = "╯",
                left = "│",
                top_left = "╭",
              },
              --vertical = {},  -- ← これでOK

            },
          }

          local results = make_popup({
            focusable = false,
            border = {
              style = border.results,
              text = {
                top = picker.results_title,
                top_align = "center",
              },
            },
          })

          local prompt = make_popup({
            enter = true,
            border = {
              style = border.prompt,
              text = {
                top = " " .. picker.prompt_title .. " ",
                top_align = "center",
              },
            },
            win_options = {
              winhighlight = "FloatTitle:TelescopePromptTitle",
            },
          })

          local preview = make_popup({
            focusable = false,
            border = {
              style = border.preview,
              text = {
                top =  " " .. picker.preview_title .. " ",
                top_align = "center",
              },
            },
            win_options = {
              winhighlight = "FloatTitle:TelescopePreviewTitle",
            }
          })

          local spacer = make_popup({
            focusable = false,
            border = "none",
          })

          local box_by_kind = {
            vertical = Layout.Box({
              Layout.Box(prompt, { size = 1 }),
              --Layout.Box(spacer, { size = 1 }),
              Layout.Box(results, { grow = 1 }),
              Layout.Box(preview, { grow = 1 }),
            }, { dir = "col" }),
            horizontal = Layout.Box({
              Layout.Box({
                Layout.Box(results, { grow = 1 }),
                Layout.Box(prompt, { size = 3 }),
              }, { dir = "col", size = "50%" }),
              Layout.Box(preview, { size = "50%" }),
            }, { dir = "row" }),
            minimal = Layout.Box({
              Layout.Box(results, { grow = 1 }),
              Layout.Box(prompt, { size = 3 }),
            }, { dir = "col" }),
          }

          local function get_box()
            local strategy = picker.layout_strategy
            if strategy == "vertical" or strategy == "horizontal" then
              return box_by_kind[strategy], strategy
            end

            local height, width = vim.o.lines, vim.o.columns
            local box_kind = "horizontal"
            if width < 100 then
              box_kind = "vertical"
              if height < 40 then
                box_kind = "minimal"
              end
            end
            return box_by_kind[box_kind], box_kind
          end

          local function prepare_layout_parts(layout, box_type)
            layout.results = results
            results.border:set_style(border.results_patch[box_type])

            layout.prompt = prompt
            prompt.border:set_style(border.prompt_patch[box_type])

            if box_type == "minimal" then
              layout.preview = nil
            else
              layout.preview = preview
              preview.border:set_style(border.preview_patch[box_type])
            end
          end

          local function get_layout_size(box_kind)
            return picker.layout_config[box_kind == "minimal" and "vertical" or box_kind].size
          end

          local box, box_kind = get_box()
          local layout = Layout({
            relative = "editor",
            position = "50%",
            size = get_layout_size(box_kind),
          }, box)

          layout.picker = picker
          prepare_layout_parts(layout, box_kind)

          local layout_update = layout.update
          function layout:update()
            local box, box_kind = get_box()
            prepare_layout_parts(layout, box_kind)
            layout_update(self, { size = get_layout_size(box_kind) }, box)
          end

          return TSLayout(layout)
        end,
      },
    })
  end,
}