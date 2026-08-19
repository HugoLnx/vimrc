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
| classic Vim config | `~/.vimrc` | `%USERPROFILE%\_vimrc` |
| classic Vim runtime dir | `~/.vim/` | `%USERPROFILE%\vimfiles\` |
| Neovim config | `~/.config/nvim/init.lua` | `%LOCALAPPDATA%\nvim\init.lua` |
| Neovim data (plugins) | `~/.local/share/nvim/` | `%LOCALAPPDATA%\nvim-data\` |

## repo-configs

`repo-configs/gitignore` and `repo-configs/gitattributes` are templates you
can drop into any repository. The installer symlinks `repo-configs/` into
each configured home directory (as `~/repo-configs`, or
`%USERPROFILE%\repo-configs` on Windows), so it's reachable from anywhere.
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
including `csharp_ls` for Unity), blink.cmp (completion), telescope.nvim
(fuzzy finder), lualine.nvim, gitsigns.nvim, kanagawa.nvim, plus
vim-tmux-navigator and vim-visual-multi (also usable under Neovim).

**Classic Vim** (vim-plug): ctrlp.vim, kanagawa.vim,
vim-visual-multi, ALE, vim-tmux-navigator.

Replaced from the old config: Vundle → vim-plug/lazy.nvim (unmaintained),
syntastic → ALE / native LSP diagnostics (archived by its author),
vim-multiple-cursors → vim-visual-multi (unmaintained), ctrlp → telescope.nvim
on the Neovim side (kept for classic Vim). Dropped: vim-go and vim-pug (low
value now that LSP covers Go, and Pug is no longer used).

## Unity / C#

Neovim gets real C# editing via treesitter (`c_sharp` parser) + `csharp-ls`
(installed automatically through mason.nvim, configured in
`nvim/lua/user/unity.lua`).

One-time setup per Unity project: **Edit > Preferences > External Tools >
"Generate .csproj files for..."** — enable it for all categories. Regenerate
(Unity usually does this automatically on script/package changes; if not,
use *Assets > Open C# Project*) whenever packages or asmdefs change, so
csharp-ls's view of the `.sln`/`.csproj` files stays current.

**TODO:** wire up "double-click a script in Unity to jump to file:line in a
running Neovim instance" (via `nvim --server`/`--remote` and small
cross-platform wrapper scripts). Not built yet — in the meantime, point
Unity's External Script Editor at VS Code or Rider for that convenience;
actual editing happens in Neovim.
