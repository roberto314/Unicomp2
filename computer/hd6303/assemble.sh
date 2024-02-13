#!/bin/bash
#
NAME=6303Rom2

ASS=dasm
#ASS=./a68
#DIR="/home/rob/Projects/mc-6502_mini/"
PWD=`pwd`
echo $PWD
${ASS} ${NAME}.asm -l${NAME}.lst -o${NAME}.bin -f3
#srec_cat ${NAME}.s19 -motorola -fill 0xff 0x0000 0x7fff -o ${NAME}.bin2 -binary # filled with FFs

#${ASS} ${NAME}.a68 -l ${NAME}.l68 -o ${NAME}.h68
#srec_cat ${NAME}.s19 -intel -fill 0xff 0x0000 0x7fff -o ${NAME}.bin -binary # filled with FFs

#rm ${NAME}.o
#srec_cat ${NAME}.bin -binary -offset 0x7800 -output ${NAME}.hex -Intel -address_length=2 
#srec_cat ${NAME}.s19 -motorola -fill 0xff 0x0000 0xFFFF -o ${NAME}.bin -binary # fill with FF
#srec_cat ${NAME}.s19 -motorola -offset -0xC000 -o ${NAME}.bin -binary # strip off the beginning
srec_cat ${NAME}.hex -intel -offset -0x8000 -fill 0xff 0x0000 0x7FFF -o ${NAME}.bin2 -binary # strip off the beginning and fill

#cp -u ${NAME}.bin ../

#Compare
#xxd IMO100.bin > main.hex
#xxd main_reassembled.bin > main_reassembled.hex
#diff main.hex main_reassembled.hex

