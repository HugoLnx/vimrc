# Plan: import the agentic (Claude/Codex) setup into this repo, cross-platform

> Final destination of this file: `pending-plans/import-agentic-setup.md` in this repo
> (`/home/hugolnx/mystuff/projects/vimrc`). Plan mode only allowed writing here; the first
> action after approval is to copy it there.

## Context

`C:\Users\hugolnx\projects\windows-terminal-rc` (= `/mnt/c/Users/hugolnx/projects/windows-terminal-rc`,
read-only source for this plan) holds an agentic setup that only works on Windows/PowerShell:

| Feature | Source file | Windows-only because |
|---|---|---|
| Claude settings: `model=opusplan`, `effortLevel=medium`, `statusLine` | `scripts/08-configure-ai-cli.ps1` | PowerShell, `$env:USERPROFILE`, command is `pwsh -File ...` |
| Custom Claude status line (model+effort, `folder/ [branch]`, ctx tokens, 5h/week used % + reset, session; ANSI color tiers, pace ratio, weighted work-minutes for the week in BRT) | `claude/statusline.ps1` | written in PowerShell; uses `TimeZoneInfo` with a Windows tz id |
| Codex `[tui] status_line = [...]` | `scripts/08-configure-ai-cli.ps1` | same script |
| `ralph-loop` / `rloop` commands (run `~/.ai/skills/gl-lnx-spec-driven-development/scripts/ralph-loop.py`) | `profile/aliases.ps1` | PowerShell functions |
| `CLAUDE_CODE_USE_POWERSHELL_TOOL=1`, pwsh 7 installed | `scripts/06-set-env-vars.ps1`, `05-set-default-pwsh.ps1` | Windows-specific by nature |

Goal: one place (this repo) that configures all of that automatically in four environments:
**Windows/PowerShell, Windows/cmd, native Ubuntu, WSL/Ubuntu**. This repo already has the right
machinery: `config.yml` lists `homes` (each with an `os`), `install/symlink.py` syncs per-home
(copy for `windows` homes, symlink otherwise), `install/install.sh` / `install.ps1` are the entry
points, and a WSL run can sync both the Linux home and `/mnt/c/Users/<you>`. We extend that
instead of building a parallel installer.

Out of scope: the non-agentic Windows bits (scoop/winget packages, `tree`/`ls`/`tvii` aliases, the
generic env vars); `~/.ai/skills` installation itself (`gl-skills-lib`); Claude settings this repo
doesn't own (permissions, plugins, theme, `skillOverrides`, ...) — they must be preserved.

## Key design decisions

1. **Port the status line to Python** (`agentic/claude/statusline.py`), not bash+jq. It must run
   identically under pwsh/cmd/bash/zsh, needs date math, JSON parsing and ANSI; Python is already a hard
   requirement of `install/symlink.py`, so no new dependency. Keep the same `CFG` dict at the top, same
   thresholds, same output format. Replace the Windows tz id with a fixed offset (`WorkTzOffsetHours = -3`,
   BRT has no DST) and optionally `zoneinfo.ZoneInfo("America/Sao_Paulo")` when available (tzdata is
   absent on Windows by default → fallback to fixed offset). Keep `STATUSLINE_NOW` override.
   Output through `sys.stdout.buffer` as UTF-8 (the `·` separator) so Windows cp1252 consoles don't break.
   Git branch via `subprocess.run(["git","-C",dir,...])`. Never raise (wrap main in try/except).
2. **Install by copying, referencing a home-local path.** Copy the script to `<home>/.claude/statusline.py`
   (matches the repo's existing "copy for windows homes" rule — avoids the WSL→NTFS symlink problem
   documented in `symlink.py`) and point settings at that path, not at the repo. For consistency copy on
   all OSes (Linux too), so a moved repo doesn't break the status line.
