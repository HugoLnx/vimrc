# Plan: close the Unity/C# LSP + AI + Unity-Editor integration gaps

Source material: `research/01-csharp-lsp-servers.md`, `research/02-ai-tool-integration.md`,
`research/03-unity-editor-integration.md`, synthesized in `solutions.md`. This plan is
written to be executable by a future session without re-deriving the research.

## Scope decisions (already made in `solutions.md`)

- Keep `csharp_ls` as the cross-platform default LSP. Do **not** switch wholesale to
  `roslyn.nvim` — it breaks Unity IntelliSense under WSL2 (Windows-path resolution bug,
  `seblyng/roslyn.nvim#266`).
- Do not add a codex-cli Neovim plugin yet — use the plain `codex` CLI from a terminal
  split/tmux pane. Revisit `codecompanion.nvim` later as a separate, deliberate decision.
- Flag Supermaven's Nov 2025 sunset to the user; no code change forced by this today.
- Add `walcht/com.walcht.ide.neovim` (Windows-only) to close the `unity.lua` open-at-line
  TODO.

## Step 1 — Turn on `csharp_ls` analyzers to close the "lightweight" gap

File: `nvim/lua/user/unity.lua`

Add `settings` to the `vim.lsp.config('csharp_ls', ...)` call to enable analyzers
(currently off by default per `csharp_ls` docs):

```lua
function M.setup(capabilities)
  vim.lsp.config('csharp_ls', {
    capabilities = capabilities,
    settings = {
      csharp = {
        analyzersEnabled = true,
      },
    },
  })
  vim.lsp.enable('csharp_ls')
end
```

Verification: open a Unity `.cs` file, confirm analyzer-driven diagnostics appear
(e.g. unused-usings, naming-convention warnings) that weren't showing before. Do this
on both WSL and Windows to confirm no regression/perf cliff before moving on.

## Step 2 — (Optional, later) Add `roslyn.nvim` gated to native Windows only

Only pursue this if Step 1's analyzer-enabled `csharp_ls` still feels insufficient.
Deep-dive research (`research/04-roslyn-windows-bridge.md`) confirmed this
Windows-only, no-bridge architecture over the alternative of bridging WSL to a
shared Windows-native Roslyn instance over TCP (`walcht/LSP-TCP-socket-adapter`) —
that bridge is real and reportedly performant, but is ~3 months old, has no
persistence/reconnect story (a manually-run foreground `.exe` with no documented
service/scheduled-task wrapper), and has zero independent field reports. Its failure
mode (WSL loses Roslyn entirely, no auto-recovery) outweighs its fidelity gain for a
personal dotfiles setup. Not adopted now; revisit if the adapter matures.

File: `nvim/lua/user/plugins/lsp.lua`

- Add `seblyng/roslyn.nvim` as a lazy.nvim plugin spec, gated with the plugin spec's
  `cond` field (confirmed via lazy.nvim's official docs — `cond` disables *loading*
  per-OS without uninstalling the plugin, unlike `enabled`, which keeps a shared
  lockfile consistent across the WSL and Windows checkouts of this repo):
  ```lua
  {
    'seblyng/roslyn.nvim',
    cond = function() return vim.fn.has('win32') == 1 end,
    opts = {},
  }
  ```
- Requires: Neovim >= 0.12 on the Windows side, .NET SDK, and the Roslyn LSP binary —
  install via Mason with the community registry (`Crashdummyy/mason-registry`), added
  in the `mason.setup({ registries = {...} })` call. That registry's `roslyn` package
  lists both `linux_x64` and `win_x64` targets, so `ensure_installed = {"roslyn"}` can
  run unconditionally on both OSes without erroring — Mason just installs the
  OS-matching binary on each side (WSL's copy goes unused, which only costs disk
  space); only the plugin's `cond` needs to be Windows-gated, not the Mason install.
- Do **not** enable this on the WSL side and do **not** pursue the TCP bridge — leave
  `csharp_ls` as the WSL fallback, per the confirmed WSL2 path-resolution bug.
- `config.yml` may need a new toggle (e.g. `csharp_lsp_roslyn: true|false`) alongside
  the existing `csharp_lsp` flag if per-machine opt-out is wanted, following the same
  `install/symlink.py` → `nvim/lua/user/local.lua` generation mechanism already used
  for `csharp_lsp`.

