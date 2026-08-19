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
      require('mason-lspconfig').setup({
        ensure_installed = { 'lua_ls', 'csharp_ls', 'gopls' },
      })

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

      local lspconfig = require('lspconfig')
      local capabilities = require('blink.cmp').get_lsp_capabilities()

      require('mason-lspconfig').setup_handlers({
        function(server_name)
          -- csharp_ls is configured separately in user.unity (Unity/.sln aware)
          if server_name ~= 'csharp_ls' then
            lspconfig[server_name].setup({ capabilities = capabilities })
          end
        end,
      })

      require('user.unity').setup(lspconfig, capabilities)
    end,
  },
}
