return {
  'nvim-telescope/telescope.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    -- optional perf extension, needs a C toolchain (make); skip if that's
    -- not available (e.g. plain Windows without MSVC/mingw installed)
    { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make', cond = vim.fn.executable('make') == 1 },
  },
  config = function()
    local telescope = require('telescope')
    telescope.setup({
      defaults = {
        file_ignore_patterns = {
          'node_modules/', '%.git/', 'deps/', '_build/', 'frameworks/',
          'tmp/cache/', 'dist/', '_old/', 'vendor/ruby/', 'coverage/',
        },
      },
    })
    pcall(telescope.load_extension, 'fzf')

    local builtin = require('telescope.builtin')
    -- Under Neovim, ctrlp.vim (classic-Vim-only, see vim/plugins.vim) never
    -- loads - Telescope is the replacement. Keep the muscle-memory shortcut.
    vim.keymap.set('n', '<C-p>', builtin.find_files, { desc = 'Find files' })
    vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Find files' })
    vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Live grep' })
    vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Find buffers' })
    vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Help tags' })
  end,
}
