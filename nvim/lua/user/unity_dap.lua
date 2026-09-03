-- Live debugging against a running Unity Editor (Mono soft-debugger), via
-- walcht/unity-dap. Windows only, since Unity Editor only runs there.
--
-- Setup (Windows, one-time):
--   1. Download the win-x64 release asset from
--      https://github.com/walcht/unity-dap/releases and extract
--      unity-debug-adapter.exe somewhere stable, e.g.
--      %LOCALAPPDATA%\unity-dap\unity-debug-adapter.exe. Update the
--      `command` path below to match.
--   2. With the Unity Editor running and Play mode active, trigger dap
--      attach and pick "Attach to Unity Editor [Mono]". The port is in
--      Unity's Editor.log (--debugger-agent=...address=127.0.0.1:<port>).
--
-- Editor/Mono-player debugging only -- IL2CPP is permanently out of scope
-- by unity-dap's own design.

local M = {}

function M.setup()
  if vim.fn.has('win32') ~= 1 then
    return
  end

  local dap = require('dap')

  dap.adapters.unity = function(cb, _config)
    cb({
      type = 'executable',
      command = 'unity-debug-adapter.exe', -- adjust to the extracted path
      args = { '--log-level=warn' },
    })
  end

  dap.configurations.cs = dap.configurations.cs or {}
  table.insert(dap.configurations.cs, {
    name = 'Attach to Unity Editor [Mono]',
    type = 'unity',
    request = 'attach',
    host = function()
      return vim.fn.input('Unity Editor host: ', '127.0.0.1')
    end,
    port = function()
      return tonumber(vim.fn.input('Unity Editor port (see Editor.log): '))
    end,
  })
end

return M
