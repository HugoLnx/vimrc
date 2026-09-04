-- Aggregates all plugin specs for lazy.setup(). Add new plugin modules here.

return {
  require('user.plugins.treesitter'),
  require('user.plugins.lsp'),
  require('user.plugins.dap'),
  require('user.plugins.completion'),
  require('user.plugins.supermaven'),
  require('user.plugins.telescope'),
  require('user.plugins.colorscheme'),
  require('user.plugins.statusline'),
  require('user.plugins.gitsigns'),
  require('user.plugins.nvim-tree'),
  require('user.plugins.auto-session'),
  unpack(require('user.plugins.misc')),
}
