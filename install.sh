#!/usr/bin/env bash
set -euo pipefail

# Use BASH_SOURCE when available; fall back to $0; protect dirname with --
SELF="${BASH_SOURCE[0]:-$0}"
REPO_DIR="$(cd "$(dirname -- "$SELF")" && pwd)"

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

# Ensure Zenburn present (plugin + direct colors fallback)
if [ ! -d "$HOME/.vim/bundle/zenburn" ]; then
  echo "[vim] Installing Zenburn colorscheme..."
  git clone https://github.com/jnurmine/Zenburn.git "$HOME/.vim/bundle/zenburn"
fi

# Put/Link the colors file where Vim always finds it
mkdir -p "$HOME/.vim/colors"
if [ -f "$HOME/.vim/bundle/zenburn/colors/zenburn.vim" ]; then
  ln -sf "$HOME/.vim/bundle/zenburn/colors/zenburn.vim" "$HOME/.vim/colors/zenburn.vim"
fi

# Non-interactive plugin install (safe if vim is headless on clusters)
if command -v vim >/dev/null 2>&1; then
  vim +PluginInstall +qall || true
fi

# --- shell aliases/functions (bashrc/zshrc) ---
if [ -x "$REPO_DIR/scripts/install_shell_snippets.sh" ]; then
  "$REPO_DIR/scripts/install_shell_snippets.sh"
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

shell:
  - Aliases/functions added between markers in ~/.bashrc and/or ~/.zshrc
MSG
