-- Session persistence, restricted to real project directories. See
-- config.yml's `allowed_dirs` option / install/symlink.py: it's baked into
-- nvim/lua/user/local.lua as OS-keyed lists (Windows and WSL/Linux use
-- different paths for the same projects), and this picks the right one
-- at runtime.

return {
  'rmagatti/auto-session',
  lazy = false,
  opts = function()
    local is_windows = vim.fn.has('win32') == 1
    local ok, local_config = pcall(require, 'user.local')
    local dirs = (ok and local_config.allowed_dirs) or {}
    local allowed_dirs = (is_windows and dirs.windows) or dirs.linux or {}

    return {
      allowed_dirs = allowed_dirs,
    }
  end,
}
