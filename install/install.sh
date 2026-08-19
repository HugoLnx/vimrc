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
  echo "Edit $repo_dir/config.yml if you want to sync other homes (e.g. a WSL Windows home)."
fi

python3="$(command -v python3 || command -v python)"
if [ -z "$python3" ]; then
  echo "error: python3 is required. Install it and re-run this script." >&2
  exit 1
fi

echo "== Symlinking config =="
"$python3" "$repo_dir/install/symlink.py"

echo "== vim-plug =="
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

if command -v vim >/dev/null 2>&1; then
  echo "== Installing classic Vim plugins =="
  vim +PlugInstall +qall || true
fi

if command -v nvim >/dev/null 2>&1; then
  echo "== Installing Neovim plugins =="
  nvim --headless "+Lazy! sync" +qa || true
fi

echo "Done."
