# Fix: Roslyn LSP hover/diagnostics showing in pt-BR instead of English

## Context

Investigated in a session accidentally started inside `TypingArena` instead of
this repo (`vimrc`). No changes were applied there — a scratch edit made to
the *deployed* config at `AppData/Local/nvim/lua/user/plugins/lsp.lua` was
reverted; the source of truth is `nvim/lua/user/plugins/lsp.lua` in this repo,
untouched.

## Root cause

The Roslyn LSP server (`Microsoft.CodeAnalysis.LanguageServer`, launched by
`roslyn.nvim`) is a .NET console app. .NET resolves `CultureInfo.CurrentUICulture`
for a process from the **Windows OS display language** by default, not from
any Neovim/editor setting.

Confirmed via `systeminfo` that this machine's Windows OS display language is
Portuguese (Brazil) — output included pt-BR strings (e.g.
`Nome do sistema operacional: ...`).

Because of that, the language server defaults its UI culture to `pt-BR` on
startup. Roslyn ships pt-BR satellite resource assemblies alongside the
English ones for diagnostic messages and quick-info/hover strings, and with
no override it picks the pt-BR resources — hence hover text and diagnostics
render in Portuguese.

Current launch command, in `nvim/lua/user/plugins/lsp.lua` (plugin spec for
`seblyng/roslyn.nvim`) → resolved by
`roslyn.nvim`'s `lsp/roslyn.lua`:

```lua
cmd = { require("roslyn.utils").get_roslyn_lsp_path(), "--stdio" },
```

No locale argument or environment variable is passed, so the server falls
back to the OS UI language.

### How VS Code avoids this

The official VS Code C# extension launches the same server binary with an
explicit `--locale <lang>` argument, derived from VS Code's own
display-language setting (`vscode.env.language`) — it doesn't rely on the OS
locale at all. `Microsoft.CodeAnalysis.LanguageServer` supports this
`--locale` CLI flag specifically to override `CurrentUICulture` independent
of the OS.

## Proposed fix

Add `--locale en-US` to the `cmd` roslyn.nvim uses to launch the server, via
`vim.lsp.config('roslyn', {...})`, since `roslyn.nvim`'s own `opts` (merged
through `require("roslyn.config").setup(...)`) don't expose `cmd` — only
`filewatching`, `choose_target`, `ignore_target`, `broad_search`,
`lock_target`, `debug`.

In `nvim/lua/user/plugins/lsp.lua`, change the `seblyng/roslyn.nvim` plugin
spec from:

```lua
{
  -- Microsoft's Roslyn C# LSP, native Windows only (Unity Editor runs
  -- there); WSL/Linux/macOS keep csharp_ls, configured above. Requires
  -- Neovim >= 0.12.
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

to:

```lua
{
  -- Microsoft's Roslyn C# LSP, native Windows only (Unity Editor runs
  -- there); WSL/Linux/macOS keep csharp_ls, configured above. Requires
  -- Neovim >= 0.12.
  'seblyng/roslyn.nvim',
  cond = function() return vim.fn.has('win32') == 1 end,
  ---@module 'roslyn.config'
  ---@type RoslynNvimConfig
  opts = {
    filewatching = 'auto',
    broad_search = false,
  },
  config = function(_, opts)
    require('roslyn').setup(opts)

    -- Without --locale, the server defaults to the Windows OS UI language
    -- (pt-BR on this machine) for hover/diagnostic text. Force English
    -- regardless of OS locale, matching what VS Code's C# extension does.
    vim.lsp.config('roslyn', {
      cmd = { require('roslyn.utils').get_roslyn_lsp_path(), '--stdio', '--locale', 'en-US' },
    })
  end,
},
```

This is config-only; it doesn't touch the Windows OS language setting.

## Verification steps (once applied)

1. Restart Neovim (or `:LspRestart` on a `.cs` buffer) so the new `cmd` takes
   effect.
2. Open a `.cs` file in `TypingArena` (or any Unity project with
   `roslyn.nvim` attached), trigger a hover (`K`) and a diagnostic (e.g. an
   unused variable), and confirm the text is in English.
3. Confirm no regression for non-Windows machines (WSL/Linux/macOS still use
   `csharp_ls`, untouched by this change).
