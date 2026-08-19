-- LSP setup, including csharp-ls for Unity/C# editing. See nvim/lua/user/unity.lua
-- for Unity-specific notes (Unity Editor settings required for this to work).

return {
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
    },
    config = function()
      require('mason').setup()

      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          local map = vim.keymap.set
          local opts = { buffer = args.buf }
          map('n', 'gd', vim.lsp.buf.definition, opts)
          map('n', 'gr', vim.lsp.buf.references, opts)
          map('n', 'K', vim.lsp.buf.hover, opts)
          map('n', '<leader>rn', vim.lsp.buf.rename, opts)
          map('n', '<leader>ca', vim.lsp.buf.code_action, opts)
        end,
      })

      local capabilities = require('blink.cmp').get_lsp_capabilities()

      -- Applies to every server mason-lspconfig auto-enables below.
      vim.lsp.config('*', { capabilities = capabilities })

      require('mason-lspconfig').setup({
        ensure_installed = { 'lua_ls', 'csharp_ls', 'gopls' },
        -- csharp_ls is configured separately in user.unity (Unity/.sln aware)
        automatic_enable = { exclude = { 'csharp_ls' } },
      })

      require('user.unity').setup(capabilities)
    end,
  },
}
