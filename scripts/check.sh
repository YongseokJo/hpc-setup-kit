#!/usr/bin/env bash
set -uo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0
warnings=0

pass() { printf 'PASS  %s\n' "$*"; }
warn() { printf 'WARN  %s\n' "$*"; warnings=$((warnings + 1)); }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }

check_bash() {
  local file="$1"
  if bash -n "$file"; then pass "bash syntax: ${file#"$KIT_ROOT/"}"; else fail "bash syntax: ${file#"$KIT_ROOT/"}"; fi
}

printf 'Repository checks\n'
for file in \
  "$KIT_ROOT/install.sh" \
  "$KIT_ROOT/install_full_stack.sh" \
  "$KIT_ROOT/setup_rclone.sh" \
  "$KIT_ROOT/bin/claude-main" \
  "$KIT_ROOT/scripts/tmux-slurm" \
  "$KIT_ROOT/scripts/slurm_free.sh" \
  "$KIT_ROOT/scripts/slurm_snapshot.sh"; do
  check_bash "$file"
done

check_bash "$KIT_ROOT/config/bashrc"
if command -v zsh >/dev/null 2>&1; then
  if zsh -n "$KIT_ROOT/config/zshrc"; then pass 'zsh syntax: config/zshrc'; else fail 'zsh syntax: config/zshrc'; fi
else
  warn 'zsh unavailable; config/zshrc was not parsed'
fi

audit_tmp="$(mktemp -d "${TMPDIR:-/tmp}/hpc-kit-check.XXXXXX")"
trap 'rm -rf "$audit_tmp"' EXIT

if command -v starship >/dev/null 2>&1; then
  if STARSHIP_CONFIG="$KIT_ROOT/config/starship.toml" starship prompt >/dev/null 2>"$audit_tmp/starship.err"; then
    pass 'Starship config parses'
  else
    fail "Starship config: $(sed -n '1p' "$audit_tmp/starship.err")"
  fi
else
  warn 'starship unavailable; config was not runtime-tested'
fi

if command -v tmux >/dev/null 2>&1; then
  socket="hpc-kit-check-$$"
  mkdir -p "$audit_tmp/home"
  if HOME="$audit_tmp/home" tmux -L "$socket" -f "$KIT_ROOT/config/tmux.conf" new-session -d 2>"$audit_tmp/tmux.err"; then
    tmux -L "$socket" kill-server >/dev/null 2>&1 || true
    pass 'tmux config loads in an isolated server'
  else
    fail "tmux config: $(sed -n '1p' "$audit_tmp/tmux.err")"
  fi
else
  warn 'tmux unavailable; config was not runtime-tested'
fi

if command -v nvim >/dev/null 2>&1; then
  if NVIM_LOG_FILE="$audit_tmp/nvim.log" nvim -u "$KIT_ROOT/config/nvim/init.lua" -i NONE --headless '+qa' >"$audit_tmp/nvim.out" 2>&1; then
    pass 'Neovim config starts headlessly'
  else
    fail "Neovim config: $(sed -n '1p' "$audit_tmp/nvim.out")"
  fi
else
  warn 'nvim unavailable; config was not runtime-tested'
fi

if "$KIT_ROOT/bin/claude-main" --help >/dev/null; then
  pass 'claude-main command starts'
else
  fail 'claude-main command failed'
fi

printf '\nLive installation checks\n'
pairs=(
  "$KIT_ROOT/config/tmux.conf|$HOME/.tmux.conf"
  "$KIT_ROOT/config/starship.toml|$HOME/.config/starship.toml"
  "$KIT_ROOT/config/nvim/init.lua|$HOME/.config/nvim/init.lua"
  "$KIT_ROOT/config/nvim/lazy-lock.json|$HOME/.config/nvim/lazy-lock.json"
  "$KIT_ROOT/vimrc|$HOME/.vimrc"
  "$KIT_ROOT/config/bashrc|$HOME/.bashrc"
  "$KIT_ROOT/config/zshrc|$HOME/.zshrc"
  "$KIT_ROOT/bin/claude-main|$HOME/.local/bin/claude-main"
  "$KIT_ROOT/scripts/tmux-slurm|$HOME/.local/bin/tmux-slurm"
  "$KIT_ROOT/scripts/slurm_free.sh|$HOME/.local/bin/slurm_free"
  "$KIT_ROOT/scripts/slurm_snapshot.sh|$HOME/.local/bin/slurm_snapshot"
)

for pair in "${pairs[@]}"; do
  src=${pair%%|*}
  dst=${pair#*|}
  if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
    pass "$dst"
  elif [ -e "$dst" ]; then
    warn "$dst exists but is not linked to the kit"
  else
    warn "$dst is not installed"
  fi
done

for cmd in git tmux vim nvim starship zoxide fzf; do
  if command -v "$cmd" >/dev/null 2>&1; then pass "command available: $cmd"; else warn "optional command missing: $cmd"; fi
done

if command -v tput >/dev/null 2>&1 && ! tput colors >/dev/null 2>&1; then
  warn "$(command -v tput) cannot load its runtime libraries"
fi

printf '\nSummary: %d failure(s), %d warning(s)\n' "$failures" "$warnings"
(( failures == 0 ))
