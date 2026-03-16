# bufindicator.nvim

[English](README.md) | [简体中文](README.zh-CN.md)

Show a short floating buffer list on `BufEnter`, with the current buffer highlighted so you can quickly confirm where you are.

## Features

- Automatically shows on buffer switch (`BufEnter`)
- Two display modes: `dynamic` and `static`
- Position options: `right`, `left`, `center`
- Custom current-item icons and non-current prefix
- Name formatting: filename, relative path, or custom function
- Scroll animation is **disabled by default** (can be enabled manually)

## Installation

### lazy.nvim

```lua
{
  "luckyPtr/bufindicator.nvim",
  config = function()
    require("bufindicator").setup()
  end,
}
```

### vim.pack (Neovim 0.12+)

```lua
vim.pack.add({
  "https://github.com/luckyPtr/bufindicator.nvim",
})

require("bufindicator").setup()
```

### packpath (`pack/*/start`)

Place this repository under `pack/*/start/` and it will load automatically.

## Quick Start

```lua
require("bufindicator").setup({
  mode = "dynamic", -- or "static"
})
```

If `setup()` is not called, the plugin falls back to default settings.

## Manual Trigger

```lua
require("bufindicator").open()
require("bufindicator").close()
```

Use `open()` to show the indicator even when you did not switch buffers.
If the indicator is already visible, calling `open()` resets its auto-close timer.
Use `close()` to hide the indicator immediately.

## Default Configuration

```lua
require("bufindicator").setup({
  mode = "dynamic",
  timeout = 2000,      -- number | false
  width = 30,
  hl_current = "BufIndicatorCurrent",
  hl_other = "BufIndicatorOther",
  padding = 1,
  max_height = nil,
  winblend = 0,
  format = "filename", -- "filename" | "relative" | function(raw_name) -> string
  position = "right", -- "right" | "left" | "center"
  current_icon_left = "",
  current_icon_right = "",
  other_prefix = "  ",
  animate = false,      -- dynamic mode only
  animate_duration = 200,
  border = "rounded", -- static mode only
})
```

## Configuration Notes

- `mode`
  - `dynamic`: window follows the highlighted buffer (optional animation), no border
  - `static`: window stays fixed and only highlight moves, supports border
- `timeout`: auto-close delay in milliseconds; set to `false` to disable auto-close (`0` means close immediately)
- `format`
  - `"filename"`: file name only
  - `"relative"`: relative path (`~` / cwd-aware)
  - `function(raw_name)`: custom formatter
- `position`: `right` (right-aligned), `left`, `center` (left-aligned content)
- `animate`: enable scroll animation for long jumps (dynamic mode only)
- `border`: static mode border style (`none/single/double/rounded/solid/shadow`) or custom border table

## Highlight Groups

Default highlight groups are defined only if you have not set them:

- `BufIndicatorCurrent`
- `BufIndicatorOther`
- `BufIndicatorNormal`
- `BufIndicatorBorder`

Example override:

```lua
vim.api.nvim_set_hl(0, "BufIndicatorCurrent", { bold = true, fg = "#ffffff" })
vim.api.nvim_set_hl(0, "BufIndicatorOther", { fg = "#7f8490" })
```

## Behavior

- Only listed, loaded buffers are shown
- Special buffers (`nofile`, `prompt`, `terminal`) are ignored
- Popup is not shown when fewer than 2 buffers are available
