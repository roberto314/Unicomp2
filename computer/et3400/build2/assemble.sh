#!/bin/bash
#
#NAME=intelHEX_dl
NAME=monitor
#NAME=tinybasic

crasm -o ${NAME}.run ${NAME}.asm >${NAME}.lst
srec_cat ${NAME}.run -offset -0x1400 -o ${NAME}.bin -binary
#srec_cat ${NAME}.run -offset -0x1C00 -o ${NAME}.bin -binary
#srec_cat ${NAME}.run -offset -0xF000 -crop 0 0x10000 -o ${NAME}.bin -binary