Verification: on native Windows, open a Unity project, confirm `:LspInfo` shows
`roslyn` attached, `UnityEngine`/custom types resolve (not just BCL types), and
`:Roslyn target` picks the right `.sln`. On WSL, confirm `csharp_ls` is still the one
that attaches (no accidental roslyn.nvim activation).

## Step 3 — Add Unity Editor → Neovim open-at-line integration (Windows only)

1. **Unity side**: install `walcht/com.walcht.ide.neovim` via Unity Package Manager →
   "Install package from git URL" → `https://github.com/walcht/com.walcht.ide.neovim.git`.
   Restart Unity Editor; confirm "Neovim" appears under
   `Edit > Preferences > External Tools`. Select it as the external script editor.
2. **Configure the command templates** in Unity's `Neovim -> Settings` panel: use the
   package's Windows defaults (loopback TCP socket `127.0.0.1:<random-port>`, no
   firewall changes needed) and the recommended terminal: **Windows Terminal (`wt`)
   with PowerShell** as the default shell — matches this repo's target shell.
3. **Neovim side**: no plugin manager install needed for the core feature (it's driven
   entirely by the Unity-side C# package shelling out to `nvim --server ... --remote-tab`
   / `--remote-send`). Just ensure Neovim is launched with a named server socket
   matching what the Unity package expects (`nvim --listen <socket>` or equivalent),
   documented in the package's README — wire this into whatever script/alias currently
   launches Neovim for Unity work on Windows.
4. Update `nvim/lua/user/unity.lua`'s comment block: remove the now-resolved TODO
   ("double-click-to-open-at-line... is not wired up yet") and replace with a short
   note pointing at `walcht/com.walcht.ide.neovim` and where its settings live (Unity's
   `External Tools` preferences, not this repo's config, since the feature is entirely
   driven from the Unity side).
5. Update `install/symlink.py` / `config.yml` only if the Neovim server-socket launch
   convention needs to be codified per-machine (e.g. a `--listen` flag added to a
   Windows launcher script under `install/`); otherwise no repo config changes needed
   beyond the comment update.

Verification (Windows only, real Unity project): double-click a `.cs` file in Unity's
Project window → confirms it opens in the running Neovim instance. Double-click a
compiler error in the Console → confirms cursor jumps to the exact line/column. Restart
Unity Editor and confirm it reconnects to the same Neovim server instance without
reconfiguring.

## Step 4 — codex-cli (no plugin, documentation-only for now)

No code change. Document for the user (e.g. in this repo's README or a note) that
`codex` CLI works today from a plain terminal split/tmux pane on both WSL and Windows,
same as `claude` CLI predates its `claudecode.nvim` integration. Revisit
`olimorris/codecompanion.nvim` (ACP adapters for both `codex` and `claude_code`) as a
separate future decision if the user wants to consolidate AI-agent plugins — this is
an architecture change (potentially retiring `claudecode.nvim`), not a small addition,
so it should get its own planning pass rather than being bundled here.

## Step 5 — Flag Supermaven's sunset to the user

No code change required — `supermaven-nvim` continues to work (free inference for
existing users per Cursor/Anysphere's Nov 21, 2025 announcement). Note in this repo's
README or a comment in `nvim/lua/user/plugins/supermaven.lua` that the upstream
project is sunset and agent-conversation features won't gain further support, so a
future replacement may be needed — left as a user decision, not actioned here.

## Overall verification checklist

- [ ] `csharp_ls` analyzers enabled and confirmed working on both WSL and Windows.
- [ ] (If Step 2 pursued) `roslyn.nvim` attaches and resolves `UnityEngine` types on
      native Windows; WSL still uses `csharp_ls` unaffected.
- [ ] Unity double-click-to-open and jump-to-line work via `com.walcht.ide.neovim` on
      Windows.
- [ ] `unity.lua`'s TODO comment updated/removed to reflect the new integration.
- [ ] `claudecode.nvim`, Supermaven, and (if added later) any codex integration still
      load without keymap collisions (`<leader>a*` namespace check).
