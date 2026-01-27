#!/bin/bash
set -e

# ==============================================================================
# GEMINI HPC FULL STACK INSTALLER (CLEAN SLATE)
# ==============================================================================
# Installs: Neovim, Tmux, Starship, Fzf, Ripgrep, Lazygit, Fd, Zoxide, Gh, Glow, Jq
# Target: ~/.local/bin
# Behavior: DELETES existing configs/binaries and reinstalls from Kit.
# ==============================================================================

# 1. SETUP VARIABLES
# ------------------------------------------------------------------------------
KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PREFIX="$HOME/.local"
BIN_DIR="$INSTALL_PREFIX/bin"
LIB_DIR="$INSTALL_PREFIX/lib"
INCLUDE_DIR="$INSTALL_PREFIX/include"
MAN_DIR="$INSTALL_PREFIX/share/man"
TMP_DIR="${TMP_DIR:-$KIT_ROOT/tmp}" # Downloads and build artifacts (overrideable)

CONFIG_SRC="$KIT_ROOT/config"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${RED}!!! WARNING: CLEAN SLATE INSTALLATION !!!${NC}"
echo -e "${RED}This will DELETE existing Neovim, Tmux, and Starship configurations/binaries in $HOME.${NC}"
echo -e "${BLUE}Installation Target: $BIN_DIR${NC}"
echo -e "${BLUE}Configuration Source: $CONFIG_SRC${NC}"
sleep 2

# 2. CLEANUP (DELETE EVERYTHING RELATED)
# ------------------------------------------------------------------------------
echo -e "${RED}>>> Cleaning up old configurations...${NC}"

# Remove Binaries (SKIPPED: User wants to keep binaries if they exist)
# rm -f "$BIN_DIR/nvim" "$BIN_DIR/tmux" "$BIN_DIR/starship" "$BIN_DIR/rg" "$BIN_DIR/lazygit" "$BIN_DIR/fzf" "$BIN_DIR/tmux-slurm" "$BIN_DIR/fd" "$BIN_DIR/zoxide" "$BIN_DIR/gh" "$BIN_DIR/glow" "$BIN_DIR/jq"

# Remove Configs
rm -rf "$HOME/.config/nvim"
rm -f "$HOME/.tmux.conf"
rm -f "$HOME/.config/starship.toml"

# Remove Data/State (Deep Clean)
rm -rf "$HOME/.local/share/nvim"
rm -rf "$HOME/.tmux"
rm -rf "$HOME/.fzf"
# rm -rf "$HOME/opt/nvim" # User specified path - Keep if exists

# Remove Libs (Optional, but ensures clean link)
# rm -f "$LIB_DIR"/libevent* "$LIB_DIR"/libncurses* 

mkdir -p "$BIN_DIR" "$LIB_DIR" "$INCLUDE_DIR" "$MAN_DIR" "$TMP_DIR"

# Export paths for compilation
# export CFLAGS="-I$INCLUDE_DIR"
# export LDFLAGS="-L$LIB_DIR -Wl,-rpath,$LIB_DIR"
if [ -n "$PKG_CONFIG_PATH" ]; then
    export PKG_CONFIG_PATH="$LIB_DIR/pkgconfig:$PKG_CONFIG_PATH"
else
    export PKG_CONFIG_PATH="$LIB_DIR/pkgconfig"
fi
export PATH="$BIN_DIR:$PATH"
export LD_LIBRARY_PATH="$LIB_DIR:$LD_LIBRARY_PATH"
# Prefer real compilers over HPC wrappers for local builds.
case "$(basename "${CC:-gcc}")" in
    cc|CC|mpicc|mpiicc|mpicxx|mpiicpc)
        export CC="gcc"
        export CXX="g++"
        ;;
    *)
        export CC="${CC:-gcc}"
        export CXX="${CXX:-g++}"
        ;;
esac

# 2.0. SETUP MODULES (HPC Environment)
# ------------------------------------------------------------------------------
if type module &> /dev/null; then
    echo -e "${YELLOW}Attempting to load modules: gcc/11.2.0 cmake ninja${NC}"
    # Load a specific newer GCC version - the default gcc (4.6.3) is too old and its
    # libstdc++.so.6 lacks GLIBCXX symbols required by cmake 3.25.2
    module load gcc/11.2.0 cmake/3.25.2 2>/dev/null || echo -e "${YELLOW}Some modules failed to load, checking PATH...${NC}"
