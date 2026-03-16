local buffers = require("bufindicator.buffers")

local M = {}

-- Internal state for debounce and cleanup
local state = {
  win_id = nil,
  buf_id = nil,
  timer = nil,       -- auto-close timer
  anim_timer = nil,   -- animation frame timer
  last_idx = nil,     -- last highlighted buffer index (persists across show() calls)
}

--- Stop and close a uv timer safely.
--- @param t userdata|nil
local function stop_timer(t)
  if t then
    t:stop()
    if not t:is_closing() then
      t:close()
    end
  end
end

--- Close the existing popup window and cancel all timers.
local function cleanup()
  stop_timer(state.timer)
  state.timer = nil

  stop_timer(state.anim_timer)
  state.anim_timer = nil

  if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
    vim.api.nvim_win_close(state.win_id, true)
  end
  state.win_id = nil

  if state.buf_id and vim.api.nvim_buf_is_valid(state.buf_id) then
    vim.api.nvim_buf_delete(state.buf_id, { force = true })
  end
  state.buf_id = nil
end

--- Compute the row offset so that `highlight_idx` is vertically centered.
--- @param editor_height number Total usable editor height
--- @param win_height number Height of the floating window
--- @param highlight_idx number 1-indexed position of the highlighted line
--- @return number row 0-indexed row for nvim_open_win
local function compute_row(editor_height, win_height, highlight_idx)
  local center = math.floor(editor_height / 2)
  local ideal_row = center - (highlight_idx - 1)
  local max_row = editor_height - win_height
  return math.max(0, math.min(ideal_row, max_row))
end

--- Compute display width of a UTF-8 string (handles CJK/icons).
--- @param s string
--- @return number
local function display_width(s)
  return vim.fn.strdisplaywidth(s)
end

--- Build a single display line for a buffer entry.
--- @param buf table { bufnr, name, is_current }
--- @param is_highlighted boolean Whether this line is the "active" highlighted one
--- @param config table Plugin configuration
--- @return string raw_line The line content (before alignment padding)
local function build_one_line(buf, is_highlighted, config)
  if is_highlighted then
    local icon_left = config.current_icon_left or ""
    local icon_right = config.current_icon_right or ""
    return icon_left .. buf.name .. icon_right
  else
    local prefix_other = config.other_prefix or "  "
    return prefix_other .. buf.name
  end
end

--- Build all display lines, highlighting a specific index.
--- @param buf_list table[] Buffer list
--- @param highlight_idx number 1-indexed line to highlight
--- @param config table Plugin configuration
--- @param win_width number Window width for alignment
--- @return string[] lines Formatted lines ready for the buffer
local function build_lines(buf_list, highlight_idx, config, win_width)
  local lines = {}
  local position = config.position or "right"

  for i, buf in ipairs(buf_list) do
    local is_hl = (i == highlight_idx)
    local raw_line = build_one_line(buf, is_hl, config)
    local line

    if position == "right" then
      local pad = win_width - display_width(raw_line)
      line = (pad > 0) and (string.rep(" ", pad) .. raw_line) or raw_line
    else
      -- "left" and "center": left-aligned
      line = raw_line
    end

    table.insert(lines, line)
  end

  return lines
end

--- Apply highlight groups to all lines in the popup buffer.
--- @param popup_buf number Buffer handle
--- @param buf_list table[] Buffer list
--- @param highlight_idx number 1-indexed line that gets current highlight
--- @param config table Plugin configuration
local function apply_highlights(popup_buf, buf_list, highlight_idx, config)
  local ns_id = vim.api.nvim_create_namespace("bufindicator")
  vim.api.nvim_buf_clear_namespace(popup_buf, ns_id, 0, -1)
  for i, _ in ipairs(buf_list) do
    local hl_group = (i == highlight_idx) and config.hl_current or config.hl_other
    vim.api.nvim_buf_add_highlight(popup_buf, ns_id, hl_group, i - 1, 0, -1)
  end
end

--- Compute the max content width across all buffers.
--- @param buf_list table[] Buffer list
--- @param config table Plugin configuration
--- @return number
local function compute_max_width(buf_list, config)
  local icon_left = config.current_icon_left or ""
  local icon_right = config.current_icon_right or ""
  local prefix_other = config.other_prefix or "  "
  local max_w = 0

  for _, buf in ipairs(buf_list) do
    local w1 = display_width(icon_left .. buf.name .. icon_right)
    local w2 = display_width(prefix_other .. buf.name)
    local w = math.max(w1, w2)
    if w > max_w then
      max_w = w
    end
  end

  return max_w
end

