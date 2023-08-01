*****************************************************************************
** ChibiOS/RT port for ARM-Cortex-M4 STM32F407.                            **
*****************************************************************************

** TARGET **

The demo runs on an STM32F411 or STM32F401 blackpill board.
(25MHz Crystal)
Serial Port on PA2,3 @ 115200 Baud (Debug Interface).

Build:
Build with eclipse or simply type "make" in the code folder.


-----------------   WORK in Progress

Functions:

Pinout:
PA0  - free
PA1  - free
PA2  - TX2 (OSTRICH)
PA3  - RX2 (OSTRICH)
PA4  - /CS_FLASH - free
PA5  - SCK1
PA6  - MISO1
PA7  - MOSI1
PA8  - /UWE (Write Enable)
PA9  - /PLD
PA10 - free
PA11 - USD DM or TX1 (Debug)
PA12 - USB DP or RX1 (Debug)
PA13 - SWDIO
PA14 - SWCLK
PA15 - free

PB0  - /LOAD (Input)
PB1  - LATCH
PB2  - free
PB3  - free
PB4  - free
PB5  - free
PB6  - free
PB7  - free
PB8  - SCL1 - free
PB9  - SDA1 - free
PB10 - free

PB12 - CNT
PB13 - /MasterReset (Reset Counter and Shift Register)
PB14 - free
PB15 - free

PC13 - UserLED, Reserve - free
PC14 - OSC32 - free
PC15 - OSC32 - /OutputReset


