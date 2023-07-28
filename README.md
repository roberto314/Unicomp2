# UNICOMP2 #

A modular 8-bit Computer able to recreate (nearly) every Retro computer of the late 70s to mid 80s 
in Hardware without FPGAs (although an FPGA can be added). Can also be used as a teaching tool for:
    - VHDL or Verilog
    - C
    - Python
    - bash and linux in general
    - Harwaredesign
    - Timing of CPUs
    - maybe Assembler
    - SPI and I2C Interfaces
    - CPLDs and FPGAs

Version 2.00

### Unicomp modules ###

* Input board:
	- a simple board to connect the signals to a linux SBC like a Raspberry Pi or an Olimex A20
	- also generates the main clock with a DS1085 chip.
	- no CPLD

* CPU board:
	- can be any 8-bit CPU (6502, 6802, 6809, 68008, 6803, 8051,...)
	- a CPLD (XC9572) for clock generation and glue logic

* Multi Serial boaŕd:
	- suggested write_enable #0
	- two chip selects on board (second one not connected, but broken out)
	- can be used with the following serial interface chips: MC6850, MOS6551, MOS6552 or pin compatible
	- RAM for address decoding

* Multi Parallel boaŕd:
	- suggested write_enable #1
	- two chip selects on board
	- can be used with the following parallel interface chips: MC6820, MC6821, MOS6520, MOS6521, MOS6522, MOS6526, MOS8520, MOS6532 in the first slot
    - the first slot can additionally mimic a MOS6530
	- the second slot can accommodate a MOS6522 or pin compatible
    - RAM for address decoding

* RAMROM board:
	- write_enable fixed at #14 (for chipselect) and #15 (rom content)
	- 512k of battery backed SRAM plus an extra RAM for address decoding
	- a STM32F401 'blackpill' board to fill the SRAM with data over USB port from the SBC
	- serial shell on the STM32 to change ROM content on the fly
	- also configures the Address Range of all peripheral modules

* Prototype board:
	- empty board for prototyping
	- no CPLD

* self made module:
	- write_enable can be any non-used line in the Range from 0 to 13.
	- size is 100mm x 100mm
	- there is the prototype board in the repository for the position of the connectors and also the labels (pinout)

### linux single board computer (SBC) ###

I uses an olimex A20 SBC (olinuxino A20) which has a lot of peripherals (4x UART, 2x SPI, 2x I2C, a lot of GPIOs, SATA, 2x SDCARD, VGA, HDMI, LAN,...)
and it is open hardware. The board is connected with three 40 pin cables (like old IDE cables) plus two 10 pin cables to the input board.

To access all the peripherals i use python with the pyA20 library here: https://pypi.org/project/pyA20/   
The debian image (bullseye minimal) can be found at: http://images.olimex.com/release/a20/   
To configure the image after downloading there are helper scripts in the unicomp folder under: olimex Board/config 
I use fbterm and tmux for a nice terminal output. Here are some pictures:   
tmux main window:
![tmux main window](pictures/tmux_main.jpg)

tmux serial window:
![tmux uart window](pictures/tmux_uart.jpg)

### python helper scripts ###

-- all scripts have to be executed with sudo bacause of direct hardware access!

* UC_set_freq.py 
	- can set the frequency for the main clock input
	- read and write registers of the DS1085 chip
	- Example: sudo UC_set_freq.py -M 14 - sets clock to 14 MHz
	- Example: sudo UC_set_freq.py -k 14318 - sets clock to 14.318 MHz
	- Example: sudo UC_set_freq.py -f 14318180 - sets clock to 14.31818 MHz
	- Example: sudo UC_set_freq.py DIV -v 245 - sets divider to 245

* UC_configure.py [configdir]
	- configures the RAM, ROM and chipselect of all the boards with a configuration file
	- Example: sudo UC_configure.py apple1

* US_set_freq_ntsc.sh
	- sets the main clock frequency to 14.31818 MHz

* US_set_freq_pal.sh
	- sets the main clock frequency to 17.734475 MHz

* set_chipselect.py [0..8]
	- sets one of the chipselect lines to low or all high
	- Example: sudo set_chipselect.py 0 - selects chip 0 
	- Example: sudo set_chipselect.py 8 - selects none

* set_config.py [0..7]
	- sets one of the configurations for the CPLD

* set_reset.py [0,1]
	- sets the reset line high or low (low = active)

* UC_check_jtag.sh
	- looks for devices (CPLDs) in the JTAG chain.

* UC_write_cpld.sh [0..?] [.jed file]
	- writes the .jed file to the selected devices
	- Example: sudo UC_write_cpld 0 filename.jed - writes .jed file to cpld zero

### CPLD programming ###

* compiling the vhdl (or verilog) code must be done on a computer with the Xilinx ISE 14.7 toolchain installed.
 Link: https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools/archive-ise.html

* compiling itself can be done inside ISE or with the supplied makefile (look inside the bord directory in cpld firmware)

* a simple **make** will compile the firmware and a **make transfer** will transfer the file to the sbc (if you changed the ip address to your address inside the makefile and the path inside project.cfg)

* on the sbc in the work folder one can find the .jed file. For programming type: **UC_write_cpld [JTAG-position] [filename.jed]**