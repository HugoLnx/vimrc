-- Neovim-only keymaps. Base mappings (H/L/J/K/etc.) come from the shared
-- vim/vimrc. LSP keymaps are set per-buffer in plugins/lsp.lua on attach.

local map = vim.keymap.set

map('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic' })
map('n', '[d', vim.diagnostic.goto_prev, { desc = 'Previous diagnostic' })
map('n', ']d', vim.diagnostic.goto_next, { desc = 'Next diagnostic' })

-- Jump history. <C-o> is remapped in vim/vimrc; keymap.set is non-recursive,
-- so these still run the built-in <C-o>/<C-i>.
map('n', '[j', '<C-o>', { desc = 'Jump back' })
map('n', ']j', '<C-i>', { desc = 'Jump forward' })

map('n', '<leader>tt', '<cmd>NvimTreeToggle<CR>', { desc = 'Toggle file tree' })
map('n', '<leader>tf', '<cmd>NvimTreeFindFile<CR>', { desc = 'Find current file in tree' })
