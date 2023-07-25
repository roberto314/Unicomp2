#!/bin/bash
#
NAME=sbc
CA65=../../../various/assembler/ca65
LD65=../../../various/assembler/ld65
#DIR="/home/rob/Projects/mc-6502_mini/"
PWD=`pwd`
echo $PWD
${CA65} --cpu 6502 -o ${NAME}.o -l ${NAME}.lst ${NAME}.asm
${LD65} -C ${NAME}.cfg -o ${NAME}.bin ${NAME}.o

rm ${NAME}.o
srec_cat ${NAME}.bin -binary -offset 0x7800 -output ${NAME}.hex -Intel -address_length=2 

cp -u ${NAME}.bin ../

#Compare
#xxd IMO100.bin > main.hex
#xxd main_reassembled.bin > main_reassembled.hex
#diff main.hex main_reassembled.hex

