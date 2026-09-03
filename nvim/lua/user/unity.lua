-- Unity/C# support, split by OS:
--   Windows: Microsoft's Roslyn LSP (seblyng/roslyn.nvim, see plugins/lsp.lua)
--   everywhere else (WSL/Linux/macOS): csharp-ls (installed via mason)
--
-- One-time Unity Editor setup required (per project):
--   Edit > Preferences > External Tools > "Generate .csproj files for..."
--   Enable it for all categories, and regenerate (Assets > Open C# Project,
--   or just let Unity regenerate on script/package changes) whenever
--   packages or asmdefs change, so the .sln/.csproj the LSP reads stays
--   current.
--
-- Unity Editor integration (double-click-to-open-at-line, live debugging) is
-- Windows-only, handled entirely Unity-side via walcht/com.walcht.ide.neovim
-- (Unity's External Tools preferences) and walcht/unity-dap (see
-- unity_dap.lua). WSL intentionally has none of this, since the Unity Editor
-- itself only runs on Windows.

local M = {}

function M.setup(capabilities)
  if vim.fn.has('win32') == 1 then
    return -- Roslyn is configured by the roslyn.nvim plugin spec (see plugins/lsp.lua);
           -- it self-attaches via its own root/ft detection, no manual vim.lsp.enable needed here.
  end

  vim.lsp.config('csharp_ls', { capabilities = capabilities })
  vim.lsp.enable('csharp_ls')
end

return M
