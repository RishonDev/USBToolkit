#!/bin/bash

set -euo pipefail

usage() {
	cat << EOF
Usage: $0 -d <device> -n <new_name> [-t <filesystem>]

Options:
  -d, --device      Device path (e.g., /dev/sda1) [REQUIRED]
  -n, --name        New partition name [REQUIRED]
  -t, --type        Filesystem type (auto-detected if omitted)

Examples:
  $0 -d /dev/sda1 -n "MyDrive"
  $0 -d /dev/sdb2 -n "Data" -t ext4

Supported filesystems:
  ext2, ext3, ext4, btrfs, xfs, vfat, ntfs, exfat

EOF
	exit 1
}

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_error() {
	echo -e "${RED}✗ Error: $1${NC}" >&2
}

log_success() {
	echo -e "${GREEN}✓ $1${NC}"
}

log_info() {
	echo -e "${YELLOW}ℹ $1${NC}"
}

# Parse command-line arguments
DEVICE=""
NEW_NAME=""
FSTYPE=""

while [[ $# -gt 0 ]]; do
	case $1 in
		-d|--device)
			DEVICE="$2"
			shift 2
			;;
		-n|--name)
			NEW_NAME="$2"
			shift 2
			;;
		-t|--type)
			FSTYPE="$2"
			shift 2
			;;
		-h|--help)
			usage
			;;
		*)
			log_error "Unknown option: $1"
			usage
			;;
	esac
done

# Validate required arguments
if [[ -z "$DEVICE" || -z "$NEW_NAME" ]]; then
	log_error "Missing required arguments"
	usage
fi

# Check if device exists
if [[ ! -b "$DEVICE" && ! -e "$DEVICE" ]]; then
	log_error "Device not found: $DEVICE"
	exit 1
fi

# Check if device is mounted (warn user)
if mountpoint -q "$(dirname "$DEVICE")" 2>/dev/null || lsblk -no MOUNTPOINT "$DEVICE" 2>/dev/null | grep -q .; then
	log_info "Device appears to be mounted. Consider unmounting before renaming."
fi

# Auto-detect filesystem type if not provided
if [[ -z "$FSTYPE" ]]; then
	log_info "Auto-detecting filesystem type..."
	FSTYPE=$(sudo blkid -o value -s TYPE "$DEVICE" 2>/dev/null || echo "")
	
	if [[ -z "$FSTYPE" ]]; then
		log_error "Could not auto-detect filesystem type. Please specify with -t option."
		exit 1
	fi
	log_info "Detected filesystem: $FSTYPE"
fi

# Normalize filesystem type to lowercase
FSTYPE=$(echo "$FSTYPE" | tr '[:upper:]' '[:lower:]')

# Rename based on filesystem type
case "$FSTYPE" in
	ext2|ext3|ext4)
		if ! command -v e2label &> /dev/null; then
			log_error "e2label not found. Install e2fsprogs package."
			exit 1
		fi
		sudo e2label "$DEVICE" "$NEW_NAME"
		log_success "Partition renamed to: $NEW_NAME"
		;;
	btrfs)
		if ! command -v btrfs &> /dev/null; then
			log_error "btrfs not found. Install btrfs-progs package."
			exit 1
		fi
		sudo btrfs filesystem label "$DEVICE" "$NEW_NAME"
		log_success "Partition renamed to: $NEW_NAME"
		;;
	xfs)
		if ! command -v xfs_admin &> /dev/null; then
			log_error "xfs_admin not found. Install xfsprogs package."
			exit 1
		fi
		sudo xfs_admin -L "$NEW_NAME" "$DEVICE"
		log_success "Partition renamed to: $NEW_NAME"
		;;
	vfat|fat)
		if command -v fatlabel &> /dev/null; then
			sudo fatlabel "$DEVICE" "$NEW_NAME"
		elif command -v mlabel &> /dev/null; then
			sudo mlabel -i "$DEVICE" ::"$NEW_NAME"
		else
			log_error "No FAT labeling tool found. Install dosfstools or mtools."
			exit 1
		fi
		log_success "Partition renamed to: $NEW_NAME"
		;;
	ntfs)
		if ! command -v ntfslabel &> /dev/null; then
			log_error "ntfslabel not found. Install ntfs-3g package."
			exit 1
		fi
		sudo ntfslabel "$DEVICE" "$NEW_NAME"
		log_success "Partition renamed to: $NEW_NAME"
		;;
	exfat)
		if ! command -v exfatlabel &> /dev/null; then
			log_error "exfatlabel not found. Install exfat-utils package."
			exit 1
		fi
		sudo exfatlabel "$DEVICE" "$NEW_NAME"
		log_success "Partition renamed to: $NEW_NAME"
		;;
	*)
		log_error "Unsupported filesystem type: $FSTYPE"
		exit 1
		;;
esac