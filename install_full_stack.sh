#!/bin/bash
set -e

# ==============================================================================
# GEMINI HPC FULL STACK INSTALLER (CLEAN SLATE)
# ==============================================================================
# Installs: Neovim, Tmux, Starship, Fzf, Ripgrep, Lazygit
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
SRC_DIR="$KIT_ROOT/src" # Keep sources in the kit directory to save download time

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
# rm -f "$BIN_DIR/nvim" "$BIN_DIR/tmux" "$BIN_DIR/starship" "$BIN_DIR/rg" "$BIN_DIR/lazygit" "$BIN_DIR/fzf"

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

mkdir -p "$BIN_DIR" "$LIB_DIR" "$INCLUDE_DIR" "$MAN_DIR" "$SRC_DIR"

# Export paths for compilation
export CFLAGS="-I$INCLUDE_DIR"
export LDFLAGS="-L$LIB_DIR -Wl,-rpath,$LIB_DIR"
export PKG_CONFIG_PATH="$LIB_DIR/pkgconfig"
export PATH="$BIN_DIR:$PATH"
export LD_LIBRARY_PATH="$LIB_DIR:$LD_LIBRARY_PATH"

# 2.0. SETUP MODULES (HPC Environment)
# ------------------------------------------------------------------------------
if type module &> /dev/null; then
    echo -e "${YELLOW}Attempting to load modules: gcc cmake ninja${NC}"
    module load gcc cmake ninja 2>/dev/null || echo -e "${YELLOW}Some modules failed to load, checking PATH...${NC}"
fi

# 2.1. CHECK DEPENDENCIES
# ------------------------------------------------------------------------------
required_cmds="gcc make curl tar git pkg-config cmake ninja"
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
download_and_extract() {
    local url=$1
    local filename=$(basename "$url")
    echo -e "${YELLOW}Processing $filename...${NC}"
    cd "$SRC_DIR"
    
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

# Ncurses
if [ -f "$LIB_DIR/pkgconfig/ncurses.pc" ]; then
     echo -e "${BLUE}Ncurses already installed. Skipping.${NC}"
else
    NCURSES_VER="6.4"
    download_and_extract "https://ftp.gnu.org/pub/gnu/ncurses/ncurses-${NCURSES_VER}.tar.gz"
    cd "$SRC_DIR/ncurses-${NCURSES_VER}"
    ./configure --prefix="$INSTALL_PREFIX" --with-shared --with-termlib --enable-pc-files --with-pkg-config-libdir="$LIB_DIR/pkgconfig" > /dev/null
    make -j$(nproc) > /dev/null
    make install > /dev/null 2>&1 || true # Suppress ldconfig noise
fi

# Libevent
if [ -f "$LIB_DIR/lib/libevent.so" ] || [ -f "$LIB_DIR/libevent.so" ] || [ -f "$LIB_DIR/lib/libevent.a" ]; then
    echo -e "${BLUE}Libevent already installed. Skipping.${NC}"
else
    LIBEVENT_VER="2.1.12-stable"
    download_and_extract "https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VER}/libevent-${LIBEVENT_VER}.tar.gz"
    cd "$SRC_DIR/libevent-${LIBEVENT_VER}"
    ./configure --prefix="$INSTALL_PREFIX" > /dev/null
    make -j$(nproc) > /dev/null
    make install > /dev/null 2>&1 || true
fi

# 5. INSTALL TMUX
# ------------------------------------------------------------------------------
if command -v tmux &> /dev/null || [ -f "$BIN_DIR/tmux" ]; then
    echo -e "${BLUE}Tmux already installed. Skipping.${NC}"
else
    echo -e "${GREEN}>>> Installing Tmux...${NC}"
    TMUX_VER="3.6a"
    download_and_extract "https://github.com/tmux/tmux/releases/download/${TMUX_VER}/tmux-${TMUX_VER}.tar.gz"
    cd "$SRC_DIR/tmux-${TMUX_VER}"
    # User requested: ./configure CFLAGS="-I$MY_LOCAL/include" LDFLAGS="-L$MY_LOCAL/lib" --prefix=$MY_LOCAL
    # We map $MY_LOCAL to $INSTALL_PREFIX
    ./configure CFLAGS="-I$INSTALL_PREFIX/include -I$INSTALL_PREFIX/include/ncurses" LDFLAGS="-L$INSTALL_PREFIX/lib -Wl,-rpath,$INSTALL_PREFIX/lib" --prefix="$INSTALL_PREFIX" > /dev/null
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
    cd "$SRC_DIR"
    if [ -d "neovim" ]; then
        rm -rf neovim
    fi
    git clone https://github.com/neovim/neovim
    cd neovim
    make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="$HOME/opt/nvim"
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
ln -sf "$HOME/.fzf/bin/fzf" "$BIN_DIR/fzf"

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