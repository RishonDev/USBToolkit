#!/bin/bash

set -euo pipefail

usage() {
	cat << EOF
Usage: $0 -d <device|mountpoint> -n <new_name> [-t <filesystem>]

Options:
  -d, --device      Device path (e.g., /dev/sda1) or mountpoint under /media/
  -n, --name        New partition name
  -t, --type        Filesystem type (auto-detected)

Examples:
  $0 -d /dev/sda1 -n MyDrive
  $0 -d /media/rishon/OldName -n NewName

EOF
	exit 1
}

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_error() { echo -e "${RED}✗ $1${NC}" >&2; }
log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_info() { echo -e "${YELLOW}ℹ $1${NC}"; }

DEVICE=""
NEW_NAME=""
FSTYPE=""

# Parse args
while [[ $# -gt 0 ]]; do
	case "$1" in
		-d|--device) DEVICE="$2"; shift 2;;
		-n|--name) NEW_NAME="$2"; shift 2;;
		-t|--type) FSTYPE="$2"; shift 2;;
		-h|--help) usage;;
		*) log_error "Unknown option: $1"; usage;;
	esac
done

[[ -z "$DEVICE" || -z "$NEW_NAME" ]] && { log_error "Missing required arguments."; usage; }

ORIGINAL_INPUT="$DEVICE"

# Resolve mountpoint → device
if [[ "$DEVICE" == /media/* || "$DEVICE" == /run/media/* || -d "$DEVICE" ]]; then
	RESOLVED=$(df --output=source "$DEVICE" 2>/dev/null | tail -1 || true)
	if [[ -n "$RESOLVED" && "$RESOLVED" != "source" ]]; then
		log_info "Resolved mountpoint '$DEVICE' → $RESOLVED"
		DEVICE="$RESOLVED"
	else
		MP=$(findmnt -n -o TARGET --target "$DEVICE" 2>/dev/null || true)
		[[ -z "$MP" ]] && { log_error "Cannot resolve device"; exit 1; }
		RESOLVED=$(df --output=source "$MP" 2>/dev/null | tail -1)
		DEVICE="$RESOLVED"
		log_info "Resolved '$DEVICE' → '$RESOLVED'"
	fi
fi

[[ ! -b "$DEVICE" ]] && { log_error "Device not found: $DEVICE"; exit 1; }

# -----------------------------
# 1) UNMOUNT THE DEVICE
# -----------------------------
log_info "Unmounting $DEVICE (if mounted)..."
sudo umount "$DEVICE" 2>/dev/null || true
sudo umount -f "$DEVICE" 2>/dev/null || true

# Auto-detect filesystem
if [[ -z "$FSTYPE" ]]; then
	log_info "Detecting filesystem..."
	FSTYPE=$(sudo blkid -o value -s TYPE "$DEVICE" || true)
	[[ -z "$FSTYPE" ]] && { log_error "Cannot detect filesystem."; exit 1; }
fi

FSTYPE=$(echo "$FSTYPE" | tr 'A-Z' 'a-z')
log_info "Filesystem: $FSTYPE"

# -----------------------------
# 2) RENAME THE DRIVE
# -----------------------------
case "$FSTYPE" in
	ext2|ext3|ext4)
		sudo e2label "$DEVICE" "$NEW_NAME"
		;;

	xfs)
		sudo xfs_admin -L "$NEW_NAME" "$DEVICE"
		;;

	vfat|fat)
		if command -v fatlabel &>/dev/null; then
			sudo fatlabel "$DEVICE" "$NEW_NAME"
		else
			sudo mlabel -i "$DEVICE" ::"$NEW_NAME"
		fi
		;;

	exfat)
		sudo exfatlabel "$DEVICE" "$NEW_NAME"
		;;

	ntfs)
		sudo ntfslabel "$DEVICE" "$NEW_NAME"
		;;

	btrfs)
		TMPDIR=$(mktemp -d)
		sudo mount "$DEVICE" "$TMPDIR"
		sudo btrfs filesystem label "$TMPDIR" "$NEW_NAME"
		sudo umount "$TMPDIR"
		rmdir "$TMPDIR"
		;;

	*)
		log_error "Unsupported filesystem: $FSTYPE"
		exit 1
		;;
esac

log_success "Drive label changed to '$NEW_NAME'"

# -----------------------------
# 3) MOUNT INTO NEW DIRECTORY
# -----------------------------
TARGET="/media/$USER/$NEW_NAME"

log_info "Creating mount directory: $TARGET"
sudo mkdir -p "$TARGET"

log_info "Mounting $DEVICE → $TARGET"
sudo mount "$DEVICE" "$TARGET"

log_success "Drive mounted at $TARGET"

exit 0
