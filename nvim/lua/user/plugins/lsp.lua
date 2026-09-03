-- LSP setup, including csharp-ls (WSL/Linux/macOS) and roslyn.nvim (Windows)
-- for Unity/C# editing. See nvim/lua/user/unity.lua for Unity-specific notes
-- (Unity Editor settings required for this to work).

return {
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
    },
    config = function()
      require('mason').setup({
        registries = {
          'github:mason-org/mason-registry',
          'github:Crashdummyy/mason-registry', -- provides the roslyn package (Windows-only, see below)
        },
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

      local capabilities = require('blink.cmp').get_lsp_capabilities()

      -- Applies to every server mason-lspconfig auto-enables below.
      vim.lsp.config('*', { capabilities = capabilities })

      -- See config.yml's `csharp_lsp` option / install/symlink.py. csharp_ls
      -- also needs the dotnet SDK on PATH to install/run; skip it on
      -- machines that don't have that (e.g. a WSL Linux side used only for
      -- non-Unity work), even if the option itself is left enabled.
      local is_windows = vim.fn.has('win32') == 1
      local ok, local_config = pcall(require, 'user.local')
      local csharp_lsp_enabled = not (ok and local_config.csharp_lsp == false)
        and vim.fn.executable('dotnet') == 1

      local ensure_installed = { 'lua_ls', 'gopls' }
      if csharp_lsp_enabled and not is_windows then
        table.insert(ensure_installed, 'csharp_ls')
      end
      if csharp_lsp_enabled and is_windows then
        table.insert(ensure_installed, 'roslyn')
      end

      require('mason-lspconfig').setup({
        ensure_installed = ensure_installed,
        -- csharp_ls (non-Windows) is configured separately in user.unity
        -- (Unity/.sln aware); roslyn (Windows) manages its own attachment
        -- via the roslyn.nvim plugin spec below.
        automatic_enable = { exclude = { 'csharp_ls', 'roslyn' } },
      })

      if csharp_lsp_enabled then
        require('user.unity').setup(capabilities)
      end
    end,
  },
  {
    -- Microsoft's Roslyn C# LSP, native Windows only (Unity Editor runs
    -- there); WSL/Linux/macOS keep csharp_ls, configured above. Requires
    -- Neovim >= 0.12.
    'seblyng/roslyn.nvim',
    cond = function() return vim.fn.has('win32') == 1 end,
    ---@module 'roslyn.config'
    ---@type RoslynNvimConfig
    opts = {
      filewatching = 'auto',
      broad_search = false,
    },
  },
  {
    -- Keeps a Unity project's .csproj <Compile> entries in sync as .cs
    -- files are added/renamed/deleted from Neovim, without needing Unity
    -- focused. Windows only, same as roslyn.nvim above.
    'apyra/nvim-unity-sync',
    cond = function() return vim.fn.has('win32') == 1 end,
    main = 'unity.plugin',
    opts = {},
  },
}
