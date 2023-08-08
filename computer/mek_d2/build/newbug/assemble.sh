#!/bin/bash
#
NAME=NEWBUG
ASSEMBLER=../../../../various/assembler/asl
P2BIN=../../../../various/assembler/p2bin
#DIR="/home/rob/Projects/mc-6502_mini/"
PWD=`pwd`
echo $PWD
${ASSEMBLER} -L -cpu 6800 ${NAME}.asm
${P2BIN} ${NAME}.p ${NAME}.bin
rm ${NAME}.p

#srec_cat ${NAME}.bin -binary -offset 0x7800 -output ${NAME}.hex -Intel -address_length=2 

#cp -u ${NAME}.bin ../

#Compare
#xxd IMO100.bin > main.hex
#xxd main_reassembled.bin > main_reassembled.hex
#diff main.hex main_reassembled.hex

