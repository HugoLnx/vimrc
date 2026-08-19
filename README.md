# vimrc

Personal editor config: a shared base for classic Vim and a full modern setup
for Neovim, working on Windows, Linux, and macOS.

## Layout

```
vim/vimrc          shared config, sourced by BOTH `vim` and `nvim`
vim/plugins.vim     classic-Vim-only plugin list (vim-plug); never loaded by Neovim
vim/syntax/html/*   HTML5/ARIA/RDFa syntax files for classic Vim (Neovim gets this via treesitter)
nvim/init.lua       Neovim entrypoint: sources vim/vimrc, then bootstraps lazy.nvim + Lua plugins
nvim/lua/user/      Neovim-only Lua config (options, keymaps, plugins, LSP, Unity)
install/install.sh  installer for Linux/macOS
install/install.ps1 installer for Windows (PowerShell)
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

| | Linux / macOS | Windows |
|---|---|---|
| classic Vim config | `~/.vimrc` | `%USERPROFILE%\_vimrc` |
| classic Vim runtime dir | `~/.vim/` | `%USERPROFILE%\vimfiles\` |
| Neovim config | `~/.config/nvim/init.lua` | `%LOCALAPPDATA%\nvim\init.lua` |
| Neovim data (plugins) | `~/.local/share/nvim/` | `%LOCALAPPDATA%\nvim-data\` |

## Plugins

**Neovim** (lazy.nvim): nvim-treesitter, nvim-lspconfig + mason.nvim (LSP,
including `csharp_ls` for Unity), blink.cmp (completion), telescope.nvim
(fuzzy finder), lualine.nvim, gitsigns.nvim, gruvbox.nvim, plus
vim-tmux-navigator and vim-visual-multi (also usable under Neovim).

**Classic Vim** (vim-plug): ctrlp.vim, vim-colors-solarized,
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
