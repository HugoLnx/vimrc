-- File-explorer sidebar. Also required by nvim-unity-sync (see lsp.lua) to
-- track .cs create/rename/delete events for Unity .csproj syncing.

return {
  'nvim-tree/nvim-tree.lua',
  dependencies = { 'nvim-tree/nvim-web-devicons' }, -- already a dep of lualine, see statusline.lua
  opts = {},
}
