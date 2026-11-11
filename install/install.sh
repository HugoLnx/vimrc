#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -f "$repo_dir/config.yml" ]; then
  echo "== Creating config.yml from _config.sample.yml =="
  os_name="linux"
  [ "$(uname)" = "Darwin" ] && os_name="mac"
  cat > "$repo_dir/config.yml" <<EOF
homes:
  - os: $os_name
    path: "~"
EOF
  echo "Edit $repo_dir/config.yml to customize labels or your current OS home."
fi

python3="$(command -v python3 || command -v python)"
if [ -z "$python3" ]; then
  echo "error: Python 3 is required. Install python3 (and PyYAML) and re-run this script." >&2
  exit 1
fi

exec "$python3" "$repo_dir/install/enforce.py" "$@"
