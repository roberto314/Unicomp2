#!/bin/bash
#
NAME=FLEXLOAD
AS02=../../../various/assembler/as02
#DIR="/home/rob/Projects/mc-6502_mini/"
PWD=`pwd`
echo $PWD
${AS02} -l${NAME}.lst -o${NAME}.bin ${NAME}.ASM

#rm ${NAME}.o
#srec_cat ${NAME}.bin -binary -offset 0x7800 -output ${NAME}.hex -Intel -address_length=2 

#cp -u ${NAME}.bin ../

#Compare
#xxd IMO100.bin > main.hex
#xxd main_reassembled.bin > main_reassembled.hex
#diff main.hex main_reassembled.hex

