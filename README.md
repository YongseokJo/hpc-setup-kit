# HPC Setup Kit

Personal, no-sudo shell and terminal setup for the Delta cluster. The kit keeps
one canonical copy of each config in Git and symlinks it into `$HOME`, so a
`git pull` updates installed settings without copying files again.

## Quick start

```bash
git clone git@github.com:YongseokJo/hpc-setup-kit.git
cd hpc-setup-kit
./install.sh --dry-run
./install.sh
./install.sh --check
```

`install.sh` is the normal and recommended entry point. Existing destination
files are renamed with a timestamp before links are created. It installs:

| Repository source | Destination |
|---|---|
| `config/bashrc` | `~/.bashrc` |
| `config/zshrc` | `~/.zshrc` |
| `config/tmux.conf` | `~/.tmux.conf` |
| `config/starship.toml` | `~/.config/starship.toml` |
| `config/nvim/init.lua` | `~/.config/nvim/init.lua` |
| `config/nvim/lazy-lock.json` | `~/.config/nvim/lazy-lock.json` |
| `vimrc` | `~/.vimrc` |
| `bin/claude-main` | `~/.local/bin/claude-main` |
| `scripts/tmux-slurm` | `~/.local/bin/tmux-slurm` |
| `scripts/slurm_free.sh` | `~/.local/bin/slurm_free` |
| `scripts/slurm_snapshot.sh` | `~/.local/bin/slurm_snapshot` |

After installation, open a new login shell. Both shell configs put
`~/.local/bin` on `PATH`.

## Installing tools

The config installer does not download software. Optional integrations are
guarded, so the shell still starts when a tool is unavailable.

For a new no-sudo account, `./install_full_stack.sh` can bootstrap missing tools
under `~/.local`. It is additive: it preserves existing editor/config state and
calls `install.sh` for the final links. It downloads and builds software, so use
the regular installer when the cluster already provides the tools you need.

Core tools used by the configuration include Bash or Zsh, tmux, Git, Vim or
Neovim, Starship, zoxide, and fzf. Slurm helpers additionally need the standard
Slurm client commands.

## Updating

```bash
cd ~/pkg/hpc-setup-kit
git pull --ff-only
./install.sh --check
```

Symlinked configs and commands—including `claude-main`—update immediately after
the pull. Re-run `install.sh` only when the repository adds a new managed file or
one of the destination links was replaced.

## Commands

- `claude-main [PATH]`: resume the largest Claude Code session for a repository.
- `claude-main --print [PATH]`: show the chosen session without launching it.
- `claude-main --all`: list the main session for every known Claude project.
- `slurm_free PARTITION`: suggest jobs that fit currently idle resources.
- `slurm_snapshot PARTITION`: print queue, partition, and start-now guidance.
- `tmux-slurm`: compact running/pending count used by the tmux status line.

Run `claude-main --help` and the Slurm helpers without arguments for details.

## tmux

The prefix is `Ctrl-j`.

| Key | Action |
|---|---|
| `prefix R` | Reload `~/.tmux.conf` |
| `prefix v` / `prefix s` | Split horizontally / vertically |
| `prefix h/j/k/l` | Move between panes |
| `prefix ;` | Enter copy mode |
| `v`, then `y` in copy mode | Select and copy through tmux/OSC52 |

TPM is optional. To install it manually:

```bash
git clone --depth 1 https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

Reload tmux, then use `prefix I`. The config loads normally when TPM is absent.

## Theme

tmux, Starship, Vim, and Neovim share the Claude-light cream/clay palette.
`ghostty-claude.config` contains the matching local-terminal colors. Copy that
file into Ghostty on the machine where Ghostty runs; it is not installed on the
remote cluster.

## rclone

`./setup_rclone.sh` installs a checksum-verified current rclone binary into
`~/.local/bin` and decrypts `rclone/rclone.gpg` into the standard private config
location. It never writes decrypted material into the repository.

```bash
./setup_rclone.sh                 # binary and config
./setup_rclone.sh --binary-only
./setup_rclone.sh --config-only
```

An existing `rclone.conf` is backed up before replacement.

## Repository layout

```text
config/       Canonical shell, tmux, prompt, and Neovim configuration
bin/          User-facing commands installed into ~/.local/bin
scripts/      Installer checks and Slurm/tmux helpers
debug_tools/  Site-specific experimental debugging/build scripts
rclone/       Encrypted rclone configuration only
```

`debug_tools` is not run by either installer and may require site-specific
module or compiler changes.

## Verification and troubleshooting

Run `./install.sh --check` after installation or an update. It validates shell
syntax, parses the terminal/editor configs where the relevant program exists,
checks every managed symlink, and reports missing optional commands.

If a locally built `tput` or `infocmp` reports a missing `libtinfow`, remove it
from the front of `PATH` or rebuild ncurses with a runtime search path. The
full-stack installer now adds that runtime path to future ncurses builds.
