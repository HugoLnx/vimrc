return {
  {
    'mg979/vim-visual-multi',
    init = function()
      vim.g.VM_maps = {
        ['Find Under'] = '<C-g>',
        ['Find Subword Under'] = '<C-g>',
      }
    end,
  },
}
