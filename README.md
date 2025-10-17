# tmux config (portable)

1) Clone:
   git clone https://github.com/<you>/tmux.git
   cd tmux

2) Install:
   ./install.sh

3) In tmux, install plugins:
   prefix (C-j) then I

Clipboard notes:
- macOS: uses pbcopy/pbpaste automatically
- Linux X11: xclip if available
- Wayland: wl-copy/wl-paste if available
- Otherwise falls back to OSC52 via tmux-yank

Tips:
- Reload config: prefix + R
- Split: v (vertical), s (horizontal)
- Move panes: h/j/k/l


## Vim (portable)

- Config: symlinked to `~/.vimrc`
- Plugin manager: **Vundle** (auto-cloned on first run)
- First install:
  ./install.sh
  vim +PluginInstall +qall

### Optional: YouCompleteMe build
If toolchain exists on the cluster:
  cd ~/.vim/bundle/YouCompleteMe
  python3 install.py --clangd-completer

If not available, skip YCM; the rest works fine.


