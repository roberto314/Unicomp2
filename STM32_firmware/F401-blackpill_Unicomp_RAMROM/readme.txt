*****************************************************************************
** ChibiOS/RT port for ARM-Cortex-M4 STM32F407.                            **
*****************************************************************************

** TARGET **

The demo runs on an STM32F411 or STM32F401 blackpill board.
(25MHz Crystal)
Serial Port over USB (also Debug Interface).

Build:
Build with eclipse or simply type "make" in the code folder.


-----------------   WORK in Progress

Functions:

Pinout:
PA0  - OFF/ON (write enable strobe)
PA1  - SEL4 (which chip gets the write enable)
PA2  - TX2 (Console + Debug)
PA3  - RX2 (Console + Debug)
PA4  - /CS_FLASH - free (/DATOE in prev. Version)
PA5  - SCK1
PA6  - MISO1
PA7  - MOSI1
PA8  - CNT (count up)
PA9  - /MWR (not used)
PA10 - /RAMCSOR (RAM CS override) - not used
PA11 - USD DM (Ostrich)
PA12 - USB DP (Ostrich)
PA13 - SWDIO
PA14 - SWCLK
PA15 - /MRD (not used)

PB0  - free
PB1  - free
PB2  - /DATOE
PB3  - free
PB4  - free
PB5  - free
PB6  - SCL
PB7  - SDA
PB8  - CTRL1 (CTRL1 for clock chip)
PB9  - /BUSFREE (signal if bus is free)
PB10 - TRST (Target Reset)

PB12 - /PLD (Parallel Load into shift register)
PB13 - /CNTOE (Counter Output on)
PB14 - CPR (Counter Latch)
PB15 - /MRC (Counter Reset)

PC13 - SEL0 (which chip gets the write enable)
PC14 - SEL1 (which chip gets the write enable)
PC15 - SEL2 (which chip gets the write enable)


