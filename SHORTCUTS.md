# Neovim Shortcuts

Reference for every keyboard shortcut available in this repo's Neovim setup
(`nvim/`). Classic Vim is out of scope here — see `vim/vimrc` /
`vim/plugins.vim` directly if you need those.

- **Leader key**: `<Space>` (`nvim/lua/user/options.lua`)
- Shortcuts are grouped by **Custom** (hand-written in this repo, in
  `vim/vimrc` or `nvim/lua/user/keymaps.lua`) vs **Plugin** (comes from a
  plugin, either configured here or the plugin's own built-in default).
- Entries with no trailing note are configured explicitly in this repo.
  Entries marked **(plugin default)** are *not* written anywhere in this
  repo's config — they're the plugin's own built-in binding, listed here
  for completeness. Since they're not pinned by this repo, they can drift
  if the plugin changes its defaults upstream.

---

## Custom

### Shortcut Highlights

| Key | Mode | Action |
|---|---|---|
| `<leader>tt` | n | Toggle file tree (NvimTree) |
| `<leader>tf` | n | Find current file in tree |
| `<leader>e` | n | Show diagnostic under cursor |
| `H` / `L` | n | Previous / next tab |
| `J` / `K` | n, v | Jump 10 lines down / up |
| `X` | n | Format entire file |
| `<C-n>` | n | Clear search highlight |

### Navigation

| Key | Mode | Action |
|---|---|---|
| `H` | n | Previous tab |
| `L` | n | Next tab |
| `J` | n, v | Jump 10 lines down |
| `K` | n, v | Jump 10 lines up |
| `[d` | n | Previous diagnostic |
| `]d` | n | Next diagnostic |

### Editing

| Key | Mode | Action |
|---|---|---|
| `<C-o>` | n | Open a new line below, stay in normal mode |
| `X` | n | Format entire file (`gqG`), restoring cursor position |
| `lenght`, `widht`, `heigth` | insert | Auto-corrected to `length`, `width`, `height` |

### Search / Find

| Key | Mode | Action |
|---|---|---|
| `<C-n>` | n | Clear last search highlight/pattern |
| `*` | v | Search forward for the visually selected text |
| `#` | v | Search backward for the visually selected text |

### Diagnostics

| Key | Mode | Action |
|---|---|---|
| `<leader>e` | n | Show diagnostic float under cursor |
| `[d` | n | Jump to previous diagnostic |
| `]d` | n | Jump to next diagnostic |

### File Explorer

| Key | Mode | Action |
|---|---|---|
| `<leader>tt` | n | Toggle NvimTree |
| `<leader>tf` | n | Find current file in NvimTree |

---

## Plugin

### Telescope

#### Highlights

| Key | Mode | Action |
|---|---|---|
| `<leader>ff` | n | Find files |
| `<leader>fg` | n | Live grep |
| `<leader>fb` | n | List open buffers |
| `<leader>fh` | n | Search help tags |
| `<CR>` | insert | Confirm selection |
| `<C-v>` | insert | Open in vertical split |
| `<Esc>` | insert | Close picker |

#### All Bindings

Launch keys (configured in `nvim/lua/user/plugins/telescope.lua`):

| Key | Mode | Action |
|---|---|---|
| `<C-p>` | n | Find files |
| `<leader>ff` | n | Find files |
| `<leader>fg` | n | Live grep |
| `<leader>fb` | n | List open buffers |
| `<leader>fh` | n | Search help tags |

Inside an open Telescope picker **(plugin default)**:

| Key | Mode | Action |
|---|---|---|
| `<C-n>` / `<Down>` | insert | Next result |
| `<C-p>` / `<Up>` | insert | Previous result |
| `<CR>` | insert | Confirm selection |
| `<C-x>` | insert | Open in horizontal split |
| `<C-v>` | insert | Open in vertical split |
| `<C-t>` | insert | Open in new tab |
| `<Esc>` | insert | Close picker |

### LSP

#### Highlights

| Key | Mode | Action |
|---|---|---|
| `gd` | n | Go to definition |
| `gr` | n | List references |
| `gs` | n | Show hover docs |
| `<leader>rn` | n | Rename symbol |
| `<leader>ca` | n | Code action |

#### All Bindings

Buffer-local, set on attach (`nvim/lua/user/plugins/lsp.lua`), applies to
any attached server (lua_ls, gopls, csharp_ls/roslyn, etc.):

| Key | Mode | Action |
|---|---|---|
| `gd` | n | Go to definition |
| `gr` | n | List references |
| `gs` | n | Show hover docs |
| `<leader>rn` | n | Rename symbol |
| `<leader>ca` | n | Code action |

> Note: hover used to be on plain `K`, which collided with the global
> "jump 10 lines up" map (`vim/vimrc`). Moved to `gs` to resolve that —
> `K` now always jumps up, even in LSP-attached buffers.

### Completion (blink.cmp)

#### Highlights

| Key | Mode | Action |
|---|---|---|
| `<C-space>` | insert | Open/trigger completion menu |
| `<C-j>` | insert | Next completion item |
| `<C-k>` | insert | Previous completion item |
| `<C-h>` | insert | Accept selected item |
| `<C-\>` | insert | Toggle signature help |
| `<C-e>` | insert | Cancel/hide menu |

#### All Bindings

Based on the built-in `"default"` preset, with `<C-n>`/`<C-p>`/`<C-y>`
disabled, `<C-j>`/`<C-k>`/`<C-h>` added in their place, and `show_signature`
moved off `<C-k>` onto `<C-\>` (`nvim/lua/user/plugins/completion.lua`):

| Key | Mode | Action |
|---|---|---|
| `<C-space>` | insert | Open/trigger completion menu |
| `<C-j>` | insert | Next completion item |
| `<C-k>` | insert | Previous completion item |
| `<C-h>` | insert | Accept selected item |
| `<C-\>` | insert | Toggle signature help |
| `<C-e>` | insert | Cancel/hide menu |
| `<Tab>` | insert | Snippet forward **(plugin default)** — not "next item" despite this doc previously saying so |
| `<S-Tab>` | insert | Snippet backward **(plugin default)** |
| `<C-b>` / `<C-f>` | insert | Scroll signature/doc popup up/down **(plugin default)** |

### AI Suggestions (Supermaven)

#### Highlights

| Key | Mode | Action |
|---|---|---|
| `<C-y>` | insert | Accept suggestion |
| `<C-l>` | insert | Accept one word of suggestion |
| `<C-]>` | insert | Clear suggestion |

#### All Bindings

Configured explicitly (`nvim/lua/user/plugins/supermaven.lua`) — its own
Tab/Enter defaults are disabled to avoid clashing with blink.cmp:

| Key | Mode | Action |
|---|---|---|
| `<C-y>` | insert | Accept suggestion |
| `<C-l>` | insert | Accept one word of suggestion |
| `<C-]>` | insert | Clear suggestion |

### File Explorer (nvim-tree)

#### Highlights

| Key | Mode | Action |
|---|---|---|
| `<CR>` / `o` | n | Open file/directory |
| `a` | n | Create file/directory |
| `d` | n | Delete |
| `r` | n | Rename |
| `x` / `p` | n | Cut / paste |
| `H` | n | Toggle hidden files |
| `R` | n | Refresh tree |

#### All Bindings

Not customized in this repo (`opts = {}`) — built-in defaults
**(plugin default)**:

| Key | Mode | Action |
|---|---|---|
| `<CR>` / `o` | n | Open file/directory |
| `a` | n | Create file/directory |
| `d` | n | Delete |
| `r` | n | Rename |
| `x` | n | Cut |
| `c` | n | Copy |
| `p` | n | Paste |
| `H` | n | Toggle hidden files |
| `R` | n | Refresh tree |
| `?` | n | Show help/all keymaps |

### Git (gitsigns)

#### Highlights

| Key | Mode | Action |
|---|---|---|
| `]c` | n | Next hunk |
| `[c` | n | Previous hunk |
| `<leader>hs` | n, v | Stage hunk |
| `<leader>hr` | n, v | Reset hunk |
| `<leader>hp` | n | Preview hunk |
| `<leader>hb` | n | Blame line |

#### All Bindings

Not customized in this repo (`opts = {}`) — built-in defaults
**(plugin default)**:

| Key | Mode | Action |
|---|---|---|
| `]c` | n | Next hunk |
| `[c` | n | Previous hunk |
| `<leader>hs` | n, v | Stage hunk |
| `<leader>hr` | n, v | Reset hunk |
| `<leader>hp` | n | Preview hunk |
| `<leader>hb` | n | Blame line |

### Multi-cursor (vim-visual-multi)

#### Highlights

| Key | Mode | Action |
|---|---|---|
| `<C-g>` | n | Select word under cursor / add next match |
| `<C-Down>` / `<C-Up>` | n | Add cursor below/above |
| `Tab` | multi-cursor mode | Switch between cursor and extend mode |
| `q` | multi-cursor mode | Remove current cursor |
| `<Esc>` | multi-cursor mode | Exit multi-cursor mode |

#### All Bindings

`Find Under` / `Find Subword Under` remapped from the plugin default
(`<C-n>`) to `<C-g>` via `g:VM_maps` in `nvim/lua/user/plugins/misc.lua`,
to resolve a collision with the global "clear search" map in `vim/vimrc`.
Everything else is a built-in default **(plugin default)**:

| Key | Mode | Action |
|---|---|---|
| `<C-g>` | n | Select word under cursor / add next match |
| `<C-Down>` / `<C-Up>` | n | Add cursor below/above |
| `Tab` | multi-cursor mode | Switch between cursor and extend mode |
| `q` | multi-cursor mode | Remove current cursor |
| `<Esc>` | multi-cursor mode | Exit multi-cursor mode |

### Debugging (nvim-dap)

#### Highlights

| Key | Mode | Action |
|---|---|---|
| `<A-b>` / `<F9>` | n | Toggle breakpoint |
| `<A-c>` / `<F5>` | n | Continue / start |
| `<A-s>` / `<F10>` | n | Step over |
| `<A-j>` / `<F11>` | n | Step into |
| `<A-k>` / `<S-F11>` | n | Step out |

#### All Bindings

Configured explicitly (`nvim/lua/user/plugins/dap.lua`) — each action is
bound to both an Alt-key and an F-key form:

| Key | Mode | Action |
|---|---|---|
| `<A-b>` / `<F9>` | n | Toggle breakpoint |
| `<A-c>` / `<F5>` | n | Continue / start |
| `<A-s>` / `<F10>` | n | Step over |
| `<A-j>` / `<F11>` | n | Step into |
| `<A-k>` / `<S-F11>` | n | Step out |

The Unity attach configuration itself still lives in
`nvim/lua/user/unity_dap.lua`.
