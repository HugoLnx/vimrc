# vimrc

Personal editor config: a shared base for classic Vim and a full modern setup
for Neovim, working on Windows, Linux, and macOS.

## Layout

```
vim/vimrc            shared config, sourced by BOTH `vim` and `nvim`
vim/plugins.vim       classic-Vim-only plugin list (vim-plug); never loaded by Neovim
vim/syntax/html/*     HTML5/ARIA/RDFa syntax files for classic Vim (Neovim gets this via treesitter)
nvim/init.lua         Neovim entrypoint: sources vim/vimrc, then bootstraps lazy.nvim + Lua plugins
nvim/lua/user/        Neovim-only Lua config (options, keymaps, plugins, LSP, Unity)
repo-configs/         .gitignore/.gitattributes templates + apply.sh, symlinked to each home
_config.sample.yml    versioned template for config.yml
config.yml            your home-directory paths (gitignored, not versioned)
install/enforce.py    label-based, current-OS-only configuration enforcer (the real entry point)
install/aspects.py    label registry, OS detection, per-label file layouts
install/fs.py         link/copy/backup helpers shared by the aspects
install/agentic.py    Claude/Codex/shell sync used by the agentic-* labels
install/install.sh    thin launcher for Ubuntu/WSL/macOS (forwards args to enforce.py)
install/install.ps1   thin launcher for Windows PowerShell
install/install.cmd   thin launcher for Windows cmd (calls install.ps1)
install/symlink.py    deprecated shim that forwards to enforce.py
install/windows_env.ps1  Windows env setup for the agentic tooling (pwsh, env var, PATH)
agentic/              Claude/Codex status line + ralph-loop shell helpers
```

`vim/vimrc` never references Lua or a plugin manager, so it's safe to source
from both editors. Plugin management is fully separate per editor: classic
Vim uses vim-plug (`vim/plugins.vim`), Neovim uses lazy.nvim
(`nvim/lua/user/plugins/`).

## Dependencies

This repo's installer enforces config files (symlinks/copies/merges) and
installs editor plugins; the external tools below are assumed to already be on PATH.

**Both platforms:**

