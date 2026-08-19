-- Neovim-only keymaps. Base mappings (H/L/J/K/etc.) come from the shared
-- vim/vimrc. LSP keymaps are set per-buffer in plugins/lsp.lua on attach.

local map = vim.keymap.set

map('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic' })
map('n', '[d', vim.diagnostic.goto_prev, { desc = 'Previous diagnostic' })
map('n', ']d', vim.diagnostic.goto_next, { desc = 'Next diagnostic' })
