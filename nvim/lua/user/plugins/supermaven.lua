-- AI inline completions. Neovim-only: Supermaven has no classic-Vim plugin.
-- Disable its own Tab/Enter keymaps so it doesn't fight blink.cmp; accept
-- suggestions with <C-y> instead.

return {
  'supermaven-inc/supermaven-nvim',
  config = function()
    require('supermaven-nvim').setup({
      keymaps = {
        accept_suggestion = '<C-y>',
        clear_suggestion = '<C-]>',
        accept_word = '<C-j>',
      },
    })
  end,
}
