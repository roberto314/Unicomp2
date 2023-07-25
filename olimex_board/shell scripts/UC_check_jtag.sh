#!/bin/bash
XP=/usr/local/bin/xc3sprog
#if [ "$EUID" -ne 0 ] 
#    then
#	echo "Please run as root or with sudo!"
#	exit
#fi

sudo $XP -c gpiod_a20 -v -j