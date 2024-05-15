setMode -bs
setCable -port xsvf -file "build/board_6502.xsvf"
addDevice -p 1 -file "build/board_6502.jed"
Program -p 1 -e -defaultVersion 0
quit
