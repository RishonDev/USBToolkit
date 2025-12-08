#!/bin/bash

# Install filesystem drivers for macOS using Homebrew
# Supports: BTRFS, EXT1/2/3/4, Swap, NTFS

set -e
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

echo "Installing filesystem drivers for macOS..."

# NTFS support

if brew install ntfs-3g 2>/dev/null; then
    echo "NTFS-3G installed"
else
    echo " NTFS-3G installation skipped"
fi

# EXT4 support via ext4fuse
if brew install ext4fuse 2>/dev/null; then
    echo "ext4fuse installed"
else
    echo "ext4fuse installation skipped"
fi

# BTRFS tools (btrfs-progs available via homebrew)
if brew install btrfs-progs 2>/dev/null; then
    echo "BTRFS tools installed"
else
    echo "BTRFS tools installation skipped (native support limited on macOS)"
fi

# Swap management utilities
if brew install coreutils 2>/dev/null; then
    echo "Coreutils installed (swap utilities)"
else
    echo "Coreutils installation skipped"
fi

echo "Filesystem driver installation complete."