-- AI inline completions. Neovim-only: Supermaven has no classic-Vim plugin.
-- Disable its own Tab/Enter keymaps so it doesn't fight blink.cmp; accept
-- suggestions with <C-y> (or <C-S-l>) instead.

return {
  'supermaven-inc/supermaven-nvim',
  config = function()
    require('supermaven-nvim').setup({
      keymaps = {
        accept_suggestion = '<C-y>',
        clear_suggestion = '<C-]>',
        accept_word = '<C-l>',
      },
    })

    -- supermaven-nvim's `keymaps` table only accepts one key per action;
    -- <C-S-l> is a second way to accept the whole suggestion, pairing with
    -- <C-l> (accept_word) above.
    vim.keymap.set('i', '<C-S-l>', require('supermaven-nvim.completion_preview').on_accept_suggestion,
      { noremap = true, silent = true, desc = 'Supermaven: accept whole suggestion' })
  end,
}
