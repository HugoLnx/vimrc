return {
  'nvim-treesitter/nvim-treesitter',
  -- main was rewritten as a different, incompatible plugin (no more
  -- nvim-treesitter.configs); master keeps the classic setup() API this
  -- config uses.
  branch = 'master',
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