- [Git](https://git-scm.com/downloads)
- [Neovim](https://github.com/neovim/neovim/blob/master/INSTALL.md) —
  `roslyn.nvim` needs ≥0.12 — plus, optionally, classic
  [Vim](https://www.vim.org/download.php)
- [Python 3](https://www.python.org/downloads/) and
  [PyYAML](https://pypi.org/project/PyYAML/) — used by `install/enforce.py`
- A C compiler and the [tree-sitter
  CLI](https://github.com/tree-sitter/tree-sitter/tree/master/cli)
  (`npm install -g tree-sitter-cli`) — needed to build treesitter parsers
  (`:TSUpdate`); see [nvim-treesitter's
  requirements](https://github.com/nvim-treesitter/nvim-treesitter#requirements)
- [ripgrep](https://github.com/BurntSushi/ripgrep#installation) — Telescope
  live-grep and ctrlp.vim's grep integration
- [Go](https://go.dev/doc/install) — `gopls`, installed automatically via
  mason.nvim
- [.NET SDK](https://dotnet.microsoft.com/en-us/download) — `csharp_ls` /
  `roslyn`, also installed via mason.nvim; without `dotnet` on PATH the C#
  LSP is silently skipped (see `nvim/lua/user/plugins/lsp.lua`)
- [git-lfs](https://git-lfs.com/) — used by the shared `gitconfig`'s LFS
  filter

See mason.nvim's own
[requirements](https://github.com/williamboman/mason.nvim#requirements) for
the baseline tools (unzip/tar, curl or wget, etc.) it needs to install and
manage LSP/DAP packages.

**Optional:**

- [make](https://www.gnu.org/software/make/) — builds Telescope's optional
  `telescope-fzf-native` perf extension (skipped automatically if absent)
- [tmux](https://github.com/tmux/tmux/wiki/Installing) — only used by
  `vim-tmux-navigator`, which is only loaded on Linux (incl. WSL); a
  no-op without it

**Windows/PowerShell only** (see "Unity / C#" below for how these fit
together):

- [Unity Editor](https://unity.com/download) (via Unity Hub)
- [walcht/com.walcht.ide.neovim](https://github.com/walcht/com.walcht.ide.neovim) —
  installed manually into a Unity project via the Package Manager
- [walcht/unity-dap](https://github.com/walcht/unity-dap/releases) — the
  `win-x64` adapter binary is downloaded manually from its releases page

## Install

```sh
# Ubuntu / WSL / macOS
./install/install.sh
```

```powershell
# Windows (run in PowerShell)
./install/install.ps1
```

The installer is label-based. With no labels it enforces every label valid for
the current OS. It backs up existing managed files when needed; `gitconfig` is
copied rather than symlinked because it commonly acquires machine-local edits.

| Label | Enforces |
|---|---|
| `vim-config` | vimrc, Vim backup/tmp directories, and classic Vim syntax files |
| `vim-plugins` | vim-plug download and `vim +PlugInstall` |
| `nvim-config` | the Neovim configuration directory |
| `nvim-local` | generated `nvim/lua/user/local.lua` from `csharp_lsp` |
| `nvim-plugins` | `Lazy! sync` with the OS-specific lockfile |
| `git-config` | `.gitconfig`, including optional UnityYAMLMerge setup |
| `git-templates` | `repo-configs/` templates |
| `agentic-claude` | Claude status line and managed settings merge |
| `agentic-codex` | Codex status line (when Codex is installed) |
| `agentic-shell` | shell aliases/profiles and Windows cmd shims |
| `win-env` | Windows PowerShell environment setup |

Groups expand to their prefix: `vim`, `nvim`, `git`, `agentic`, and `win`.
`all` selects everything applicable to the current OS.

```powershell
# Windows PowerShell
.\install\install.ps1 -Labels agentic -DryRun
```

```bat
:: Windows cmd
install\install.cmd -Labels agentic
```

```sh
# Ubuntu / WSL / macOS
./install/install.sh agentic-codex --dry-run
```

The shared flags are `--skip LABEL ...`, `--dry-run`, `--check`, and
`--list`. PowerShell spells them as `-Skip`, `-DryRun`, `-Check`, and `-List`.
`--check` performs no changes and exits nonzero when configuration has drift.

There are deliberately no `vim-shortcuts` or `nvim-shortcuts` labels:
shortcuts live in `vim/vimrc` and `nvim/lua/user/keymaps.lua` and are enforced
with `vim-config` and `nvim-config` respectively.

`--list` prints every label, whether it applies on the detected OS (`windows`,
`wsl`, `linux` or `mac`) and what the current selection resolves to. Labels that
don't apply (e.g. `win-env` outside Windows) are skipped with a notice.

Only the current OS is configured, and only the `config.yml` home matching it
is used. WSL counts as Linux. This is a breaking change: WSL no longer syncs a
Windows home; run the PowerShell (or cmd) installer on Windows for that side.

On Windows, creating symlinks requires Developer Mode or an elevated
PowerShell session; if that's not available the installer falls back to
copying the files (and you'll need to re-run it after future `git pull`s).

### config.yml

`install.sh`/`install.ps1` create `config.yml` on first run. Its `homes` list
can contain entries for several OSes, but a run uses only the entry matching
its current OS; if there is none, it uses `~`.

```yaml
homes:
  - os: linux
    path: "~"
```

An entry can set `unity_yaml_merge` to the path of `UnityYAMLMerge.exe`
(bundled with each Unity Editor install), which adds a
`[mergetool "unityyamlmerge"]` block to that home's `.gitconfig` so `git
mergetool` can resolve Unity scene/prefab conflicts. It's per-home and
optional because the path is version-specific and only makes sense where
Unity is actually installed. A multi-OS file like this is fine: each run only
reads the entry for the OS it runs on:

```yaml
homes:
  - os: linux
    path: "~"
  - os: windows
    path: "~"
    unity_yaml_merge: 'C:\Program Files\Unity\Hub\Editor\6000.0.17f1\Editor\Data\Tools\UnityYAMLMerge.exe'
```

Use `skip: [labels]` in an entry to omit labels/groups from default (no-label)
runs. Explicit command-line labels take precedence over `skip`. The old
`only_vim: true`, `only_nvim: true` and `agentic: false` fields still work for
one release as deprecated aliases for skips (`only_nvim` = `skip: [vim, git,
agentic]`; it is mutually exclusive with `only_vim`); migrate them to `skip`.

`config.yml` also accepts a top-level `csharp_lsp: false` to disable the
csharp_ls LSP integration (Unity/.sln-aware, see `nvim/lua/user/unity.lua`)
entirely — useful if you don't do C#/Unity work on a given machine. It
defaults to `true` and is applied by generating the gitignored
`nvim/lua/user/local.lua`, which `nvim/lua/user/plugins/lsp.lua` reads at
startup.

`config.yml` is gitignored (it's machine-specific); rerun the appropriate
installer after editing it or pulling changes. The deprecated `--vim-only`,
`--nvim-only` and `--agentic-only` flags remain temporarily; use the `vim nvim`,
`nvim` and `agentic` groups instead (e.g. `./install/install.sh nvim`). `--only <os>` is no longer supported: the installer
always selects its current OS.

| | Linux / macOS | Windows |
|---|---|---|
| classic Vim config | `~/.vimrc` | `$env:USERPROFILE\_vimrc` |
| classic Vim runtime dir | `~/.vim/` | `$env:USERPROFILE\vimfiles\` |
| Neovim config | `~/.config/nvim/init.lua` | `$env:LOCALAPPDATA\nvim\init.lua` |
| Neovim data (plugins) | `~/.local/share/nvim/` | `$env:LOCALAPPDATA\nvim-data\` |

## Agentic (Claude/Codex) setup

Select the `agentic` group (or one of `agentic-claude`, `agentic-codex`, and
`agentic-shell`) to set up the Claude Code / Codex CLI tooling. `win-env` is
a separate Windows-only label.

What gets installed:

- `agentic/claude/statusline.py` → `<home>/.claude/statusline.py`, wired
  into Claude Code's `settings.json`.
- Claude `settings.json` keys merged (other keys untouched): `model`,
  `effortLevel`, `statusLine`.
- Codex `config.toml`: `[tui] status_line` set.
- `ralph-loop` / `rloop` for each shell, from `agentic/shell/` (copied to
  `<home>/.claude/agentic/shell/` and sourced from a marked block in your
  shell profile): `aliases.sh` for bash/zsh, `aliases.ps1` for PowerShell,
  `ralph-loop.cmd`/`rloop.cmd` copied to `<home>/.claude/bin/` for cmd.
- Windows only (`install/windows_env.ps1`, idempotent): PowerShell 7 via
  winget if `pwsh` is missing, user env var
  `CLAUDE_CODE_USE_POWERSHELL_TOOL=1`, and `<home>\.claude\bin` added to the
  user `PATH`. Open a new terminal afterwards.

**Tuning the status line:** edit the `CFG` block at the top of
`agentic/claude/statusline.py` and re-run the installer. To test it with a
fixed clock, set `STATUSLINE_NOW` (epoch seconds)
when piping a sample JSON payload into it.

**Limitations:**

- Rate-limit segments only appear for Pro/Max logins, and only after the
  first response in a session.
- Codex's footer accepts only its built-in status-line items, so it is not
  as customizable as Claude's.
- `ralph-loop` needs the skill at
  `~/.ai/skills/gl-lnx-spec-driven-development` (it prints an error and
  exits 1 if the script is missing).

## repo-configs

`repo-configs/gitignore` and `repo-configs/gitattributes` are templates you
can drop into any repository. The `git-templates` label symlinks (copies, on Windows) `repo-configs/` into
each configured home directory (as `~/repo-configs`, or
`$env:USERPROFILE\repo-configs` on Windows), so it's reachable from anywhere.
To apply the templates to the repository you're currently in:

```sh
~/repo-configs/apply.sh
```

This copies the templates into the current working directory as
`.gitignore` and `.gitattributes` (not symlinks, since each repo may want
to tweak its own copy — e.g. the "Project-specific rules" section at the
top of `.gitignore`).

## Plugins

**Neovim** (lazy.nvim): nvim-treesitter, nvim-lspconfig + mason.nvim (LSP,
including `csharp_ls` for Unity on WSL/Linux/macOS and `roslyn.nvim` on
Windows), nvim-dap (debugging, `unity-dap` on Windows), blink.cmp
(completion), supermaven-nvim (AI inline completions, Neovim-only),
telescope.nvim (fuzzy finder), lualine.nvim, gitsigns.nvim, kanagawa.nvim,
plus vim-visual-multi (also usable under Neovim), plus vim-tmux-navigator
(Linux only, incl. WSL).
Windows additionally gets `apyra/nvim-unity-sync` (keeps a Unity project's
`.csproj` in sync with files added/renamed/deleted in Neovim).

**Classic Vim** (vim-plug): ctrlp.vim, kanagawa.vim,
vim-visual-multi, ALE, vim-tmux-navigator (Linux only, incl. WSL).

lazy.nvim's lockfile is per-OS — `nvim/lazy-lock.linux.json`,
`.mac.json`, `.windows.json` — instead of the usual single
`lazy-lock.json`. `nvim/init.lua` picks the right one at startup via
`vim.fn.has('win32')`/`has('mac')`. This matters because the same `nvim/`
directory is shared across every configured home (symlinked on Linux/macOS,
copied on Windows — see `install/enforce.py`), and plugin commits (plus
which plugins even load, e.g. `roslyn.nvim` vs `csharp_ls` in
`nvim/lua/user/plugins/lsp.lua`) can legitimately differ per platform; a
single shared lockfile would have each OS overwriting the others' updates
on every `git pull` + resync.

Replaced from the old config: Vundle → vim-plug/lazy.nvim (unmaintained),
syntastic → ALE / native LSP diagnostics (archived by its author),
vim-multiple-cursors → vim-visual-multi (unmaintained), ctrlp → telescope.nvim
on the Neovim side (kept for classic Vim). Dropped: vim-go and vim-pug (low
value now that LSP covers Go, and Pug is no longer used).

## Unity / C#

Neovim gets real C# editing via treesitter (`c_sharp` parser) plus an LSP
that's split by OS, since the Unity Editor itself only runs on Windows:

- **WSL/Linux/macOS**: `csharp_ls` (installed automatically through
  mason.nvim). No Unity Editor integration and no debugging integration —
  editing only.
- **Windows**: Microsoft's Roslyn LSP via `seblyng/roslyn.nvim` (installed
  through mason.nvim's `Crashdummyy/mason-registry`), plus full Unity
  Editor integration:
  - **`walcht/com.walcht.ide.neovim`** (Unity package, installed via
    Unity's Package Manager from
    `https://github.com/walcht/com.walcht.ide.neovim.git`, then selected as
    the External Script Editor under *Edit > Preferences > External
    Tools*) — double-click a script or a Console error in Unity to
    open/jump-to-line in the running Neovim instance.
  - **`apyra/nvim-unity-sync`** — keeps the `.csproj` in sync as `.cs`
    files are added/renamed/deleted from Neovim, without needing Unity
    focused.
  - **`walcht/unity-dap`** (`nvim/lua/user/unity_dap.lua`) — live
    attach-debugging against Unity's Mono soft-debugger via nvim-dap.
    Editor/Mono-player only; IL2CPP isn't supported. Requires downloading
    the `win-x64` adapter release separately (see the file's header
    comment).

This split (which server, which OS gets Unity Editor/debugging
integration) is implemented in `nvim/lua/user/unity.lua`,
`nvim/lua/user/plugins/lsp.lua`, and `nvim/lua/user/plugins/dap.lua`.

One-time setup per Unity project: **Edit > Preferences > External Tools >
"Generate .csproj files for..."** — enable it for all categories. Regenerate
(Unity usually does this automatically on script/package changes; if not,
use *Assets > Open C# Project*) whenever packages or asmdefs change, so the
LSP's view of the `.sln`/`.csproj` files stays current.

## Unity Project setup

Steps to wire a new Unity project into this config's Windows integration
(Unity Editor open/jump-to-line, `.csproj` sync, live debugging):

1. Confirm Unity Editor is installed (via Unity Hub) and that the Windows
   Neovim install is ≥0.12 (`roslyn.nvim`'s floor).
2. In the Unity project: **Package Manager → Install package from git
   URL** → `https://github.com/walcht/com.walcht.ide.neovim.git`.
3. Restart Unity, then set **Edit > Preferences > External Tools >
   External Script Editor** to "Neovim".
4. In Unity's **Neovim → Settings** panel: leave the Windows defaults
   (loopback TCP socket, random port); set the terminal to Windows
   Terminal (`wt`) with PowerShell.
5. Enable **Edit > Preferences > External Tools > "Generate .csproj files
   for..."** for all categories (see "Unity / C#" above — one-time per
   project, regenerate via *Assets > Open C# Project* whenever packages or
   asmdefs change).
6. Download the `win-x64` asset from
   [walcht/unity-dap](https://github.com/walcht/unity-dap/releases),
   extract `unity-debug-adapter.exe` somewhere stable (e.g.
   `$env:LOCALAPPDATA\unity-dap\unity-debug-adapter.exe`), and update the
   `command` path in `nvim/lua/user/unity_dap.lua`'s `dap.adapters.unity`
   to point at it if it's not already on PATH.
7. Open Neovim on Windows once so `lazy.nvim`/`mason.nvim` install
   `roslyn`, `roslyn.nvim`, and `nvim-unity-sync` (their specs are
   Windows-only).

**Verification checklist:**

- [ ] Double-click a `.cs` file in Unity's Project window → opens at the
      right file in the running Neovim instance
- [ ] Double-click a compiler error in the Console → cursor jumps to the
      exact line/column in Neovim
- [ ] Restart Unity Editor → the Neovim integration reconnects without
      reconfiguring
- [ ] Open a Unity `.cs` file in Neovim, run `:LspInfo` → `roslyn` (not
      `csharp_ls`) is attached and `UnityEngine`/custom project types
      resolve
- [ ] Create/rename/delete a `.cs` file from Neovim (Unity not focused) →
      the `.csproj`'s `<Compile>` entries update and Roslyn picks up the
      change without waiting for Unity to regenerate
- [ ] With the Unity Editor running and Play mode active, trigger a
      `nvim-dap` attach, pick "Attach to Unity Editor [Mono]", enter
      `127.0.0.1` and the port from Unity's `Editor.log`
      (`--debugger-agent=...address=127.0.0.1:<port>`) → a breakpoint in
      a `MonoBehaviour` script is hit

## Tools health checklist

General checklist to confirm the Neovim tooling in this config is
installed and working, independent of any specific project:

- [ ] `:checkhealth` reports no errors for core Neovim health
- [ ] `:Lazy` shows all plugins installed with no failed installs (and,
      on WSL/Linux/macOS, that `roslyn.nvim`/`nvim-unity-sync` are
      correctly skipped via their Windows-only `cond`)
- [ ] `:Mason` shows the expected LSP/DAP servers installed (`csharp_ls`
      or `roslyn`, `gopls`, etc.)
- [ ] `:TSUpdate` completes, and treesitter highlighting works in a
      `.cs`, `.go`, and `.lua` file
- [ ] Open a source file, run `:LspInfo` → the expected LSP server
      attaches; hover (`K`) and go-to-definition work
- [ ] blink.cmp: a completion popup appears while typing
- [ ] supermaven-nvim: an inline AI suggestion appears while typing
- [ ] Telescope: fuzzy-find and live-grep (ripgrep-backed) both return
      results
- [ ] gitsigns.nvim: the sign column shows changes in a modified git file
- [ ] lualine.nvim statusline renders correctly
- [ ] nvim-dap: a breakpoint can be set and hit for at least one
      configured adapter
- [ ] vim-visual-multi: multi-cursor editing works
- [ ] vim-tmux-navigator (Linux only, incl. WSL): `<C-w> h/j/k/l` crosses between
      Neovim splits and tmux panes, including from inside a `:terminal`
      buffer
