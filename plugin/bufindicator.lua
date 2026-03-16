-- bufindicator.nvim - Show buffer list on buffer switch
-- Loaded automatically via vim.pack (pack/plugins/start/)

if vim.g.loaded_bufindicator then
  return
end
vim.g.loaded_bufindicator = true

local group = vim.api.nvim_create_augroup("BufIndicator", { clear = true })

vim.api.nvim_create_autocmd("BufEnter", {
  group = group,
  callback = function()
    require("bufindicator").show()
  end,
  desc = "Show buffer indicator on buffer switch",
})
