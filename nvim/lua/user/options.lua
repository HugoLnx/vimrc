-- Neovim-only option overrides. Most options come from the shared vim/vimrc
-- (already sourced by init.lua before this module loads).

vim.g.mapleader = ' '
vim.opt.termguicolors = true
vim.opt.signcolumn = 'yes'
vim.opt.updatetime = 300
vim.opt.completeopt = { 'menu', 'menuone', 'noselect' }

-- No plugin in this config uses Neovim's remote-plugin providers; disabling
-- them explicitly skips startup detection work and silences checkhealth noise.
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
