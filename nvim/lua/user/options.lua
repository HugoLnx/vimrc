-- Neovim-only option overrides. Most options come from the shared vim/vimrc
-- (already sourced by init.lua before this module loads).

vim.g.mapleader = ' '
vim.opt.termguicolors = true
vim.opt.signcolumn = 'yes'
vim.opt.updatetime = 300
vim.opt.completeopt = { 'menu', 'menuone', 'noselect' }
