#!/bin/bash
XP=/usr/local/bin/xc3sprog

#if [ "$EUID" -ne 0 ] 
#    then
#	echo "Please run as root or with sudo!"
#	exit
#fi

if [ -z "$1" ] 
    then
	echo "Please give JTAG Position as first argument!"
	exit
fi
echo "Writing to device: $1"

if [ -z "$2" ] 
    then
	echo "Please give filename as second argument!"
	exit
fi
echo "filename is: $2"
sudo $XP -c gpiod_a20 -v -p $1 $2:w

