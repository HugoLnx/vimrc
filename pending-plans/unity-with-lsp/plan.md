# Plan: split C# LSP + Unity integration by OS (Windows/Roslyn+Unity vs. WSL/csharp_ls-only)

> **Supersedes the original scope of this plan.** The original version of
> this file (see git history) considered *layering* `roslyn.nvim` on top of
> `csharp_ls`, a WSL↔Windows TCP bridge (`walcht/LSP-TCP-socket-adapter`),
> AI-tool integration (codex-cli, Supermaven), and Unity Editor integration
> as one bundled pass. The current scope, set explicitly by the user, is
> narrower and final for these pieces:
>
> - **Windows/PowerShell** (Unity Editor runs here): Microsoft's Roslyn LSP,
>   running natively, no WSL bridge, plus Unity Editor → Neovim integration
>   (open-at-line via `com.walcht.ide.neovim`) and live debugging (attach via
>   `walcht/unity-dap`).
> - **WSL/Ubuntu/bash**: `csharp_ls` only, no Unity Editor integration, no
>   debugging integration.
>
> AI-tool integration and Supermaven's sunset (originally steps 4–5 of this
> plan) are out of scope here — see `solutions.md`'s section 2 if revisited
> later as a separate decision.

Source material: `research/01-csharp-lsp-servers.md`,
`research/03-unity-editor-integration.md`, `research/04-roslyn-windows-bridge.md`,
synthesized in `solutions.md`. Re-verified this session (2026-09-02) with a
fresh direct fetch of the `apyra/nvim-unity` and `walcht/com.walcht.ide.neovim`
READMEs — no material contradictions found versus the original research,
except one open item flagged in Step 3 below.

## Scope decisions

- **No dual-LSP, no bridge.** Windows uses Roslyn exclusively; WSL uses
  `csharp_ls` exclusively. The TCP bridge (`walcht/LSP-TCP-socket-adapter`)
  considered in `research/04-roslyn-windows-bridge.md` is explicitly not
  adopted — WSL simply never touches Roslyn.
- **`seblyng/roslyn.nvim`** (not bare `nvim-lspconfig`'s built-in `roslyn`
  definition) is the chosen Windows-side plugin — user's explicit choice,
  for its multi-solution/target switching, `broad_search` root detection,
  and source-generated-file support on top of raw lspconfig.
- **`walcht/com.walcht.ide.neovim`** (not `apyra/nvim-unity`) is the chosen
  Unity-side package to close the `unity.lua` open-at-line TODO — it's the
  only one of the three Unity-integration projects researched whose
  documentation explicitly implements jump-to-line via
  `nvim --server {socket} --remote-send ":call cursor({line},{column})<CR>"`,
  re-confirmed via a fresh fetch of its current README this session.
  `apyra/nvim-unity`'s README (also re-fetched fresh) still only documents
  "opens when clicked," no jump-to-line/cursor-position mention.

## Step 1 — Split `nvim/lua/user/unity.lua` by OS

Replace the single shared `csharp_ls` wiring with an OS branch:

```lua
function M.setup(capabilities)
  if vim.fn.has('win32') == 1 then
    return -- Roslyn is configured by the roslyn.nvim plugin spec (see plugins/lsp.lua);
           -- it self-attaches via its own root/ft detection, no manual vim.lsp.enable needed here.
  end

  vim.lsp.config('csharp_ls', { capabilities = capabilities })
  vim.lsp.enable('csharp_ls')
end
```

