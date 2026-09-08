return {
  'nvim-treesitter/nvim-treesitter',
  -- main was rewritten as a different, incompatible plugin (no more
  -- nvim-treesitter.configs); master keeps the classic setup() API this
  -- config uses.
  branch = 'master',
  build = ':TSUpdate',
  config = function()
    -- Treesitter parses asynchronously (since Neovim 0.11), yielding
    -- mid-parse across scheduler ticks. Short-lived scratch buffers (e.g.
    -- LSP hover's floating-preview buffer, which is markdown and can
    -- contain fenced code blocks) can get wiped (bufhidden=wipe) while an
    -- injection parse is still yielded, leaving the resumed coroutine
    -- holding invalid nodes -> "attempt to call method 'range' (a nil
    -- value)" in the highlighter's decoration provider. Forcing sync
    -- parsing removes that race entirely (see :h news-0.11.txt).
    vim.g._ts_force_sync_parsing = true

    require('nvim-treesitter.configs').setup({
      ensure_installed = {
        'c', 'cpp', 'c_sharp', 'html', 'css', 'javascript', 'typescript',
        'lua', 'vim', 'vimdoc', 'go', 'ruby', 'elixir', 'yaml', 'json',
        'markdown', 'dockerfile',
      },
      highlight = { enable = true },
      indent = { enable = true },
    })
  end,
}
