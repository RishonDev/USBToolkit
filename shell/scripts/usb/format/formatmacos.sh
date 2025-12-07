#!/bin/zsh

GPT="TRUE"
FS=""
FS_SIZE=""
FS_NAME=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -a | --addPartition)
      diskutil addPartition "$2" "$3" "$4" "$5"
      shift 5
      ;;
    -e | --erase)
      diskutil eraseVolume "$2"
      shift 2
      ;;
    -ed | --eraseDisk)
      diskutil eraseDisk "$2" "$3" "$4" "$5"
      shift 4
      ;;
    -g | --gpt)
      GPT="TRUE"
      shift
      ;;
    -m | --mbr)
      GPT="FALSE"
      shift
      ;;
    -fs | --filesystem)
      FS="$2"
      shift 2
      ;;
    -fsn | --filesystemname)
      FS_NAME="$2"
      shift 2
      ;;
    -fss | --filesystemsize)
      FS_SIZE="$2"
      shift 2
      ;;
    --getID)
      diskutil info "$2" | grep "Part of Whole:" | awk '{print $NF}'
      shift 2
      ;;
    -lfs | --largeFileSystem)
      DISK_PATH=$(diskutil info "$2" | grep "Device Node:" | awk '{print $NF}')
      DISK_ID=$(diskutil info "$2" | grep "Part of Whole:" | awk '{print $NF}')
      diskutil formatDisk "$DISK_PATH"
      if [[ "$GPT" == "FALSE" ]]; then
        diskutil partitionDisk "$DISK_ID" MBR fat32 WEFI 100m "$FS" "$FS_NAME" "$FS_SIZE"
      else
        diskutil partitionDisk "$DISK_ID" GPT fat32 WEFI 100m "$FS" "$FS_NAME" "$FS_SIZE"
      fi
      shift
      ;;
    --diskWithEFI | -dwe)
      DISK_PATH=$(diskutil info "$2" | grep "Device Node:" | awk '{print $NF}')
      DISK_ID=$(diskutil info "$2" | grep "Part of Whole:" | awk '{print $NF}')
      diskutil formatDisk "$DISK_PATH"
      if [[ "$GPT" == "FALSE" ]]; then
        diskutil partitionDisk "$DISK_ID" MBR fat32 WEFI 100m "$FS" "$FS_NAME" "$FS_SIZE"
      else
        diskutil partitionDisk "$DISK_ID" GPT fat32 WEFI 100m "$FS" "$FS_NAME" "$FS_SIZE"
      fi
      shift
      ;;
    -h | --help)
      echo "Usage: $(basename "$0") [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  -h, --help                    Show this help message"
      echo "  -dwe, --diskWithEFI DISK      Create disk with EFI and main partition"
      echo "  -lfs, --largeFileSystem DISK  Create FAT32 EFI + exFat for files > 4GB"
      echo "  -fs, --filesystem TYPE        Filesystem type for -lfs or -dwe"
      echo "  -fsn, --filesystemname NAME   Filesystem name for -lfs or -dwe"
      echo "  -fss, --filesystemsize SIZE   Filesystem size for -lfs or -dwe"
      echo "  -m, --mbr                     Use MBR partition scheme"
      echo "  -g, --gpt                     Use GPT partition scheme"
      echo "  -ed, --eraseDisk TYPE NAME ID Erase entire disk"
      echo "  -e, --erase TYPE NAME MOUNT   Erase partition"
      echo "  -a, --addPartition ID TYPE NAME MOUNT  Add partition to disk"
      echo "  --getID DISK                  Print disk ID for given path"
      shift
      ;;
  esac
done
