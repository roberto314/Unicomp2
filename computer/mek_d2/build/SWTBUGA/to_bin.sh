#!/bin/bash

NAME=${1}
echo "Enter Name without Extension."
echo $NAME

srec_cat ${NAME}.S19 -offset -0xE000 -o ${NAME}.bin -binary
