#!/bin/bash

while [[ $# -gt 0 ]]; do
  case $1 in
   -a | --addPartition)
       diskutil addPartition  "$2 $3 $4 $5"
       shift
       shift
       ;;
    -e|--erase)

      shift # past argument
      shift # past value
      ;;
    --eraseDisk)
      shift
      shift
      ;;
    --diskWithEFI)
      ;;
    --largeFileSystem)
      ;;
    --filesystemname)
      ;;
    --fileSystemsize)
      ;;
    --filesystem)
      ;;
    --getID)
      ;;
    --gpt)
      ;;
    --mbr)
      ;;

    -h |--help)
      echo "usage: "
      echo "-h   (or) --help                                                      | Prints this help"
      echo "-dwe (or) --diskWithEFI DISK_PATH                                     | Creates a disk with EFI and the main partition with the given filesystem  "
      echo "-lfs (or) --largeFileSystem DISK_PATH                                 | Creates a FAT32 EFI with an exFat partition for booting files > 4GB"
      echo "-fss (or) --filesystemsize FILESYSTEM_SIZE                            | Input for the size of filesystem size for -lfs or -dwe flag"
      echo "-fsn (or) --filesystemname                                            | Input flag for file system name for the -lfs or -dwe flag"
      echo "-fs  (or) --filesystem FILESYSTEM_NAME                                | Input flag for file system type for the -lfs or -dwe flag"
      echo "-m   (or) --mbr                                                       | Specifies MBR to be used for the -lfs or -dwe flag"
      echo "-g   (or) --gpt                                                       | Specifies MBR to be used for the -lfs or -dwe flag"
      echo "-ed  (or) --eraseDisk FILESYSTEM_TYPE NEW_NAME DISK_ID                | Erases a whole disk with the specified arguments"
      echo "-e   (or) --erase FILESYSTEM_TYPE NEW_NAME MOUNT_POINT                | Erases a partition disk with the specified arguments"
      echo "-a   (or) --addPartition  DISK_ID FILESYSTEM_TYPE NEW_NAME MOUNT_POINT| Adds a prtition to disk with the specified arguments"
      echo "--getID  DISK_PATH                                                    | Prints out the disk ID of the given disk path"
      shift
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;

  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters
