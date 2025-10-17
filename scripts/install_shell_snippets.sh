#!/usr/bin/env bash
set -euo pipefail

BLOCK_START="# >>> tmux-vim-portable aliases >>>"
BLOCK_END="# <<< tmux-vim-portable aliases <<<"

# 1) capture the block literally (no expansion)
tmp_block="$(mktemp)"
cat >"$tmp_block" <<'EOF'
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

# sbatch helper: remember last run script per directory
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

# Bash-only keybindings (guarded)
if [ -n "${BASH_VERSION:-}" ]; then
  set -o vi
	bind '"kj": vi-movement-mode'
	bind '"^z": run-fg-editor'
	bind '"\e[A": history-search-backward'
	bind '"\e[B": history-search-forward'
fi
# <<< tmux-vim-portable aliases <<<
EOF

update_one() {
	rc="$1"
	[ -f "$rc" ] || touch "$rc"

	tmp_rc="$(mktemp)"
	# 2) drop any existing block (between markers, inclusive)
	awk -v s="$BLOCK_START" -v e="$BLOCK_END" '
		BEGIN{inblk=0}
		$0==s {inblk=1; next}
		$0==e {inblk=0; next}
		!inblk {print}
		' "$rc" > "$tmp_rc"

	# ensure trailing newline
	printf "\n" >> "$tmp_rc"
	# 3) append the fresh block
	cat "$tmp_block" >> "$tmp_rc"

	mv "$tmp_rc" "$rc"
	echo "Updated: $rc"
}

targets=()
[ -f "$HOME/.bashrc" ] && targets+=("$HOME/.bashrc")
[ -f "$HOME/.zshrc" ] && targets+=("$HOME/.zshrc")
if [ "${#targets[@]}" -eq 0 ]; then
	case "${SHELL:-}" in *zsh*) targets+=("$HOME/.zshrc");; *) targets+=("$HOME/.bashrc");; esac
fi

for rc in "${targets[@]}"; do
	update_one "$rc"
done

rm -f "$tmp_block"
echo "Done. Run:  source ~/.bashrc   or   source ~/.zshrc"
