#!/usr/bin/env python3
"""Label-based, current-OS-only enforcer for this repo's setup.

Usage: enforce.py [LABEL ...] [--skip LABEL ...] [--dry-run] [--check]
                  [--list] [--os CTX] [--config PATH]
No labels means 'all'. Run --list for labels. See _config.sample.yml.
"""

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import aspects  # noqa: E402
import fs  # noqa: E402

REPO_ROOT = fs.REPO_ROOT


def _warn(msg):
    print(f"warning: {msg}", file=sys.stderr)


def build_parser():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('labels', nargs='*', help='labels/groups to enforce (default: all)')
    p.add_argument('--skip', nargs='+', default=[], metavar='LABEL',
                   help='labels/groups to leave out')
    p.add_argument('--dry-run', action='store_true',
                   help='no filesystem/network/subprocess side effects')
    p.add_argument('--check', action='store_true',
                   help='dry-run; exit 1 if anything would change')
    p.add_argument('--list', action='store_true', help='list labels and exit')
    p.add_argument('--os', dest='os_override', metavar='CTX',
                   help='override detected OS (windows|wsl|linux|mac); testing only')
    p.add_argument('--config', type=Path, default=REPO_ROOT / 'config.yml',
                   help='path to config.yml (default: repo root)')
    p.add_argument('--vim-only', action='store_true',
                   help='DEPRECATED: same as "vim nvim"')
    p.add_argument('--agentic-only', action='store_true',
                   help='DEPRECATED: same as "agentic"')
    p.add_argument('--only', nargs='*', help=argparse.SUPPRESS)
    return p


def pick_entry(config, family):
    for h in config.get('homes') or []:
        if isinstance(h, dict) and h.get('os') == family:
            return dict(h)
    return {}


def home_path(entry):
    raw = entry.get('path') or '~'
    if raw.startswith('~'):
        base = os.environ.get('HOME') or os.environ.get('USERPROFILE') or str(Path.home())
        raw = base + raw[1:]
    return Path(raw)


def _as_list(v):
    if v is None:
        return []
    return [v] if isinstance(v, str) else list(v)


def effective_skip(entry):
    skip = _as_list(entry.get('skip'))
    if entry.get('only_vim'):
        _warn("config 'only_vim' is deprecated; use skip: [git, agentic]")
        skip += ['git', 'agentic']
    if entry.get('agentic') is False:
        _warn("config 'agentic: false' is deprecated; use skip: [agentic]")
        skip.append('agentic')
    return skip


def print_list(ctx, selected):
    names = {a.label for a in selected}
    print(f"detected os: {ctx}")
    for a in aspects.ASPECTS:
        ok = ctx in a.contexts
        mark = 'yes' if ok else f'no (not applicable on {ctx})'
        sel = 'selected' if a.label in names else '-'
        print(f"  {a.label:<15} {sel:<9} applies: {mark:<8} {a.description}")
    print("groups: " + ', '.join(f"{g} ({' '.join(l)})" for g, l in aspects.GROUPS.items()))


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.only is not None:
        parser.error("--only was removed: the enforcer now only configures the OS it "
                     "runs on. Run it on that OS (install.ps1 for Windows) and pick "
                     "labels with positional args, e.g. 'enforce.py vim nvim'.")

    labels = list(args.labels)
    if args.vim_only:
        _warn("--vim-only is deprecated; use labels: vim nvim")
        labels += ['vim', 'nvim']
    if args.agentic_only:
        _warn("--agentic-only is deprecated; use label: agentic")
        labels.append('agentic')

    try:
        ctx = aspects.detect_os(args.os_override)
    except ValueError as e:
        parser.error(str(e))
    family = aspects.os_family(ctx)

    if args.config.exists():
        config = fs.load_config(args.config)
    else:
        print(f"note: no config at {args.config}; using defaults (home ~)")
        config = {}
    entry = pick_entry(config, family)
    home = home_path(entry)

    skip = list(args.skip)
    legacy = effective_skip(entry)
    if not labels:
        skip += legacy

    try:
        to_run, not_applicable = aspects.resolve(labels, skip, ctx)
    except ValueError as e:
        parser.error(str(e))

    if args.list:
        print_list(ctx, to_run)
        return 0

    for label in not_applicable:
        print(f"notice: {label} not applicable on {ctx}")

    dry = args.dry_run or args.check
    c = aspects.Context(home=home, ctx=ctx, family=family, entry=entry,
                        config=config, dry_run=dry, check=args.check)
    print(f"== {ctx}: {home} ==")
    results = []
    for a in to_run:
        print(f"-- {a.label} --")
        try:
            status = a.run(c)
        except Exception as e:  # noqa: BLE001
            print(f"  error: {e}", file=sys.stderr)
            status = 'failed'
        results.append((a.label, status))

    print("== summary ==")
    names = {'ok': 'up to date', 'changed': 'would change' if dry else 'changed'}
    for label, status in results:
        print(f"  {label:<15} {names.get(status, status)}")
    if any(s == 'failed' for _, s in results):
        return 1
    if args.check and any(s == 'changed' for _, s in results):
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
