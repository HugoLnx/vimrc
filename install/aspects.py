"""Aspect registry, OS detection, layouts and label resolution for enforce.py."""

import os
import shutil
import subprocess
import sys
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

import fs

REPO_ROOT = fs.REPO_ROOT
PROC_VERSION = Path('/proc/version')  # injectable for tests
PLUG_URL = 'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
NETWORK_TIMEOUT = 60
PLUGIN_TIMEOUT = 600

CONTEXTS = ('windows', 'wsl', 'linux', 'mac')


def detect_os(override=None, proc_version=None):
    if override:
        if override not in CONTEXTS:
            raise ValueError(f"unknown os '{override}' (valid: {', '.join(CONTEXTS)})")
        return override
    if os.name == 'nt' or sys.platform == 'win32':
        return 'windows'
    if sys.platform == 'darwin':
        return 'mac'
    path = Path(proc_version) if proc_version else PROC_VERSION
    try:
        if 'microsoft' in path.read_text().lower():
            return 'wsl'
    except OSError:
        pass
    return 'linux'


def os_family(ctx):
    return 'linux' if ctx == 'wsl' else ctx


def layout_for(family, home):
    """Per-label groups: {label: {'ensure_dirs': [Path], 'links': [(src_rel, target, copy)]}}."""
    if family in ('linux', 'mac'):
        # vim/vimrc (sourced by Neovim too) points backupdir/directory here,
        # so both editor labels must ensure these dirs exist.
        editor_dirs = [home / '.vim' / 'backup', home / '.vim' / 'tmp']
        return {
            'vim-config': {
                'ensure_dirs': list(editor_dirs),
                'links': [
                    ('vim/vimrc', home / '.vimrc', False),
                    ('vim/syntax/html', home / '.vim' / 'syntax' / 'html', False),
                ],
            },
            'nvim-config': {
                'ensure_dirs': list(editor_dirs),
                'links': [('nvim', home / '.config' / 'nvim', False)],
            },
            'git-templates': {
                'ensure_dirs': [],
                'links': [('repo-configs', home / 'repo-configs', False)],
            },
        }
    if family == 'windows':
        # copy, not symlink: see history; WSL-created links into a Windows
        # home become Junctions that native apps cannot follow.
        editor_dirs = [home / 'vimfiles' / 'backup', home / 'vimfiles' / 'tmp']
        return {
            'vim-config': {
                'ensure_dirs': list(editor_dirs),
                'links': [
                    ('vim/vimrc', home / '_vimrc', True),
                    ('vim/vimrc', home / 'AppData' / 'Local' / 'vim' / 'vimrc', True),
                    ('vim/syntax/html', home / 'vimfiles' / 'syntax' / 'html', True),
                ],
            },
            'nvim-config': {
                'ensure_dirs': list(editor_dirs),
                'links': [('nvim', home / 'AppData' / 'Local' / 'nvim', True)],
            },
            'git-templates': {
                'ensure_dirs': [],
                'links': [('repo-configs', home / 'repo-configs', True)],
            },
        }
    raise ValueError(f"Unknown os '{family}' (expected linux, mac, or windows)")


@dataclass
class Context:
    home: Path
    ctx: str
    family: str
    entry: dict = field(default_factory=dict)
    config: dict = field(default_factory=dict)
    dry_run: bool = False
    check: bool = False


@dataclass
class Aspect:
    label: str
    group: str
    contexts: tuple
    description: str
    run: Callable


def _status(changed):
    return 'changed' if changed else 'ok'


# ---- file aspects ----

def _run_layout(label):
    def run(c):
        layout = layout_for(c.family, c.home)[label]
        changed = False
        for d in layout['ensure_dirs']:
            if d.is_dir():
                continue
            changed = True
            if c.dry_run:
                print(f"  [dry-run] mkdir -p {d}")
            else:
                d.mkdir(parents=True, exist_ok=True)
        for source_rel, target, copy in layout['links']:
            if fs.link_or_copy(REPO_ROOT / source_rel, target, copy, c.dry_run):
                changed = True
        return _status(changed)
    return run


def _run_nvim_local(c):
    return _status(fs.sync_local_nvim_config(c.config.get('csharp_lsp', True), c.dry_run))


def _run_git_config(c):
    return _status(fs.sync_gitconfig(
        c.home / '.gitconfig', c.entry.get('unity_yaml_merge'), c.dry_run))


# ---- plugin aspects ----

def _run_plugin_cmd(cmd, c, label):
    shown = ' '.join(cmd)
    if c.dry_run or c.check:
        print(f"  [dry-run] {shown}")
        return 'ok'
    if shutil.which(cmd[0]) is None:
        print(f"  notice: '{cmd[0]}' not found on PATH; skipping {label}")
        return 'skipped'
    print(f"  {shown}")
    try:
        r = subprocess.run(cmd, timeout=PLUGIN_TIMEOUT)
    except (OSError, subprocess.SubprocessError) as e:
        print(f"  warning: {shown} failed: {e}", file=sys.stderr)
        return 'failed'
    if r.returncode != 0:
        print(f"  warning: {shown} exited {r.returncode}", file=sys.stderr)
        return 'failed'
    return 'changed'