--- Compute the horizontal col position based on config.position.
--- @param position string "right" | "left" | "center"
--- @param editor_width number
--- @param win_width number
--- @param padding number
--- @param border string Border style (accounts for border width)
--- @return number col
local function compute_col(position, editor_width, win_width, padding, border)
  -- Border takes extra columns (1 left + 1 right for non-"none" borders)
  local border_offset = (border ~= "none") and 2 or 0
  if position == "center" then
    return math.floor((editor_width - win_width - border_offset) / 2)
  elseif position == "left" then
    return padding
  else
    -- "right" (default)
    return editor_width - win_width - padding - border_offset
  end
end

--- Rewrite the popup buffer content and highlights for a given highlight index.
--- Also repositions the floating window so the highlighted line stays centered.
--- Used by dynamic mode animation.
--- @param buf_list table[] Buffer list
--- @param highlight_idx number 1-indexed highlight position
--- @param config table Plugin configuration
--- @param win_width number Window width
--- @param editor_height number Editor height
--- @param win_height number Window height
--- @param col number Window column position
local function update_frame(buf_list, highlight_idx, config, win_width, editor_height, win_height, col)
  if not state.win_id or not vim.api.nvim_win_is_valid(state.win_id) then
    return
  end
  if not state.buf_id or not vim.api.nvim_buf_is_valid(state.buf_id) then
    return
  end

  local lines = build_lines(buf_list, highlight_idx, config, win_width)

  vim.bo[state.buf_id].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf_id, 0, -1, false, lines)
  vim.bo[state.buf_id].modifiable = false

  apply_highlights(state.buf_id, buf_list, highlight_idx, config)

  local new_row = compute_row(editor_height, win_height, highlight_idx)
  vim.api.nvim_win_set_config(state.win_id, {
    relative = "editor",
    row = new_row,
    col = col,
  })

  if #buf_list > win_height then
    vim.api.nvim_win_set_cursor(state.win_id, { highlight_idx, 0 })
  end
end

--- Compute per-step intervals using an ease-out curve.
--- @param steps number Total animation steps
--- @param total_duration number Total animation duration in ms
--- @return number[] intervals Per-step interval in ms
local function ease_out_intervals(steps, total_duration)
  if steps <= 0 then
    return {}
  end
  if steps == 1 then
    return { total_duration }
  end

  local weights = {}
  local total_weight = 0
  for i = 1, steps do
    local w = (2 * i - 1)
    weights[i] = w
    total_weight = total_weight + w
  end

  local intervals = {}
  for i = 1, steps do
    intervals[i] = math.max(1, math.floor(total_duration * weights[i] / total_weight))
  end

  return intervals
end

--- Start the auto-close timer.
--- @param config table Plugin configuration
local function start_close_timer(config)
  local timer = vim.uv.new_timer()
  timer:start(config.timeout, 0, vim.schedule_wrap(function()
    cleanup()
  end))
  state.timer = timer
end

------------------------------------------------------------------------
-- Dynamic mode: window position follows highlighted buffer (original)
------------------------------------------------------------------------

