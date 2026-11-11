# Plan: label-based, current-OS-only setup enforcer

> Destination after approval: copy to `pending-plans/enforce-labels.md` (same convention as
> `pending-plans/import-agentic-setup.md`).

## Context

Today the setup is a pile of modes: `install/symlink.py` has `--vim-only`, `--agentic-only`, `--only
linux|windows|mac` (an OS *filter* over `config.yml` homes), per-home `only_vim` / `agentic` flags, while
`install.sh` / `install.ps1` bolt on extra steps outside Python (vim-plug download, `vim +PlugInstall`,
`nvim "+Lazy! sync"`, WSL→Windows interop for `windows_env.ps1`). Aspects can't be selected individually
(e.g. "only Codex", "only nvim plugins"), and a WSL run reaches across into the Windows home.

Goal: one enforcer where every aspect of the repo has an explicit **label**, you pick labels on the
command line (or persistently skip some in `config.yml`), and it enforces **only for the OS it runs on**.
Windows is configured by running the Windows entry point, Ubuntu/WSL by `install.sh`.

## Decisions

### 1. Current-OS detection (no more cross-OS syncing)
`detect_os()` in the enforcer returns one **context**:
`windows` (native, PowerShell or cmd), `wsl` (Linux with `microsoft` in `/proc/version`), `linux` (native
Ubuntu/other), `mac`. For home-layout purposes `wsl` behaves as `linux`; the context only gates labels
(e.g. `win-env` is windows-only) and messages. `--os` override exists for testing only.
The PowerShell-vs-cmd distinction doesn't matter to Python: on Windows both PowerShell profiles and the
`.cmd` shims are installed by the `agentic-shell` label. Shell choice stays in the entry points
(`install.sh`, `install.ps1`, `install.cmd`), which are thin and just forward arguments.
**Breaking change (requested):** a WSL run no longer touches `/mnt/c/Users/...`; run `install.ps1` on
Windows for that side. The WSL-interop block in `install.sh` is removed.

### 2. Label set (group = prefix; `group` selects all `group-*`; `all` = everything valid for this OS)

| Label | Enforces | OS contexts |
|---|---|---|
| `vim-config` | `vimrc`, `.vim/backup|tmp` dirs, `syntax/html` (link on linux/mac/wsl, copy on windows) | all |
| `vim-plugins` | download vim-plug, `vim +PlugInstall +qall` (skipped with notice if `vim` missing) | all |
| `nvim-config` | `nvim/` dir link/copy (`~/.config/nvim` or `AppData/Local/nvim`) | all |
| `nvim-local` | generated `nvim/lua/user/local.lua` from `csharp_lsp` | all |
| `nvim-plugins` | `nvim --headless "+Lazy! sync" +qa` using the per-OS lockfile | all |
| `git-config` | `~/.gitconfig` (+ Unity mergetool block from `unity_yaml_merge`) | all |
| `git-templates` | `repo-configs/` link/copy (gitignore/gitattributes/apply.sh) | all |
| `agentic-claude` | `~/.claude/statusline.py`, merge `settings.json` (model, effortLevel, statusLine) | all |
| `agentic-codex` | `~/.codex/config.toml` `[tui] status_line` (only if `.codex` exists) | all |
| `agentic-shell` | `ralph-loop`/`rloop`: .bashrc/.zshrc block (linux/wsl/mac); PS profiles + `.cmd` shims (windows) | all |
| `win-env` | `windows_env.ps1`: pwsh 7, `CLAUDE_CODE_USE_POWERSHELL_TOOL`, `.claude\bin` on PATH | windows only |

Groups: `vim`, `nvim`, `git`, `agentic`, `win` (= `win-*`), and `all`. Rationale for what is NOT a label:
`vim-shortcuts`/`nvim-shortcuts` — shortcuts live inside `vim/vimrc` and `nvim/lua/user/keymaps.lua`,
which are linked as whole files/dirs, so they can't be enforced separately without splitting the files.
They are covered by `*-config` (documented in the README label table). If you later want them separate,
split `vimrc` into `vim/shortcuts.vim` sourced from it, and add the label then.
Splitting `*-config` vs `*-plugins` is real: configs are file syncs (fast, offline), plugins are network/
subprocess actions.

### 3. CLI (single Python entry point `install/enforce.py`; `symlink.py` becomes a thin deprecated shim)

```
enforce.py [LABEL ...] [--skip LABEL ...] [--dry-run] [--check] [--list] [--os CTX] [--config PATH]
```
- No labels ⇒ `all`. Labels are the positional args; groups expand by prefix; unknown label ⇒ error listing valid ones.
- `--skip` removes labels/groups from the selection.
- `--list`: prints every label, description, whether it applies on the detected OS, and what the current
  selection resolves to. Labels not valid for this OS are skipped with a one-line notice (explicitly
  requested ones, e.g. `win-env` on Linux, print "not applicable on wsl").
- `--dry-run`: no filesystem/network/subprocess side effects (plugin actions print the command).
- `--check`: dry-run that exits 1 if anything would change (drift detection; useful in a quick sanity check).
- Deprecated aliases kept for one release with a warning: `--vim-only` ⇒ `vim nvim`, `--agentic-only` ⇒
  `agentic`, `--only <os>` ⇒ error pointing to the new model.
- Entry points forward args: `install.sh [labels…]` (bash, also `--dry-run` etc.), `install.ps1 -Labels a,b
  -Skip c -DryRun -Check -List` (builds the argv), `install.cmd %*` (passthrough to `install.ps1`).
  Entry points still do only: locate Python (and give a clear install hint), create `config.yml` if missing,
  call `enforce.py`. Everything else moves into Python.

