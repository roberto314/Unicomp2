; ----------------- assembly instructions ---------------------------- 
;
; this is a subroutine library only
; it must be included in an executable source file
;
;
;*** I/O Locations *******************************
; define the i/o address of the ACIA1 chip

;*** 6850 CIA ************************
ACIA := $A000
ACIAControl := ACIA+0
ACIAStatus := ACIA+0
ACIAData := ACIA+1

;*** 6551 CIA ************************
;ACIAData       =     $F000
;ACIAStatus       =     $F001
;ACIA1cmd       =     $F002
;ACIAControl       =     $F003
;***********************************************************************
; 6551 / 6850 I/O Support Routines
;
ACIA1_init:
;               lda #$1f               ; 1E - 9k6, 1F - 19.2K/8/1
;               sta ACIAControl           ; control reg 
;               ;lda #$10
;               ;sta ACIAStatus
;               lda #$0B               ; N parity/echo off/rx int off/ dtr active low
;               ;lda #$09               ; N parity/echo off/rx int off/ dtr active low/ RX Interrupt
;               sta ACIA1cmd           ; command reg 
;               rts                      ; done
                  lda #$95        ; Set ACIA baud rate, word size and Rx interrupt (to control RTS)
                  sta ACIAControl
                  rts
;
; input chr from ACIA1 (waiting)
ACIA1_Input:
;               lda   ACIAStatus           ; Serial port status             
;               and   #$08               ; is recvr full
;               beq   ACIA1_Input        ; no char to get
;               lda   ACIAData           ; get chr
;               rts                      ;
;
               lda   ACIAControl           ; Serial port status
               lsr           
               bcc   ACIA1_Input
               lda   ACIAData           ; get chr
               rts                      ;
;
; non-waiting get character routine 
;ACIA1_Scan:    clc
;               lda   ACIAControl           ; Serial port status
;               and   #$08               ; mask rcvr full bit
;               beq   ACIA1_scan2
;               lda   ACIAData           ; get chr
;	      sec
;ACIA1_scan2:   rts
;
ACIA1_Scan:    clc
               lda   ACIAControl           ; Serial port status
               and   #$01
               cmp   #$01
               bne   ACIA1_scan2
               lda   ACIAData           ; get chr
               sec
ACIA1_scan2:   rts
;
; output to OutPut Port
;

;ACIA1_Output:  PHA                      ; save registers
;ACIA1_Out1:    lda   ACIAStatus           ; serial port status
;               and   #$10               ; is tx buffer empty
;               beq   ACIA1_Out1         ; no
;               pla                      ; get chr
;               sta   ACIAData           ; put character to Port
;               rts                      ; done

ACIA1_Output:  PHA                      ; save registers
ACIA1_Out1:    lda   ACIAStatus         ; serial port status
               and   #$02               
               cmp   #$02
               bne   ACIA1_Out1         
               pla                      ; get chr
               sta   ACIAData           ; put character to Port
               rts                      ; done
;end of file
