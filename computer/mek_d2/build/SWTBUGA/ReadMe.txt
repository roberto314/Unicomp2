SWTBUGA - Augmented SWTBUG

SWTBUGA adds the following enhancements to SWTBUG 1.0
    
  - Similar to the "O"ptional port prefix for the L, P,
    and E commands, a digit prefix (0-7) can be used to
    specify any port for an MP-S board to use for the L,
    P, and E commands (e.g., "2L" to load from port 2).

  - Following a load command, the I/O port address used
    is saved at $A046 which will load into register X if
    a "G" command is used to enter the loaded program.
    This is useful for a two-stage loader.

  - The "D"isk boot command has been fixed by adding a 
    delay for the motor to spin up and a check to see if
    the boot sector was read without errors. The boot
    operation is tried up to ten times. If a DC-x cont-
    roller is not detected, or boot from the DC-x fails,
    the a boot from a Percom controller is attempted
    if it's presence is detected at $C000. If that boot
    option is not present or fails, then control returns
    to SWTBUG.

  - The new "T"est memory command (SUMTEST) is followed
    by the low address and max address+1 of the memory
    range to be tested. The test runs until reset is
    pressed.

SWTBUGA maintains all of the entry points of the 
original SWTBUG. Since SWTBUGA is larger than 1K,
it must be located in an EPROM board on the bus and
the CPU board modified to allow off-board access to
$E000 through at least $E500 or so.

