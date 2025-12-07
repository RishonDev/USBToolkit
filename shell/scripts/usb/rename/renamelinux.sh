#!/bin/bash

while [[ $# -gt 0 ]]; do
  case $1 in
    -e|--ext4)
    	e2label $2 $3
    	shift
    	shift
    	;;
    -v|--verify)
      	if EMPTY="TRUE" && WRITEMODE="TRUE"
      	then
      		  sudo badblocks -w -s -o error.log $2
        fi
      	if EMPTY="TRUE" && WRITEMODE="FALSE"
      	then
      	  sudo badblocks -s -o error.log $2
      	fi
      	if EMPTY="FALSE"
      	then
      	    f3write $2
      	    f3read $2
      	fi
      shift # past argument
      shift # past value
      ;;
    -w | --write)
    	WRITEMODE="TRUE"
    	shift
    	shift
    ;;

    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done