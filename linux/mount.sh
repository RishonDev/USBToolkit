#!/bin/bash

resolve_device() {
  local path="$1"

  # Already a /dev device
  [[ "$path" == /dev/* ]] && { echo "$path"; return; }

  # If user passed a path inside the device (rare case), detect via findmnt/df
  if command -v findmnt >/dev/null 2>&1; then
    findmnt -n -o SOURCE --target "$path" && return
  fi

  df --output=source "$path" 2>/dev/null | tail -1
}

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -m, --mount <device|path> <mountpoint>   Mount a block device at the mountpoint
  -t, --type <fstype>                      Filesystem type (optional)
  -o, --options <opts>                     Mount options (optional)
  -h, --help                               Show this help message

Examples:
  $0 --mount /dev/sdb1 /media/usb
  $0 -m /dev/nvme0n1p3 /mnt/data -t ext4
  $0 -m /dev/sdc1 /mnt/drive -o rw,noatime
EOF
}

[[ $# -eq 0 ]] && { usage; exit 1; }

fstype=""
opts=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--mount)
      device="$(resolve_device "$2")"
      target="$3"
      shift 3
      ;;
    -t|--type)
      fstype="$2"
      shift 2
      ;;
    -o|--options)
      opts="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

# Ensure both args exist
if [[ -z "${device:-}" || -z "${target:-}" ]]; then
  usage
  exit 1
fi

# Create mountpoint if missing
[[ ! -d "$target" ]] && mkdir -p "$target"

# Construct mount command
cmd=(mount)

[[ -n "$fstype" ]] && cmd+=("-t" "$fstype")
[[ -n "$opts" ]] && cmd+=("-o" "$opts")

cmd+=("$device" "$target")

"${cmd[@]}"
