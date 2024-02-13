#!/bin/bash
#
NAME=mc3
ASS=../../../../various/assembler/as1
#DIR="/home/rob/Projects/mc-6502_mini/"
PWD=`pwd`
echo $PWD

${ASS} ${NAME}.asm -l > ${NAME}.lst
#srec_cat ${NAME}.s19 -motorola -o ${NAME}.bin -binary
srec_cat ${NAME}.s19 -motorola -offset -0xB000 -o ${NAME}.bin -binary # begin cut
#srec_cat ${NAME}.s19 -motorola -offset -0xF800 -fill 0xff 0x0000 0x07ff -o ${NAME}.bin -binary # filled with FFs

#${ASS} ${NAME}.asm -l ${NAME}.lst -o ${NAME}.hex
#srec_cat ${NAME}.OBJ -intel -offset -0x2400 -fill 0xff 0x0000 0x100 -o ${NAME}.bin -binary # filled with FFs
#srec_cat ${NAME}.hex -intel -offset -0x2400 -o ${NAME}.bin -binary # filled with FFs
#rm ${NAME}.hex

#srec_cat ${NAME}.bin -binary -offset 0x7800 -output ${NAME}.hex -Intel -address_length=2 
#srec_cat ${NAME}.s19 -motorola -offset -0x4800 -fill 0xff 0x0000 0x37ff -o ${NAME}.bin -binary # strip off the beginning

#cp -u ${NAME}.bin ../

#Compare
#xxd IMO100.bin > main.hex
#xxd main_reassembled.bin > main_reassembled.hex
#diff main.hex main_reassembled.hex

