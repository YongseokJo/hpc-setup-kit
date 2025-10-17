#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- tmux ---
if [ -f "$HOME/.tmux.conf" ] && [ ! -L "$HOME/.tmux.conf" ]; then
  mv "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak.$(date +%s)"
fi
ln -sf "$REPO_DIR/tmux.conf" "$HOME/.tmux.conf"

if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

# --- vim ---
if [ -f "$HOME/.vimrc" ] && [ ! -L "$HOME/.vimrc" ]; then
  mv "$HOME/.vimrc" "$HOME/.vimrc.bak.$(date +%s)"
fi
ln -sf "$REPO_DIR/vimrc" "$HOME/.vimrc"

# Bootstrap Vundle (vimrc also auto-clones it, but do it here to avoid first-run delay)
if [ ! -d "$HOME/.vim/bundle/Vundle.vim" ]; then
  git clone https://github.com/VundleVim/Vundle.vim "$HOME/.vim/bundle/Vundle.vim"
fi

# Non-interactive plugin install (safe if vim is headless on clusters)
if command -v vim >/dev/null 2>&1; then
  vim +PluginInstall +qall || true
fi

cat << 'MSG'
Installed.

tmux:
  - Start tmux, then press:  prefix (C-j) + I  to install tmux plugins
  - Reload: prefix + R

vim:
  - Plugins installed via Vundle; if YouCompleteMe is present:
      cd ~/.vim/bundle/YouCompleteMe && python3 install.py --clangd-completer || true
    (optional; skip if toolchain unavailable on the cluster)
MSG
