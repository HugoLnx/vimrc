local M = {}

-- How far each hint fg moves from its base fg toward the accent fg.
local HINT_BLEND = 0.35
local SLASH_BLEND = 0.75

local function get(name)
  return vim.api.nvim_get_hl(0, { name = name, link = false })
end

local function blend(from, to, amount)
  local out = 0
  for shift = 16, 0, -8 do
    local a, b = math.floor(from / 2 ^ shift) % 256, math.floor(to / 2 ^ shift) % 256
    out = out + math.floor(a + (b - a) * amount + 0.5) * 2 ^ shift
  end
  return out
end

local function define(name, base, accent, amount, with_bg)
  local base_hl, accent_fg = get(base), get(accent).fg
  local base_fg = base_hl.fg or get('Normal').fg
  if not (base_fg and accent_fg) then
    vim.api.nvim_set_hl(0, name, { link = accent })
    return
  end
  vim.api.nvim_set_hl(0, name, {
    fg = blend(base_fg, accent_fg, amount),
    -- Tabline groups replace the whole highlight, so they must carry the bg.
    bg = with_bg and base_hl.bg or nil,
    bold = with_bg and base_hl.bold or nil,
  })
end

function M.setup()
  define('PathShortenHint', 'TabLine', 'Special', HINT_BLEND, true)
  define('PathShortenHintSel', 'TabLineSel', 'Special', HINT_BLEND, true)
  define('PathShortenSlash', 'TabLine', 'DiagnosticError', SLASH_BLEND, true)
  define('PathShortenSlashSel', 'TabLineSel', 'DiagnosticError', SLASH_BLEND, true)
  define('TelescopePathShortenHint', 'TelescopeResultsNormal', 'Special', HINT_BLEND, false)
  define('TelescopePathShortenSlash', 'TelescopeResultsNormal', 'DiagnosticError', SLASH_BLEND, false)
end

-- Picks the hint group for the char at a marked position.
function M.group(char, prefix, suffix)
  return prefix .. (char:match('[/\\]') and 'Slash' or 'Hint') .. (suffix or '')
end

M.setup()
vim.api.nvim_create_autocmd('ColorScheme', {
  group = vim.api.nvim_create_augroup('user_pathshorten_highlight', { clear = true }),
  callback = M.setup,
})

return M
