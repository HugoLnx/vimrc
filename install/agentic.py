#!/usr/bin/env python3
"""Install the managed Claude Code, Codex, and shell helper configuration."""

import datetime
import json
import re
import shutil
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
AGENTIC_SRC = REPO_ROOT / 'agentic'


def _backup_copy(path: Path) -> Path:
    """Copy an existing file aside, retaining the original for the write."""
    timestamp = datetime.datetime.now().strftime('%Y%m%d%H%M%S%f')
    backup = path.parent / f'{path.name}_{timestamp}.bkp'
    shutil.copy2(path, backup)
    print(f'  backing up {path} -> {backup}')
    return backup


def to_windows_path(p: Path | str) -> str:
    """Convert a WSL-mounted home path to a forward-slash Windows path."""
    value = str(p).replace('\\', '/')
    match = re.match(r'^/mnt/([a-zA-Z])(?:/(.*))?$', value)
    if match:
        suffix = match.group(2) or ''
        return f'{match.group(1).upper()}:/' + suffix
    if re.match(r'^[a-zA-Z]:/', value):
        return value[0].upper() + value[1:]
    return value


def merge_claude_settings(path: Path, desired: dict, dry_run: bool) -> bool:
    """Merge desired settings in JSON, retaining existing key order and values."""
    old = path.read_text(encoding='utf-8') if path.exists() else ''
    settings = json.loads(old) if old.strip() else {}
    changed = False
    for key, value in desired.items():
        if settings.get(key, object()) != value:
            settings[key] = value
            changed = True
    if not changed:
        return False
    content = json.dumps(settings, indent=2, ensure_ascii=False) + '\n'
    if dry_run:
        return True
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        _backup_copy(path)
    path.write_text(content, encoding='utf-8', newline='\n')
    return True


def upsert_codex_status_line(path: Path, line: str, dry_run: bool) -> bool:
    """Insert or replace Codex's tui.status_line using its line-oriented TOML."""
    old = path.read_text(encoding='utf-8') if path.exists() else ''
    lines = old.replace('\r\n', '\n').splitlines()
    out: list[str] = []
    in_tui = False
    found = False
    tui_seen = False
    header = re.compile(r'^\s*\[(.+?)\]\s*$')
    status = re.compile(r'^\s*status_line\s*=')
    for current in lines:
        match = header.match(current)
        if match:
            if in_tui and not found:
                out.append(line)
                found = True
            in_tui = match.group(1) == 'tui'
            tui_seen = tui_seen or in_tui
            out.append(current)
        elif in_tui and status.match(current):
            out.append(line)
            found = True
        else:
            out.append(current)
    if in_tui and not found:
        out.append(line)
        found = True
    if not tui_seen:
        if out:
            out.append('')
        out.extend(('[tui]', line))
    content = '\n'.join(out) + '\n'
    if content == old:
        return False
    if dry_run:
        return True
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        _backup_copy(path)
    path.write_text(content, encoding='utf-8', newline='\n')
    return True


def upsert_marker_block(file: Path, name: str, body: str, dry_run: bool) -> bool:
    """Replace (or append) a named marker-delimited shell profile block."""
    begin = f'# >>> {name} >>>'
    end = f'# <<< {name} <<<'
    block = f'{begin}\n{body.strip()}\n{end}'
    old = file.read_text(encoding='utf-8') if file.exists() else ''
    pattern = re.compile(re.escape(begin) + r'.*?' + re.escape(end), re.DOTALL)
    if pattern.search(old):
        content = pattern.sub(block, old)
    elif old.strip():
        content = old.rstrip() + '\n\n' + block + '\n'
    else:
        content = block + '\n'
    if content == old:
        return False
    if dry_run:
        return True
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text(content, encoding='utf-8', newline='\n')
    return True


def _copy_managed(source: Path, target: Path, dry_run: bool) -> bool:
    """Copy a managed path and report whether it changed (or would change)."""
    # Imported lazily while this module is also usable from the old shim.
    try:
        from fs import already_copied, backup_if_exists, copy_path
    except ModuleNotFoundError:
        try:
            from .fs import already_copied, backup_if_exists, copy_path
        except ImportError:
            try:
                from symlink import already_copied, backup_if_exists, copy_path
            except ModuleNotFoundError:
                from .symlink import already_copied, backup_if_exists, copy_path

    if already_copied(source, target):
        print(f'  up to date: {target}')
        return False
    action = f'copy {source} -> {target}'
    if dry_run:
        print(f'  [dry-run] {action}')
        return True
    print(f'  {action}')
    backup_if_exists(target)
    copy_path(source, target)
    return True


