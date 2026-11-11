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

# WSL: configure the Windows side (pwsh, env var, PATH) for any windows home.
if grep -Eq '^[[:space:]]*-?[[:space:]]*os:[[:space:]]*"?windows' "$repo_dir/config.yml"; then
  if command -v powershell.exe >/dev/null 2>&1 && command -v wslpath >/dev/null 2>&1; then
    echo "== Windows environment (agentic) =="
    win_homes="$("$python3" - "$repo_dir/config.yml" <<'PYEOF' 2>/dev/null || true
import sys
try:
    import yaml
    for h in (yaml.safe_load(open(sys.argv[1])) or {}).get("homes") or []:
        if h.get("os") == "windows":
            print(h.get("win_path") or h.get("path") or "")
except Exception:
    pass
PYEOF
)"
    while IFS= read -r wh; do
      [ -n "$wh" ] || continue
      case "$wh" in
        [A-Za-z]:\\*|[A-Za-z]:/*) win_home="$wh" ;;
        *) win_home="$(wslpath -w "$wh" 2>/dev/null || true)" ;;
      esac
      if [ -z "$win_home" ]; then
        echo "warning: could not derive Windows path for '$wh'; skipping windows_env.ps1" >&2
        continue
      fi
      powershell.exe -NoProfile -ExecutionPolicy Bypass \
        -File "$(wslpath -w "$repo_dir/install/windows_env.ps1")" \
        -UserProfile "$win_home" \
        || echo "warning: windows_env.ps1 failed (non-fatal)" >&2
    done <<< "$win_homes"
  else
    echo "Notice: windows home configured but powershell.exe/wslpath unavailable (no WSL interop); skipping windows_env.ps1. Run install\\install.ps1 on Windows instead."
  fi
fi

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