fi

# 2.1. CHECK DEPENDENCIES
# ------------------------------------------------------------------------------
required_cmds="gcc make curl tar git pkg-config cmake"
missing_cmds=""
for cmd in $required_cmds; do
    if ! command -v $cmd &> /dev/null; then
        missing_cmds="$missing_cmds $cmd"
    fi
done

if [ -n "$missing_cmds" ]; then
    echo -e "${RED}Error: Missing required commands:${YELLOW}$missing_cmds${NC}"
    echo -e "${RED}Since you don't have sudo, these must be available in your environment modules or installed by an admin.${NC}"
    exit 1
fi

# 3. HELPER FUNCTIONS
# ------------------------------------------------------------------------------
check_c_compiler() {
    local cc="${CC:-gcc}"
    local test_dir="$TMP_DIR/cc-test"
    echo -e "${BLUE}>>> Checking C compiler (${cc})...${NC}"
    rm -rf "$test_dir"
    mkdir -p "$test_dir"
    cat > "$test_dir/conftest.c" <<'EOF'
int main(void) { return 0; }
EOF
    if ! "$cc" "$test_dir/conftest.c" -o "$test_dir/conftest" > "$test_dir/compile.log" 2>&1; then
        echo -e "${RED}C compiler failed to compile a test program.${NC}"
        tail -n 40 "$test_dir/compile.log" || true
        echo -e "${YELLOW}Hint: Missing libc headers/dev packages (e.g., glibc-devel) or broken toolchain/module.${NC}"
        echo -e "${YELLOW}If your environment sets CC to a wrapper (cc/mpicc/mpiicc), try: CC=gcc CXX=g++ ./install_full_stack.sh${NC}"
        exit 1
    fi
    if ! "$test_dir/conftest" > /dev/null 2>&1; then
        echo -e "${RED}C compiler produced a binary that cannot run.${NC}"
        echo -e "${YELLOW}Hint: Filesystem may be mounted noexec. Try setting TMP_DIR to an executable path (e.g., TMP_DIR=\$HOME/.local/src).${NC}"
        exit 1
    fi
}

download_and_extract() {
    local url=$1
    local filename=$(basename "$url")
    echo -e "${YELLOW}Processing $filename...${NC}"
    cd "$TMP_DIR"
    
    # Check if file exists and is a valid tarball
    if [ -f "$filename" ]; then
        if ! tar -tf "$filename" &>/dev/null; then
            echo -e "${RED}File $filename exists but is invalid/corrupted. Deleting...${NC}"
            rm -f "$filename"
        else
            echo -e "${BLUE}File $filename already exists and is valid. Skipping download.${NC}"
        fi
    fi

    if [ ! -f "$filename" ]; then
        echo -e "${YELLOW}Downloading $filename...${NC}"
        if ! curl -L --fail -O "$url"; then
            echo -e "${RED}Download failed for $url${NC}"
            return 1
        fi
    fi
    
    echo -e "${YELLOW}Extracting $filename...${NC}"
    tar -xf "$filename"
}

# 4. INSTALL DEPENDENCIES (Ncurses, Libevent)
# ------------------------------------------------------------------------------
echo -e "${GREEN}>>> Installing Dependencies (Ncurses, Libevent)...${NC}"
echo -e "${BLUE}(Note: You may see 'ldconfig: Permission denied' errors. This is normal without sudo and can be ignored.)${NC}"

# Unset these to ensure clean build for dependencies
unset CFLAGS LDFLAGS
check_c_compiler

# Ncurses
if [ -f "$LIB_DIR/pkgconfig/ncurses.pc" ] || [ -f "$LIB_DIR/libncursesw.so" ]; then
     echo -e "${BLUE}Ncurses already installed. Skipping.${NC}"
