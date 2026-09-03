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
install/symlink.py    reads config.yml, symlinks this repo's config into each listed home
install/install.sh    installer for Linux/macOS
install/install.ps1   installer for Windows (PowerShell)
```

`vim/vimrc` never references Lua or a plugin manager, so it's safe to source
from both editors. Plugin management is fully separate per editor: classic
Vim uses vim-plug (`vim/plugins.vim`), Neovim uses lazy.nvim
(`nvim/lua/user/plugins/`).

## Dependencies

This repo's installer only symlinks config files and installs editor
plugins; the external tools below are assumed to already be on PATH.

**Both platforms:**

- [Git](https://git-scm.com/downloads)
- [Neovim](https://github.com/neovim/neovim/blob/master/INSTALL.md) —
  `roslyn.nvim` needs ≥0.12 — plus, optionally, classic
  [Vim](https://www.vim.org/download.php)
- [Python 3](https://www.python.org/downloads/) and
  [PyYAML](https://pypi.org/project/PyYAML/) — used by `install/symlink.py`
- A C compiler — needed to build treesitter parsers (`:TSUpdate`); see
  [nvim-treesitter's requirements](https://github.com/nvim-treesitter/nvim-treesitter#requirements)
- [ripgrep](https://github.com/BurntSushi/ripgrep#installation) — Telescope
  live-grep and ctrlp.vim's grep integration
- [Go](https://go.dev/doc/install) — `gopls`, installed automatically via
  mason.nvim
- [.NET SDK](https://dotnet.microsoft.com/en-us/download) — `csharp_ls` /
  `roslyn`, also installed via mason.nvim; without `dotnet` on PATH the C#
  LSP is silently skipped (see `nvim/lua/user/plugins/lsp.lua`)
- [Claude Code CLI](https://docs.claude.com/en/docs/claude-code/overview),
  logged in — drives `claudecode.nvim`
- [git-lfs](https://git-lfs.com/) — used by the shared `gitconfig`'s LFS
  filter

See mason.nvim's own
[requirements](https://github.com/williamboman/mason.nvim#requirements) for
the baseline tools (unzip/tar, curl or wget, etc.) it needs to install and
manage LSP/DAP packages.

**Optional:**

- [make](https://www.gnu.org/software/make/) — builds Telescope's optional
  `telescope-fzf-native` perf extension (skipped automatically if absent)
- [tmux](https://github.com/tmux/tmux/wiki/Installing) — `vim-tmux-navigator`
  is a no-op without it

**Windows/PowerShell only** (see "Unity / C#" below for how these fit
together):

- [Unity Editor](https://unity.com/download) (via Unity Hub)
- [walcht/com.walcht.ide.neovim](https://github.com/walcht/com.walcht.ide.neovim) —
  installed manually into a Unity project via the Package Manager
- [walcht/unity-dap](https://github.com/walcht/unity-dap/releases) — the
  `win-x64` adapter binary is downloaded manually from its releases page

## Install

```sh
# Linux / macOS
./install/install.sh
```

```powershell
# Windows (run in PowerShell)
./install/install.ps1
```

Both installers back up any existing config (timestamped), then symlink this
repo's files into place so `git pull` updates apply immediately without
re-running the installer. `gitconfig` is copied instead of symlinked, since
it commonly picks up machine-local edits.

On Windows, creating symlinks requires Developer Mode or an elevated
PowerShell session; if that's not available the installer falls back to
copying the files (and you'll need to re-run it after future `git pull`s).

### config.yml

The actual linking work is config-driven: `install.sh`/`install.ps1` create
`config.yml` from `_config.sample.yml` on first run (one entry for your
native home) and then call `install/symlink.py`, which reads `config.yml`'s
`homes` list and creates every link. `config.yml` only says *where* each
home directory is — `symlink.py` decides which files/subfolders get linked
under it, based on each entry's `os`.

```yaml
homes:
  - os: linux
    path: "~"
```

If you're on WSL, you can list both your Linux home and your Windows home
(reachable at `/mnt/c/Users/<you>`) and one run keeps both in sync. A home
entry can also set `unity_yaml_merge` to the path of `UnityYAMLMerge.exe`
(bundled with each Unity Editor install), which adds a
`[mergetool "unityyamlmerge"]` block to that home's `.gitconfig` so `git
mergetool` can resolve Unity scene/prefab conflicts. It's per-home and
optional because the path is version-specific and only makes sense where
Unity is actually installed:

```yaml
homes:
  - os: linux
    path: /home/hugolnx
  - os: windows
    path: /mnt/c/Users/hugolnx
    unity_yaml_merge: 'C:\Program Files\Unity\Hub\Editor\6000.0.17f1\Editor\Data\Tools\UnityYAMLMerge.exe'
```

`config.yml` also accepts a top-level `csharp_lsp: false` to disable the
csharp_ls LSP integration (Unity/.sln-aware, see `nvim/lua/user/unity.lua`)
entirely — useful if you don't do C#/Unity work on a given machine. It
defaults to `true` and is applied by generating the gitignored
`nvim/lua/user/local.lua`, which `nvim/lua/user/plugins/lsp.lua` reads at
startup.

`config.yml` is gitignored (it's machine-specific); re-run
`python3 install/symlink.py` any time after editing it or pulling changes.
Useful flags: `--dry-run` (preview only) and `--only linux` / `--only
windows` / `--only mac` (limit to matching `os` entries). Note that
symlinking into a `/mnt/c/...` path from WSL depends on Windows/WSL's
symlink support being enabled — if it's not, `symlink.py` falls back to
copying, same as the native-Windows fallback.

| | Linux / macOS | Windows |
|---|---|---|
| classic Vim config | `~/.vimrc` | `$env:USERPROFILE\_vimrc` |
| classic Vim runtime dir | `~/.vim/` | `$env:USERPROFILE\vimfiles\` |
| Neovim config | `~/.config/nvim/init.lua` | `$env:LOCALAPPDATA\nvim\init.lua` |
| Neovim data (plugins) | `~/.local/share/nvim/` | `$env:LOCALAPPDATA\nvim-data\` |

## repo-configs

`repo-configs/gitignore` and `repo-configs/gitattributes` are templates you
can drop into any repository. The installer symlinks `repo-configs/` into
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
plus vim-tmux-navigator and vim-visual-multi (also usable under Neovim).
Windows additionally gets `apyra/nvim-unity-sync` (keeps a Unity project's
`.csproj` in sync with files added/renamed/deleted in Neovim).

**Classic Vim** (vim-plug): ctrlp.vim, kanagawa.vim,
vim-visual-multi, ALE, vim-tmux-navigator.

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
- [ ] claudecode.nvim: the Claude Code CLI launches from Neovim and
      responds
- [ ] nvim-dap: a breakpoint can be set and hit for at least one
      configured adapter
- [ ] vim-tmux-navigator: pane navigation crosses between tmux and Neovim
      splits (if using tmux)
- [ ] vim-visual-multi: multi-cursor editing works
