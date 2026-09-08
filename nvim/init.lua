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

require('lazy').setup(require('user.plugins'), {
  rocks = { enabled = false },
})

-- The buffer named on the command line gets its FileType event fired
-- before this file finishes sourcing, so any plugin that hooks FileType to
-- activate itself (LSP's vim.lsp.enable(), treesitter, roslyn.nvim, ...)
-- misses it for that first buffer. Re-fire it now that everything's loaded.
if vim.bo.filetype ~= '' then
  vim.api.nvim_exec_autocmds('FileType', { buffer = 0 })
end