else
    NCURSES_VER="6.4"
    rm -rf "$TMP_DIR/ncurses-${NCURSES_VER}" # Ensure clean build dir
    download_and_extract "https://ftp.gnu.org/pub/gnu/ncurses/ncurses-${NCURSES_VER}.tar.gz"
    cd "$TMP_DIR/ncurses-${NCURSES_VER}"
    # Simplified config matching user's success
    if ! ./configure --prefix="$INSTALL_PREFIX" --with-shared --with-termlib --enable-widec > "$TMP_DIR/ncurses-configure.log" 2>&1; then
        echo -e "${RED}Ncurses configure failed. Showing tail of log:${NC}"
        tail -n 60 "$TMP_DIR/ncurses-configure.log" || true
        tail -n 60 "$TMP_DIR/ncurses-${NCURSES_VER}/config.log" || true
        exit 1
    fi
    make -j$(nproc) > /dev/null
    make install > /dev/null 2>&1 || true # Suppress ldconfig noise
    # Create compatibility symlinks (ncursesw -> ncurses) for programs expecting non-wide names
    cd "$LIB_DIR"
    ln -sf libncursesw.so libncurses.so
    ln -sf libncursesw.so.6 libncurses.so.6
    ln -sf libtinfow.so libtinfo.so
    ln -sf libtinfow.so.6 libtinfo.so.6
    cd "$INCLUDE_DIR"
    ln -sf ncursesw ncurses
fi

# Libevent
if [ -f "$LIB_DIR/lib/libevent.so" ] || [ -f "$LIB_DIR/libevent.so" ] || [ -f "$LIB_DIR/lib/libevent.a" ]; then
    echo -e "${BLUE}Libevent already installed. Skipping.${NC}"
else
    LIBEVENT_VER="2.1.12-stable"
    download_and_extract "https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VER}/libevent-${LIBEVENT_VER}.tar.gz"
    cd "$TMP_DIR/libevent-${LIBEVENT_VER}"
    ./configure --prefix="$INSTALL_PREFIX" > /dev/null
    make -j$(nproc) > /dev/null
    make install > /dev/null 2>&1 || true
fi

# 5. INSTALL TMUX
# ------------------------------------------------------------------------------
TMUX_VER="3.6a"
TMUX_NEED_INSTALL=1
if command -v tmux &> /dev/null; then
    TMUX_INSTALLED_VER="$(tmux -V 2>/dev/null)"
    TMUX_INSTALLED_VER="${TMUX_INSTALLED_VER#tmux }"
    if [ "$TMUX_INSTALLED_VER" = "$TMUX_VER" ]; then
        TMUX_NEED_INSTALL=0
    fi
elif [ -f "$BIN_DIR/tmux" ]; then
    TMUX_INSTALLED_VER="$("$BIN_DIR/tmux" -V 2>/dev/null)"
    TMUX_INSTALLED_VER="${TMUX_INSTALLED_VER#tmux }"
    if [ "$TMUX_INSTALLED_VER" = "$TMUX_VER" ]; then
        TMUX_NEED_INSTALL=0
    fi
fi

if [ "$TMUX_NEED_INSTALL" -eq 0 ]; then
    echo -e "${BLUE}Tmux ${TMUX_VER} already installed. Skipping.${NC}"
else
    echo -e "${GREEN}>>> Installing Tmux ${TMUX_VER}...${NC}"
    download_and_extract "https://github.com/tmux/tmux/releases/download/${TMUX_VER}/tmux-${TMUX_VER}.tar.gz"
    cd "$TMP_DIR/tmux-${TMUX_VER}"
    # User requested: ./configure CFLAGS="-I$MY_LOCAL/include" LDFLAGS="-L$MY_LOCAL/lib" --prefix=$MY_LOCAL
    # We map $MY_LOCAL to $INSTALL_PREFIX
    ./configure CFLAGS="-I$INSTALL_PREFIX/include -I$INSTALL_PREFIX/include/ncursesw" LDFLAGS="-L$INSTALL_PREFIX/lib -Wl,-rpath,$INSTALL_PREFIX/lib" --prefix="$INSTALL_PREFIX" > /dev/null
    make -j$(nproc) > /dev/null
    make install > /dev/null
fi