def _plug_path(c):
    if c.family == 'windows':
        return c.home / 'vimfiles' / 'autoload' / 'plug.vim'
    return c.home / '.vim' / 'autoload' / 'plug.vim'


def _run_vim_plugins(c):
    target = _plug_path(c)
    if c.dry_run or c.check:
        if not target.is_file():
            print(f"  [dry-run] download {PLUG_URL} -> {target}")
        return _run_plugin_cmd(['vim', '+PlugInstall', '+qall'], c, 'vim-plugins')
    if not target.is_file():
        print(f"  download {PLUG_URL} -> {target}")
        try:
            with urllib.request.urlopen(PLUG_URL, timeout=NETWORK_TIMEOUT) as resp:
                data = resp.read()
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        except Exception as e:  # noqa: BLE001 - non-fatal by design
            print(f"  warning: could not download vim-plug: {e}", file=sys.stderr)
            return 'failed'
    return _run_plugin_cmd(['vim', '+PlugInstall', '+qall'], c, 'vim-plugins')


def _run_nvim_plugins(c):
    return _run_plugin_cmd(['nvim', '--headless', '+Lazy! sync', '+qa'], c, 'nvim-plugins')


# ---- agentic ----

def _run_agentic(name):
    def run(c):
        import agentic
        fn = getattr(agentic, name)
        return _status(fn(c.home, c.family, c.entry, c.dry_run))
    return run


def _run_win_env(c):
    script = REPO_ROOT / 'install' / 'windows_env.ps1'
    exe = 'powershell' if shutil.which('powershell') else 'pwsh'
    cmd = [exe, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(script),
           '-UserProfile', str(c.home)]
    if c.dry_run or c.check:
        print(f"  [dry-run] {' '.join(cmd)}")
        return 'ok'
    if shutil.which(exe) is None:
        print("  notice: neither powershell nor pwsh found; skipping win-env")
        return 'skipped'
    try:
        r = subprocess.run(cmd, timeout=PLUGIN_TIMEOUT)
    except (OSError, subprocess.SubprocessError) as e:
        print(f"  warning: win-env failed: {e}", file=sys.stderr)
        return 'failed'
    return 'changed' if r.returncode == 0 else 'failed'


ALL_CTX = CONTEXTS

ASPECTS = [
    Aspect('vim-config', 'vim', ALL_CTX,
           'vimrc, ~/.vim backup/tmp dirs, syntax/html', _run_layout('vim-config')),
    Aspect('nvim-config', 'nvim', ALL_CTX,
           'nvim/ config directory link/copy', _run_layout('nvim-config')),
    Aspect('nvim-local', 'nvim', ALL_CTX,
           'generated nvim/lua/user/local.lua from csharp_lsp', _run_nvim_local),
    Aspect('git-config', 'git', ALL_CTX,
           '~/.gitconfig (+ Unity mergetool block)', _run_git_config),
    Aspect('git-templates', 'git', ALL_CTX,
           'repo-configs/ link/copy', _run_layout('git-templates')),
    Aspect('vim-plugins', 'vim', ALL_CTX,
           'download vim-plug and run vim +PlugInstall', _run_vim_plugins),
    Aspect('nvim-plugins', 'nvim', ALL_CTX,
           'nvim --headless "+Lazy! sync"', _run_nvim_plugins),
    Aspect('agentic-claude', 'agentic', ALL_CTX,
           'Claude Code statusline.py and settings.json', _run_agentic('sync_claude')),
    Aspect('agentic-codex', 'agentic', ALL_CTX,
           'Codex config.toml [tui] status_line', _run_agentic('sync_codex')),
    Aspect('agentic-shell', 'agentic', ALL_CTX,
           'ralph-loop/rloop shell aliases, profiles, shims', _run_agentic('sync_shell')),
    Aspect('win-env', 'win', ('windows',),
           'windows_env.ps1: pwsh 7, Claude env var, PATH', _run_win_env),
]

LABELS = [a.label for a in ASPECTS]
GROUPS = {g: [a.label for a in ASPECTS if a.label.startswith(g + '-')]
          for g in ('vim', 'nvim', 'git', 'agentic', 'win')}


def _expand(names):
    """Returns (set of labels, set of explicitly named labels)."""
    labels, explicit = set(), set()
    for n in names:
        if n == 'all':
            labels.update(LABELS)
        elif n in GROUPS:
            labels.update(GROUPS[n])
        elif n in LABELS:
            labels.add(n)
            explicit.add(n)
        else:
            raise ValueError(
                f"unknown label or group '{n}'.\n"
                f"  valid labels: {', '.join(LABELS)}\n"
                f"  valid groups: {', '.join(GROUPS)}, all")
    return labels, explicit


def resolve(selection, skip, ctx):
    """Returns (aspects_to_run in registry order, not_applicable_labels)."""
    selected, explicit = _expand(selection or ['all'])
    skipped, _ = _expand(skip or [])
    not_applicable = []
    run = []
    for a in ASPECTS:
        if a.label not in selected or a.label in skipped:
            continue
        if ctx not in a.contexts:
            if a.label in explicit:
                not_applicable.append(a.label)
            continue
        run.append(a)
    return run, not_applicable
