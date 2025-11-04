#!/bin/bash

mkdir -p ~/.config/rclone
cp rclone.conf ~/.config/rclone/
chmod 600 ~/.config/rclone/rclone.conf

# Add rclone binary path to .bash_profile if not already there
if ! grep -q "export PATH=$(pwd)\\rclone:\$PATH" ~/.bash_profile 2>/dev/null; then
	echo "export PATH=$(pwd)/rclone:\$PATH" >> ~/.bash_profile
	echo "Added rclone to PATH in ~/.bash_profile"
	echo "Please source your bashrc."
fi


#!/usr/bin/env bash
set -euo pipefail

# Where to install rclone binary (no sudo needed)
BASE_DIR="$(pwd)"
INSTALL_DIR="$BASE_DIR/rclone"
CONFIG_FILE="$INSTALL_DIR/rclone.conf"
CONFIG_DEST_DIR="$HOME/.config/rclone"

echo ">>> Base directory: $BASE_DIR"
echo ">>> Installing rclone binary to: $INSTALL_DIR"
echo ">>> Config file: $CONFIG_FILE"
echo

# -----------------------------
# 1) Download and install rclone
# -----------------------------
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
cd "$TMP_DIR"

echo ">>> Downloading latest rclone..."
curl -sLO https://downloads.rclone.org/rclone-current-linux-amd64.zip

echo ">>> Unzipping..."
unzip -q rclone-current-linux-amd64.zip

RCLONE_DIR="$(find . -maxdepth 1 -type d -name 'rclone-*-linux-amd64' | head -n 1)"
if [[ -z "$RCLONE_DIR" ]]; then
	    echo "ERROR: Could not find extracted rclone directory."
			    exit 1
fi

mkdir -p "$INSTALL_DIR"
cp "$RCLONE_DIR/rclone" "$INSTALL_DIR/"
chmod 755 "$INSTALL_DIR/rclone"

echo ">>> rclone installed successfully in $INSTALL_DIR"

# -----------------------------
# 2) Install rclone.conf (if provided)
# -----------------------------
mkdir -p "$CONFIG_DEST_DIR"

if [[ -f "$CONFIG_FILE" ]]; then
	echo ">>> Copying config to $CONFIG_DEST_DIR"
	cp "$CONFIG_FILE" "$CONFIG_DEST_DIR/rclone.conf"
	chmod 600 "$CONFIG_DEST_DIR/rclone.conf"
else
	echo "WARNING: $CONFIG_FILE not found. Skipping config copy."
fi

# -----------------------------
# 3) Add INSTALL_DIR to PATH in shell profiles
# -----------------------------
PATH_LINE="export PATH=\"$INSTALL_DIR:\$PATH\""
if ! grep -Fq "$PATH_LINE" ~/.bash_profile 2>/dev/null; then
	echo "$PATH_LINE" >> ~/.bash_profile
	echo ">>> Added $INSTALL_DIR to PATH in ~/.bash_profile"
else
	echo ">>> PATH already contains $INSTALL_DIR"
fi



echo
echo ">>> Setup complete."

# Try to show rclone version using the new binary
echo ">>> Verifying rclone installation..."
"$INSTALL_DIR/rclone" version || {
	echo "WARNING: rclone installed, but could not run it. Check $INSTALL_DIR and PATH."
}

echo
echo "NOTE: Open a new shell, or run:"
echo "      source ~/.bash_profile  # or source ~/.bashrc"
echo "to pick up the updated PATH."


