#!/bin/bash
AVRDUDE=/usr/bin/avrdude
PART=m328p
BAUD=57600

if [ $# -eq 0 ]
    then 
	echo "Please supply filename as argument."
	exit
fi



#${AVRDUDE} -v -p ${PART} -P /dev/ttyUSB0 -b ${BAUD} -c avrisp -U hfuse:r:${1}
#${AVRDUDE} -v -p ${PART} -P /dev/ttyUSB0 -b ${BAUD} -c avrisp -U flash:w:${1}