Update the file's top comment block: remove the "double-click-to-open-at-line
... not wired up yet" TODO and replace with a short note that Unity Editor
integration is Windows-only, handled entirely on the Unity side via
`walcht/com.walcht.ide.neovim` (Unity's `External Tools` preferences), and
that WSL intentionally has no Unity Editor integration.

## Step 2 — Add `seblyng/roslyn.nvim`, Windows-gated, in `nvim/lua/user/plugins/lsp.lua`

- In the `mason.setup({...})` call, add the community registry (no official
  Mason package for Roslyn exists yet):
  ```lua
  require('mason').setup({
    registries = {
      'github:mason-org/mason-registry',
      'github:Crashdummyy/mason-registry',
    },
  })
  ```
- Add `'roslyn'` to `ensure_installed` only when on native Windows (mirror
  the existing `csharp_lsp_enabled` gating pattern, but flip it: `csharp_ls`
  installs only when **not** Windows, `roslyn` installs only when Windows):
  ```lua
  local is_windows = vim.fn.has('win32') == 1
  local csharp_lsp_enabled = not (ok and local_config.csharp_lsp == false)
    and vim.fn.executable('dotnet') == 1

  local ensure_installed = { 'lua_ls', 'gopls' }
  if csharp_lsp_enabled and not is_windows then
    table.insert(ensure_installed, 'csharp_ls')
  end
  if csharp_lsp_enabled and is_windows then
    table.insert(ensure_installed, 'roslyn')
  end
  ```
- Keep `csharp_ls` excluded from `automatic_enable` (unity.lua still enables
  it manually on non-Windows) and add `roslyn` to the same exclude list —
  `roslyn.nvim`'s own plugin setup manages attachment, so mason-lspconfig
  shouldn't also try to auto-enable it:
  ```lua
  automatic_enable = { exclude = { 'csharp_ls', 'roslyn' } },
  ```
- Add the plugin spec (new entry in the array this file returns), gated with
  lazy.nvim's `cond` (not `enabled`, so the plugin stays installed/lockfile-
  consistent across the WSL and Windows checkouts of this repo, just inert
  on WSL):
  ```lua
  {
    'seblyng/roslyn.nvim',
    cond = function() return vim.fn.has('win32') == 1 end,
    ---@module 'roslyn.config'
    ---@type RoslynNvimConfig
    opts = {
      filewatching = 'auto',
      broad_search = false,
    },
  },
  ```
- Requires Neovim ≥0.12 on the Windows side — confirm the installed Neovim
  version there before enabling; `roslyn.nvim`'s Makefile shows this was a
  breaking bump from an older 0.10+ floor.

Verification: on native Windows, open a Unity `.cs` file, run `:LspInfo` and
confirm `roslyn` (not `csharp_ls`) is attached, and that `UnityEngine`/custom
project types resolve (not just BCL types — this is exactly the failure mode
`seblyng/roslyn.nvim#266` describes if something's misconfigured). On WSL,
confirm `csharp_ls` still attaches and `roslyn.nvim` never loads (`:Lazy`
shows it skipped via `cond`).

## Step 3 — Unity Editor → Neovim integration (Windows only, Unity-side)

1. In Unity: Package Manager → "Install package from git URL" →
   `https://github.com/walcht/com.walcht.ide.neovim.git`. Restart Unity;
   confirm "Neovim" appears under `Edit > Preferences > External Tools` and
   select it as the external script editor.
2. In Unity's `Neovim -> Settings` panel: use the Windows defaults (loopback
   TCP socket, random port) and set the terminal to **Windows Terminal (`wt`)
   with PowerShell**.
3. **Open item to verify hands-on (sources disagree):** the deep prior
   research (`research/03-unity-editor-integration.md`) says the Neovim side
   must be launched with a matching `--listen`/server socket for the Unity
   package to find it; a fresh direct fetch of the current README this
   session instead describes the package as managing "server connections
   through IPC sockets without requiring manual `--server`/`--listen` setup."
   Don't guess which is current — check the package's actual
   `Neovim -> Settings` panel and README once installed, and adjust however
   Neovim is normally launched on the Windows side only if a matching
   `--listen` turns out to still be required.
4. No lazy.nvim plugin needed for this feature — it's entirely driven from
   the Unity-side C# package shelling out to `nvim --server ... --remote-tab`
   / `--remote-send`.

Verification (Windows, real Unity project): double-click a `.cs` file in
Unity's Project window → opens in the running Neovim instance. Double-click a
compiler error in the Console → cursor jumps to the exact line/column.
Restart Unity Editor and confirm it reconnects to the same Neovim server
instance without reconfiguring (Unity persists the target via
`EditorPrefs`).

## Step 4 — Add `walcht/unity-dap` live debugging (Windows only)

