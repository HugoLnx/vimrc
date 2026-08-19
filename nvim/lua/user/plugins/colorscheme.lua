return {
  'lifepillar/vim-solarized8',
  priority = 1000,
  config = function()
    vim.o.background = 'dark'
    vim.cmd('colorscheme solarized8')
  end,
}
