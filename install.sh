#!/usr/bin/env bash
set -euo pipefail

# Symlink all dotfiles from this kit into $HOME. Idempotent: re-running only
# relinks what's missing or wrong, and backs up anything it replaces.
#
# Layout (canonical):
#   config/tmux.conf      -> ~/.tmux.conf
#   config/starship.toml  -> ~/.config/starship.toml
#   config/nvim/init.lua  -> ~/.config/nvim/init.lua
#   config/bashrc         -> ~/.bashrc
#   config/zshrc          -> ~/.zshrc
#   vimrc                 -> ~/.vimrc              (kept at repo root)

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS=$(date +%Y%m%d-%H%M%S)

link () {
  local src="$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "ok     $dst"
    return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    echo "backup $dst -> $dst.bak.$TS"
    mv "$dst" "$dst.bak.$TS"
  fi
  ln -s "$src" "$dst"
  echo "link   $dst -> $src"
}

mkdir -p "$HOME/.config"
link "$REPO_DIR/config/tmux.conf"     "$HOME/.tmux.conf"
link "$REPO_DIR/config/starship.toml" "$HOME/.config/starship.toml"
mkdir -p "$HOME/.config/nvim"
link "$REPO_DIR/config/nvim/init.lua" "$HOME/.config/nvim/init.lua"
link "$REPO_DIR/vimrc"                "$HOME/.vimrc"
link "$REPO_DIR/config/bashrc"        "$HOME/.bashrc"
link "$REPO_DIR/config/zshrc"         "$HOME/.zshrc"

echo
echo "Done. Open a new shell / tmux session."
echo "  - nvim plugins:  lazy.nvim installs on first launch"
echo "  - vim plugins:   vim +PluginInstall +qall  (Vundle auto-clones)"
echo "  - tmux plugins:  prefix (C-j) then I       (TPM)"
echo "  - Ghostty theme (LOCAL machine): copy ghostty-claude.config"
echo "                   into your Ghostty config and reload."
