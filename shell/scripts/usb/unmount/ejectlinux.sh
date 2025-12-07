#!/bin/bash

while [[ $# -gt 0 ]]; do
  case $1 in
    -u|--unmount)
      	umount $2
      	exit 0
    ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}"