Source: `research/05-unity-debugging.md`, decision recorded in `solutions.md`
section 4. Chosen over `ownself/nvim-dap-unity` specifically to avoid that
tool's unresolved `vstuc` licensing question — `unity-dap` is MIT-licensed
and shares its author/ecosystem with the already-adopted
`com.walcht.ide.neovim`. Trade-off accepted: Editor/Mono-player debugging
only, no IL2CPP (permanently out of scope by the author's own design), and
this is manual `nvim-dap` wiring — no Neovim plugin automates the install
the way `nvim-dap-unity` does for `vstuc`.

1. **Neovim side prerequisite**: `mfussenegger/nvim-dap` must already be a
   plugin in this repo (add it via lazy.nvim if not present — check
   `nvim/lua/user/plugins/` first).
2. **Download the debug adapter** (Windows): grab the `win-x64` asset from
   `https://github.com/walcht/unity-dap/releases` (latest at last check:
   `v0.1.0`) and extract `unity-debug-adapter.exe` somewhere stable, e.g.
   `%LOCALAPPDATA%\unity-dap\unity-debug-adapter.exe`. Confirm Mono is on
   PATH on the Windows side (Unity ships its own Mono; verify the adapter
   can find/use it — check `unity-dap`'s README if it fails to start).
3. **New file**: `nvim/lua/user/unity_dap.lua` (Windows-gated, parallel to
   how `unity.lua` now branches on `vim.fn.has('win32')`), wiring the
   adapter and an "attach to Unity Editor" configuration per the
   `walcht/neovim-unity` guide's documented snippet:
   ```lua
   local M = {}

   function M.setup()
     if vim.fn.has('win32') ~= 1 then
       return
     end

     local dap = require('dap')

     dap.adapters.unity = function(cb, config)
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
       -- address/port: prompt manually, or wire up automatic discovery per
       -- the walcht/neovim-unity guide's try_get_unity_editor_ip_port()
       -- helper (parses Editor.log / derives 56000 + PID % 1000 on Windows
       -- via PowerShell) once the manual flow is confirmed working.
     })
   end

   return M
   ```
   Start with the manual address/port entry (prompt via `vim.ui.input`, as
   shown in the guide) to get attach working end-to-end first; only add the
   automatic port-discovery helper as a follow-up once basic attach is
   confirmed, since that helper's exact Windows implementation wasn't fully
   captured in this research pass.
4. Wire `require('user.unity_dap').setup()` into wherever `nvim-dap` is
   configured (alongside/after the plugin's own `require('dap')` setup),
   gated the same way `unity.lua`'s csharp_ls/roslyn split already is.

Verification (Windows, real Unity project): with the Unity Editor running
and a project open, trigger `dap` attach (`:DapContinue` or the repo's bound
debug keymap once one exists) → select "Attach to Unity Editor [Mono]" →
enter `127.0.0.1` and the port found in Unity's `Editor.log`
(`--debugger-agent=...address=127.0.0.1:<port>`, discoverable via Windows
PowerShell per the guide) → confirm a breakpoint set in a `MonoBehaviour`
script is hit when that code path runs in Play mode.

## Overall verification checklist

- [ ] Windows: `:LspInfo` shows `roslyn` attached on a Unity `.cs` file;
      `UnityEngine`/custom types resolve.
- [ ] Windows: `roslyn.nvim` requires Neovim ≥0.12 — confirmed before/after.
- [ ] WSL: `csharp_ls` still attaches exactly as before; `roslyn.nvim` never
      loads (`cond` returns false).
- [ ] Windows: double-click-to-open and jump-to-line work via
      `com.walcht.ide.neovim`; confirmed persistence across Unity restarts.
- [ ] WSL: no Unity Editor integration present or attempted (by design).
- [ ] `unity.lua`'s TODO comment removed/updated to reflect the new split.
- [ ] Windows: `walcht/unity-dap` attaches to a running Unity Editor and
      breakpoints in Mono-debuggable Play-mode code are hit.
- [ ] WSL: no debugging integration present or attempted (Unity Editor
      doesn't run there; by design).
