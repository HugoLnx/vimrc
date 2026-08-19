-- Unity/C# support: wires up csharp-ls (installed via mason) so opening a
-- Unity project's .cs files gets completion/diagnostics/go-to-def.
--
-- One-time Unity Editor setup required (per project):
--   Edit > Preferences > External Tools > "Generate .csproj files for..."
--   Enable it for all categories, and regenerate (Assets > Open C# Project,
--   or just let Unity regenerate on script/package changes) whenever
--   packages or asmdefs change, so the .sln/.csproj csharp-ls reads stays
--   current.
--
-- TODO: double-click-to-open-at-line from the Unity Editor into a running
-- Neovim instance (via `nvim --server`/`--remote`) is not wired up yet.
-- For now, Unity's External Script Editor can stay pointed at VS Code/Rider
-- for that convenience; editing itself happens in Neovim.

local M = {}

function M.setup(lspconfig, capabilities)
  lspconfig.csharp_ls.setup({
    capabilities = capabilities,
  })
end

return M