--- @param config table
local function show_dynamic(config)
  local buf_list, current_idx = buffers.get_buffers(config)

  if #buf_list < 2 then
    state.last_idx = current_idx
    return
  end

  local editor_width = vim.o.columns
  local editor_height = vim.o.lines - vim.o.cmdheight - 1
  local max_height = config.max_height or math.floor(editor_height * 0.8)
  local win_height = math.min(#buf_list, max_height)
  local position = config.position or "right"

  local pre_max_width = compute_max_width(buf_list, config)
  local win_width = math.min(math.max(pre_max_width, 10), config.width)

  -- Animation logic
  local animate = config.animate
  local from_idx = state.last_idx or current_idx
  if from_idx < 1 then from_idx = 1 end
  if from_idx > #buf_list then from_idx = #buf_list end

  local distance = math.abs(current_idx - from_idx)
  local should_animate = animate and (distance > 1)

  local initial_highlight = should_animate and from_idx or current_idx

  local lines = build_lines(buf_list, initial_highlight, config, win_width)

  local row = compute_row(editor_height, win_height, initial_highlight)
  local col = compute_col(position, editor_width, win_width, config.padding, "none")

  -- Create buffer & window
  local popup_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[popup_buf].bufhidden = "wipe"
  vim.bo[popup_buf].buftype = "nofile"

  vim.api.nvim_buf_set_lines(popup_buf, 0, -1, false, lines)
  vim.bo[popup_buf].modifiable = false

  local win_id = vim.api.nvim_open_win(popup_buf, false, {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    style = "minimal",
    border = "none",
    focusable = false,
    noautocmd = true,
    zindex = 50,
  })

  apply_highlights(popup_buf, buf_list, initial_highlight, config)

  vim.api.nvim_win_set_option(win_id, "winblend", config.winblend or 0)
  vim.api.nvim_win_set_option(win_id, "winhighlight", "Normal:BufIndicatorNormal")

  if #buf_list > win_height then
    vim.api.nvim_win_set_cursor(win_id, { initial_highlight, 0 })
  end

  state.win_id = win_id
  state.buf_id = popup_buf
  state.last_idx = current_idx

  if should_animate then
    local direction = (current_idx > from_idx) and 1 or -1
    local steps = distance
    local total_duration = config.animate_duration or 200
    local intervals = ease_out_intervals(steps, total_duration)

    local step = 0
    local anim_timer = vim.uv.new_timer()

    local function next_frame()
      step = step + 1
      local idx = from_idx + direction * step

      vim.schedule(function()
        update_frame(buf_list, idx, config, win_width, editor_height, win_height, col)

        if idx == current_idx then
          stop_timer(state.anim_timer)
          state.anim_timer = nil
          start_close_timer(config)
        end
      end)
    end

    local function schedule_step(s)
      if s > steps then return end
      local interval = intervals[s] or 16
      anim_timer:start(interval, 0, function()
        next_frame()
        if s < steps then
          vim.schedule(function()
            if state.anim_timer and not state.anim_timer:is_closing() then
              schedule_step(s + 1)
            end
          end)
        end
      end)
    end

    state.anim_timer = anim_timer
    schedule_step(1)
  else
    start_close_timer(config)
  end
end

------------------------------------------------------------------------
-- Static mode: window position fixed, only highlight moves
------------------------------------------------------------------------

--- @param config table
local function show_static(config)
  local buf_list, current_idx = buffers.get_buffers(config)

  if #buf_list < 2 then
    state.last_idx = current_idx
    return
  end

  local editor_width = vim.o.columns
  local editor_height = vim.o.lines - vim.o.cmdheight - 1
  local border = config.border or "none"
  local position = config.position or "right"

  local pre_max_width = compute_max_width(buf_list, config)
  local win_width = math.min(math.max(pre_max_width, 10), config.width)

  -- Window height: fit all buffers, capped by max_height
  local max_height = config.max_height or math.floor(editor_height * 0.8)
  local win_height = math.min(#buf_list, max_height)

  -- Border takes vertical space too (1 top + 1 bottom for non-"none")
  local border_v = (border ~= "none") and 2 or 0

  -- Static mode: window is vertically centered in the editor
  local row = math.floor((editor_height - win_height - border_v) / 2)
  row = math.max(0, row)

  local col = compute_col(position, editor_width, win_width, config.padding, border)

  -- Build lines: in static mode, the current buffer is highlighted but
  -- each buffer name always occupies its fixed position
  local lines = build_lines(buf_list, current_idx, config, win_width)

  local popup_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[popup_buf].bufhidden = "wipe"
  vim.bo[popup_buf].buftype = "nofile"

  vim.api.nvim_buf_set_lines(popup_buf, 0, -1, false, lines)
  vim.bo[popup_buf].modifiable = false

  local win_id = vim.api.nvim_open_win(popup_buf, false, {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    style = "minimal",
    border = border,
    focusable = false,
    noautocmd = true,
    zindex = 50,
  })

  apply_highlights(popup_buf, buf_list, current_idx, config)

  local winhighlight = "Normal:BufIndicatorNormal"
  if border ~= "none" then
    winhighlight = winhighlight .. ",FloatBorder:BufIndicatorBorder"
  end
  vim.api.nvim_win_set_option(win_id, "winblend", config.winblend or 0)
  vim.api.nvim_win_set_option(win_id, "winhighlight", winhighlight)

  -- If buffer list exceeds window height, scroll to make current visible
  if #buf_list > win_height then
    vim.api.nvim_win_set_cursor(win_id, { current_idx, 0 })
  end

  state.win_id = win_id
  state.buf_id = popup_buf
  state.last_idx = current_idx

  start_close_timer(config)
end

------------------------------------------------------------------------
-- Public entry point
------------------------------------------------------------------------

--- Show the buffer indicator floating window.
--- Dispatches to dynamic or static mode based on config.mode.
--- @param config table Plugin configuration
function M.show(config)
  cleanup()

  local mode = config.mode or "dynamic"
  if mode == "static" then
    show_static(config)
  else
    show_dynamic(config)
  end
end

return M
