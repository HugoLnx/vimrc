local M = {}
local pathshorten = require('user.pathshorten')

function M.render()
  local tabs = vim.api.nvim_list_tabpages()
  local current = vim.api.nvim_get_current_tabpage()
  local out = {}
  for n, tab in ipairs(tabs) do
    local buf = vim.api.nvim_win_get_buf(vim.api.nvim_tabpage_get_win(tab))
    local name = vim.api.nvim_buf_get_name(buf)
    name = name == '' and '[No Name]' or vim.fn.fnamemodify(name, ':~:.')
    local modified = vim.bo[buf].modified
    local target = math.min(40, math.floor(vim.o.columns / #tabs) - 2 - (modified and 2 or 0))
    local short = pathshorten.shorten(name, target):gsub('%%', '%%%%')
    out[#out + 1] = '%' .. n .. 'T' .. (tab == current and '%#TabLineSel#' or '%#TabLine#')
      .. ' ' .. short .. (modified and ' +' or '') .. ' '
  end
  return table.concat(out) .. '%#TabLineFill#%T'
end

vim.o.tabline = "%!v:lua.require'user.tabline'.render()"

return M
