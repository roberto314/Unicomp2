#!/bin/bash
STFLASH=/usr/local/bin/st-flash

if [ $# -eq 0 ]
    then 
	echo "Please supply filename as argument."
	exit
fi

FILE=${1}

echo Filename is: ${FILE}
#${STFLASH} --format ihex read ${FILE} 0 0xFFFF
#${STFLASH} --format ihex write ${FILE}
#${STFLASH} --format binary write ${1} 0x8000000