# 6. INSTALL BINARIES (Neovim, Ripgrep, Lazygit)
# ------------------------------------------------------------------------------
echo -e "${GREEN}>>> Installing Binaries (Neovim, Ripgrep, Lazygit)...${NC}"

# Neovim (Build from Source)
if [ -x "$HOME/opt/nvim/bin/nvim" ]; then
    echo -e "${BLUE}Neovim already installed at $HOME/opt/nvim. Skipping build.${NC}"
else
    echo -e "${GREEN}>>> Building Neovim from source...${NC}"

    # Verify cmake version (Neovim requires 3.13+)
    CMAKE_VER=$(cmake --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    CMAKE_MAJOR=$(echo "$CMAKE_VER" | cut -d. -f1)
    CMAKE_MINOR=$(echo "$CMAKE_VER" | cut -d. -f2)
    if [ -z "$CMAKE_MAJOR" ] || [ "$CMAKE_MAJOR" -lt 3 ] || { [ "$CMAKE_MAJOR" -eq 3 ] && [ "$CMAKE_MINOR" -lt 13 ]; }; then
        echo -e "${RED}Error: Neovim requires CMake >= 3.13, but found version $CMAKE_VER${NC}"
        echo -e "${YELLOW}Current cmake: $(which cmake)${NC}"
        echo -e "${YELLOW}Try loading a newer cmake module: module load cmake/3.x${NC}"
    fi

    cd "$TMP_DIR"
    if [ -d "neovim" ]; then
        rm -rf neovim
    fi
    git clone https://github.com/neovim/neovim
    cd neovim

    # Use Unix Makefiles if ninja is not available
    if command -v ninja &> /dev/null; then
        echo -e "${BLUE}Using Ninja generator${NC}"
        make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="$HOME/opt/nvim"
    else
        echo -e "${YELLOW}Ninja not found, using Unix Makefiles${NC}"
        make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="$HOME/opt/nvim" CMAKE_GENERATOR="Unix Makefiles"
    fi
    make install
fi

# Symlink to BIN_DIR for consistency with the rest of this script
ln -sf "$HOME/opt/nvim/bin/nvim" "$BIN_DIR/nvim"

# Ripgrep
if [ -x "$BIN_DIR/rg" ]; then
    echo -e "${BLUE}Ripgrep already installed. Skipping.${NC}"
else
    RG_VER="14.1.0"
    RG_ARCHIVE="ripgrep-${RG_VER}-x86_64-unknown-linux-musl.tar.gz"

    if [ -f "$RG_ARCHIVE" ] && ! tar -tf "$RG_ARCHIVE" &>/dev/null; then
        echo -e "${RED}Invalid Ripgrep archive found. Deleting...${NC}"
        rm -f "$RG_ARCHIVE"
    fi

    if [ ! -f "$RG_ARCHIVE" ]; then
        echo -e "${YELLOW}Downloading Ripgrep...${NC}"
        curl -L --fail -O "https://github.com/BurntSushi/ripgrep/releases/download/${RG_VER}/$RG_ARCHIVE"
    fi
    tar -xf "$RG_ARCHIVE"
    cp "ripgrep-${RG_VER}-x86_64-unknown-linux-musl/rg" "$BIN_DIR/"
fi

# Fd
if [ -x "$BIN_DIR/fd" ]; then
    echo -e "${BLUE}Fd already installed. Skipping.${NC}"
else
    echo -e "${GREEN}>>> Installing Fd...${NC}"
    FD_VER="10.2.0"
    FD_ARCHIVE="fd-v${FD_VER}-x86_64-unknown-linux-musl.tar.gz"

    if [ -f "$FD_ARCHIVE" ] && ! tar -tf "$FD_ARCHIVE" &>/dev/null; then
        rm -f "$FD_ARCHIVE"
    fi

    if [ ! -f "$FD_ARCHIVE" ]; then
        curl -L --fail -O "https://github.com/sharkdp/fd/releases/download/v${FD_VER}/$FD_ARCHIVE"
    fi
    tar -xf "$FD_ARCHIVE"
    cp "fd-v${FD_VER}-x86_64-unknown-linux-musl/fd" "$BIN_DIR/"
fi

# Zoxide
if [ -x "$BIN_DIR/zoxide" ]; then
    echo -e "${BLUE}Zoxide already installed. Skipping.${NC}"
else
    echo -e "${GREEN}>>> Installing Zoxide...${NC}"
    ZOXIDE_VER="0.9.6"
    ZOXIDE_ARCHIVE="zoxide-${ZOXIDE_VER}-x86_64-unknown-linux-musl.tar.gz"

    if [ -f "$ZOXIDE_ARCHIVE" ] && ! tar -tf "$ZOXIDE_ARCHIVE" &>/dev/null; then
        rm -f "$ZOXIDE_ARCHIVE"
    fi

    if [ ! -f "$ZOXIDE_ARCHIVE" ]; then
        curl -L --fail -O "https://github.com/ajeetdsouza/zoxide/releases/download/v${ZOXIDE_VER}/$ZOXIDE_ARCHIVE"
    fi
    tar -xf "$ZOXIDE_ARCHIVE"
    cp "zoxide" "$BIN_DIR/"
fi

# GitHub CLI (gh)
if [ -x "$BIN_DIR/gh" ]; then
    echo -e "${BLUE}GitHub CLI already installed. Skipping.${NC}"
else
    echo -e "${GREEN}>>> Installing GitHub CLI...${NC}"
    GH_VER="2.63.0"
    GH_ARCHIVE="gh_${GH_VER}_linux_amd64.tar.gz"

    if [ -f "$GH_ARCHIVE" ] && ! tar -tf "$GH_ARCHIVE" &>/dev/null; then
        rm -f "$GH_ARCHIVE"
    fi

    if [ ! -f "$GH_ARCHIVE" ]; then
        curl -L --fail -O "https://github.com/cli/cli/releases/download/v${GH_VER}/$GH_ARCHIVE"
    fi
    tar -xf "$GH_ARCHIVE"
    cp "gh_${GH_VER}_linux_amd64/bin/gh" "$BIN_DIR/"
fi

# Glow
if [ -x "$BIN_DIR/glow" ]; then
    echo -e "${BLUE}Glow already installed. Skipping.${NC}"
else
    echo -e "${GREEN}>>> Installing Glow...${NC}"
    GLOW_VER="2.0.0"
    GLOW_ARCHIVE="glow_${GLOW_VER}_linux_x86_64.tar.gz"

    if [ -f "$GLOW_ARCHIVE" ] && ! tar -tf "$GLOW_ARCHIVE" &>/dev/null; then
        rm -f "$GLOW_ARCHIVE"
    fi

    if [ ! -f "$GLOW_ARCHIVE" ]; then
        curl -L --fail -O "https://github.com/charmbracelet/glow/releases/download/v${GLOW_VER}/$GLOW_ARCHIVE"
    fi
    tar -xf "$GLOW_ARCHIVE"
    # The binary is inside a subdirectory
    cp glow*/glow "$BIN_DIR/"
fi

# Jq
if [ -x "$BIN_DIR/jq" ]; then
    echo -e "${BLUE}Jq already installed. Skipping.${NC}"
else
    echo -e "${GREEN}>>> Installing Jq...${NC}"
    JQ_VER="1.8.1"
    cd "$TMP_DIR"
    if [ ! -f "jq-linux64" ]; then
        curl -L --fail -o jq-linux64 "https://github.com/jqlang/jq/releases/download/jq-${JQ_VER}/jq-linux-amd64"
    fi
    cp jq-linux64 "$BIN_DIR/jq"
    chmod +x "$BIN_DIR/jq"
fi

# Lazygit
if [ -x "$BIN_DIR/lazygit" ]; then
    echo -e "${BLUE}Lazygit already installed. Skipping.${NC}"
else
    echo -e "${GREEN}>>> Installing Lazygit...${NC}"
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | sed -n 's/.*"tag_name": "v\([^"]*\)".*/\1/p' | head -n 1)

    if [ -z "$LAZYGIT_VERSION" ]; then
        echo -e "${YELLOW}Could not detect latest Lazygit version. Defaulting to 0.40.2${NC}"
        LAZYGIT_VERSION="0.40.2"
    fi

    echo -e "Detected Lazygit version: ${LAZYGIT_VERSION}"

    if [ ! -f "lazygit.tar.gz" ]; then
        curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    fi
    tar xf lazygit.tar.gz
    mv lazygit "$BIN_DIR/"
