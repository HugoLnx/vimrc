#!/usr/bin/env python3
"""Symlinks this repo's vim/nvim config into the home directories listed in
config.yml. See _config.sample.yml for the config schema.

config.yml only says *where* each home directory is (per OS); the mapping
of which files/subfolders get linked under each home lives here, in
LAYOUTS below - not in the config file.
"""

import argparse
import datetime
import filecmp
import shutil
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def layout_for(os_name, home):
    """Returns {'ensure_dirs': [Path, ...], 'links': [(source_rel, target, copy), ...]}
    for the given os_name ('linux', 'mac', 'windows') and home root Path."""
    if os_name in ('linux', 'mac'):
        return {
            'ensure_dirs': [home / '.vim' / 'backup', home / '.vim' / 'tmp'],
            'links': [
                ('vim/vimrc', home / '.vimrc', False),
                ('vim/syntax/html', home / '.vim' / 'syntax' / 'html', False),
                ('nvim', home / '.config' / 'nvim', False),
                ('repo-configs', home / 'repo-configs', False),
            ],
        }
    if os_name == 'windows':
        return {
            'ensure_dirs': [home / 'vimfiles' / 'backup', home / 'vimfiles' / 'tmp'],
            'links': [
                ('vim/vimrc', home / '_vimrc', False),
                ('vim/syntax/html', home / 'vimfiles' / 'syntax' / 'html', False),
                ('nvim', home / 'AppData' / 'Local' / 'nvim', False),
                ('repo-configs', home / 'repo-configs', False),
            ],
        }
    raise ValueError(f"Unknown os '{os_name}' (expected linux, mac, or windows)")


def load_config(config_path):
    try:
        import yaml
    except ImportError:
        print(
            "error: PyYAML is required to read config.yml.\n"
            "Install it with: pip install pyyaml",
            file=sys.stderr,
        )
        sys.exit(1)

    with open(config_path) as f:
        data = yaml.safe_load(f) or {}
    return data.get('homes') or []


def backup_if_exists(target):
    if target.exists() or target.is_symlink():
        timestamp = datetime.datetime.now().strftime('%Y%m%d%H%M%S')
        backup_path = target.parent / f"{target.name}_{timestamp}.bkp"
        print(f"  backing up {target} -> {backup_path}")
        target.rename(backup_path)


def already_linked(source, target):
    if not target.is_symlink():
        return False
    try:
        return target.resolve() == source.resolve()
    except FileNotFoundError:
        return False


def copy_path(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    if source.is_dir():
        shutil.copytree(source, target)
    else:
        shutil.copy2(source, target)


def already_copied(source, target):
    if not target.is_file() or not source.is_file():
        return False
    return filecmp.cmp(source, target, shallow=False)


def link_or_copy(source, target, copy, dry_run):
    if copy:
        if already_copied(source, target):
            print(f"  up to date: {target}")
            return

        action = f"copy {source} -> {target}"
        if dry_run:
            print(f"  [dry-run] {action}")
            return
        print(f"  {action}")
        backup_if_exists(target)
        copy_path(source, target)
        return

    if already_linked(source, target):
        print(f"  up to date: {target}")
        return

    action = f"symlink {source} -> {target}"
    if dry_run:
        print(f"  [dry-run] {action}")
        return

    print(f"  {action}")
    backup_if_exists(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    try:
        target.symlink_to(source, target_is_directory=source.is_dir())
    except OSError as e:
        print(
            f"  warning: could not create symlink ({e}); falling back to copy.\n"
            f"           re-run this script after 'git pull' to pick up changes.",
            file=sys.stderr,
        )
        copy_path(source, target)


def gitconfig_content(unity_yaml_merge):
    content = (REPO_ROOT / 'gitconfig').read_text()
    if unity_yaml_merge:
        content += (
            '\n[mergetool "unityyamlmerge"]\n'
            '\ttrustExitCode = false\n'
            f'\tcmd = \'{unity_yaml_merge}\' merge -p "$BASE" "$REMOTE" "$LOCAL" "$MERGED"\n'
        )
    return content


def sync_gitconfig(target, unity_yaml_merge, dry_run):
    content = gitconfig_content(unity_yaml_merge)
    if target.is_file() and target.read_text() == content:
        print(f"  up to date: {target}")
        return

    action = f"write {target}"
    if dry_run:
        print(f"  [dry-run] {action}")
        return

    print(f"  {action}")
    backup_if_exists(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content)


def sync_home(entry, dry_run):
    os_name = entry.get('os')
    raw_path = entry.get('path')
    if not os_name or not raw_path:
        print(f"skipping incomplete homes entry: {entry}")
        return

    home = Path(raw_path).expanduser()
    print(f"== {os_name}: {home} ==")

    layout = layout_for(os_name, home)

    for d in layout['ensure_dirs']:
        if dry_run:
            print(f"  [dry-run] mkdir -p {d}")
        else:
            d.mkdir(parents=True, exist_ok=True)

    for source_rel, target, copy in layout['links']:
        source = REPO_ROOT / source_rel
        link_or_copy(source, target, copy, dry_run)

    sync_gitconfig(home / '.gitconfig', entry.get('unity_yaml_merge'), dry_run)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        '--config', default=REPO_ROOT / 'config.yml',
        type=Path, help='path to config.yml (default: repo root)',
    )
    parser.add_argument(
        '--dry-run', action='store_true',
        help='preview actions without touching the filesystem',
    )
    parser.add_argument(
        '--only', nargs='+', choices=['linux', 'mac', 'windows'],
        help='only sync homes matching these os values',
    )
    args = parser.parse_args()

    if not args.config.exists():
        print(f"error: config file not found: {args.config}", file=sys.stderr)
        sys.exit(1)

    homes = load_config(args.config)
    if args.only:
        homes = [h for h in homes if h.get('os') in args.only]

    if not homes:
        print("No homes configured (see _config.sample.yml). Nothing to do.")
        return

    for entry in homes:
        sync_home(entry, args.dry_run)


if __name__ == '__main__':
    main()
