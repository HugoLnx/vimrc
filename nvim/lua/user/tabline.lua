local M = {}
local pathshorten = require('user.pathshorten')
local highlight = require('user.pathshorten_highlight')

local function label(text, marks, selected)
  local base = selected and '%#TabLineSel#' or '%#TabLine#'
  local suffix = selected and 'Sel' or ''
  local out, last = {}, 0
  for _, i in ipairs(marks) do
    local c = text:sub(i, i)
    out[#out + 1] = text:sub(last + 1, i - 1):gsub('%%', '%%%%')
    out[#out + 1] = '%#' .. highlight.group(c, 'PathShorten', suffix) .. '#' .. c:gsub('%%', '%%%%') .. base
    last = i
  end
  out[#out + 1] = text:sub(last + 1):gsub('%%', '%%%%')
  return base .. ' ' .. table.concat(out)
end

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
    local short, marks = pathshorten.shorten_marked(name, target)
    out[#out + 1] = '%' .. n .. 'T' .. label(short, marks, tab == current)
      .. (modified and ' +' or '') .. ' '
  end
  return table.concat(out) .. '%#TabLineFill#%T'
end

vim.o.tabline = "%!v:lua.require'user.tabline'.render()"

return M
