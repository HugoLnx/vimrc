return {
  'nvim-treesitter/nvim-treesitter',
  build = ':TSUpdate',
  config = function()
    require('nvim-treesitter.configs').setup({
      ensure_installed = {
        'c', 'cpp', 'c_sharp', 'html', 'css', 'javascript', 'typescript',
        'lua', 'vim', 'vimdoc', 'go', 'ruby', 'elixir', 'yaml', 'json',
        'markdown', 'dockerfile',
      },
      highlight = { enable = true },
      indent = { enable = true },
    })
  end,
}
