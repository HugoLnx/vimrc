# Solutions: C# LSP, AI tooling, and Unity Editor integration for Neovim

Synthesized from `research/01-csharp-lsp-servers.md`, `research/02-ai-tool-integration.md`,
`research/03-unity-editor-integration.md`, and `research/04-roslyn-windows-bridge.md`.
This repo is deployed identically to WSL-ubuntu/bash and native Windows/PowerShell;
Unity Editor itself only runs on the Windows side.

---

## 1. C# LSP server

| Option | Feature depth | WSL+Windows parity | Maintenance | Verdict |
|---|---|---|---|---|
| **`seblyng/roslyn.nvim`** (Microsoft Roslyn LSP) | Highest — first-party MS project system, richer analyzers/code-lens/inlay-hints, multi-target switching | **Broken for Unity when run inside WSL2**: Unity's Windows-generated `.csproj` embeds `C:\...` paths a Linux-hosted Roslyn process can't resolve (confirmed root cause + accepted fix in `roslyn.nvim` issue #266). A full-fidelity fix exists (see "WSL parity options" below) but adds real operational risk. Works cleanly if Neovim is also native Windows. | Active (weekly-ish commits) | Best LSP quality, but **not "just works" identically on both OSes** without extra plumbing |
| **`csharp_ls`** (current setup) | Smaller opt-in surface (analyzers off by default, needs `csharpls-extended-lsp.nvim` for decompiled sources, no multi-solution picker) — largely a non-issue for Unity's single-`.sln` layout | No confirmed WSL/Windows-Unity-path bug reports, but **unverified, not proven immune** (same MSBuild/HintPath machinery) | Active — commits within days of research, ongoing perf work | Simplest to keep working identically everywhere; "lightweight" impression may partly be `analyzersEnabled=false` default, not an inherent gap |
| **OmniSharp** | Roslyn-based but older framework; no first-party MS investment | Same per-OS manual-binary friction as roslyn.nvim; untested against Unity/WSL path issue | Declining — OmniSharp's own maintainer and the `walcht/neovim-unity` guide both recommend avoiding it | Not recommended |

**Recommendation:** Keep `csharp_ls` as the default everywhere (matches the existing
auto-skip/opt-out pattern in `lsp.lua`/`unity.lua`, requires no new cross-OS bridging).
Layer in `seblyng/roslyn.nvim` **only when Neovim is running natively on Windows**
(`vim.fn.has('win32') == 1`, via lazy.nvim's `cond` field), since that's the one
environment where Roslyn "just works" without the WSL path-translation problem — this
mirrors the repo's existing per-machine capability detection (`dotnet` on PATH,
`config.yml`'s `csharp_lsp` flag) rather than introducing an all-or-nothing swap. Turn
on `csharp.analyzersEnabled = true` for `csharp_ls` first and re-evaluate whether the
"lightweight" gap still matters before committing to dual-LSP complexity.

### WSL parity options for `roslyn.nvim` — bridge vs. Windows-only (deep dive)

The Windows-path bug above can, in principle, be fully closed even for WSL by *not*
running a second Roslyn instance in WSL at all, and instead having WSL's Neovim talk
to the single Windows-native Roslyn process over a TCP bridge
(`walcht/LSP-TCP-socket-adapter`). Two candidate architectures were compared in depth
(`research/04-roslyn-windows-bridge.md`):

| | Architecture A — TCP-bridge (shared Windows-native Roslyn) | Architecture B — Windows-only Roslyn (WSL keeps `csharp_ls`) |
|---|---|---|
| **Mechanism** | `walcht/LSP-TCP-socket-adapter` runs on Windows, spawns Roslyn LS as a stdio child process, exposes it over a TCP socket, and rewrites WSL↔Windows path URIs in transit. WSL-side Neovim connects via Neovim's *built-in* `vim.lsp.rpc.connect(host, port)` as the LSP `cmd` — no `nc`/`socat` needed. | `roslyn.nvim` plugin spec gated with `cond = function() return vim.fn.has('win32') == 1 end`; WSL2 simply never activates it and keeps using `csharp_ls`, fully local and independent. |
| **One-time setup** | Higher: build/download the adapter `.exe`, discover the WSL2 NAT gateway IP (or set up Windows' newer "mirrored" WSL networking mode), wire a non-standard `cmd` into `roslyn.nvim`'s config (the exact `roslyn.nvim`-specific integration point for overriding `cmd` isn't documented — would need empirical verification). | Low: one `cond` predicate. Mason's `Crashdummyy/mason-registry` `roslyn` package already lists both `linux_x64` and `win_x64` targets, so running the same `mason.setup()`/`ensure_installed` unconditionally on both OSes installs the right binary per-OS with no error — only `roslyn.nvim`'s *activation* needs gating, not the Mason install. |
| **Per-session friction** | High: the adapter is a **manually-run foreground process with no documented service/scheduled-task/persistence story** — confirmed absent from all sources checked, not an assumption. | None beyond normal `roslyn.nvim` startup. |
| **Failure blast radius** | A third process plus a network hop WSL now depends on for *all* WSL C# LSP support. No documented reconnect behavior if the adapter dies, Windows sleeps, or the discovered NAT IP goes stale after a reboot — WSL loses Roslyn entirely until manually noticed and restarted. | None: WSL's `csharp_ls` is unaffected by anything on the Windows side. |
| **Maturity** | Adapter is ~3 months old (built Dec 2025), author's own "performance is similar to native" claim is explicitly caveated as "not tested thoroughly," and the author tried Unix domain sockets first and had to fall back to TCP because that didn't work. **Zero independent field reports** of sustained day-to-day use were found beyond the two GitHub issue threads where it was invented. | Both halves are already-vetted, stable approaches (this repo's own prior research covers `csharp_ls` on WSL; `cond` is a long-documented lazy.nvim primitive). |

**Recommendation: Architecture B (Windows-only, no bridge).** For a single-maintainer
personal dotfiles setup, the bridge trades a one-line `cond` gate for an ongoing
operational dependency that, when it breaks, breaks *all* WSL C# LSP support with no
auto-recovery — a worse failure mode than WSL simply staying on `csharp_ls`'s smaller
feature set. The fidelity gain is real but doesn't outweigh that risk today. Revisit
the bridge once it gains a persistence/reconnect story and some field validation, and
note that adopting B now doesn't foreclose adding A later — Architecture A is purely
additive on top of B, not a replacement for it.

---

## 2. AI tool integration

| Tool | Status | Action |
|---|---|---|
| **Supermaven** (`supermaven-nvim`) | **Sunset by Cursor/Anysphere on Nov 21, 2025.** Free inference continues for existing Neovim users, but no further development and no agent-conversation support. | Flag to user as end-of-life; not worth new investment. Keep running as-is (it still works) or plan a future replacement (e.g. a `blink.cmp` source backed by another provider) — a decision for the user, not made here. |
| **`claudecode.nvim`** (current) | Actively maintained, de facto standard for driving `claude` CLI from Neovim. Its MCP `getDiagnostics` bridge is the **only** place LSP choice reaches an AI tool at all (Claude Code CLI hardcodes its IDE-tool allowlist down to `getDiagnostics` + `executeCode`) — a narrow, real, but small benefit from a better LSP. | Keep as-is. |
| **`codex-cli` integration** (new) | No plugin matches `claudecode.nvim`'s maturity yet. Two narrow `codex.nvim` projects exist (`nwiizo/codex.nvim` — Linux/macOS only, ~7 stars, too new; `johnseth97/codex.nvim` — 258 stars, plain terminal-toggle, no ACP). The more future-proof path is **`olimorris/codecompanion.nvim`**'s built-in `codex` ACP adapter (backed by OpenAI's own `codex-acp` bridge), which could also absorb Claude Code under one plugin — but that's a bigger architectural swap than "add codex," not decided here. | Two viable paths, user's choice: **(a)** low-risk: plain terminal/tmux pane running `codex` CLI (zero plugin risk, works today); **(b)** higher-investment: adopt `codecompanion.nvim` with ACP adapters for both `codex` and `claude_code`, potentially retiring `claudecode.nvim`. Do **not** adopt `johnseth97/codex.nvim` or `nwiizo/codex.nvim` as a bolt-on third plugin — both are low-adoption/narrow and would just add keymap-namespace risk (`<leader>a*` collision with existing Claude Code bindings) for little gain over the terminal fallback. |

**Recommendation:** No LSP-driven reason to prefer roslyn.nvim over csharp_ls for AI
tooling (the one connected channel, `getDiagnostics`, is a minor win, not decisive).
For codex-cli, start with the zero-risk terminal/tmux fallback; revisit
`codecompanion.nvim` later as a deliberate, separate decision if the user wants to
consolidate all AI agents under one plugin.

---

## 3. Unity Editor integration (Windows/PowerShell only)

| Project | What it does | Solves the `unity.lua` open-at-line TODO? | Maintenance |
|---|---|---|---|
| **`apyra/nvim-unity`** | Unity-side External Script Editor package; click-to-open, "Regenerate Project Files" button, prebuilt Windows/.exe installer | Click-to-open only documented; jump-to-line **not documented** (mechanism undisclosed/proprietary). One field report of import errors assuming NvChad. | Active (Apr 2026) |
| **`apyra/nvim-unity-sync`** | Pure-Lua Neovim plugin keeping `.csproj` `<Compile>` entries in sync as `.cs` files are added/renamed/deleted from Neovim, without needing Unity focused | No — doesn't touch open/jump behavior at all; solves a different problem (LSP seeing new files before Unity regenerates) | Slower (Oct 2025, "early development") |
| **`walcht/com.walcht.ide.neovim`** (via the `walcht/neovim-unity` guide) | Unity-side External Script Editor package that explicitly implements `nvim --server {socket} --remote-tab {file}` (open) and `nvim --server {socket} --remote-send ":call cursor({line},{column})<CR>"` (jump-to-line), with Windows defaults: loopback TCP socket on a random port (no firewall/registry setup needed), Win32-API window focus, recommended Windows Terminal + PowerShell | **Yes — unambiguously**, this is exactly the mechanism the TODO describes | Active (Mar 2026) |

**Recommendation:** Adopt **`walcht/com.walcht.ide.neovim`** to close the `unity.lua`
TODO — it's the only project whose documented mechanism matches what the TODO already
names (`nvim --server`/`--remote`), needs no WSL bridging since Unity + this Neovim
instance are both native Windows, and its recommended terminal (Windows Terminal +
PowerShell) matches this repo's target shell. Optionally add **`apyra/nvim-unity-sync`**
alongside it later if "Unity doesn't see files created in Neovim until refocused"
becomes a real pain point — it's small, independent, and additive; not needed for the
open-at-line TODO itself. Skip `apyra/nvim-unity`: its jump-to-line support is
unconfirmed and its own field reports raise config-compatibility concerns.

---

## Combined recommended solution

1. **LSP**: Keep `csharp_ls` everywhere (no change needed to close this out); add
   `seblyng/roslyn.nvim` gated to native-Windows-only Neovim (`cond` on `vim.fn.has('win32')`)
   as a later enhancement. Do **not** pursue the WSL↔Windows TCP bridge
   (`walcht/LSP-TCP-socket-adapter`) at this time — it's real but too immature
   (no persistence/reconnect story, ~3 months old, no independent field reports) for
   a personal dotfiles setup; revisit later if it matures.
2. **AI tools**: Keep `claudecode.nvim` and Supermaven as-is (flag Supermaven's sunset to
   the user); add `codex` CLI via a plain terminal/tmux workflow, no new plugin yet.
3. **Unity Editor integration**: Add `walcht/com.walcht.ide.neovim` (Windows-only, via
   Unity Package Manager) to finally close the `unity.lua` open-at-line TODO.

See `plan.md` for the concrete execution steps.
