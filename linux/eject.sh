#!/bin/bash

resolve_device() {
  local path="$1"

  [[ "$path" == /dev/* ]] && { echo "$path"; return; }

  if command -v findmnt >/dev/null 2>&1; then
    findmnt -n -o SOURCE --target "$path" && return
  fi

  df --output=source "$path" 2>/dev/null | tail -1
}

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -e, --eject <device|mountpoint>   Eject the device or the device backing the mountpoint
  -h, --help                        Show this help message

Examples:
  $0 --eject /dev/sdb1
  $0 --eject /media/user/MyUSB
EOF
}

# Show help if no args
[[ $# -eq 0 ]] && { usage; exit 1; }

while [[ $# -gt 0 ]]; do
  case $1 in
    -e|--eject)
      dev="$(resolve_device "$2")"
      eject "$dev"
      shift
      shift
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
