-- Neovim entrypoint. Shares the classic-Vim base config (vim/vimrc) and
-- layers modern Neovim-only tooling (lazy.nvim, treesitter, LSP, telescope)
-- on top. See nvim/lua/user/ for the Lua modules.

-- stdpath('config') may be a symlink into the repo (see install/), so
-- resolve it before walking up to the sibling vim/ directory.
local config_dir = vim.fn.resolve(vim.fn.stdpath('config'))
local shared_vimrc = config_dir .. '/../vim/vimrc'
if vim.fn.filereadable(shared_vimrc) == 1 then
  vim.cmd('source ' .. vim.fn.fnameescape(shared_vimrc))
end

require('user.options')
require('user.keymaps')
require('user.lazy-bootstrap')

require('lazy').setup(require('user.plugins'))