def _write_result(path: Path, changed: bool, dry_run: bool) -> None:
    if not changed:
        print(f'  up to date: {path}')
    elif dry_run:
        print(f'  [dry-run] write {path}')
    else:
        print(f'  write {path}')


def sync_claude(home: Path, os_name: str, entry: dict, dry_run: bool) -> bool:
    """Synchronize Claude's status line and managed settings."""
    claude = home / '.claude'
    changed = _copy_managed(
        AGENTIC_SRC / 'claude' / 'statusline.py', claude / 'statusline.py', dry_run)

    managed = json.loads((AGENTIC_SRC / 'claude' / 'settings.managed.json').read_text(encoding='utf-8'))
    command = (f'python "{to_windows_path(home)}/.claude/statusline.py"'
               if os_name == 'windows' else f'python3 "{home}/.claude/statusline.py"')
    desired = dict(managed)
    desired['statusLine'] = {'type': 'command', 'command': command, 'padding': 0}
    settings = claude / 'settings.json'
    settings_changed = merge_claude_settings(settings, desired, dry_run)
    _write_result(settings, settings_changed, dry_run)
    return changed or settings_changed


def sync_codex(home: Path, os_name: str, entry: dict, dry_run: bool) -> bool:
    """Synchronize Codex's status line if Codex has been installed."""
    del os_name, entry

    codex = home / '.codex'
    if codex.exists():
        line = (AGENTIC_SRC / 'codex' / 'status_line.txt').read_text(encoding='utf-8').strip()
        target = codex / 'config.toml'
        changed = upsert_codex_status_line(target, line, dry_run)
        _write_result(target, changed, dry_run)
        return changed
    else:
        print('  up to date: Codex not installed (no .codex directory)')
        return False


def sync_shell(home: Path, os_name: str, entry: dict, dry_run: bool) -> bool:
    """Synchronize shell aliases, profiles, and Windows command shims."""
    del entry
    claude = home / '.claude'
    changed = _copy_managed(AGENTIC_SRC / 'shell', claude / 'agentic' / 'shell', dry_run)
    if os_name in ('linux', 'mac'):
        body = (f'[ -f "{home}/.claude/agentic/shell/aliases.sh" ] && '
                f'. "{home}/.claude/agentic/shell/aliases.sh"')
        profiles = [home / '.bashrc', home / '.zshrc']
        existing = [profile for profile in profiles if profile.exists()]
        if not existing:
            existing = [profiles[0]]
        for profile in existing:
            profile_changed = upsert_marker_block(profile, 'agentic', body, dry_run)
            _write_result(profile, profile_changed, dry_run)
            changed = changed or profile_changed
    elif os_name == 'windows':
        win_home = to_windows_path(home)
        body = (f'if (Test-Path "{win_home}/.claude/agentic/shell/aliases.ps1") {{\n'
                f'    . "{win_home}/.claude/agentic/shell/aliases.ps1"\n}}')
        for profile in (
            home / 'Documents' / 'PowerShell' / 'Microsoft.PowerShell_profile.ps1',
            home / 'Documents' / 'WindowsPowerShell' / 'Microsoft.PowerShell_profile.ps1',
        ):
            profile_changed = upsert_marker_block(profile, 'agentic', body, dry_run)
            _write_result(profile, profile_changed, dry_run)
            changed = changed or profile_changed
        bin_dir = claude / 'bin'
        changed = _copy_managed(
            AGENTIC_SRC / 'shell' / 'ralph-loop.cmd', bin_dir / 'ralph-loop.cmd', dry_run) or changed
        changed = _copy_managed(
            AGENTIC_SRC / 'shell' / 'rloop.cmd', bin_dir / 'rloop.cmd', dry_run) or changed
        print(f'  note: add {to_windows_path(bin_dir)} to PATH if it is not already registered')
    else:
        raise ValueError(f"Unknown os '{os_name}' (expected linux, mac, or windows)")
    return changed


def sync_agentic(home: Path, os_name: str, entry: dict, dry_run: bool) -> bool:
    """Synchronize all managed agentic configuration for one home directory."""
    claude_changed = sync_claude(home, os_name, entry, dry_run)
    codex_changed = sync_codex(home, os_name, entry, dry_run)
    shell_changed = sync_shell(home, os_name, entry, dry_run)
    return claude_changed or codex_changed or shell_changed
