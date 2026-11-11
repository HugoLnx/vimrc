#!/usr/bin/env python3
"""Deprecated shim: use install/enforce.py (label-based enforcer)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import enforce  # noqa: E402


def main(argv=None):
    print("warning: install/symlink.py is deprecated; use install/enforce.py",
          file=sys.stderr)
    return enforce.main(sys.argv[1:] if argv is None else argv)


if __name__ == '__main__':
    sys.exit(main())
