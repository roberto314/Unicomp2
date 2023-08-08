#!/bin/bash
#
#NAME=intelHEX_dl
NAME=mondeb

crasm -o ${NAME}.run ${NAME}.asm >${NAME}.lst
srec_cat ${NAME}.run -offset -0xF000 -crop 0 0x10000 -o ${NAME}.bin -binary