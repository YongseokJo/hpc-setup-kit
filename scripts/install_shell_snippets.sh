#!/usr/bin/env bash
set -euo pipefail

BLOCK_START="# >>> tmux-vim-portable aliases >>>"
BLOCK_END="# <<< tmux-vim-portable aliases <<<"

read -r -d '' BLOCK_CONTENT <<'EOF'
# >>> tmux-vim-portable aliases >>>
### Alias
alias down_popeye="scp yjo10@popeye:~/ceph/transfer/* ~/ceph/transfer"
alias up_popeye="scp ~/ceph/transfer/* yjo10@popeye:~/ceph/transfer "
alias popeye="ssh popeye"
alias qs="squeue -u yjo10"
alias ll="ls -alrth"
alias psal="ps --user=yjo10 -ux"
alias venv="source ~/pyenv/venv/bin/activate"
alias newvenv="source ~/pyenv/newvenv/bin/activate"
alias torch="source ~/pyenv/torch/bin/activate"
alias nlp="source ~/pyenv/nlp/bin/activate"
alias sbi="source ~/pyenv/sbi/bin/activate"
alias yt_plot="source ~/pyenv/yt_plot/bin/activate"
alias venv_sbi="source ~/pyenv/venv_sbi/bin/activate"
alias lightning="source ~/pyenv/lightning/bin/activate"
alias mine="source ~/pyenv/mine/bin/activate"
alias MI="source ~/pyenv/MI/bin/activate"
alias tt="tmux attach -t 0"
alias reload_bash="source ~/.bash_profile"
alias gpu_check="~carriero/bin/gpuUsage -t 4 -u yjo10"
alias rr="ssh rustyamd2"
# alias sr="sbatch run.sh"

function sr {
  local last_file_path=".last_run_code"
  if [ $# -eq 1 ]; then
    echo "$1" > "$last_file_path"
    sbatch "$1"
  elif [ -f "$last_file_path" ]; then
    local last_file
    last_file=$(cat "$last_file_path")
    if [ -f "$last_file" ]; then
      sbatch "$last_file"
      echo "$last_file"
    else
      echo "Error: Previously saved file '$last_file' no longer exists in this directory."
    fi
  else
    echo "Usage: sr <filename>"
    echo "Or run without arguments to re-run the last script in this directory."
  fi
}

if [ -n "${BASH_VERSION:-}" ]; then
  set -o vi
  bind '"kj":vi-movement-mode'
  bind '"^z": run-fg-editor'
  bind '"\e[A": history-search-backward'
  bind '"\e[B": history-search-forward'
fi
# <<< tmux-vim-portable aliases <<<
EOF

add_block () {
  local rcfile="$1"
  [ -f "$rcfile" ] || touch "$rcfile"
  if grep -qF "$BLOCK_START" "$rcfile"; then
    awk -v start="$BLOCK_START" -v end="$BLOCK_END" -v repl="$BLOCK_CONTENT" '
      $0==start {print start; print repl; inblock=1; next}
      $0==end   {print end; inblock=0; next}
      !inblock  {print}
    ' "$rcfile" > "${rcfile}.tmp"
    mv "${rcfile}.tmp" "$rcfile"
  else
    { echo ""; echo "$BLOCK_CONTENT"; } >> "$rcfile"
  fi
  echo "Updated: $rcfile"
}

targets=()
[ -f "$HOME/.bashrc" ] && targets+=("$HOME/.bashrc")
[ -f "$HOME/.zshrc" ] && targets+=("$HOME/.zshrc")
if [ ${#targets[@]} -eq 0 ]; then
  if [[ "${SHELL:-}" == *zsh* ]]; then targets+=("$HOME/.zshrc"); else targets+=("$HOME/.bashrc"); fi
fi
for rc in "${targets[@]}"; do add_block "$rc"; done
echo "Done. source ~/.bashrc or ~/.zshrc"
