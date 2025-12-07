#!/bin/bash

filesystem="ext4"
scheme="gpt"
while [[ $# -gt 0 ]]; do
  case $1 in
  -a | --addPartition)
    parted "$2" mkpart "$3" "$4" "$5"
    mkfs."$filesystem" "$5"
    shift
    shift
    ;;
    -e|--erase)
      # Code to erase a partition
      parted "$2" rm "$3"
      shift # past argument
      shift # past value
      ;;
    --eraseDisk)
      # Code to erase the whole disk and remove all partitions
      parted "$2" mklabel "$scheme"
      shift
      shift
      ;;
    --zero)
      dd if=/dev/zero of="$2" bs=1m
      shift
      shift
      ;;
    --diskWithEFI)
      parted "$2" mklabel gpt mkpart ESP fat32 1MiB 201MiB set 1 boot on mkpart primary "$filesystem" 201MiB 100%
      shift
      shift
      ;;
    --fs)
      filesystem="$2"
      shift
      shift
      ;;
    --gpt)
      scheme="gpt"
      ;;
    --mbr)
      ;;
    -h | --help)
      echo "Usage: formatlinux.sh [options]"
      echo ""
      echo "Options:"
      echo "  -a, --addPartition <device> <name> <type> <end>   Add a partition"
      echo "  -e, --erase <device> <partition>                  Erase a partition"
      echo "  --eraseDisk <device>                              Erase entire disk"
      echo "  --zero <device>                                   Zero out device"
      echo "  --diskWithEFI <device>                            Create disk with EFI"
      echo "  --fs <filesystem>                                 Set filesystem (default: ext4)"
      echo "  --gpt                                             Use GPT scheme (default)"
      echo "  --mbr                                             Use MBR scheme"
      echo "  -h, --help                                        Show this help message"
      exit 0
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}"
