local is_wsl = vim.fn.has('wsl') == 1

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
  {
    -- tmux <-> Neovim pane navigation, WSL only (no-op without tmux
    -- elsewhere). Its own <C-h/j/k/l> defaults are disabled and remapped
    -- onto <C-w> h/j/k/l to match vanilla Neovim window navigation.
    'christoomey/vim-tmux-navigator',
    cond = function() return is_wsl end,
    init = function()
      vim.g.tmux_navigator_no_mappings = 1
    end,
    config = function()
      local dirs = { h = 'Left', j = 'Down', k = 'Up', l = 'Right' }
      for key, dir in pairs(dirs) do
        vim.keymap.set('n', '<C-w>' .. key, '<cmd>TmuxNavigate' .. dir .. '<CR>',
          { desc = 'Navigate window/pane ' .. dir:lower() })
        vim.keymap.set('t', '<C-w>' .. key, '<C-\\><C-n><cmd>TmuxNavigate' .. dir .. '<CR>',
          { desc = 'Navigate window/pane ' .. dir:lower() .. ' (from terminal)' })
      end
    end,
  },
}
