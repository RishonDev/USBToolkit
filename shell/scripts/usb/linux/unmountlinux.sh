#!/bin/bash

set -euo pipefail

usage() {
	cat << EOF
Usage: $0 -d <device> [-f]

Options:
  -d, --device      Device or mount point (e.g., /dev/sda1, /mnt/usb) [REQUIRED]
  -f, --force       Force unmount (use with caution)
  -h, --help        Display this help message

Examples:
  $0 -d /dev/sda1
  $0 -d /mnt/usb -f

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
FORCE=0

while [[ $# -gt 0 ]]; do
	case $1 in
		-d|--device)
			DEVICE="$2"
			shift 2
			;;
		-f|--force)
			FORCE=1
			shift
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
if [[ -z "$DEVICE" ]]; then
	log_error "Missing required argument: device"
	usage
fi

# Check if device/mount point exists
if [[ ! -b "$DEVICE" && ! -d "$DEVICE" ]]; then
	log_error "Device or mount point not found: $DEVICE"
	exit 1
fi

# Check if it's mounted
if ! lsblk -no MOUNTPOINT "$DEVICE" 2>/dev/null | grep -q .; then
	log_info "Device is not mounted: $DEVICE"
	exit 0
fi

# Attempt unmount
log_info "Unmounting $DEVICE..."

if [[ $FORCE -eq 1 ]]; then
	if sudo umount -f "$DEVICE" 2>/dev/null; then
		log_success "Device unmounted successfully"
		exit 0
	else
		log_error "Failed to force unmount device"
		exit 1
	fi
else
	if sudo umount "$DEVICE" 2>/dev/null; then
		log_success "Device unmounted successfully"
		exit 0
	else
		log_error "Failed to unmount device (use -f to force)"
		exit 1
	fi
fi
