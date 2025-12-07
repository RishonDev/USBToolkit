#!/bin/zsh

while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--verify)
      diskutil verifyDisk -"$2"
      shift # past argument
      shift # past value
      ;;
  esac
done
