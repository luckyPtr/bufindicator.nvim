local window = require("bufindicator.window")

local M = {}

--- Default configuration
local defaults = {
  -- Display mode:
  --   "dynamic" - window moves so the current buffer is vertically centered,
  --               supports scroll animation, no border
  --   "static"  - window stays fixed, only highlight moves,
  --               supports border, ignores animate/animate_duration
  mode = "dynamic",
  -- Auto-dismiss delay in milliseconds, or false to disable auto-close
  timeout = 2000,
  -- Maximum floating window width (characters)
  width = 30,
  -- Highlight group for the current buffer line
  hl_current = "BufIndicatorCurrent",
  -- Highlight group for other buffer lines
  hl_other = "BufIndicatorOther",
  -- Padding from the editor edge
  padding = 1,
  -- Maximum popup height (nil = 80% of editor height)
  max_height = nil,
  -- Window transparency (0 = opaque, 100 = fully transparent)
  winblend = 0,
  -- Name format: "filename", "relative", or a function(raw_name) -> string
  format = "filename",
  -- Popup position: "right" (right-aligned), "left" (left-aligned), or "center" (left-aligned)
  position = "right",
  -- Icon displayed to the LEFT of the current buffer name (default: none)
  current_icon_left = "",
  -- Icon displayed to the RIGHT of the current buffer name (default: none)
  current_icon_right = "",
  -- Prefix for other (non-current) buffer lines
  other_prefix = "  ",
  -- Enable scroll animation when jumping to non-adjacent buffers (dynamic mode only)
  animate = false,
  -- Total animation duration in milliseconds (dynamic mode only)
  animate_duration = 200,
  -- Border style for static mode: "none", "single", "double", "rounded", "solid", "shadow"
  -- or a custom border table (see :h nvim_open_win). Ignored in dynamic mode.
  border = "rounded",
}

--- Resolved configuration (populated after setup())
M.config = {}

--- Whether the plugin has been set up
M._setup_done = false

--- Define default highlight groups (only if not already defined by the user).
local function define_highlights()
  -- Current buffer: bold, inherits from Normal (transparent bg)
  vim.api.nvim_set_hl(0, "BufIndicatorCurrent", { default = true, bold = true, link = "Normal" })
  -- Other buffers: dimmed text
  vim.api.nvim_set_hl(0, "BufIndicatorOther", { default = true, link = "Comment" })
  -- Popup background: transparent (link to editor Normal so bg matches)
  vim.api.nvim_set_hl(0, "BufIndicatorNormal", { default = true, link = "Normal" })
  -- Popup border (static mode)
  vim.api.nvim_set_hl(0, "BufIndicatorBorder", { default = true, link = "FloatBorder" })
end

--- Setup the plugin with user configuration.
--- @param opts? table User configuration overrides
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", {}, defaults, opts)
  M._setup_done = true
  define_highlights()
end

--- Show the buffer indicator popup.
--- Called by the BufEnter autocmd.
function M.show()
  -- Lazy setup: if user didn't call setup(), use defaults
  if not M._setup_done then
    M.setup()
  end

  -- Schedule to avoid issues inside autocmd context
  vim.schedule(function()
    -- Guard: don't trigger for special buffer types
    local bt = vim.bo.buftype
    if bt == "nofile" or bt == "prompt" or bt == "terminal" then
      return
    end

    window.show(M.config)
  end)
end

--- Manually show the buffer indicator.
--- If already visible, resets the auto-close timeout.
function M.open()
  if not M._setup_done then
    M.setup()
  end

  vim.schedule(function()
    local bt = vim.bo.buftype
    if bt == "nofile" or bt == "prompt" or bt == "terminal" then
      return
    end

    window.show_or_reset(M.config)
  end)
end

--- Manually close the buffer indicator.
function M.close()
  vim.schedule(function()
    window.close()
  end)
end

return M
