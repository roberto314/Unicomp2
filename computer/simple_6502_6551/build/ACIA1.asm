; ----------------- assembly instructions ---------------------------- 
;
; this is a subroutine library only
; it must be included in an executable source file
;
;
;*** I/O Locations *******************************
; define the i/o address of the ACIA1 chip
;*** 6551 CIA ************************
ACIA1dat       =     $A000
ACIA1sta       =     $A001
ACIA1cmd       =     $A002
ACIA1ctl       =     $A003
;***********************************************************************
; 6551 I/O Support Routines
;
ACIA1_init:
ACIA1portset:
               lda #$1e               ; 1E - 9k6, 1F - 19.2K/8/1
               sta ACIA1ctl           ; control reg 
               ;lda #$10
               ;sta ACIA1sta
               lda #$0B               ; N parity/echo off/rx int off/ dtr active low
               ;lda #$09               ; N parity/echo off/rx int off/ dtr active low/ RX Interrupt
               sta ACIA1cmd           ; command reg 
               rts                      ; done
;
; input chr from ACIA1 (waiting)
;

ACIA1_Input:
               lda   ACIA1sta           ; Serial port status             
               and   #$08               ; is recvr full
               beq   ACIA1_Input        ; no char to get
               lda   ACIA1dat           ; get chr
               rts                      ;
;
; non-waiting get character routine 
;

ACIA1_Scan:    clc
               lda   ACIA1sta           ; Serial port status
               and   #$08               ; mask rcvr full bit
               beq   ACIA1_scan2
               lda   ACIA1dat           ; get chr
	      sec
ACIA1_scan2:   rts
;
; output to OutPut Port
;

ACIA1_Output:  PHA                      ; save registers
ACIA1_Out1:    lda   ACIA1sta           ; serial port status
               and   #$10               ; is tx buffer empty
               beq   ACIA1_Out1         ; no
               pla                      ; get chr
               sta   ACIA1dat           ; put character to Port
               rts                      ; done
;
;end of file