fi

# 7. INSTALL FZF
# ------------------------------------------------------------------------------
if [ -d "$HOME/.fzf" ]; then
    echo -e "${BLUE}Fzf already installed. Skipping.${NC}"
else
    echo -e "${GREEN}>>> Installing Fzf...${NC}"
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    "$HOME/.fzf/install" --bin --no-update-rc
fi
if [ -e "$BIN_DIR/fzf" ] && [ "$(readlink -f "$BIN_DIR/fzf")" = "$(readlink -f "$HOME/.fzf/bin/fzf")" ]; then
    echo -e "${BLUE}Fzf symlink already points to the correct binary. Skipping link.${NC}"
else
    ln -sf "$HOME/.fzf/bin/fzf" "$BIN_DIR/fzf"
fi

# 8. INSTALL STARSHIP
# ------------------------------------------------------------------------------
if [ -x "$BIN_DIR/starship" ]; then
    echo -e "${BLUE}Starship already installed. Skipping.${NC}"
else
    echo -e "${GREEN}>>> Installing Starship...${NC}"
    curl -sS https://starship.rs/install.sh | sh -s -- -b "$BIN_DIR" -y > /dev/null
fi

# 9. RESTORE CONFIGURATIONS (Source of Truth: Kit)
# ------------------------------------------------------------------------------
echo -e "${GREEN}>>> Restoring Configurations from Kit...${NC}"

