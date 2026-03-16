# bufindicator.nvim

[English](README.md) | [简体中文](README.zh-CN.md)

在切换 Buffer 时显示一个短暂的浮动列表，突出当前 Buffer，帮助你快速确认当前位置。

## 特性

- 基于 `BufEnter` 自动显示，无需手动触发
- 两种展示模式：`dynamic` / `static`
- 支持左/中/右三种位置
- 支持当前项左右图标、普通项前缀
- 支持名称格式化（文件名、相对路径、自定义函数）
- 默认关闭滚动动画（可手动开启）

## 安装

### lazy.nvim

```lua
{
  "luckyPtr/bufindicator.nvim",
  config = function()
    require("bufindicator").setup()
  end,
}
```

### vim.pack（Neovim 0.12+）

```lua
vim.pack.add({
  "https://github.com/luckyPtr/bufindicator.nvim",
})

require("bufindicator").setup()
```

### packpath（`pack/*/start`）

把仓库放到 `pack/*/start/` 下即可自动加载。

## 快速开始

```lua
require("bufindicator").setup({
  mode = "dynamic", -- 或 "static"
})
```

如果不调用 `setup()`，插件会使用默认配置。

## 手动触发

```lua
require("bufindicator").open()
require("bufindicator").close()
```

使用 `open()` 可以在不切换 Buffer 的情况下主动显示指示器。
如果指示器已经显示，再次调用 `open()` 会重置自动关闭计时。
使用 `close()` 可以立即关闭指示器。

## 默认配置

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
  animate = false,      -- 仅 dynamic 模式生效
  animate_duration = 200,
  border = "rounded", -- 仅 static 模式生效
})
```

## 配置说明

- `mode`
  - `dynamic`：窗口跟随高亮项移动（可选动画），无边框
  - `static`：窗口固定，仅高亮变化，支持边框
- `timeout`：浮窗自动关闭时间（毫秒）；设为 `false` 表示不自动关闭（`0` 表示立即关闭）
- `format`
  - `"filename"`：仅显示文件名
  - `"relative"`：显示相对路径（`~` / 当前工作目录）
  - `function(raw_name)`：自定义显示文本
- `position`：`right`（右对齐）、`left`、`center`（内容左对齐）
- `animate`：是否启用跨多项切换时的滚动动画（仅 `dynamic`）
- `border`：`static` 模式边框样式（`none/single/double/rounded/solid/shadow`）或自定义边框表

## 高亮组

插件会在未自定义时提供以下默认高亮：

- `BufIndicatorCurrent`
- `BufIndicatorOther`
- `BufIndicatorNormal`
- `BufIndicatorBorder`

覆盖示例：

```lua
vim.api.nvim_set_hl(0, "BufIndicatorCurrent", { bold = true, fg = "#ffffff" })
vim.api.nvim_set_hl(0, "BufIndicatorOther", { fg = "#7f8490" })
```

## 行为说明

- 仅显示已加载且可列出的普通 Buffer
- 特殊缓冲区（`nofile` / `prompt` / `terminal`）不会触发显示
- 当 Buffer 数量少于 2 时不显示浮窗