3. **Merge, never overwrite, the AI config files.** Port the idempotent merge logic of
   `08-configure-ai-cli.ps1` to Python: load `<home>/.claude/settings.json`, set only the managed keys
   (`model`, `effortLevel`, `statusLine`), write only if changed, with a `.bak` backup (use existing
   `backup_if_exists` style/timestamps). Codex `config.toml`: port the line-based `[tui] status_line`
   upsert (no TOML library needed; skip when `<home>/.codex` doesn't exist).
4. **Per-home command string** for `statusLine.command`, derived from the home's `os`:
   - linux/mac: `python3 "<home>/.claude/statusline.py"`
   - windows: `python "C:/Users/<you>/.claude/statusline.py"` (forward slashes; works for Claude Code under
     PowerShell or Git Bash). When running from WSL, convert `/mnt/<d>/...` → `<D>:/...` (new helper
     `to_windows_path`), with optional explicit `win_path:` override in the home entry.
5. **Aliases per shell, via marker blocks** (same idempotent `# >>> ... >>>` pattern as
   `scripts/04-setup-profile.ps1`), pointing at repo-owned snippet files copied next to the config:
   - bash/zsh: `agentic/shell/aliases.sh` defines `ralph-loop` function + `rloop` alias; installer
     inserts a source block in `~/.bashrc` and `~/.zshrc` (if present).
   - PowerShell: `agentic/shell/aliases.ps1` (the two functions from the source repo) dot-sourced from
     `$PROFILE` (pwsh 7 and Windows PowerShell 5.1 profile paths).
   - cmd: `ralph-loop.cmd` / `rloop.cmd` shims in `<home>\.claude\bin` (added to the user PATH) calling
     `python "%USERPROFILE%\.ai\skills\...\ralph-loop.py" %*` (cmd has no profile; doskey would need an
     AutoRun registry key — shims are less invasive).
   All variants check the script exists and print a clear error if not, as the source does.
6. **Windows-only extras stay Windows-only**: `CLAUDE_CODE_USE_POWERSHELL_TOOL=1` user env var and
   installing PowerShell 7 are applied only for `os: windows` homes and only by `install.ps1` (native), or
   from WSL through `powershell.exe` interop when a windows home is configured (best effort, skipped with
   a notice if interop is unavailable). They are not applied to Linux homes.
7. **Opt-out/opt-in via `config.yml`**, mirroring `only_vim`: new per-home `agentic: true|false`
   (default true unless `only_vim`), and honor `--vim-only` (skips agentic too). Add
   `--agentic-only` CLI flag for iterating on just this part.

## Repo layout to add

```
agentic/
  claude/statusline.py        # port of claude/statusline.ps1 (same CFG block, same output)
  claude/settings.managed.json# the managed keys: model, effortLevel (statusLine added at runtime)
  codex/status_line.txt       # the single status_line value (or constant in sync script)
  shell/aliases.sh            # ralph-loop + rloop (bash/zsh)
  shell/aliases.ps1           # ralph-loop + rloop (PowerShell)
  shell/ralph-loop.cmd        # cmd shim (rloop.cmd generated/duplicated)
install/agentic.py            # sync logic, imported by symlink.py (keeps symlink.py from growing further)
```

## Implementation steps

1. **Port statusline** → `agentic/claude/statusline.py`. Test fixtures: take real JSON payloads, run the
   `.ps1` (via `pwsh` on Windows, `STATUSLINE_NOW` fixed) and the `.py`, diff the outputs (strip nothing —
   ANSI included). Cover: missing `rate_limits`, missing `context_window`, folder name >12 chars, detached
   HEAD, non-git dir, weekend/weekday weighting across the weekly reset.
2. **`install/agentic.py`** with functions reusing `symlink.py` helpers (`backup_if_exists`,
   `already_copied`, `copy_path`, dry-run printing — import them or move to a small shared module):
   - `sync_agentic(home, os_name, entry, dry_run)`: copy `statusline.py`; merge Claude settings; upsert
     Codex `status_line`; install shell aliases for that os; return summary.
   - `merge_claude_settings(path, desired, dry_run)`, `upsert_codex_status_line(path, dry_run)`,
     `upsert_marker_block(file, name, body, dry_run)` (generic, replaces block in place),
     `to_windows_path(p)`.
3. **Hook into `install/symlink.py`**: in `sync_home`, after the existing links/gitconfig and when not
   `vim_only` and `entry.get('agentic', True)`, call `sync_agentic`. Add `--agentic-only` / skip logic in
   `main()`; update the module docstring.
4. **Windows-only env/pwsh step**: new `install/windows_env.ps1` (port of `05`/`06` scripts, trimmed to the
   Claude var + pwsh check) invoked by `install/install.ps1`; from `install.sh`, when a windows home is
   configured and `powershell.exe` exists, invoke it via `powershell.exe -NoProfile -File <wslpath -w ...>`.
5. **Entry points**: `install/install.sh` and `install/install.ps1` already run `symlink.py`; add only a
   python/PyYAML precheck message if needed and the Windows step above. Add a `install/install.cmd`
   wrapper (`powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"`) so cmd users have a
   one-liner.
6. **Config**: extend `_config.sample.yml` comments with `agentic`, `win_path`, and a note that WSL
   setups list both homes; add `agentic: false` to nothing by default. Existing `config.yml` has the
   linux home with `only_vim: true` — leave it unless the user wants agentic there (decision below).
7. **Docs**: README section "Agentic (Claude/Codex) setup": what is installed, per-environment matrix,
   how to tune the status line (edit `agentic/claude/statusline.py` CFG, re-run install), how to test with
   `STATUSLINE_NOW`, limitation notes carried over from the source README (limits segments only for
   Pro/Max logins; Codex footer only accepts built-in items).
8. **Retire duplication** (follow-up, not part of this change): once verified, leave a note in
   `windows-terminal-rc`'s README pointing here; don't delete anything there in this change.

## Behavior matrix (what each environment gets)

| | Win/PowerShell | Win/cmd | Ubuntu | WSL/Ubuntu |
|---|---|---|---|---|
| entry point | `install\install.ps1` | `install\install.cmd` | `install/install.sh` | `install/install.sh` (both homes in `config.yml`) |
| statusline.py + settings merge | ✔ `<win home>\.claude` | ✔ same | ✔ `~/.claude` | ✔ both homes (Windows one with `C:/...` command) |
| Codex status_line | ✔ if `.codex` exists | ✔ | ✔ | ✔ per home |
| ralph-loop/rloop | `$PROFILE` block | `.cmd` shims on PATH | `~/.bashrc`/`~/.zshrc` block | Linux home: rc blocks; Windows home: ps1 block + shims |
| `CLAUDE_CODE_USE_POWERSHELL_TOOL`, pwsh 7 | ✔ | ✔ | — | ✔ via `powershell.exe` interop, best effort |

## Verification

- `python3 install/symlink.py --dry-run` on this WSL box (linux + windows homes): prints the planned
  copies/merges, touches nothing; then a real run; second run must report everything "up to date"/
  "unchanged" (idempotency), and `.bak` files only on the first change.
- Merge safety: diff `~/.claude/settings.json` before/after — only `model`, `effortLevel`, `statusLine`
  differ; `permissions`, `enabledPlugins`, `skillOverrides`, etc. intact. Same for `~/.codex/config.toml`
  (`vim_mode_*` and `[tui.model_availability_nux]` untouched).
- Statusline: `echo '<sample json>' | python3 ~/.claude/statusline.py` on Linux and
  `... | python C:\Users\<you>\.claude\statusline.py` in both PowerShell and cmd; compare against the
  original `.ps1` output with the same `STATUSLINE_NOW`; check colors with a real `claude` session on each
  of the four environments (Ubuntu native needs a real or VM/container check — e.g. `docker run ubuntu`
  with python3 for the script + installer dry run).
- Aliases: new shell in each env → `rloop --help` resolves (error message if the skill script is missing).
- PowerShell 5.1 & 7: profile block present exactly once after two runs.
- Add a small `tests/` (pytest or plain assert script) for `merge_claude_settings`,
  `upsert_codex_status_line`, `upsert_marker_block`, `to_windows_path` and statusline golden outputs.

## Open decisions (defaults chosen; flag if you disagree)

- Python port rather than keeping pwsh for Windows + a separate bash version (single source of truth wins).
- Copy (not symlink) the statusline to every home.
- Should the existing Linux home in `config.yml` (currently `only_vim: true`) get the agentic setup? Default
  assumed: yes — drop `only_vim` there or set `agentic: true` explicitly.
