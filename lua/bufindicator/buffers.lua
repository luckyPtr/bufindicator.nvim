local M = {}

--- Get all listed buffers with metadata.
--- @param config table The plugin configuration
--- @return table[] List of { bufnr, name, is_current }
--- @return number current_idx 1-indexed position of current buffer in the list
function M.get_buffers(config)
  local current_bufnr = vim.api.nvim_get_current_buf()
  local bufs = {}
  local current_idx = 1

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buflisted then
      local raw_name = vim.api.nvim_buf_get_name(bufnr)
      local display_name = M.format_name(raw_name, config)
      local is_current = (bufnr == current_bufnr)

      table.insert(bufs, {
        bufnr = bufnr,
        name = display_name,
        is_current = is_current,
      })

      if is_current then
        current_idx = #bufs
      end
    end
  end

  return bufs, current_idx
end

--- Format a buffer name according to config.
--- @param raw_name string Full buffer path
--- @param config table The plugin configuration
--- @return string Formatted display name
function M.format_name(raw_name, config)
  if raw_name == "" then
    return "[No Name]"
  end

  local fmt = config.format
  if type(fmt) == "function" then
    return fmt(raw_name)
  end

  if fmt == "relative" then
    return vim.fn.fnamemodify(raw_name, ":~:.")
  end

  -- default: "filename"
  return vim.fn.fnamemodify(raw_name, ":t")
end

return M