### 4. `config.yml` (backward compatible, simplified)
- The `homes:` list is read, but only the entry whose `os` matches the current context (`wsl`→`linux`) is
  used; no matching entry ⇒ home defaults to `~`. Extra-OS entries are ignored (not an error), so existing
  files keep working.
- New persistent per-OS keys inside that entry: `skip: [labels…]` (applied only when no labels are given on
  the CLI, i.e. default `all` runs), plus existing `unity_yaml_merge`, `win_path` (no longer needed → drop),
  top-level `csharp_lsp`. Legacy `only_vim: true` ⇒ treated as `skip: [git, agentic]` with a deprecation
  warning; legacy `agentic: false` ⇒ `skip: [agentic]`.
- Rule: labels given on the CLI always win over `skip`, so `./install.sh agentic` works even though the
  current Linux entry has `only_vim: true`.

### 5. Code structure
- `install/aspects.py`: registry `ASPECTS = [Aspect(label, group, contexts, description, run)]`, label
  resolution (`resolve(selection, skip, ctx)`), `detect_os()`.
- `install/enforce.py`: argparse, config loading (reuse `load_config`), runs resolved aspects in a fixed
  order (config → local → plugins → agentic → win-env) with a `Context` (home, os, dry_run, check, entry,
  counters for changed/up-to-date).
- Reuse, don't rewrite: `link_or_copy`, `already_copied`, `already_linked`, `backup_if_exists`,
  `sync_gitconfig`, `sync_local_nvim_config`, `layout_for` from `install/symlink.py` (move into
  `install/fs.py` / `aspects.py` — pure refactor, keep behaviour); `sync_agentic` in `install/agentic.py` is
  split into three callables: `sync_claude`, `sync_codex`, `sync_shell` (its helpers
  `merge_claude_settings`, `upsert_codex_status_line`, `upsert_marker_block`, `to_windows_path` stay).
- `layout_for` returns per-label link groups instead of `links`/`extra_links` (`vim-config` gets the vimrc +
  syntax links, `nvim-config` the nvim link, `git-templates` the repo-configs link).
- Plugin aspects: vim-plug download via `urllib.request` (replaces curl / Invoke-WebRequest, one code
  path); vim/nvim via `subprocess.run` with a timeout, failures reported but non-fatal (as today's `|| true`).
  `win-env`: `subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
  install/windows_env.ps1])` on native Windows only.
- Summary at the end: per label `changed / up to date / skipped / failed`, exit code non-zero on failure
  (`--check`: non-zero on drift).

## Files

Create: `install/enforce.py`, `install/aspects.py`, `install/fs.py` (shared helpers moved from symlink.py),
`tests/test_enforce.py`.
Modify: `install/symlink.py` (shim that warns and delegates), `install/agentic.py` (split sync fn),
`install/install.sh`, `install/install.ps1`, `install/install.cmd`, `_config.sample.yml`, `README.md`
(replace the install/agentic mode docs with a label table, per-OS usage matrix and the breaking-change
note), `tests/test_agentic.py` (adapt to the split).
Untouched: `agentic/*`, `nvim/*`, `vim/*`, `gitconfig`, `repo-configs/*`, `config.yml` (user decision, see below).

## Verification

1. Unit tests (plain `unittest`, temp homes only): label/group resolution, unknown label error, `--skip`,
   `config skip` vs CLI precedence, legacy flag mapping, `detect_os` with faked `/proc/version`/`os.name`,
   not-applicable label notices, `--check` exit codes, each aspect enforced alone (e.g. `agentic-codex`
   writes only `~/.codex/config.toml`; `git-config` writes only `.gitconfig`), idempotent second run.
2. `python3 install/enforce.py --list` and `--dry-run` with a throwaway `--config` + `HOME` in the scratchpad
   for: default (`all`), `agentic`, `nvim-plugins vim-plugins` (dry-run prints commands only), `win-env`
   on WSL (→ not applicable, exit 0).
3. Real run limited to temp homes; then `--check` on the real `~` shows exactly the expected drift (nothing
   for aspects already enforced: agentic is already applied; vim/nvim/git links reported as they are).
4. `bash -n install/install.sh`; PowerShell parse check of `install.ps1`/`install.cmd` via `powershell.exe`
   interop; forwarding test: `install.sh agentic-codex --dry-run` prints only the codex aspect.
5. Run the existing `tests/test_statusline.py` and `tests/test_agentic.py` — must still pass.
6. Not verifiable here (call out in the final report): native Windows PowerShell/cmd runs and bare Ubuntu.

## Execution (when approved; same adhoc-subagent method as before)
Two clusters after the parent does the label/CLI design above: (A) `aspects.py` + `fs.py` + `enforce.py` +
`symlink.py` shim + `test_enforce.py`; (B) entry scripts, `agentic.py` split + `test_agentic.py`, README,
`_config.sample.yml` — A defines the interface (`Aspect`, `Context`, label names above), B codes against it.
Parent verifies per the list above; no commit unless asked.

## Open decisions (defaults chosen)
- Drop WSL→Windows-home syncing (follows "current OS only"); `win_path` field removed.
- No separate shortcuts labels (see rationale); easy to add by splitting files.
- Leave the user's `config.yml` untouched; the new `skip:` key replaces `only_vim` when they want it.