# Tmux
if [ -f "$CONFIG_SRC/tmux.conf" ]; then
    cp "$CONFIG_SRC/tmux.conf" "$HOME/.tmux.conf"
else
    echo -e "${YELLOW}Warning: No tmux.conf in kit!${NC}"
fi

# Starship
mkdir -p "$HOME/.config"
if [ -f "$CONFIG_SRC/starship.toml" ]; then
    cp "$CONFIG_SRC/starship.toml" "$HOME/.config/starship.toml"
fi

# Neovim
if [ -d "$CONFIG_SRC/nvim" ]; then
    cp -r "$CONFIG_SRC/nvim" "$HOME/.config/"
else
    echo -e "${YELLOW}Warning: No nvim config in kit!${NC}"
fi

# 9.1. INSTALL UTILITY SCRIPTS
# ------------------------------------------------------------------------------
echo -e "${GREEN}>>> Installing utility scripts...${NC}"
if [ -f "$KIT_ROOT/scripts/tmux-slurm" ]; then
    cp "$KIT_ROOT/scripts/tmux-slurm" "$BIN_DIR/tmux-slurm"
    chmod +x "$BIN_DIR/tmux-slurm"
fi
if [ -f "$KIT_ROOT/scripts/slurm_free.sh" ]; then
    ln -sf "$KIT_ROOT/scripts/slurm_free.sh" "$BIN_DIR/slurm_free"
fi
if [ -f "$KIT_ROOT/scripts/slurm_snapshot.sh" ]; then
    ln -sf "$KIT_ROOT/scripts/slurm_snapshot.sh" "$BIN_DIR/slurm_snapshot"
fi

# 10. POST-INSTALL SETUP (Plugins)
# ------------------------------------------------------------------------------
echo -e "${GREEN}>>> Setting up Plugins...${NC}"

# Tmux Plugins (TPM)
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
# Install plugins headlessly if possible (requires tmux server)
# We can't easily do this without starting a server, but we can try:
"$HOME/.tmux/plugins/tpm/bin/install_plugins" || true

# Neovim Plugins (Lazy.nvim)
echo -e "${GREEN}>>> Syncing Neovim plugins...${NC}"
# Use the BIN_DIR symlink which points to the new install
"$BIN_DIR/nvim" --headless "+Lazy! sync" +qa

