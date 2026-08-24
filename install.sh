#!/usr/bin/env bash
set -euo pipefail

# Install the kit by symlinking its canonical configs and helper commands into
# $HOME. Re-running is safe: matching links are left alone and replaced files
# are timestamped rather than deleted.
#
# Layout (canonical):
#   config/tmux.conf      -> ~/.tmux.conf
#   config/starship.toml  -> ~/.config/starship.toml
#   config/nvim/*         -> ~/.config/nvim/*
#   config/bashrc         -> ~/.bashrc
#   config/zshrc          -> ~/.zshrc
#   vimrc                 -> ~/.vimrc              (kept at repo root)

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS=$(date +%Y%m%d-%H%M%S)
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: ./install.sh [--dry-run | --check]

  --dry-run  Show the links/backups that would be made.
  --check    Run the repository and live-install health checks.
  -h, --help Show this help.
EOF
}

case "${1:-}" in
  "") ;;
  --dry-run) DRY_RUN=1 ;;
  --check) exec "$REPO_DIR/scripts/check.sh" ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

ensure_dir() {
  local dir="$1"
  if (( DRY_RUN )); then
    [ -d "$dir" ] || echo "mkdir  $dir"
  else
    mkdir -p "$dir"
  fi
}

link () {
  local src="$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "ok     $dst"
    return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    echo "backup $dst -> $dst.bak.$TS"
    (( DRY_RUN )) || mv "$dst" "$dst.bak.$TS"
  fi
  (( DRY_RUN )) || ln -s "$src" "$dst"
  echo "link   $dst -> $src"
}

ensure_dir "$HOME/.config"
link "$REPO_DIR/config/tmux.conf"     "$HOME/.tmux.conf"
link "$REPO_DIR/config/starship.toml" "$HOME/.config/starship.toml"
ensure_dir "$HOME/.config/nvim"
link "$REPO_DIR/config/nvim/init.lua" "$HOME/.config/nvim/init.lua"
link "$REPO_DIR/config/nvim/lazy-lock.json" "$HOME/.config/nvim/lazy-lock.json"
link "$REPO_DIR/vimrc"                "$HOME/.vimrc"
link "$REPO_DIR/config/bashrc"        "$HOME/.bashrc"
link "$REPO_DIR/config/zshrc"         "$HOME/.zshrc"

# User commands onto PATH (both shell configs add ~/.local/bin).
ensure_dir "$HOME/.local/bin"
link "$REPO_DIR/bin/claude-main"      "$HOME/.local/bin/claude-main"
link "$REPO_DIR/scripts/tmux-slurm"   "$HOME/.local/bin/tmux-slurm"
link "$REPO_DIR/scripts/slurm_free.sh" "$HOME/.local/bin/slurm_free"
link "$REPO_DIR/scripts/slurm_snapshot.sh" "$HOME/.local/bin/slurm_snapshot"

if (( DRY_RUN )); then
  echo
  echo "Dry run only; nothing was changed."
  exit 0
fi

missing=()
for cmd in git tmux vim nvim starship zoxide fzf; do
  command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done

echo
echo "Done. Open a new shell / tmux session."
echo "  - claude-main:   resume the main Claude Code session for a repo"
echo "  - nvim plugins:  lazy.nvim installs on first launch"
echo "  - vim plugins:   vim +PluginInstall +qall  (Vundle auto-clones)"
echo "  - tmux plugins:  prefix (C-j) then I       (TPM)"
echo "  - Ghostty theme (LOCAL machine): copy ghostty-claude.config"
echo "                   into your Ghostty config and reload."
if (( ${#missing[@]} )); then
  echo
  echo "Optional tools not currently found: ${missing[*]}"
  echo "Configs guard optional integrations, but those features remain disabled"
  echo "until the corresponding tools are installed."
fi
echo
echo "Verify this installation with:  ./install.sh --check"
