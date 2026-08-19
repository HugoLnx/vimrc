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

      -- See config.yml's `csharp_lsp` option / install/symlink.py. csharp_ls
      -- also needs the dotnet SDK on PATH to install/run; skip it on
      -- machines that don't have that (e.g. a WSL Linux side used only for
      -- non-Unity work), even if the option itself is left enabled.
      local ok, local_config = pcall(require, 'user.local')
      local csharp_lsp_enabled = not (ok and local_config.csharp_lsp == false)
        and vim.fn.executable('dotnet') == 1

      local ensure_installed = { 'lua_ls', 'gopls' }
      if csharp_lsp_enabled then
        table.insert(ensure_installed, 'csharp_ls')
      end

      require('mason-lspconfig').setup({
        ensure_installed = ensure_installed,
        -- csharp_ls is configured separately in user.unity (Unity/.sln aware)
        automatic_enable = { exclude = { 'csharp_ls' } },
      })

      if csharp_lsp_enabled then
        require('user.unity').setup(capabilities)
      end
    end,
  },
}