# 11. FINALE
# ------------------------------------------------------------------------------
echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN} CLEAN INSTALLATION COMPLETE! ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "1. Binaries are in: ${YELLOW}$BIN_DIR${NC}"
echo -e "2. Neovim installed to: ${YELLOW}$HOME/opt/nvim${NC}"
echo -e "3. Configs restored to: ${YELLOW}$HOME/.config${NC}"
echo -e "4. Please ensure your PATH is updated:"
echo -e "   ${YELLOW}export PATH=\"$HOME/opt/nvim/bin:$BIN_DIR:\$PATH\"${NC}"
echo -e "   (Add this to your .bashrc)"
# Automatically append if user requested, but script convention is just to echo.
# However, user explicitly said "echo ... >> .bashrc". I'll do it.
echo 'export PATH="$HOME/opt/nvim/bin:$PATH"' >> "$HOME/.bashrc"
echo -e "${BLUE}Added $HOME/opt/nvim/bin to .bashrc${NC}"

# 11.1. UPDATE .BASHRC (IDEMPOTENT)
# ------------------------------------------------------------------------------
BASHRC="$HOME/.bashrc"
touch "$BASHRC"
append_line_if_missing() {
    local line="$1"
    local file="$2"
    if ! grep -Fqx "$line" "$file"; then
        echo "$line" >> "$file"
        return 0
    fi
    return 1
}

if append_line_if_missing 'eval "$(starship init bash)"' "$BASHRC"; then
    echo -e "${BLUE}Added starship init to .bashrc${NC}"
fi

if append_line_if_missing 'eval "$(zoxide init bash)"' "$BASHRC"; then
    echo -e "${BLUE}Added zoxide init to .bashrc${NC}"
fi

if append_line_if_missing 'alias nv="nvim"' "$BASHRC"; then
    echo -e "${BLUE}Added nv alias to .bashrc${NC}"
fi

if append_line_if_missing 'alias vi="nvim"' "$BASHRC"; then
    echo -e "${BLUE}Added vi alias to .bashrc${NC}"
fi

if ! grep -Eq '^vie[[:space:]]*\(\)' "$BASHRC"; then
    cat <<'EOF' >> "$BASHRC"

vie () {
  local dir f
  dir="$(find . -maxdepth 3 -type d 2>/dev/null | sed 's|^\./||' | grep -v '^\.$' | fzf --prompt 'dir> ')" || return
  f="$(find "./$dir" -maxdepth 3 -type f 2>/dev/null | sed "s|^\./$dir/||" | fzf --prompt 'nvim> ')" || return
  nvim "./$dir/$f"
}
EOF
    echo -e "${BLUE}Added vie helper to .bashrc${NC}"
fi

if ! grep -Eq '^vir[[:space:]]*\(\)' "$BASHRC"; then
    cat <<'EOF' >> "$BASHRC"

vir () {
  local f
  f="$(find . -type f -printf '%P\n' 2>/dev/null | fzf --prompt 'nvim> ')" || return
  nvim "./$f"
}
EOF
    echo -e "${BLUE}Added vir helper to .bashrc${NC}"
fi

if ! grep -Eq '^vif[[:space:]]*\(\)' "$BASHRC"; then
    cat <<'EOF' >> "$BASHRC"

vif () {
  local f
  f="$(find . -maxdepth 1 -type f -printf '%P\n' 2>/dev/null | fzf --prompt 'nvim> ')" || return
  nvim "./$f"
}
EOF
    echo -e "${BLUE}Added vif helper to .bashrc${NC}"
fi

if ! grep -Eq '^vifind[[:space:]]*\(\)' "$BASHRC"; then
    cat <<'EOF' >> "$BASHRC"

vifind () {  # nvfind <filename or glob>
  local pat="${1:?usage: nvfind <name>}"
  local matches
  mapfile -t matches < <(find . -type f -name "$pat" -print 2>/dev/null | sed 's|^\./||')
  if (( ${#matches[@]} == 0 )); then
    echo "No match for: $pat" >&2
    return 1
  elif (( ${#matches[@]} == 1 )); then
    nvim "${matches[0]}"
  else
    printf '%s\n' "${matches[@]}" | fzf --prompt 'open> ' | xargs -r nvim
  fi
}
EOF
    echo -e "${BLUE}Added vifind helper to .bashrc${NC}"
fi
