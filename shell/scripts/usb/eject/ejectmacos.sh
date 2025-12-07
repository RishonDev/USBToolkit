#!/bin/zsh

while [[ $# -gt 0 ]]; do
  case $1 in
    -e|--eject)
      diskutil eject "$2"
      shift # past argument
      shift # past value
      ;;
  esac
done