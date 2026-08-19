#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
timestamp=$(date +%Y%m%d%H%M%S)

backup() {
  local target="$1"
  if [ -e "$target" ] || [ -L "$target" ]; then
    echo "Backing up $target -> ${target}_${timestamp}.bkp"
    mv "$target" "${target}_${timestamp}.bkp"
  fi
}

echo "== Classic Vim =="
mkdir -p ~/.vim/backup ~/.vim/tmp
backup ~/.vimrc
ln -s "$repo_dir/vim/vimrc" ~/.vimrc
backup ~/.vim/syntax
mkdir -p ~/.vim/syntax
backup ~/.vim/syntax/html
ln -s "$repo_dir/vim/syntax/html" ~/.vim/syntax/html
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

echo "== Neovim =="
mkdir -p ~/.config
backup ~/.config/nvim
ln -s "$repo_dir/nvim" ~/.config/nvim

echo "== git =="
backup ~/.gitconfig
cp "$repo_dir/gitconfig" ~/.gitconfig

if command -v vim >/dev/null 2>&1; then
  echo "== Installing classic Vim plugins =="
  vim +PlugInstall +qall || true
fi

if command -v nvim >/dev/null 2>&1; then
  echo "== Installing Neovim plugins =="
  nvim --headless "+Lazy! sync" +qa || true
fi

echo "Done."
