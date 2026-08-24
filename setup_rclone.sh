#!/usr/bin/env bash
set -euo pipefail

# Install the current rclone binary into ~/.local/bin and, unless requested
# otherwise, decrypt this kit's config directly into ~/.config/rclone.

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/rclone"
ENCRYPTED_CONFIG="$KIT_ROOT/rclone/rclone.gpg"
INSTALL_BINARY=1
INSTALL_CONFIG=1

usage() {
  cat <<'EOF'
Usage: ./setup_rclone.sh [--binary-only | --config-only]

The existing rclone config is backed up before replacement. Decrypted config
material is created only in a private temporary directory and the destination.
EOF
}

case "${1:-}" in
  "") ;;
  --binary-only) INSTALL_CONFIG=0 ;;
  --config-only) INSTALL_BINARY=0 ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

for cmd in curl unzip gpg install mktemp sha256sum awk; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing required command: $cmd" >&2
    exit 1
  }
done

case "$(uname -m)" in
  x86_64) rclone_arch=amd64 ;;
  aarch64|arm64) rclone_arch=arm64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

audit_tmp="$(mktemp -d "${TMPDIR:-/tmp}/hpc-rclone.XXXXXX")"
trap 'rm -rf "$audit_tmp"' EXIT
chmod 700 "$audit_tmp"

if (( INSTALL_BINARY )); then
  version_text="$(curl --fail --silent --show-error --location --retry 3 \
    https://downloads.rclone.org/version.txt)"
  rclone_version="${version_text#rclone v}"
  [[ "$rclone_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "Unexpected rclone version response: $version_text" >&2
    exit 1
  }

  release_name="rclone-v${rclone_version}-linux-${rclone_arch}"
  release_url="https://downloads.rclone.org/v${rclone_version}"
  archive="$audit_tmp/${release_name}.zip"
  sums="$audit_tmp/SHA256SUMS"
  curl --fail --silent --show-error --location --retry 3 --output "$archive" \
    "$release_url/${release_name}.zip"
  curl --fail --silent --show-error --location --retry 3 --output "$sums" \
    "$release_url/SHA256SUMS"
  unzip -q "$archive" -d "$audit_tmp/unpacked"

  rclone_dir="$audit_tmp/unpacked/$release_name"
  [ -d "$rclone_dir" ] || { echo "Downloaded archive has an unexpected layout" >&2; exit 1; }

  release_archive="${release_name}.zip"
  expected="$(awk -v name="$release_archive" '$2 == name { print $1; exit }' "$sums")"
  [ -n "$expected" ] || { echo "No checksum published for $release_archive" >&2; exit 1; }
  printf '%s  %s\n' "$expected" "$archive" | sha256sum --check --status -

  mkdir -p "$BIN_DIR"
  install -m 0755 "$rclone_dir/rclone" "$BIN_DIR/rclone"
  echo "Installed: $BIN_DIR/rclone"
fi

if (( INSTALL_CONFIG )); then
  [ -f "$ENCRYPTED_CONFIG" ] || {
    echo "Encrypted config not found: $ENCRYPTED_CONFIG" >&2
    exit 1
  }
  decrypted="$audit_tmp/rclone.conf"
  gpg --quiet --output "$decrypted" --decrypt "$ENCRYPTED_CONFIG"
  mkdir -p "$CONFIG_DIR"
  if [ -f "$CONFIG_DIR/rclone.conf" ]; then
    backup="$CONFIG_DIR/rclone.conf.bak.$(date +%Y%m%d-%H%M%S)"
    cp -p "$CONFIG_DIR/rclone.conf" "$backup"
    echo "Backed up: $backup"
  fi
  install -m 0600 "$decrypted" "$CONFIG_DIR/rclone.conf"
  echo "Installed: $CONFIG_DIR/rclone.conf"
fi

if (( INSTALL_BINARY )); then
  "$BIN_DIR/rclone" version | sed -n '1p'
fi
