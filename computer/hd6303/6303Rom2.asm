    org    $0000
            
;   ROM01.ASM 	(HD6303YCP Microprocessor)
;   V2.1e  11/28/16 Fixed PATCH return and updated some DELAY values
;   V2.1d  11/25/16 Fixed a few bugs found in BASIC
;   V2.1c  11/23/16 Added SYS, PEEK & POKE to BASIC
;   V2.1   11/17/16 Fixed Assembeler bug in DESPACE & SHIFTBL 
;   V2.0   12/23 Adding MicroBASIC
;   V1.6   12/19 RAM is now 32K, Stack in External Ram, IRQ Test Option '%' 
;   V1.5   12/10 Added SNDIHXR Send iHex function, set RP5CR after reset.  
;   V1.4   12/7  Improved BEEP, moved stack to internal RAM, 1a fix not needed  
;   V1.3   12/7  Added INCHRIF some code cleanup
;   V1.2   12/5  Added Assemble (A) function
;   V1.1   12/2  Added List (B) BEEP function.
;   V1.0   11/30  Added List (L) function.   
;   11/28   Functions d,D,S,T,G,g,@,F,M,:,I,O  all working
;            Jump Tables installed for External calls and IRQs
;           GetIHEX will process 8K in about 9sec.
;   V5.6    Added debug function and more ROM jump locs
;           Aded  'g'  Go 2000 command        
;
	    processor	HD6303
      
END         equ $FF     ; Mark END OF TEXT      
REG_DDRP2   equ $01     ; PORT 2 DDR
REG_PORT2   equ $03     ; PORT 2 I/O Address
REG_TCSR1   equ $08     ;Timer Control/Status Reg 1
REG_FRCH    equ $09     ; Free Running Counter MSB
REG_FRCL    equ $0A     ; Free Running Counter LSB
REG_OCR1H   equ $0B     ; Output Compare Reg 1 MSB
REG_OCR1L   equ $0C     ; Output Compare Reg 1 LSB
REG_TCSR2   equ $0F     ;Timer Control/Status Reg 2
REG_RMCR    equ $10     ;RATE AND MODE CONTROL REGISTER
REG_TRCSR1  equ $11     ;TXD/RXD CONTROL AND STATUS REG.
REG_RDR     equ $12     ;RECEIVE DATA REGISTER
REG_TDR     equ $13     ;TRANSMIT DATA REGISTER
REG_PORT5   equ $15     ; PORT 5 I/O Address
REG_DDRP6   equ $16     ; PORT 6 DDR       
REG_PORT6   equ $17     ; PORT 6 I/O Address
REG_DDRP5   equ $20     ; PORT 5 DDR
REG_TRCSR2  equ $1E     ;TXD/RXD CONTROL AND STATUS REG#2.
REG_TCSSR3  equ $1B     ;TIMER CONTROL AND STATUS REG#3.
REG_TCONR   equ $1C     ;TIMER2 CONSTANT REG.
REG_T2CNT   equ $1D     ;TIMER2 COUNTER REG.

;**** INTERNAL RAM System Variables *****************************
;** The HD6303YCP has 256 bytes of internal RAM at $0040-$013F **
            org	   $0040        ; Start of Internal RAM 	    
TX_BYTE     equ    $40          ; Byte to send
RX_BYTE     equ    $41          ; Byte recieved
FLAGS_A     equ    $42          ; Flags A: Bit 0=ECHO                            
COUNT_A     equ    $43          ; Counter A
COUNT_B     equ    $44          ; Counter B
COUNT_C     equ    $45          ; Counter C
ADDR_HI     equ    $46
ADDR_LO     equ    $47
TEMP_01     equ    $48          ; Temp Storage 1
TEMP_02     equ    $49          ; Temp Storage 2
TEMP_03     equ    $4A          ; Temp Storage 3
TEMP_04     equ    $4B          ; Temp Storage 4
REC_LEN     equ    $4C          ; iHex Record Length 
REC_TYPE    equ    $4D          ; iHex Record Type
REC_CSUM    equ    $4F          ; iHex Record Checksum
BLINK_CT    equ    $50          ; Blink Counter
IRQFLAG1    equ    $51          ; IRQ Save Flag
IRQFLAG2    equ    $52          ; IRQ Read Flag

OPCD        equ    $53          ; Opcode for disassembly
ROWADDH     equ    $54          ; Mnemonic Table Row Address
ROWADDL     equ    $55          
OPCFLAGS    equ    $56          ;Opcode flags
DISABUFP    equ    $57          ;Dissasmbly buffer pointer (2 bytes)
DISADD1     equ    $59          ;Disassembly start address (2 bytes)
DISADD2     equ    $5B          ;Disassembly End address (2 bytes)
LINECT      equ    $5D          ;Disassembly Line count 

DISABUF     equ    $60          ;Dissasmbly buffer (16 bytes $60-$6F) 
PARMBUF     equ    $70          ;Parameter buffer 5 bytes $70-$74
PARMLEN     equ    $75          ;Parameter Length 
MSTMRXL     equ    $76          ;10ms Timer Low byte
MSTMRXM     equ    $77          ;10ms Timer Mid byte
MSTMRXH     equ    $78          ;10ms Timer Hi byte 

IRQJUMP     equ    $80          ; IRQ Jump Table Start(store ISR address at IRXxxx+1)
IRQNMI      equ    $83          ; Non Maskable Interrupt
IRQSWI      equ    $86          ; Software Interrupt
IRQIRQ1     equ    $89          ; IRQ1
IRQICI      equ    $8C          ; Timer1 Input Capture
IRQOCI      equ    $8F          ; Timer 1 Output Capture
IRQTOI      equ    $92          ; Timer 1 Overflow
IRQCMI      equ    $95          ; Timer 2 Counter Match
IRQIRQ2     equ    $98          ; IRQ2
IRQSIO      equ    $9B          ; RDRF+ORFE+TDRE+PER

DREG_A      equ    $F0          ;A Register
DREG_B      equ    $F1          ;B Register
DREG_XH     equ    $F2          ;X Register
DREG_XL     equ    $F3
DREG_SPH    equ    $F4          ;Stack Pointer
DREG_SPL    equ    $F5
DREG_PCH    equ    $F6          ;Program Counter
DREG_PCL    equ    $F7
DREG_F      equ    $F8          ;Flags

; *************************************************************************
;   MicroBASIC Constants      $0220-$0390
; *************************************************************************
MAXLIN      equ    $72	 ; dc.b 72     ; Max Line Length
BACKSP      equ    $7F	 ; dc.b $7F    ;// EMK puTTY backspace = 127
CANCEL      equ    $1B	 ; dc.b $1B    ;// EMK Use ESC as cancel

;  **** ORG $0220  *** MEMORY VARIABLES *****     
INDEX1      equ    $0220	 
INDEX2      equ    $0222	  
INDEX3      equ    $0224	  
INDEX4      equ    $0226	  
SAVESP      equ    $0228	  
NEXTBA      equ    $022A	 ;  dc.w END/BASICTOP  
WORKBA      equ    $022C	 ;  dc.w END/BASICTOP  
SOURCE      equ    $022E	 ;  dc.w END/BASICTOP  
PACKLN      equ    $0230	  
HIGHLN      equ    $0232	  
BASPNT      equ    $0234	  
BASLIN      equ    $0236	  
PUSHTX      equ    $0238	  
XSTACK      equ    $023A	 ; dc.w $707F 
RNDVAL      equ    $023C	  
DIMPNT      equ    $023E	  
DIMCAL      equ    $0240	  
PRCNT       equ    $0242	               ;Print counter
MEMEND      equ    $0246	 ; dc.w $6FFF 	;FDB $1FFF 			#### /DTU
ARRTAB      equ    $0248	  
KEYWD       equ    $024A	  
TSIGN       equ    $024C	   
NCMPR       equ    $024D	   
TNUMB       equ    $024E	   
ANUMB       equ    $024F	   
BNUMB       equ    $0250	   
AESTK       equ    $0251	 ; dc.w ASTACK 
FORPNT      equ    $0253	 ; dc.w FORSTK 
VARPNT      equ    $0255	 ; dc.w VARTAB 
SBRPNT      equ    $0257	 ; dc.w SBRSTK 
SBRSTK      equ    $0259	   
FORSTK      equ    $0269	 
DIMVAR      equ    $0299	 ;dc.w VARTAB      
BUFNXT      equ    $02AC	 ;dc.w $00B0 
ENDBUF      equ    $02AE	 ;dc.w $00B0
BUFFER      equ    $02B0	 
VARTAB      equ    $0300	 
ASTACK      equ    $038C
BASICTOP	  equ    $0390   ;Use this in ROM implementation

; *************************************************************************
;;OPCDTYPE    equ    $F840
;;OPCDEXCP    equ    $F850
;;MNETBLH     equ    $F860
;;MNETBLL     equ    $F9F0
; ***********************************************************************
; * External Call Jump Table
; ***********************************************************************
;DELAYX    equ    $FBD0         ;Delay based on contents of X approx 10.5us/count         
;OUTCHR    equ    $FBD3         ;Send byte in A to Serial Port
;INCHR     equ    $FBD6         ;wait for a serial byte and return in A
;INCHRE    equ    $FBD9         ;wait for a serial byte and return in A with echo
;PUTS      equ    $FBDC         ;Transmit data indexed by X
;OUTHEX    equ    $FBDF         ;Output A as 2 HEX digits
;GETHEXB   equ    $FBE2         ;Wait until a HEX byte is entered 
;INHEXB    equ    $FBE5         ;Input 2 hex digits return with byte value in A
;GETADDR   equ    $FBE8         ;Get 4 byte address, save in ADDR_HI & ADDR_LO
;DODUMP    equ    $FBEB         ;Jump here to save regs, print regs and return 
;DMPREG    equ    $FBEE         ;Save current state of registers in RAM
;PRTREGS   equ    $FBF1         ;Send saved register values to terminal
;BEEP      equ    $FBF4         ;Beep based on contents of A & B
;INCHRIF   equ    $FBF7         ;Input char if available .. Returns zero if none

	    org   $8000	    ;Start of ROM $8000

RESET	  ;subroutine
        SEI            ;Disable interrupts
        LDAA  #$60
        STAA  $14       ;Set RAM/Port5 Ctrl RAME=1,STBY=1,AMRE=0,HLTE=0,MRE=0,IRQ1&2=0
                 
        LDS   #$7FF0   ;Set Stack Pointer (top of external RAM - 16bytes)

        LDAA  #$01    
        STAA  FLAGS_A  ; Echo Flag ON 

        LDX   #3510    ; delay approx 20ms
DELBOOT DEX
        BNE   DELBOOT       
        
        LDAA  #$F7
        STAA  REG_DDRP2       ;Set Port2 to OUTPUT (except P2.3=Input for RXD)
        LDAA	#$FF        
        STAA  REG_DDRP5       ;P5 DDR  = OUTPUT
        STAA  REG_PORT5       ;P5 OUTPUTS ALL HIGH
        STAA	REG_DDRP6       ;P6 DDR  = OUTPUT 
        LDAA  #$00
        STAA  REG_PORT6       ;P6 PORT = All LEDs OFF
        
        LDAA  #250
        STAA  BLINK_CT
        JSR   SERINIT   ;INIT INTERNAL UART, INTERNAL CLOCK, 9600 BAUD
        JSR   IRQINIT   ;Populate IRQ Jump Table

        JSR   FLASHP6   ;Blink LEDs 5x

        LDAA   #25     ;Duration=1/4sec. 
        LDAB   #$10    ;Frequency ($10 approx 3KHZ)
        JSR    BEEP    ;Call BEEP
        
MONITOR LDX   #BOOTMSG
        JSR   PUTS      ;Startup Message
        
        LDAA  REG_RDR   ;Clear RXD flags & flush buffer

LOOP1   LDX   #175      ; MAIN Program Loop starting point.
        JSR   DELAYX    ;delay approx 1ms
        
BLINK1  DEC   BLINK_CT  ;Decrement the blink counter (250ms based on delay above)
        BNE   GETCHR    ; NO = look for input & continue
        LDAA  #250      ; YES = Reset the blink counter
        STAA  BLINK_CT
        LDAA  REG_PORT6
        CMPA  #$80      ;Was previous output = MSB only set?
        BEQ   BLINK2    ;Yes = Set $70 output
        LDAA  #$80      ; No = Set $80 output 
        STAA  REG_PORT6 ;P6 PORT
        JMP   GETCHR    ; continue...
BLINK2  LDAA  #$70      ; Set $70 output
        STAA  REG_PORT6 ;P6 PORT

GETCHR  JSR   INCHRIF   ;Get input if available
        BCS	  NOCHR     ; No Data Ready then loop again
        JSR   OUTCHR    ;echo it
        LDX   #MSGNL    ;Send Newline
        JSR   PUTS
              
DOMENU  LDAA  RX_BYTE   ;Get inbyte       
        CMPA  #'d       ;**** Lowercase 'd' = Dump 16 bytes ****
        BNE   IS_D      
        JSR   GETADDR   ;Enter Address:
        BCS   DOMENUX        
        LDX   #MSGNL    ;Send Newline
        JSR   PUTS
        JSR   DUMP16    ;DUMP16
DOMENUX LDX   #MSGOK
        JSR   PUTS      ; Print OK
NOCHR   JMP   LOOP1
        
IS_D    CMPA  #'D       ;**** DUMP256 Command ****
        BNE   IS_G      ;Uppercase 'D'= Dump 256
        JSR   GETADDR   ;Get Start address
        BCS   DOMENUX        
        LDX   #MSGNL    ;Send Newline
        JSR   PUTS
        JSR   DUMP256   ;Call DUMP256
        JMP   MENUXOK   ;Print OK and resume main loop
        
IS_G    CMPA  #'G       ;**** GO Command **** 
        BNE   IS_LG
        JSR   GETADDR   ;Enter Address
        BCS   DOMENUX        
        LDX   #MSGNL    ;Send Newline
        JSR   PUTS
        LDX   ADDR_HI
        JSR   0,X
        JMP   MENUXOK   ;Print OK and resume main loop
        
IS_LG   CMPA  #'g       ;******** go 2000 Command **** 
        BNE   IS_S
        LDX   #$2000    ; Load address of $2000
        JSR   0,X
        JMP   MENUXOK   ;Print OK and resume main loop        

IS_S    CMPA  #'S       ;******** Set Memory **********
        BNE   IS_T
        JSR   GETADDR   ;Enter Start Address
        BCS   DOMENUX        
        LDX   #MSGNL
        JSR   PUTS      ;Newline        
SETMEM  JSR   INHEXB    ;Get 1 hex byte
        BCS   SETMEMX   ;If enter was pressed then exit
        LDX   ADDR_HI   ;Get address -> X     
        STAA  0,X       ;Store input byte
        INX             ;Point at next address
        STX   ADDR_HI   ;Save it
        LDAA  #$20
        JSR   OUTCHR    ;Output a space
        JMP   SETMEM    ;Do it again
SETMEMX JMP   MENUXOK   ;Print OK and resume main loop
        
IS_T    CMPA  #'T       ;**** Text Chars to Memory ****
        BNE   IS_O
        JSR   GETADDR   ;Enter Start Address
        BCS   TXTMEMX        
        LDX   #MSGNL
        JSR   PUTS      ;Newline        
TXTMEM  JSR   INCHRE    ;Get 1 character and echo
        CMPA  #$0D      ;Is it Return?
        BEQ   TXTMEMX   ;Exit 
        LDX   ADDR_HI   ;Get Address     
        STAA  0,X       ;Save byte
        INX             ;Inc Address
        STX   ADDR_HI   ;Save Address
        JMP   TXTMEM    ;Repeat
TXTMEMX JMP   MENUXOK   ;Print OK and resume main loop

IS_O    CMPA  #'O       ;**** PORT OUTPUT ****
        BNE   IS_I
        JSR   PORTOUT
        LDX   #MSGOK
        JSR   PUTS      ;Send OK
        LDX   #$FFFF    ;delay approx 373ms
        JSR   DELAYX
        JMP   LOOP1  

IS_I    CMPA  #'I       ;**** PORT INPUT ****
        BNE   IS_L
        JSR   PORTIN
        JMP   MENUXOK   ;Print OK and resume main loop 
        
IS_L    CMPA  #'L       ;**** List Memory (Dissamble)****
        BNE   IS_A
        JSR   LISTMEM
        JMP   MENUXOK   ;Print OK and resume main loop

IS_A    CMPA  #'A       ;**** Assemble to Memory ****
        BNE   IS_M
        LDX   #MSGSTART   ;Enter Start Address:
        JSR   PUTS
        JSR   INHEXB      ;Get 2 hex digits
        BCS   IS_AX       ; Exit if enter was pressed ...just exit
        STAA  ADDR_HI
        JSR   INHEXB      ;Get 2 hex digits
        STAA  ADDR_LO
        
        JSR   ASM2MEM   ;Assemble to memory
IS_AX   JMP   MENUXOK   ;Print OK and resume main loop
                                 
IS_M    CMPA  #'M       ;******** Display Menu ********
        BNE   IS_LCM
SHOMNU  LDX   #MSGHLP
        JSR   PUTS      ;Show Menu
        JMP   LOOP1
IS_LCM  CMPA  #'m       
        BEQ   SHOMNU
        
IS_C    CMPA  #'C      ;********* Clear Screen ********
        BNE   IS_F
        LDX   #MSGCLS
        JSR   PUTS      ;Clear Screen VT100 Sequence: Esc[2J Esc[H 
        JMP   LOOP1
        
IS_F    CMPA  #'F       ;******** Fill Memory *******
        BNE   IS_LCF
        JSR   FILLMEM
        JMP   MENUXOK   ;Print OK and resume main loop
               
IS_LCF  CMPA  #'f       ;******** Flash LEDs 10x *******
        BNE   IS_H
        LDAB  #10
        JSR   FLASH1
        JMP   MENUXOK   ;Print OK and resume main loop       

IS_H    CMPA  #'H       ;** Set High Speed 19200 baud ***
        BNE   IS_Z
        LDX   #MSG19200 ;Baud Rate to 19200..  
        JSR   PUTS      
        JSR   SERINI2
        JMP   MENUX    ;resume main loop       

IS_Z    CMPA  #'Z       ;******** Beep *****************
        BNE   IS_B
        LDAA   #100     ;Duration = 1 sec. 
        LDAB   #$30     ;Frequency    ($30 approx 1KHZ)
        JSR    BEEP     ;Call BEEP 
        JMP   MENUXOK   ;Print OK and resume main loop

IS_B    CMPA  #'B       ;******** START BASIC (COLD)***********
        BNE   IS_LCB
        LDX   #MSGBASIC ;  NAM MICRO  MICROBASIC V1.3C
        JSR   PUTS      
IS_B2   JMP   COLDST

IS_LCB  CMPA  #'b       ;******** START BASIC (WARM)***********
        BNE   IS_PCT
        LDX   IMPLET
        CPX   #LET
        BNE   IS_B2    ;** IF BASIC not started use COLD START
        JMP   READY    ;** else jump to warm start location
        
IS_PCT  CMPA  #'%       ;**** Start/Stop 10ms Timer ****
        BNE   IS_IHR
        SEI
        JSR   MS10TMR
        JMP   MENUXOK   ;Print OK and resume main loop                          
        
IS_IHR  CMPA  #$3A       ;**** Get IHEX Rec (no echo) ****
        BNE   IS_SIHX
        JSR   GETIHEX
        LDX   #MSGNL
        JSR   PUTS      ;Newline
        JMP   LOOP1
        
IS_SIHX CMPA  #$3B      ; is it a ";"
        BNE   IS_AT
        JSR   SNDIHXR    ;Do Send iHex Rec
        JMP   LOOP1      ;No response just continue
        
IS_AT   CMPA  #'@       ;**** Attention Command - Response = "$$$" ****
        BNE   MENUX
        LDX   #MSGATNRSP
        JSR   PUTS      ;Attention Respones Message = "$$$"
        JMP   LOOP1        
        
MENUXOK LDX   #MSGOK
        JSR   PUTS      ;Newline
MENUX   JMP   LOOP1
        

;;************************************************************************
;; DELAYX                                                             OK
;; Delay routine  approx 5.696us/count  (X * 5.696us)+8.3us 
;; $AB71(43889) 1/4sec   $FFFF(65535)  0.373287sec
;;************************************************************************
DELAYX  ;subroutine       ;approx 5.696 us/count
DELAY1  DEX 
        CPX   #$0000     
        BNE   DELAY1
        RTS

;;************************************************************************
;; FLASHP6                                                            OK
;; Toggle all the bits (LEDs) on P6 ON/OFF 5 times using 1/4sec. delay
;;************************************************************************
FLASHP6 ;subroutine
        LDAB  #05 
FLASH1  LDAA  #$00
        STAA  $17       ;P6 PORT
        LDX   #21937    ;approx 1/8 sec
        JSR   DELAYX
        
        LDAA  #$FF
        STAA  $17       ;P6 PORT
        LDX   #21937    ;approx 1/8 sec
        JSR   DELAYX
        DECB 
        CMPB  #$00 
        BNE   FLASH1
        RTS

;;************************************************************************
;; BEEP    Beep using Timer1(FRC) for duration timing
;; Call with: A=Duration $00-$FF(in 10ms increments)  B=PulseWidth $01-$FF  
;; Frequency byte calculation  f = 1/(PW+3 * 0.0000114)
;; eg: PW=84 = Approx 1KHZ ((84+3)*0.0000114)=0.000992 1/0.000992=1008Hz
;; PW=((1/f)/0.0000114)-3  eg: (1/1000)=0.001 (0.001/0.0000114)=87.7  (87-3)=84
;; Returns with X,A,B and OCR1 unchanged      (340hz - 21.9Khz)
;;************************************************************************
BEEP    ;subroutine
        PSHX           ;Save X
        PSHA
        PSHB
        LDX   REG_OCR1H
        PSHX
        
        STAB  DISABUF+1  ;Pulse Width Value -> DISABUF & DISABUF+1
        STAA  DISABUF+2  ;Duration Value -> DISABUF+2
        CLR   DISABUF    ;Clear High Bytes
        
        LDD   REG_FRCH   ;Set FRC Output $300c = 12300 = 10ms
        ADDD  #$300C
        STD   REG_OCR1H
        LDAA  REG_DDRP2  ;Set PORT2 BIT0 = OUTPUT
        ORAA  #$01
        STAA  REG_DDRP2
        SEI              ;Disable interrupts
BEEP1   LDAA  REG_PORT2
        ORAA  #$01 
        STAA  REG_PORT2  ; set the bit
        
        LDX   DISABUF   ;Get Pulse Width Value ->X
        JSR   DELAYX    ;Delay based on DISABUF
        
        LDAA  REG_PORT2
        ANDA  #$FE
        STAA  REG_PORT2  ; clear the bit

        LDX   DISABUF   ;Get Pulse Width Value ->X
        JSR   DELAYX    ;Delay based on DISABUF
        
        LDAA  REG_TCSR1   ;Test OCFI flag
        ANDA  #$40
        BEQ   BEEP1      ;If Not Set continue...   else...
        LDD   REG_FRCH   ;  Otherwise re-load the OCR1 Register
        ADDD  #$300C     ;  with current value + 12300 ($300C)
        STD   REG_OCR1H
        
        DEC   DISABUF+2  ; Decrement Duration Counter...Done?
        BNE   BEEP1      ; If Not Done, continue...
        
        ;Restore values from stack & exit
BEEPX   PULX
        STX   REG_OCR1H   ;Restore original OCR1 value
        PULB
        PULA 
        PULX               ;Restore ORIGINAL X
        CLI                ;Enable interrupts        
        RTS
;;************************************************************************
;; SERINIT   Initialize the Serial Port using Timer1
;;************************************************************************
SERINIT ;subroutine
        LDAA  #$05      ;ENABLE INTERNAL UART, INTERNAL CLOCK, 9600 BAUD
	      STAA  REG_RMCR
	      LDAA  #$0A      ;ENABLE RECIEVE AND TRANSMITT DATA
	      STAA  REG_TRCSR1
	      LDAA  #$00      ;1 Stop bits No Parity
	      STAA  REG_TRCSR2
	      LDAA  REG_RDR	  ;FLUSH BUFFER AND CLEAR ERROR FLAGS
        RTS
;;************************************************************************
;; SERINI2   Initialize the Serial Port to 19200 baud using Timer2
;; TCONR: 0=38400, 1=19200, 3=9600, 7=4800, 15=2400 (baud with 4.9152MHZ Xtal)
;;************************************************************************
SERINI2 ;subroutine
        LDAA  #$01
SERINI3 STAA  REG_TCONR  ;Timer2 Constan Reg=1 (19200 baud with 4.9152MHZ Xtal)
        LDAA  REG_TRCSR1
	      ANDA  #$F5      ;DISABLE RECIEVE AND TRANSMITT DATA
	      STAA  REG_TRCSR1
        LDAA  #$24      ;ENABLE INTERNAL UART, SS2=1(use T2) & CC0=1(8 bit data)
	      STAA  REG_RMCR
	      LDAA  #$00      ;1 Stop bits No Parity
	      STAA  REG_TRCSR2
        
        LDAA  REG_TRCSR1
	      ORAA  #$0A      ;ENABLE RECIEVE AND TRANSMITT DATA
	      STAA  REG_TRCSR1
        LDAA  #$10
        STAA  REG_TCSSR3 ;Enable Timer2 Counter (T2E=1)
	      LDAA  REG_RDR	  ;FLUSH BUFFER AND CLEAR ERROR FLAGS
        RTS

;;************************************************************************
;; IRQINIT   Initialize the Interrupt Jump Table 
;;************************************************************************
IRQINIT ;subroutine
        LDAA #$7E      ;Jump Instruction
        STAA IRQJUMP   ;$80          ; User Jump or TRAP
        STAA IRQNMI    ;$83          ; Non Maskable Interrupt
        STAA IRQSWI    ;$86          ; Software Interrupt
        STAA IRQIRQ1   ;$89          ; IRQ1
        STAA IRQICI    ;$8C          ; Timer1 Input Capture
        STAA IRQOCI    ;$8F          ; Timer 1 Output Capture
        STAA IRQTOI    ;$92          ; Timer 1 Overflow
        STAA IRQCMI    ;$95          ; Timer 2 Counter Match
        STAA IRQIRQ2   ;$98          ; IRQ2
        STAA IRQSIO    ;$9B          ; RDRF+ORFE+TDRE+PER
        LDX  TRAP01
        STX  IRQJUMP+1
        LDX  #IRQDEFT
        STX  IRQNMI+1    ;$83          ; Non Maskable Interrupt
        STX  IRQSWI+1    ;$86          ; Software Interrupt
        STX  IRQIRQ1+1   ;$89          ; IRQ1
        STX  IRQICI+1    ;$8C          ; Timer1 Input Capture
        STX  IRQOCI+1    ;$8F          ; Timer 1 Output Capture
        STX  IRQTOI+1    ;$92          ; Timer 1 Overflow
        STX  IRQCMI+1    ;$95          ; Timer 2 Counter Match
        STX  IRQIRQ2+1   ;$98          ; IRQ2
        STX  IRQSIO+1    ;$9B          ; RDRF+ORFE+TDRE+PER
        RTS
        
;;************************************************************************
;; OUTCHR  Transmit a serial byte from A                               OK
;;
;; TRCSR1: |RDRF|ORFE|TDRE|RiE|RE|TIE|TE|WU| 
;;************************************************************************
OUTCHR  ;subroutine
	      PSHB		             ;SAVE B-REG
OUTCHR1	LDAB	REG_TRCSR1     ;Get Status Reg 
	      ASLB                 ;TDRE->C
	      ASLB
	      ASLB
	      BCC	  OUTCHR1	       ;READY FOR NEXT CHARACTER
	      STAA  REG_TDR
	      PULB                 ;RESTORE B-REG
        RTS

;;************************************************************************
;; INCHR  wait for a serial byte and return in A
;;
;;************************************************************************
INCHRER ;subroutine
       	LDAA  REG_RDR	        ;ON ERROR, FLUSH BUFFER AND CLEAR ERROR FLAG
INCHR	  LDAA  REG_TRCSR1
        ANDA  #$C0	          ;FILTER OUT RDRF AND ORFE
        CMPA	#$00
        BEQ	  INCHR           ;WAIT FOR CHARACTER
        CMPA  #$40
        BEQ   INCHRER;        ;CHECK FOR FRAMING ERROR
        LDAA  REG_RDR         ;READ RECIEVED CHARACTER
        STAA  RX_BYTE         ;Save in RX_BYTE
        RTS
;;************************************************************************
;; INCHRE  wait for a serial byte and return in A with echo
;;************************************************************************
INCHRE  ;subroutine
        JSR   INCHR
        JSR   OUTCHR
        LDAA  RX_BYTE
        RTS
;******************************************************************
; INCHRIF  Input a character if available
; Returns with input character or zero (with C=1) if none available
;******************************************************************
INCHRIF LDAA  REG_TRCSR1
        ANDA  #$C0	          ;FILTER OUT RDRF AND ORFE
        CMPA	#$00
        BEQ	  INCHRNC         ; No Data Ready loop again
        JSR   INCHR           ; Data Available so GET Byte  
        CLC                   ; Clear The Carry
        RTS                   ; Return
INCHRNC LDAA  REG_RDR         ;Clear RXD flags & flush buffer
        LDAA  #$00            ; No Data - Return zero and C=1
        SEC
        RTS
       
;;************************************************************************
;; PUTS                                                                OK
;; PRINT DATA POINTED AT BY X-REG
;;************************************************************************
PUTS2   ;subroutine
        JSR   OUTCHR
        INX
PUTS    LDAA  0,X
        CMPA  #$FF
        BNE   PUTS2   ;GO ON IF NOT EOT
        RTS
     
;;************************************************************************
;; OUTNIBH
;; OUTPUT High 4 bits of A as 1 HEX Digit
;; OUTNIBL
;; OUTPUT Low 4 bits of A as 1 HEX Digit
;;************************************************************************
OUTNIBH ;subroutine        
        LSRA          ;OUT HEX LEFT HEX DIGIT
        LSRA
        LSRA
        LSRA
OUTNIBL ANDA  #$0F     ;OUT HEX RIGHT HEX DIGIT
        ORAA  #$30
        CMPA  #$39
        BLS   OUTNIBX
        ADDA  #$7
OUTNIBX JSR   OUTCHR
        RTS 
     
;;************************************************************************
;; OUTHEX
;; Output A as 2 HEX digits
;;************************************************************************
OUTHEX  ;subroutine        
        PSHB            ;Save B
        TAB             ;Save A in B 
        JSR   OUTNIBH   ;Print High 4 bits
        TBA             ;Get A from B 
        JSR   OUTNIBL   ;Print Low 4 Bits
        PULB            ;Restore B
        RTS
        
        
;;************************************************************************
;; GETHEXB    Wait for 2 HEX chars to be entered, return with value in A 
;;************************************************************************
GETHEXB ;subroutine        
        JSR   INCHR      ;Get 1 char
        CMPA  #$0D       ; Is it CR?
        BEQ   GETHEX5    ; Return with C=1
        CMPA  #$1B       ; is it Esc?
        BEQ   GETHEX5    ; Return with C=1
;        CMPA  #$20
;        BEQ   GETHEX5
         
        CMPA  #'0        ; < '0'  ?
        BMI   GETHEXB     ; Get another keystroke
        CMPA  #'g        ; > 'f'  ?
        BPL   GETHEXB     ; Get another keystroke
        CMPA  #$3A        ; <= '9' ?
        BPL   GETHEX1     ; NO = continue  else...
        JMP   GETHEX3     ; Echo & Return
GETHEX1 ANDA  #$4F        ;Convert to Uppercase          
        CMPA  #'G        ; > 'F' ?
        BPL   GETHEXB     ; Get another keystroke
        CMPA  #$40        ; < 'A' 
        BLS   GETHEXB     ; Get another keystroke
        STAA  RX_BYTE     ; Save Uppercase version in RX_BYTE
GETHEX3 LDAA  FLAGS_A
        ANDA  #$01        ;Is ECHO ON?
        BEQ   GETHEX4     ;NO = Skip OUTCHR
        LDAA  RX_BYTE        
        JSR   OUTCHR
GETHEX4 LDAA  RX_BYTE     ;Get Input byte
        CLC               ;Return with C=0  OK
        RTS 
GETHEX5 SEC               ;Return with C=1  Exit Char entered (Esc or CR)
        RTS
                 
;;************************************************************************
;; CHR2VAL   Convert ASCII hex char to value in A
;;************************************************************************
CHR2VAL ;subroutine
        CMPA  #'A         ; < 'A'
        BPL   CHR2VL1        
        ANDA  #$0F
        RTS
CHR2VL1 SUBA  #55         ; 'A'-'F'
        RTS        

;;************************************************************************
;; GETADDR Prompt for & input 4 hex chars save value in ADDR_HI & ADDR_LO
;;************************************************************************
GETADDR ;subroutine
        LDX   #MSG001   ;Enter Address:
        JSR   PUTS
GETADR1 JSR   INHEXB
        BCS   GETADDX
        STAA  ADDR_HI
        JSR   INHEXB
        BCS   GETADDX
        STAA  ADDR_LO
        CLC
GETADDX RTS

 ;;************************************************************************
 ;; INHEXB   Input 2 hex digits return with byte value in A
 ;;          If C=1  exit char was entered
 ;;************************************************************************
INHEXB  ;subroutine
        JSR   GETHEXB
        BCS   INHEXBX
        JSR   CHR2VAL
        ASLA
        ASLA
        ASLA
        ASLA
        ANDA  #$F0
        STAA  TEMP_01
        JSR   GETHEXB
        BCS   INHEXBX
        JSR   CHR2VAL
        ORAA  TEMP_01
        STAA  TEMP_01
        CLC
INHEXBX RTS
  
;;************************************************************************
;; DUMP16                                                              OK
;; Call with start address in ADDR_HI & ADDR_LO
;;************************************************************************
DUMP16  ;subroutine
        LDAA  ADDR_HI    ;Print Address as 4 HEX chrs
        JSR   OUTHEX   
        LDAA  ADDR_LO
        JSR   OUTHEX   
        LDAA  #$20       ;Print 2 spaces
        JSR   OUTCHR   
        JSR   OUTCHR
        LDX   ADDR_HI
        LDAB  #16        ;Set Byte count
DUMP161 LDAA  0,X        ;Get Data byte
        JSR   OUTHEX     ;Print as HEX
        LDAA  #$20        
        DECB
        CMPB  #8         ;On 8th byte print '-' instead of space 
        BNE   DUMP162
        LDAA  #'-
DUMP162 JSR   OUTCHR
        INX 
        CMPB  #00        ; Done?
        BNE   DUMP161    ; Do next byte
        JSR   OUTCHR     ; print 3 spaces
        JSR   OUTCHR
        JSR   OUTCHR
        LDX   ADDR_HI
        LDAB  #16        ;Set Byte count
DUMP163 LDAA  0,X        ;Get Data byte
        CMPA  #$20       ;Less than blank? 
        BPL   DUMP164
        LDAA  #'.
DUMP164 CMPA  #$7F       ;Greater than `~`  
        BMI   DUMP165
        LDAA  #'.
DUMP165 JSR   OUTCHR     ;print it (or the .)
        INX
        DECB
        CMPB  #00        ;Done?
        BNE   DUMP163    ;Do next byte
        LDAA  #10
        JSR   OUTCHR     ;Print LF&CR then return
        LDAA  #13
        JMP   OUTCHR

;;************************************************************************
;; DUMP256                                                              OK
;; Call with start address in ADDR_HI & ADDR_LO
;;************************************************************************
DUMP256  ;subroutine
        LDAA  #16
        STAA  COUNT_A
DMP2561 JSR   DUMP16
        LDAA  COUNT_A
        DECA
        CMPA  #00
        BEQ   DMP256X
        STAA  COUNT_A           
        LDD   ADDR_HI
        ADDD  #16
        STD   ADDR_HI
        JMP   DMP2561
DMP256X RTS        
 
;******************************************************************
; GETIHEX:
; the ':' command - wait for an iHEX record and store it
;                   verify checksum and respond with '*' if OK 
;******************************************************************             
GETIHEX  ;subroutine
        LDAA  #00     
        STAA  COUNT_C    ;Clear Checksum
        STAA  COUNT_A    ;Byte Counter
        STAA  FLAGS_A    ;Echo Off
             
        JSR   INHEXB     ;GET RECORD LENGTH
        BCS   GIHERR     ;If non hex goto exit
        STAA  REC_LEN    ;Save REC LEN
        STAA  COUNT_A    ;Save in Byte counter
                  
        JSR   INHEXB     ;Get Address save in ADDR_HI & ADDR_LO
        STAA  ADDR_HI
        JSR   INHEXB
        STAA  ADDR_LO        

        JSR   INHEXB     ;GET RECORD TYPE
        BCS   GIHERR     ;If non hex goto exit
        STAA  REC_TYPE   ;Save REC TYPE
             
        LDX   ADDR_HI    ;Get Address 
                                        
NEXTIHB JSR   INHEXB     ;Get Data Byte
        BCS   GIHERR     ;If non hex goto exit
        STAA  TEMP_01    ;Save in TEMP_01
        ADDA  COUNT_C    ; Add to Checksum Count
        STAA  COUNT_C 
        LDAA  TEMP_01    ; Get input byte   
        STAA  0,X        ; Store in Memory  
        INX              ; Inc Address Pointer
        LDAA  COUNT_A    ; Get Byte Counter
        DECA             ; Decrement
        CMPA  #00
        BEQ   GIHCSUM    ; Done? - Calculate Checksum
        STAA  COUNT_A    ; Update Counter
        JMP   NEXTIHB    ; Get next byte

GIHCSUM JSR   INHEXB     ; GET INPUT CHECKSUM 
        BCS   GIHERR     ;If non hex goto exit
        STAA  REC_CSUM   ;Save Checksum
        LDAB  COUNT_C    ; Get Checksum counter ->B
        LDAA  REC_LEN    ; Get Rec Len 
        ABA              ; Add Total  B+A->A
        TAB              ; Save New Total A->B
        LDAA  REC_TYPE   ; Get Rec Type
        ABA              ; Add Total  B+A->A
        TAB              ; Save New Total A->B
        LDAA  ADDR_HI    ; Address HI
        ABA              ; Add Total  B+A->A
        TAB              ; Save New Total A->B
        LDAA  ADDR_LO   ; Address LO
        ABA              ; Add Total
        NEGA             ; 2's complement 
        STAA  COUNT_C   ; Save in Checksum counter
        TAB              ; also in B 
              
        CMPB  REC_CSUM  ; Get Input Checksum
        BNE   GIHERR2   ; Checksum Error
                                  ; Otherwise 
        JMP   GIHEXIT  ; Good Record - Exit
             
GIHERR  LDAA  #'?       ; Input Error (NON-HEX data)
        JMP   GIHEXX1
      
GIHERR2 LDAA  #'E      ; Checksum Error
        JMP   GIHEXX1 
             
GIHEXIT LDAA  #'*
GIHEXX1 JSR   OUTCHR
        LDAA  #$01
        STAA  FLAGS_A   ; Turn ECHO BACK ON
        RTS
        
 ;******************************************************************
; SNDIHXRC  the ';' command
; Get Length and start address and send an iHEX record with checksum
;******************************************************************             
SNDIHXR CLRA
        STAA  COUNT_C  ;Clear Checksum
        STAA  COUNT_A  ;Byte Counter
        STAA  REC_TYPE ;Record Type always = 0

        LDAA  FLAGS_A
        ANDA  #$FE 
        STAA  FLAGS_A  ;Set ECHO OFF
             
        JSR   INHEXB   ;GET RECORD LENGTH
        BCS   SIHRERR  ; Goto ERROR Exit
        STAA  REC_LEN  ; Save in REC_LEN
        STAA  COUNT_A  ; Save in Byte Counter

        JSR   INHEXB   ;GET Start Address HI
        BCS   SIHRERR  ; Goto ERROR Exit
        STAA  ADDR_HI
        JSR   INHEXB   ;GET Start Address LO
        BCS   SIHRERR  ; Goto ERROR Exit
        STAA  ADDR_LO
                  
        LDAA  #$20
        JSR   OUTCHR   ;Send Space to Indicate good len & address.
                          
        LDX   ADDR_HI  ;Address->X
NXTSHXB LDAA  0,X      ;Get Data from memory  
        JSR   OUTHEX   ;Send as 2 hex chars
        LDAA  0,X      ;Get Data from memory (again)
        ADDA  COUNT_C  ;Add to Checksum counter
        STAA  COUNT_C
        INX            ; Inc Address Pointer
             
        DEC   COUNT_A  ; Decrement Byte Counter
        BEQ   SIHCSUM  ; Done? - Calculate Checksum
        JMP   NXTSHXB  ; Send next byte

SIHCSUM LDAB  COUNT_C    ; Get Checksum counter in B
        LDAA  REC_LEN    ; Get Rec Len in A 
        ABA              ; Add Total
        TAB              ; Save New Total in B
        LDAA  REC_TYPE   ; Get Rec Type
        ABA              ; Add Total
        TAB              ; Save New Total in B
        LDAA  ADDR_HI    ; Address HI
        ABA              ; Add Total
        TAB              ; Save New Total
        LDAA  ADDR_LO    ; Address LO
        ABA              ; Add Total
        NEGA             ; 2's complement 
        STAA  COUNT_C    ; Save in Checksum counter
        JSR   OUTHEX     ; Send Checksum
        JMP   SIHREX     ; Exit
             
SIHRERR LDAA  #'?         ; Input Error (NON-HEX data)
        JSR   OUTCHR 

SIHREX  LDX   #MSGNL       ; send CR & LF 
        JSR   PUTS
              
        LDAA  FLAGS_A
        ORAA  #$01
        STAA  FLAGS_A     ;Set ECHO ON
        RTS

;;************************************************************************
;; PORTOUT  
;;************************************************************************
PORTOUT ;subroutine
        LDX   #MSGPRT
        JSR   PUTS      ;Enter Port#
        JSR   INCHRE
        STAA  TEMP_03
        LDX   #MSGVAL
        JSR   PUTS      ;Enter Value:
        JSR   INHEXB
        STAA  TEMP_04   ;Save Value
        LDAA  TEMP_03   ;Get Port#
        CMPA  #'2
        BNE   OUTP5
        LDAA  #$FF
        STAA  $01      ;Port2 DDR
        LDAA  TEMP_04 
        STAA  $03
OUTP5   CMPA  #'5
        BNE   OUTP6
        LDAA  #$FF
        STAA  $20      ;Port5 DDR
        LDAA  TEMP_04 
        STAA  $15
OUTP6   CMPA  #'6
        BNE   OUTPX
        LDAA  #$FF
        STAA  $16      ;Port6 DDR
        LDAA  TEMP_04 
        STAA  $17
OUTPX   RTS
;;************************************************************************
;; PORTOUT  
;;************************************************************************
PORTIN  ;subroutine
        LDX   #MSGPRT
        JSR   PUTS      ;Enter Port#
        JSR   INCHRE
        TAB
        LDAA  #$20
        JSR   OUTCHR
        CMPB  #'2
        BNE   INP5
        LDAA  #$00
        STAA  $01      ;Port2 DDR
        LDAA  $03 
        JSR   OUTHEX
INP5    CMPB  #'5
        BNE   INP6
        LDAA  #$00
        STAA  $20      ;Port5 DDR
        LDAA  $15
        JSR   OUTHEX
INP6    CMPB  #'6
        BNE   INPX                            
        LDAA  #$00
        STAA  $16      ;Port6 DDR
        LDAA  $17
        JSR   OUTHEX
        LDAA  #$FF
        STAA  $16      ;Restore Port6 DDR
INPX    RTS

;;******************************************************************
;; Debugging ;subroutines
;;******************************************************************
DODUMP  JSR   DMPREG    ;DEBUG!! Dump registers        DEBUG!!
        JMP   PRTREGS   ;DEBUG!! Print saved registers DEBUG!! 
;;******************************************************************        
;;******************************************************************
;;DMPREG  Save current state of registers in RAM 
;;******************************************************************
DMPREG  Subroutine
        STAA   DREG_A    ;A Register
        STAB   DREG_B    ;B Register
        STX    DREG_XH   ;X Register
        STS    DREG_SPH  ;Stack Pointer
        PULX
        STX    DREG_PCH  ;Program Counter (from stack)
        PSHX
        LDX    DREG_XH   ;Restore X
        TPA              ;FLAGS->A 
        STAA   DREG_F    ;Flags
        LDAA   DREG_A    ;Restore A
        RTS
        
;;******************************************************************
;; PRTREGS  Send saved register values to terminal
;;******************************************************************
PRTREGS Subroutine
        LDX   #MSGNL
        JSR   PUTS      ;Newline
        LDAA  #$20
        JSR   OUTCHR
        LDAA  #'A
        JSR   OUTCHR
        LDAA  #':
        JSR   OUTCHR
        LDAA  DREG_A   ;Get Saved A
        JSR   OUTHEX
        LDAA  #$20
        JSR   OUTCHR
        LDAA  #'B
        JSR   OUTCHR
        LDAA  #':
        JSR   OUTCHR
        LDAA  DREG_B   ;Get Saved B
        JSR   OUTHEX
        LDAA  #$20
        JSR   OUTCHR
        LDAA  #'X
        JSR   OUTCHR
        LDAA  #':
        JSR   OUTCHR
        LDAA  DREG_XH   ;Get Saved X
        JSR   OUTHEX
        LDAA  DREG_XL   ;Get Saved X
        JSR   OUTHEX
        LDAA  #$20
        JSR   OUTCHR
        LDAA  #'S
        JSR   OUTCHR
        LDAA  #':
        JSR   OUTCHR
        LDAA  DREG_SPH   ;Get Saved Stack Pointer
        JSR   OUTHEX
        LDAA  DREG_SPL   ;Get Saved Stack Pointer
        JSR   OUTHEX
        LDAA  #$20
        JSR   OUTCHR
        LDAA  #'P
        JSR   OUTCHR
        LDAA  #':
        JSR   OUTCHR
        LDAA  DREG_PCH   ;Get Saved Program Counter
        JSR   OUTHEX
        LDAA  DREG_PCL   ;Get Saved Program Counter
        JSR   OUTHEX
        LDAA  #$20
        JSR   OUTCHR
        LDAA  #'F
        JSR   OUTCHR
        LDAA  #':
        JSR   OUTCHR
        LDAA  DREG_F   ;Get Saved Flags
        JSR   OUTHEX
        LDX   #MSGNL
        JSR   PUTS      ;Newline
        RTS
        
;;******************************************************************
;; FILLMEM  Fill Memory routine (F fill)
;;******************************************************************
FILLMEM ;subroutine        
        LDX   #MSGSTART   ;Enter Start Address:
        JSR   PUTS
        JSR   INHEXB
        BCS   FILLEX
        STAA  ADDR_HI
        JSR   INHEXB
        BCS   FILLEX
        STAA  ADDR_LO
        
        LDX   #MSGENDAD   ;Enter End Address:
        JSR   PUTS
        JSR   INHEXB
        BCS   FILLEX
        STAA  DISADD1
        JSR   INHEXB
        BCS   FILLEX 
        STAA  DISADD1+1
          
        LDX   #MSGVAL     ;Value:
        JSR   PUTS
        JSR   INHEXB
                          ;Start of fill process
        LDX   ADDR_HI    ;Get address
FILL01  STAA  0,X        ;Store the Value
        CPX   DISADD1    ;Match on End Adress?
        BEQ   FILLEX     ;Exit
        INX
        JMP   FILL01
FILLEX  RTS
        
        
;;******************************************************************
;; LISTMEM  Disassemble code routine (L List)
;;******************************************************************
LISTMEM ;subroutine        
        LDX   #MSGSTART   ;Enter Start Address:
        JSR   PUTS
        JSR   INHEXB
        STAA  ADDR_HI
        JSR   INHEXB
        STAA  ADDR_LO
        
        LDAA  #$FF
        STAA  LINECT   ;Default line count to indicate use end address         
        
        LDX   #MSGENDAD   ;Enter End Address:
        JSR   PUTS
        JSR   INHEXB
        STAA  DISADD1
        BCC   LIST01      ;If Enter NOT pressed skip ahead else set LINECT=16 
        LDAA  #16
        STAA  LINECT
        JMP   LIST02
LIST01  JSR   INHEXB
        STAA  DISADD1+1
        BCC   LIST02      ;If Enter NOT pressed skip ahead else set LINECT=16  
        LDAA  #16
        STAA  LINECT
                          ;Start of disassembly
LIST02  LDX   ADDR_HI     ;Get address of opcode
        LDAA   0,X        ;Get the opcode and save it in OPCD
        STAA  OPCD
        LDX   #MSGNL
        JSR   PUTS        ;Print a Newline
        
        JSR   OPCTYPE     ;determine opcode type and parmcount
        LDAA  OPCD
        ANDA  #$C0
        CMPA  #$00
        BNE   LIST03
        JSR   SRCHMNL     ;Search Mnemonic Table LO for opcode in A
        JMP   LIST04  
LIST03  JSR   SRCHMNH     ;Search Mnemonic Table HI for opcode in A
        CMPA  #$00
        BNE   LIST05      ;Continue only if opcode found in table 
        LDX   #MNETBLM    ;Get Table Start Address of table M   
        JSR   SRCHMH1     ;Search Mnemonic Table 'M' for opcode in A
LIST04  CMPA  #$00
        BNE   LIST05      ;Continue only if opcode found in table 
        LDAA  #'?         ;If not found report error
        JSR   OUTCHR
        JSR   OUTCHR
        JMP   LISTEX           
        
LIST05  LDAA  #$20        ;Print a space
        JSR   OUTCHR   
        
        JSR   CLRDABUF  ;Clear the disassembly buffer & reset pointer
        JSR   PUTMNEM   ;Transfer the mnemonic for the opcode found to the disassembly buffer
      
        LDAA  ADDR_HI     ;Print Address
        JSR   OUTHEX  
        LDAA  ADDR_LO
        JSR   OUTHEX  
        LDAA  #$20        ;Print 1 space
        JSR   OUTCHR
             
        LDAA  OPCD
        JSR   OUTHEX      ;print Opcode
        LDAA  #$20        ;Print 1 space
        JSR   OUTCHR
             
        LDAA  OPCFLAGS    ;Get OPCFLAGA
        ANDA  #$03        ;Mask for parm count (0, 1 or 2)
        CMPA  #$00        ;If zero parms just print spaces
        BEQ   LIST07 
        LDX   ADDR_HI     ;GET opcode address in X
        CMPA  #$01        ;Check parm count .. if 1 only print 1 parm     
        BEQ   LIST06
        INX               ;point X at parm
        LDAA  0,X
        JSR   OUTHEX      ;print parm#
        LDAA  #$20        ;Print 1 space
        JSR   OUTCHR     
LIST06  INX               ;point X at parm
        LDAA  0,X
        JSR   OUTHEX      ;print parm
        LDAA  #$20        ;Print 1 space
        JSR   OUTCHR     
                 ;print the appropriate number of spaces based on parm count
LIST07  LDAB  OPCFLAGS    ;Get OPCFLAGA
        ANDB  #$03        ;Mask for parm count (0, 1 or 2)
        LDAA  #$04
        SBA               ;3 - parmcount -> A
        TAB               ;A->B
LIST08  LDAA  #$20        ;Print 3 spaces
        JSR   OUTCHR
        JSR   OUTCHR
        JSR   OUTCHR        
        DECB
        CMPB  #$00        ;If not done print 3 more spaces 
        BNE   LIST08 
                  
        LDX   #DISABUF
        JSR   PUTS        ;Print the Mnemonic buffer

        LDX   ADDR_HI     ;GET opcode address
        LDAA  OPCFLAGS    ;Get OPCFLAGA
        ANDA  #$03        ;Mask for parm count (0, 1 or 2)
        CMPA  #$00        ;If zero parms just update X and exit
        BEQ   LIST10
        CMPA  #$01        ;Check parm count .. if 1 only print 1 parm     
        BEQ   LIST09 
        INX               ;point X at parm
        LDAA  0,X
        JSR   OUTHEX     
LIST09  INX               ;point X at parm
        LDAA  0,X
        JSR   OUTHEX      ;print parm
        
LIST10  INX               ;point X at next opcode 
        STX   ADDR_HI     ;Save new address
        LDAA  OPCFLAGS    ;Get OPCFLAGA
        ANDA  #$30        ;Mask for type (0, 1 or 2)
        CMPA  #$30      
        BNE   LISTNXT     ;If Not type 3 just continue otherwise add ",X" to output
        LDAA  #',
        JSR   OUTCHR
        LDAA  #'X
        JSR   OUTCHR

LISTNXT LDAA  LINECT
        CMPA  #$FF        ;Using END Address?
        BEQ   LSTCKEA 
        DECA
        STAA  LINECT
        CMPA  #00
        BEQ   LISTEX
        JMP   LIST02 
         
LSTCKEA LDX   DISADD1     ;Get the end address ->X
        CPX   ADDR_HI     ;Subtract current address (next opcode to process)
        BMI   LISTEX      ;If done exit otherwise ...
        JMP   LIST02      ;   process the next opcode                            
LISTEX  RTS

;******************************************************************
;CLRDABUF
;******************************************************************
CLRDABUF ;subroutine
        LDX   #$0060
        LDAA  #$20
CLRDAB1 STAA  0,X
        INX
        CPX   #$6F
        BNE   CLRDAB1
        LDAA  #$FF
        STAA  0,X
        LDX   #$0060
        STAA  DISABUFP
        RTS 

;******************************************************************
; PUTMNEM
; transfer the mnemonic for the opcode found to the disassembly buffer
; populate the parameter format that will be used
;******************************************************************
PUTMNEM  ;subroutine
        LDX   #DISABUF
        STX   DISABUFP 
PUTMNE1 LDX   ROWADDH
        LDAA  0,X
        INX
        STX   ROWADDH
        LDX   DISABUFP
        STAA  0,X
        INX 
        STX   DISABUFP
        CPX   #$64
        BNE   PUTMNE1
        
        LDAA  OPCFLAGS   ;Add 'A' or 'B' if indicated by flags
        ANDA  #$0C
        CMPA  #$04
        BNE   PUTMNE2
        LDAA  #'A
        STAA  DISABUF+3
        JMP   PUTMNE3
PUTMNE2 CMPA  #$08
        BNE   PUTMNE3
        LDAA  #'B
        STAA  DISABUF+3
PUTMNE3 LDAA  OPCFLAGS
        ANDA  #$30
        CMPA  #$00
        BNE   PUTMNE4
        LDAA  #$FF
        STAA  DISABUF+6
        RTS         
PUTMNE4 CMPA  #$10
        BNE   PUTMNE5
        LDAA  #'#
        STAA  DISABUF+6         
        LDAA  #'$
        STAA  DISABUF+7
        LDAA  #$FF
        STAA  DISABUF+8
        RTS
PUTMNE5 LDAA  #'$
        STAA  DISABUF+6
        LDAA  #$FF        
        STAA  DISABUF+7
        RTS

;******************************************************************
;OPCTYPE  Set OPCFLAGS indicating type, action and parm count 
;         RETURN with OPCFLAGS in A
;******************************************************************
OPCTYPE   ;subroutine 
        LDX   #OPCDTYPE ;Get address of OPCDTYPE lookup table in X
        LDAB  OPCD      ;Get opcode
        LSRB            ;Shift hi bits to low 4 bits 
        LSRB
        LSRB
        LSRB                        
        ANDB  #$0F      ;mask high 4 bits
        ABX             ;add to X
        LDAA  0,X       ;Get the flags from the table
        STAA  OPCFLAGS  ;Store in OPCFLAGS
        ANDA  #$03      ;Mask parm count bits
        CMPA  #$00      ; If Zero no parms
        BEQ   OPCTYPX   ; so just exit  .. otherwise...          
OPCEXCP LDX   #OPCDEXCP ; Check exception table 
        LDAB  OPCD
OPCEXP1 LDAA  0,X        
        CMPA  #00
        BEQ   OPCTYPX
        INX 
        CBA
        BNE   OPCEXP1
        INC   OPCFLAGS  ;If found add 1 to parm count
        
OPCTYPX RTS
  
;******************************************************************
;SRCHMNH    Search Mnemonic Table 'H' 
;******************************************************************
SRCHMNH  ;subroutine
        LDX   #MNETBLH   ;Get Table Start Address
SRCHMH1 STX   ROWADDH    ;Save in ROWADDH & L
        INX              ;Skip past Mnemonic bytes
        INX
        INX
        INX
        LDAB  #$04      ;byte count = 4 (4 bytes per mnemonic row)
SRCHMH2 LDAA  0,X       ;Get opcode from table
        CMPA  OPCD      ;compare to save opcode
        BEQ   SRCHMHX   ;Match found then exit
                        ; else
        INX             ;point next opcode 
        DECB            ;dec byte count
        CMPB  #00       ;done with this mnemonic/row
        BNE   SRCHMH2   ;not yet .. then test this opcode 
        LDAA  0,X       ;get 1st byte from next row
        CMPA  #00       ;zero indicates end of table reached - search failed
        BNE   SRCHMH1   ; not zero then keep looking
SRCHMHX RTS   ; otherwise return with A=0

;******************************************************************
;SRCHMNL    Search Mnemonic Table 'L'
;******************************************************************
SRCHMNL  ;subroutine
        LDX   #MNETBLL   ;Get Table Start Address
SRCHML1 STX   ROWADDH    ;Save in ROWADDH & L
        INX              ;Skip past Mnemonic bytes
        INX
        INX
        INX
SRCHML2 LDAA  0,X       ;Get opcode from table
        CMPA  OPCD      ;compare to save opcode
        BEQ   SRCHMLX   ;Match found then exit
                        ; else
        INX             ;point start of next row 
        LDAA  0,X       ;get 1st byte from next row
        CMPA  #00       ;zero indicates end of table reached - search failed
        BNE   SRCHML1   ; not zero then keep looking
SRCHMLX RTS   ; otherwise return with A=0

;;************************************************************************
;;  Assemble Function ASM2MEM
;;************************************************************************
;;******************************************************************
;; ASM2MEM  Assemble to Memory function
;;    Call with start address in ADDR_HI & ADDR_LO
;;******************************************************************        
ASM2MEM ;subroutine        
        LDAA  #$00        ;Reset line count
        STAA  LINECT
        
        LDX   #MSGNL
        JSR   PUTS      ;Newline
        
        LDAA  ADDR_HI   ;Print Address
        JSR   OUTHEX
        LDAA  ADDR_LO
        JSR   OUTHEX
        LDAA  #$20      ;Print a space
        JSR   OUTCHR
        
        JSR   CLRDABUF  ; Clear input buffer
        JSR   GETSTR    ; Input 1 line of text
        STX   DISABUFP  ; save buffer exit position 
        CPX   #DISABUF+3
        BCC   ASM201      
ASM2X1  RTS             ; Less than 3 bytes entered = DONE just exit
        
ASM201  JSR   DESPACE   ; Remove spaces from input
        JSR   MOVPRM    ; Move parm bytes to PARMBUF & set PARMLEN
        JSR   SETTYPE   ; Set type flags
        CMPA  #$FF      ;Check for error
        BNE   ASM202
        JMP   ASM2ERX
        
ASM202  LDX   #MNETBLL  ;Address of MNETBLL->X
        LDAB  #$05      ; Table Row length ->B
        JSR   ASMSH4    ;Search Table L
        CMPA  #$00
        BNE   ASM2PR    ;if found search continue to process...
        
ASM2SH  LDAA  #$00        ;Reset line count
        STAA  LINECT
        LDX   #MNETBLH  ;Address of MNETBLH->X
        LDAB  #$08
        JSR   ASMSH4    ;Search Table H
        CMPA  #$00
        BEQ   ASM2SM    ; if not found search table M
        LDAB  OPCFLAGS  ; Get Type 0,1,2,4 or 8
        CMPB  #$02
        BNE   ASM2SH1
        LDAA  5,X       ;if type=2 use opcode col#1
        JMP   ASM2PR
ASM2SH1 CMPB  #$04        
        BNE   ASM2SH2
        LDAA  6,X       ;if type=4 use opcode col#2
        JMP   ASM2PR
ASM2SH2 CMPB  #$08        
        BNE   ASM2PR
        LDAA  7,X       ;if type=8 use opcode col#3
        JMP   ASM2PR    ; else using opcd col#0 (already saved)
        
ASM2SM  LDAA  #$00        ;Reset line count
        STAA  LINECT
        LDX   #MNETBLM  ;Address of MNETBLM->X 
        LDAB  #$08
        JSR   ASMSH3    ;Search Table M (compare 1st 3 bytes only)
        CMPA  #$00
        BEQ   ASM2ERX   ;if not found --> ERROR exit 
        LDAB  $63       ;Check 4th mnemonic byte
        CMPB  #'A
        BNE   ASM2SM1
        LDAA  6,X       ;if='A' use opcode col#2
        JMP   ASM2PR
ASM2SM1 CMPB  #'B
        BNE   ASM2SM2
        LDAA  7,X       ;if='B' use opcode col#3
        JMP   ASM2PR        
ASM2SM2 LDAB  OPCFLAGS  ;4th byte must be blank so ..Get Type 0,1,2,4 or 8
        CMPB  #$04
        BNE   ASM2SM3
        LDAA  4,X       ;if type=4 use opcode col#0
        JMP   ASM2PR    ;  else
ASM2SM3 LDAA  5,X       ; use opcode col#1
        JMP   ASM2PR        

ASM2PR  STAA  OPCD
        LDX   ADDR_HI  ;Store opcode..
        LDAA  OPCD
        STAA  0,X        
        STX   DISADD2
         
        LDAA  #$20      ;Print a space
ASMPAD  JSR   OUTCHR
        INC   DISABUFP+1   ;Pad with spaces depending on input line length
        LDAB  DISABUFP+1
        CMPB  #DISABUF+15        
        BCS   ASMPAD   
        
        LDAA  OPCD                
        JSR   OUTHEX   ;Print OPCODE and 1 space
        LDAA  #$20     ;Print a space
        JSR   OUTCHR
        JSR   CVTPRMS
        JSR   OUTPRMS
        STX   ADDR_HI
        JMP   ASM2MEM   ; process another line of input

ASM2ERX LDX   #MSGERR   ;print ERROR message
        JSR   PUTS
ASM2END RTS

;******************************************************************
; OUTPRMS  Output values in PARMBUF move parm data to target memory 
;  Call with X=target address 
;  returns with X updated to next target address
;******************************************************************
OUTPRMS ;subroutine
        INX             ;Skip past opcode location
        LDAA  PARMLEN   ;Get Parm buffer pointer
        CMPA  #$70      ; $70 = NO PARMS
        BNE   OUTPRM1
        RTS             ; exit if no parms
OUTPRM1 LDAA  PARMBUF   ; get 1st parm byte
        STAA  0,X       ; save to target address
        INX             ; point to next address
        JSR   OUTHEX    ; print parm byte
        LDAA  #$20      ;Print a space
        JSR   OUTCHR
        LDAA  PARMLEN   ;Get Parm buffer pointer
        CMPA  #$74      ; $74= 2 bytes of parm data
        BEQ   OUTPRM2   ; If = $74 continue
        RTS             ; else exit
OUTPRM2 LDAA  PARMBUF+1 ; get 2nd parm byte, save, print & exit 
        STAA  0,X
        INX
        JSR   OUTHEX
        RTS

;******************************************************************
; CVTPRMS   convert ASCII in PARMBUF to value(s) in PARMBUF 
;******************************************************************
CVTPRMS ;subroutine
        LDAB  PARMLEN    ;Get parm buffer pointer
        CMPB  #$70       ;$70 = NO PARMS
        BNE   CVTPRM1    ;If we do have parm data continue..
        RTS              ;else exit
CVTPRM1 LDAA  PARMBUF    ;Get 1st parm character
        JSR   CHR2VAL    ;convert to it's HEX value
        ASLA             ;Shift LEFT 4x
        ASLA
        ASLA
        ASLA
        ANDA  #$F0       ;Mask low 4bits
        STAA  PARMBUF    ;Save it
        LDAA  PARMBUF+1  ;Get 2nd parm character
        JSR   CHR2VAL    ;Convert to HEX value
        ADDA  PARMBUF    ;combine with 1st byte data
        STAA  PARMBUF    ;Save it 
        CMPB  #$74       ; PARMLEN = $74 = 2 parm bytes
        BEQ   CVTPRM2
        RTS              ;if only 1 byte entered just exit
CVTPRM2 LDAA  PARMBUF+2  ;Get 3rd parm character      
        JSR   CHR2VAL    ;convert to it's HEX value   
        ASLA             ;Shift LEFT 4x               
        ASLA                                          
        ASLA                                          
        ASLA                                          
        ANDA  #$F0       ;Mask low 4bits              
        STAA  PARMBUF+1  ;Save it                     
        LDAA  PARMBUF+3  ;Get 4th parm character      
        JSR   CHR2VAL    ;Convert to HEX value        
        ADDA  PARMBUF+1  ;combine with 3rd byte data  
        STAA  PARMBUF+1  ;Save it                     
        RTS

;******************************************************************
; SETTYP Set the type flags in OPCFLAGS
;      type4 may already  have already been set if indexed ('X')
;      was detected in DESPACE. 
;      Type 0 = IMPLIED, 1=IMMEDIATE, 2=DIRECT, 4=INDEXED, 8=EXTENDED
;******************************************************************        
SETTYPE ;subroutine
        LDAA  PARMLEN   ;Get Parmlen  
        CMPA  #$70      ;$70 = zero length NO PARMs
        BNE   SETTYP4   
        LDAA  #$00      ;set type=0
        JMP   SETTYPN   ;Save type & exit
SETTYP4 LDAA  OPCFLAGS
        CMPA  #$04       ;Indexed flag set? (set in DESPACE)
        BNE   SETTYP1
        RTS
SETTYP1 LDAA  DISABUF+4  
        CMPA  #'#        ;'#' indicates immediate instruction  
        BNE   SETTYP2
        LDAA  DISABUF+5  ;Next byte MUST be '$' else ERROR     
        CMPA  #'$
        BNE   SETTYPX
        LDAA  #$01       ;set type=1
        JMP   SETTYPA        
SETTYP2 LDAA  DISABUF+4        
        CMPA  #'$        ;If 1st byte afer mnemonic is not '#' it MUST be '$'
        BNE   SETTYPX    ;   else ERROR
        LDAA  #$02
        STAA  OPCFLAGS   ;Could be type 2 or 8... start with type 2 
        LDAA  PARMLEN
        CMPA  #PARMBUF+4  ;if 4 parm bytes the set type 8
        BNE   SETTYPN     ; else leave it at 2
        LDAA  #$08
SETTYPA STAA  OPCFLAGS    ;save result
        RTS
        
SETTYPN LDAA  OPCFLAGS    ;always return with flags in A
        RTS
        
SETTYPX LDAA  #$FF        ;Syntax ERROR return code = $FF
        STAA  OPCFLAGS
        RTS         
        
;******************************************************************
; ASMSH4   Compare the first 4 bytes of mnemonic with table value
; call with X loaded with start of table and b=table row len (8 or 5)
; updates LINECT with table row# and OPCD with return value
; returns with next table byte set or A=0 if not found
;******************************************************************
ASMSH4  ;subroutine
        JSR   ASMSH3
        CMPA  #$00
        BEQ   ASMSH4X
        LDAA  DISABUF+3
        CMPA  3,X
        BNE   ASMSH4N
        LDAA  4,X
ASMSH4X STAA  OPCD
        RTS
ASMSH4N ABX       
        LDAA  0,X
        CMPA  #00
        BEQ   ASMSH4X
        INC   LINECT
        JMP   ASMSH4

;******************************************************************
; ASMSH3   Compare the first 3 bytes of mnemonic with table value
; call with X loaded with start of table and b=table row len (8 or 5)
; updates LINECT with table row# and OPCD with return value
; returns with next table byte set or A=0 if not found 
;******************************************************************
ASMSH3  ;subroutine
        JSR   ASMCMP3  ;compare 3 byte of mnemonic data
        BNE   ASMSH3N  ;match failed try next row
        LDAA  3,X      ;match found
ASMSH3X STAA  OPCD     ;save last matched byte in OPCD and exit A!=0 
        RTS             
ASMSH3N ABX            ;Point X at start of next table row
        LDAA  0,X      ;Check 1st byte of mnemonic
        CMPA  #00      ;if this is a zero - end of table - search failed
        BEQ   ASMSH3X  ;exit with A=0  OPCD=0  
        INC   LINECT   ; else add 1 to line counter
        JMP   ASMSH3   ;continue search

;******************************************************************
; ASMCMP3   Compare the first 3 bytes of mnemonic with table value
;          call with X loaded with start of bytes to compare
;          returns Z flag set if all 3 match or cleared if not 
;******************************************************************
ASMCMP3 ;subroutine
        LDAA  DISABUF
        CMPA  0,X
        BNE   ASMCP3X
        LDAA  DISABUF+1
        CMPA  1,X
        BNE   ASMCP3X
        LDAA  DISABUF+2
        CMPA  2,X
ASMCP3X RTS

;******************************************************************
; MOVPRM   Move parameter bytes from input buffer to PARMBUF
;          set PARMLEN to offset of last byte+1
;******************************************************************
MOVPRM  ;subroutine
        LDAA  #PARMBUF        
        STAA  PARMLEN    ;Reset parm length pointer
        LDX   #DISABUF+3  ;Set X = start of data-1
MOVPRM1 INX               ;Next byte
        LDAA   0,X        ;Get Byte
        CMPA  #$2F        ;Is it < '0'
        BLS   MOVPRM1     ;Keep looking
        CMPA  #'G        ;Is it >'F'
        BCC   MOVPRMX     ; Done 
        PSHX              ;Save X
        LDAB  PARMLEN     ;Get parm buf pointer
        CMPB  #PARMBUF+4  ;Parm Buffer Full?
        BEQ   MOVPRM2
        LDX   #$0000
        ABX               ;parm buf pointer -> X
        STAA  0,X         ;Save parm byte in parm buf
        INC   PARMLEN     ;inc parmlen
        LDAA  #$FF        ;Terminate parm buffer
        STAA  1,X 
MOVPRM2 PULX              ;restore x
        CPX   #DISABUF+16  ;end of buffer reached?
        BNE   MOVPRM1     ; keep going ... otherwise return
MOVPRMX RTS        

;******************************************************************
; DESPACE  Remove spaces from buffer  detect 'X' in buffer
;******************************************************************
DESPACE ;subroutine
        LDAA  #00
        STAA  OPCFLAGS      ;CLEAR ALL FLAGS 
        LDX   #DISABUF+4       
DSPACE1 LDAA   0,X          ;Get A Byte
        CMPA  #'X           ;If we encounter an 'X' set bit 2 of OPCFLAGS
        BNE   DSPACE2
        LDAA  #$04          ;Set type=4(indexed) if we encounter 'X'
        STAA  OPCFLAGS 
DSPACE2 CMPA  #$20          ;Is the byte a space?
        BNE   DSPACE3       ;NO= Process next byte
        JSR   SHIFTBL       ;YES=Shift everything left 1 position
        JMP   DSPACE1       ;Continue...
DSPACE3 INX                 
        CPX   #DISABUF+15   ;Processed entire buffer?
        BNE   DSPACE1       ;No = Continue
        LDAA  DISABUF+3
        CMPA  #$FF
        BNE   DESPACX
        LDAA  #$20
        STAA  DISABUF+3  
DESPACX RTS

;******************************************************************
; SHIFTBL  Shift DISABUF left 1 position
;******************************************************************
SHIFTBL ;subroutine
        PSHX
SHFTBL1 LDAA  1,X
        STAA  0,X
        INX
        CPX   #DISABUF+15
        BNE   SHFTBL1
        PULX
        RTS
        
;******************************************************************
; GETSTR  Input up to 16bytes and store in DISABUF
;******************************************************************
GETSTR  ;subroutine     
        LDX   #DISABUF
GETSTR1 JSR   INCHR       ;Get a byte
        CMPA  #$0D        ;Is It CR?  
        BEQ   GETSTRX     ; if so then exit
        CMPA  #$7F        ; Backspace?
        BNE   GETSTR2
        CPX   #DISABUF
        BEQ   GETSTR1
        DEX
        JSR   OUTCHR
        JMP   GETSTR1
GETSTR2 CMPA  #'Z         ;  <=Z?
        BMI   GETSTR3     ; dont convert
        ANDA  #$5F        ;Convert to UPPERCASE
GETSTR3 JSR   OUTCHR      ;echo it
        STAA  0,X         ; Save the byte
        INX               ;Inc buffer pointer
        CPX   #DISABUF+16  ;Buffer Full?
        BNE   GETSTR1     ; If not then get another byte else exit
GETSTRX LDAA  #$FF        ; Terminate buffer with $FF
        STAA  0,X
        RTS
        
;******************************************************************
;10MSTMR       Enable 10ms system counter
;REG_TCSSR3  equ $1B     ;TIMER CONTROL AND STATUS REG#3.
;REG_TCONR   equ $1C     ;TIMER2 CONSTANT REG.
;REG_T2CNT   equ $1D     ;TIMER2 COUNTER REG.
;******************************************************************
MS10TMR LDAA  REG_TCSSR3
        ANDA  #$50
        CMPA  #$00
        BNE   TMROFF
        LDX  #MS10IRQ
        STX  IRQCMI+1    ;Set IRQ Vector
        LDAA  #$60       ;Set Match Register = $60 (10ms)
        STAA  REG_TCONR
        LDAA #$72        ;Set TSCR3  ECMI=1, T2E=1 CKS1=1 CKS0=0 (E/128)
        STAA  REG_TCSSR3
        LDAA  #$00
        STAA  MSTMRXL
        STAA  MSTMRXM
        STAA  MSTMRXH
        CLI              ; Clear IRQ mask bit
        LDX  #MSGON
        JSR  PUTS
        RTS
        
TMROFF  LDAA  #$00       ;Reset Match Register
        STAA  REG_TCONR
        LDAA #$20        ;Set TSCR3  ECMI=0, T2E=0 CKS1=0 CKS0=0 (E/128)
        STAA  REG_TCSSR3
        SEI
        LDX  #MSGOFF
        JSR  PUTS
        RTS
        
;******************************************************************
; MS10IRQ  Timer2 Interrupt Service Routine for 10ms counter function
;******************************************************************
MS10IRQ SEI              ;Disable interrupts
        LDAA #$72        ;Set TSCR3  ECMI=1, T2E=1 CKS1=1 CKS0=0 (E/128)
        STAA REG_TCSSR3  ;(Clears CMF flag)
        
        INC   MSTMRXL    ;INC Low counter
        BNE   MS10IRX     
        INC   MSTMRXM    ;INC Mid counter
        BNE   MS10IRX     
        INC   MSTMRXH    ;INC Hi counter
        BNE   MS10IRX     
               
MS10IRX CLI
        RTI
        
;;************************************************************************
;;  Default IRQ Routine 
;;************************************************************************        
IRQDEFT STAA  IRQFLAG1
        STX   $FFFF
        STX   $FFFF
        STX   $FFFF
        RTI 
;;************************************************************************
;;  Trap IRQ Routine 
;;************************************************************************        
TRAP01  ;subroutine           
        LDAA	#$55
        STAA	$17   ;P6 PORT
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        JMP   TRAP01
MONEND   equ   .

;;************************************************************************
;;************************************************************************
        org $8B00      ;BASIC COLD START         v2.1b
; NAM MICRO  MICROBASIC
;* ***** VERSION 1.3A *****
;* BY ROBERT H UITERWYK, TAMPA, FLORIDA
;*
;* MODIFIED TO RUN ON THE MC3
;* BY DANIEL TUFVESSON (DTU) 2013
;*
;* ADDITIONAL BUGFIXES
;* BY LES HILDENBRANDT (LHI) 2013
;*
;*  EMK ROM Version 2.1   
;*  12/22/15 * Split code from data memory 
;*  12/23/15 * Added a few comments, moved MAXLIN,BACKSP,CANCEL to constants
;*  11/23/16 * Added SYS(),PEEK() & POKE() commands to BASIC
;
;;************************************************************************
;;************************************************************************
COLDST  LDX  #INDEX1
        CLRA
CLRVMEM STAA 0,X
        INX
        CPX  #ASTACK
        BNE  CLRVMEM
        
INITVM  LDX  #BASICTOP     ;Init the menory variables(USE #ENDBASIC for RAM version)
        STX  NEXTBA          
        STX  WORKBA          
        STX  SOURCE        
        LDX  #$707F 
        STX  XSTACK        
        LDX  #$6FFF
        STX  MEMEND        
        LDX  #ASTACK
    	  STX  AESTK         
        LDX  #FORSTK
     	  STX  FORPNT        
        LDX  #VARTAB
     	  STX  VARPNT        
        LDX  #SBRSTK
     	  STX  SBRPNT                
        LDX  #VARTAB
        STX  DIMVAR        
        LDX  #$00B0 
        STX  BUFNXT         
        STX  ENDBUF        
        
PROGM   JMP  START		;	Start Basic
COMMAN  dc.b "RUN"
        dc.b $1E
        dc.w RUN
        dc.b "LIST"
        dc.b $1E
        dc.w CLIST 
        dc.b "NEW"
        dc.b $1E
        dc.w START
        dc.b "PAT"
        dc.b $1E
        dc.w PATCH
        dc.b "SYS"
        dc.b $1E
        dc.w SYSCALL
        dc.b "PEEK"
        dc.b $1E
        dc.w DOPEEK        
        dc.b "POKE"
        dc.b $1E
        dc.w DOPOKE        
GOLIST  dc.b "GOSUB"
        dc.b $1E
        dc.w GOSUB
        dc.b "GOTO"
        dc.b $1E
        dc.w GOTO
        dc.b "GO TO"
        dc.b $1E
        dc.w GOTO
        dc.b "SIZE"
        dc.b $1E
        dc.w SIZE
        dc.b "THEN"
        dc.b $1E
        dc.w IF2
        dc.b "PRINT"
        dc.b $1E
        dc.w PRINT
        dc.b "LET"
        dc.b $1E
IMPLET  dc.w LET
        dc.b "INPUT"
        dc.b $1E
        dc.w INPUT
        dc.b "IF"
        dc.b $1E
        dc.w IF
        dc.b "END"
        dc.b $1E
        dc.w READY
        dc.b "RETURN"
        dc.b $1E
        dc.w RETURN
        dc.b "DIM"
        dc.b $1E
        dc.w DIM
        dc.b "FOR"
        dc.b $1E
        dc.w FOR
        dc.b "NEXT"
        dc.b $1E
        dc.w NEXT
        dc.b "REM"
        dc.b $1E
        dc.w REMARK
PAUMSG  dc.b "PAUSE"
        dc.b $1E
        dc.w PAUSE
        dc.b $20
COMEND  dc.b $1E
        dc.w LET
        
RDYMSG  dc.b $0D
        dc.b $0A
        dc.b "READY"
        dc.b $1E
PROMPT  dc.b $23
        dc.b $1E
        dc.b $1E
PGCNTL  dc.b $10
        dc.b $16
        dc.b $1E
        dc.b $1E
        dc.b $1E
ERRMS1  dc.b "ERROR# "
        dc.b $1E
ERRMS2  dc.b " IN LINE "
        dc.b $1E

KEYBD   LDAA #$3F
        BSR OUTCH
KEYBD0  LDX #BUFFER
        LDAB #10
KEYBD1  BSR INCH
        CMPA #$00
        BNE KEYB11
        DECB
        BNE KEYBD1	;BNE KEYBD11			#### /LHI
KEYB10  JMP READY
KEYB11  CMPA #CANCEL
        BEQ DEL
        CMPA #$0D
        BEQ IEXIT
KEYBD2  CMPA #$0A
        BEQ KEYBD1
        CMPA #$15
        BEQ KEYBD1
        CMPA #$13
        BEQ KEYBD1
KEYB55  CMPA #BACKSP
        BNE KEYBD3
        CPX #BUFFER
        BEQ KEYBD1
        DEX
        BRA KEYBD1
KEYBD3  CPX #BUFFER+71
        BEQ KEYBD1
        STAA 0,X
        INX
        BRA KEYBD1
DEL     BSR CRLF
CNTLIN  LDX #PROMPT
        BSR OUTNCR
        BRA KEYBD0
IEXIT   LDAA #$1E
        STAA ,X
        STX ENDBUF
        BSR CRLF
        RTS

OUTCH   JSR CHKBRK	              ;BSR BREAK			#### /DTU
ECHO    JMP OUTCHR                ; JMP OUTEEE    /EMK

INCH    JSR  INCHR               ;JMP INEEE   /EMK
        CMPA #CANCEL
        BNE  ECHO
        RTS
        
;BREAK2  PULA
;        RTS
                                 
OUTPUT  BSR OUTNCR       ;Send chars based on X, to terminal until $1E is encountered
        BRA CRLF

OUTPU2  BSR  OUTCH
OUTPU3  INX
OUTNCR  LDAA 0,X
        CMPA #$1E
        BNE OUTPU2
        RTS

CRLF    BSR PUSHX       ;Send CR & LF (X is retained)
        LDX #CRLFST
        BSR OUTNCR
        BSR PULLX
        RTS

CRLFST  dc.b $0D
        dc.b $0A
CREND   dc.b $1E
        dc.b $FF,$FF
        dc.b $FF,$FF
        dc.b $1E
        
PUSHX   STX PUSHTX      ;PUSH X into  XSTACK 
        LDX XSTACK
        DEX
        DEX
        STX XSTACK
        PSHA
        LDAA PUSHTX
        STAA 0,X
        LDAA PUSHTX+1
        STAA 1,X
        PULA
        LDX PUSHTX
        RTS

PULLX   LDX XSTACK     ;PULL X from  XSTACK 
        LDX 0,X
        INC XSTACK+1
        INC XSTACK+1
        RTS

STORE   PSHA
        PSHB
        BSR PUSHX
        JSR PULLAE
        LDX AESTK
        INX
        INX
        STX AESTK
        DEX
        LDX 0,X
        STAA 0,X
        STAB 1,X
        BSR PULLX
        PULB
        PULA
        RTS

IND     BSR PUSHX
        PSHA
        PSHB
        LDX AESTK
        INX
        INX
        STX AESTK
        DEX
        LDX 0,X
        LDAA 0,X
        LDAB 1,X
        JSR PUSHAE
        PULB
        PULA
        BSR PULLX
        RTS

LIST    LDX NEXTBA
        STX WORKBA
        LDX SOURCE
        BRA LIST1
LIST0   LDX INDEX3
LIST1   CPX WORKBA
        BEQ LEXIT
        BSR OUTLIN
        INX
        BRA LIST1
LEXIT   RTS

OUTLIN  LDAA 0,X
        CLR PRCNT
        INX
        LDAB 0,X
        INX
        CLR TSIGN
        JSR PRN0
        BSR PRINSP
OUTLI1  LDAA 0,X
        INX
        JSR PUSHX
        LDX #COMMAN
        STX KEYWD
        STAA KEYWD+1
        LDX KEYWD
        DEX
OUTLI2  DEX
        LDAA 0,X
        CMPA #$1E
        BNE OUTLI2
        INX
        INX
        INX
        JSR OUTNCR
        JSR PULLX
        JMP OUTPUT

PRINSP  PSHA
        LDAA #$20
        JSR OUTCH
        PULA
        RTS

RANDOM  INX
        INX
        LDAA 0,X
        CMPA #'D
        BNE  TSTVER
        JSR PUSHX
        LDAA RNDVAL
        LDAB RNDVAL+1
        LDX  #0000
RAND1   ADCB 1,X
        ADCA 0,X
        INX
        INX
        CPX #RNDVAL
        BNE  RAND1
        ANDA #$7F
        STAA RNDVAL
        STAB RNDVAL+1
        STX   INDEX1
        LDAA INDEX1
        LDAB INDEX1+1
        JMP   TSTV9

TSTV    JSR   SKIPSP
	      JSR   CHKBRK              ;JSR BREAK			#### /DTU
        JSR   TSTLTR
        BCC   TSTV1
        RTS

TSTV1   CMPA #'R
        BNE TSTV2
        LDAB 1,X
        CMPB #'N
        BEQ  RANDOM
TSTV2   JSR PUSHX
        SUBA #$40
        STAA VARPNT+1
        ASLA
        ADDA VARPNT+1
        STAA VARPNT+1
        LDX VARPNT
        LDAA VARPNT
        LDAB VARPNT+1
        TST  2,X
        BNE  TSTV20
        JMP  TSTV9

TSTV20  LDX  0,X
        STX  DIMPNT
        INX
        INX
        STX DIMCAL
        JSR  PULLX
        JSR INXSKP
        CMPA #'(
        BEQ TSTV22
TSTVER  JMP DBLLTR
TSTV22  INX
        JSR EXPR
        JSR PUSHX
        JSR PULLAE
        TSTA
        BEQ TSTV3
SUBER1  JMP  SUBERR

TSTV3   LDX DIMPNT
        TSTB
        BEQ  SUBER1
        CMPB 0,X
        BHI  SUBER1
        LDAA 1,X
        STAA ANUMB
        BEQ TST666
        LDX DIMCAL
TSTV4   DECB
        BEQ TSTV6
        LDAA ANUMB
TSTV5   INX
        INX
        DECA
        BNE TSTV5
        BRA TSTV4

TSTV6   STX DIMCAL
        JSR PULLX
        JSR SKIPSP
        CMPA #',
        BNE TSTVER
        INX
        JSR EXPR
        JSR PUSHX
        JSR PULLAE
        TSTA
        BNE SUBER1
        LDX DIMPNT
        TSTB
        BEQ SUBER1
        CMPB 1,X
        BHI SUBER1
TST666  LDX DIMCAL
TSTV7   INX
        INX
        DECB
        BNE TSTV7
        DEX
        DEX
        STX DIMCAL
        JSR PULLX
        JSR SKIPSP
TSTV8   CMPA  #')
        BNE TSTVER
        JSR PUSHX
        LDAA DIMCAL
        LDAB DIMCAL+1
TSTV9   JSR  PULLX
        INX
        JSR PUSHAE
        CLC
        RTS

TSTLTR  CMPA #$41     ;Subroutine TSTLTR - Return C=0 if 'A'-'Z'
        BMI NONO
        CMPA #$5A
        BLE YESNO
TESTNO  CMPA #$30     ;Subroutine TESTNO - Return C=0 if '0'-'9'
        BMI NONO
        CMPA #$39
        BLE YESNO
NONO    SEC
        RTS
YESNO   CLC
        RTS

PULPSH  BSR PULLAE       ;PULL A & B from AESTK without removing the values
PUSHAE  STS SAVESP       ;PUSH A & B onto AESTK
        LDS AESTK
        PSHB
        PSHA
        STS AESTK
        LDS SAVESP
        RTS

PULLAE  STS SAVESP        ;PULL A & B from AESTK
        LDS AESTK
        PULA
        PULB
        STS AESTK
        LDS SAVESP
        RTS

FACT    JSR SKIPSP
        JSR TSTV
        BCS FACT0
        JSR IND
        RTS

FACT0   JSR TSTN
        BCS FACT1
        RTS

FACT1   CMPA #'(
        BNE FACT2
        INX
        BSR  EXPR
        JSR  SKIPSP
        CMPA #')
        BNE FACT2
        INX
        RTS

FACT2   LDAB #13
        JMP  ERROR

TERM    BSR  FACT
TERM0   JSR SKIPSP
        CMPA #'*
        BNE TERM1
        INX
        BSR FACT
        BSR MPY
        BRA TERM0

TERM1   CMPA #'/
        BNE TERM2
        INX
        BSR FACT
        JSR DIV
        BRA TERM0

TERM2   RTS

EXPR    JSR SKIPSP
        CMPA #'-
        BNE EXPR0
        INX
        BSR TERM
        JSR NEG
        BRA EXPR1
EXPR0   CMPA #'+
        BNE EXPR00
        INX
EXPR00  BSR TERM
EXPR1   JSR SKIPSP
        CMPA #'+
        BNE EXPR2
        INX
        BSR TERM
        JSR ADD
        BRA EXPR1
EXPR2   CMPA #'-
        BNE EXPR3
        INX
        BSR TERM
        JSR SUB
        BRA EXPR1
EXPR3   RTS

MPY     BSR MDSIGN
        LDAA #15
        STAA 0,X
        CLRB
        CLRA
MPY4    LSR 3,X
        ROR 4,X
        BCC MPY5
        ADDB 2,X
        ADCA 1,X
        BCC MPY5
MPYERR  LDAA #2
        JMP ERROR
MPY5    ASL 2,X
        ROL 1,X
        DEC 0,X
        BNE MPY4
        TSTA
        BMI MPYERR
        TST TSIGN
        BPL MPY6
        JSR NEGAB
MPY6    STAB 4,X
        STAA 3,X
        JSR PULLX
        RTS

MDSIGN  JSR PUSHX
        CLRA
        LDX AESTK
        TST 1,X
        BPL MDS2
        BSR NEG
        LDAA #$80
MDS2    INX
        INX
        STX AESTK
        TST 1,X
        BPL MDS3
        BSR NEG
        ADDA #$80
MDS3    STAA TSIGN
        DEX
        DEX
        RTS

DIV     BSR MDSIGN
        TST 1,X
        BNE DIV33
        TST 2,X
        BNE DIV33
        LDAB #8
        JMP ERROR
DIV33   LDAA #1
DIV4    INCA
        ASL 2,X
        ROL 1,X
        BMI DIV5
        CMPA #17
        BNE DIV4
DIV5    STAA 0,X
        LDAA 3,X
        LDAB 4,X
        CLR 3,X
        CLR 4,X
DIV163  SUBB 2,X
        SBCA 1,X
        BCC DIV165
        ADDB 2,X
        ADCA 1,X
        CLC
        BRA DIV167
DIV165  SEC
DIV167  ROL 4,X
        ROL 3,X
        LSR 1,X
        ROR 2,X
        DEC 0,X
        BNE DIV163
        TST TSIGN
        BPL DIV169
        BSR NEG
DIV169  JSR PULLX
        RTS

NEG     PSHA
        PSHB
        JSR PULLAE
        BSR NEGAB
        JSR PUSHAE
        PULB
        PULA
        RTS

NEGAB   COMA
        COMB
        ADDB #1
        ADCA #0
        RTS

SUB     BSR NEG
ADD     JSR PULLAE
ADD1    STAB BNUMB
        STAA ANUMB
        JSR PULLAE
        ADDB BNUMB
        ADCA ANUMB
        JSR PUSHAE
        CLC
        RTS

FINDNO  LDAA HIGHLN
        LDAB HIGHLN+1
        SUBB PACKLN+1
        SBCA PACKLN
        BCS  HIBALL
FINDN1  LDX  SOURCE
FIND0   JSR PULPSH
        SUBB 1,X
        SBCA 0,X
        BCS FIND3
        BNE FIND1
        TSTB
        BEQ  FIND4
FIND1   INX
FIND2   BSR  INXSKP
        CMPA #$1E
        BNE  FIND2
        INX
        CPX NEXTBA
        BNE FIND0
HIBALL  LDX  NEXTBA
FIND3   SEC
FIND4   STX WORKBA
        JSR PULLAE
        RTS

SKIPSP  LDAA 0,X         ;Get the next non-space character (advances X)
        CMPA #$20
        BNE  SKIPEX
INXSKP  INX
        BRA SKIPSP
SKIPEX  RTS

LINENO  JSR INTSTN      ;Subroutine LINENO  
        BCC  LINE1      ;If Valid Number continue 
        LDAB #7         ; Otherwise return ERROR #7
        JMP  ERROR
LINE1   JSR PULPSH      ;Get A & B from ASTK
        STAA PACKLN     ;Update PACKLN
        STAB PACKLN+1
        STX BUFNXT      ;Update buffer pointer
        RTS

NXTLIN  LDX  BASPNT     ;Advance X to the start of the next BASIC line
NXTL12  LDAA 0,X
        INX
        CMPA #$1E
        BNE  NXTL12	   ;BNE NXTLIN			#### /DTU
        STX BASLIN
        RTS

CCODE   BSR SKIPSP
        STX INDEX4
        STS SAVESP
        LDX #COMMAN-1
LOOP3   LDS  INDEX4
        DES
LOOP4   INX
        PULA
        LDAB 0,X
        CMPB #$1E
        BEQ LOOP7
        CBA
        BEQ  LOOP4
LOOP5   INX
        CPX #COMEND
        BEQ CCEXIT
        LDAB 0,X
        CMPB #$1E
        BNE  LOOP5
LOOP6   INX
        INX
        BRA LOOP3
LOOP7   INX
        STS BUFNXT
        STS BASPNT
LOOP8   LDS SAVESP
        RTS

CCEXIT  LDS SAVESP
        LDX #BUFFER       ;EMK  - Command lookup failed - Reset BASPNT 
        STX BASPNT        ;EMK
        LDX #IMPLET       ;Command lookup failed - Use LET
        RTS

START   LDX SOURCE      ;Reset pointer to start of source workspace
        STX NEXTBA
        STX WORKBA
        STX ARRTAB
        DEX
        CLRA
START2  INX            ;Fill workspace with zeros
        STAA 0,X
        CPX MEMEND
        BNE  START2
START1  CLRA           ;Reset Line# pointers & counters 
        STAA PACKLN
        STAA PACKLN+1
        STAA PRCNT       ;Reset Print counter
        LDX PACKLN
        STX HIGHLN
        
READY   LDS #$7045       ;WARM START HERE
        LDX #RDYMSG      ; Print "READY"
        JSR OUTPUT
        
NEWLIN  LDS #$7045       ;Reset Stack Pointer
        LDX #$707F
        STX XSTACK       ;Reset XSTACK
        CLR PRCNT        ;Reset print counter
NEWL3   JSR CNTLIN
        LDX #BUFFER
        JSR SKIPSP
        STX BUFNXT
        JSR TESTNO
        BCS LOOP2
        JMP NUMBER
LOOP2   CMPA #$1E
        BEQ NEWLIN
        JSR CCODE
        LDX 0,X
        JMP  0,X

ERROR   LDS #$7045
        JSR CRLF
        LDX #ERRMS1
        JSR OUTNCR
        CLRA
        JSR PUSHAE
        JSR PRN
        LDX #ERRMS2
        JSR OUTNCR
        CLRB
        LDAA BASLIN
        CMPA #$02        ;// EMK changed due to Relocation of zero page storage: 
        BNE ERROR1       ;// EMK  ORG $20 -> ORG $220
        LDAA #$00        ;// EMK  
        JMP ERROR2       ;// EMK
ERROR1  LDX BASLIN
        LDAA 0,X
        LDAB 1,X
ERROR2  JSR PRN0
        JSR CRLF
        BRA READY

RUN     LDX  SOURCE
        STX BASLIN
        LDX #SBRSTK
        STX SBRPNT
        LDX #FORSTK
        STX FORPNT
        LDX #$707F
        STX XSTACK
        LDX NEXTBA
        STX ARRTAB
        CLRA
        DEX
RUN1    INX
        STAA 0,X
        CPX MEMEND
        BNE RUN1
        LDX #VARTAB
        LDAB  #78
RUN2    STAA 0,X
        INX
        DECB
        BNE RUN2
        JMP  BASIC

CLIST   LDX #PGCNTL
        JSR OUTPUT
        LDX  BASPNT
CLIST1  JSR SKIPSP
        CMPA #$1E
        BEQ CLIST4
        JSR INTSTN
        STX BASPNT
        JSR FINDN1
        STX INDEX3
        LDX BASPNT
        PSHA
        JSR SKIPSP
        CMPA #$1E
        PULA
        BNE CLIST2
        JSR PUSHAE
        BRA  CLIST3
CLIST2  INX
        JSR  INTSTN
CLIST3  CLRA
        LDAB #1
        JSR ADD1
        JSR FINDN1
        JSR LIST0
        BRA CLIST5
CLIST4  JSR  LIST
CLIST5  JMP  REMARK
        NOP

PATCH   JSR   NXTLIN
        LDX   #BASIC
        STX   SAVESP
        LDS   #SAVESP
        SEI              ;Disable interrupts
        LDAA  #$60
        STAA  $14        ;Set RAM/Port5 Ctrl RAME=1,STBY=1,AMRE=1,HLTE=0,MRE=0,IRQ1&2=0
        LDS   #$7FF0     ;Set Stack Pointer (top of external RAM - 16bytes)
        JMP   MONITOR    ;JMP CONTRL          /EMK
                         ;CONTRL  EQU  $C000  /EMK
                         
                         ;***** SYS(aaaa,A,B) ************** /EMK
SYSCALL JSR   GETPRMP    ;X Points to byte after "(" 
        JSR   CVTADDR    ;4 Char Address to BUFFER+32 & BUFFER+33 
        LDAA  5,X        ;X+5= v1
        JSR   GETVALU    ;Get 8bit Variable Value
        STAA  BUFFER+34
        LDAA  7,X        ;X+7= v2
        JSR   GETVALU    ;Get 8bit Variable Value
        STAA  BUFFER+35
        LDAA  BUFFER+34  ;Load v1      
        LDAB  BUFFER+35  ;Load v2
        LDX   BUFFER+32  ;X = Converted Address 
        JSR   0,X        ;JSR (eg if "SYS(FBF4,A,B)" then beep should be called)
        STAA  BUFFER+34  ;Save A Return Value
        STAB  BUFFER+35  ;Save B Return value
        JSR   GETPRMP    ;X Points to byte after "("
        LDAA  5,X        ;X+5= v1
        LDAB  BUFFER+34
        JSR   SETVALU    ;Set 8bit Variable Value
        LDAA  7,X        ;X+7= v2
        LDAB  BUFFER+35
        JSR   SETVALU    ;Set 8bit Variable Value
SYSCALX JSR   NXTLIN     ;Process Next Statement
        JMP   BASIC 
                         ;***** PEEK(aaaa,A) ************** /EMK
DOPEEK  JSR   GETPRMP    ;X Points to byte after "("
        JSR   CVTADDR    ;4 Char Address to BUFFER+32 & BUFFER+33   
        LDX   BUFFER+32  ;X = Converted Address
        LDAB  0,X        ;Get Value pointed to by aaaa ->b 
        STAB  BUFFER+34  ;save for debugging
        JSR   GETPRMP    ;X Points to byte after "("
        LDAA  5,X        ;X+9=v ->A
        JSR   SETVALU    ;Set 8bit Variable Value = B
        JMP   SYSCALX    ;Process Next Statement
                         ;***** PEEK(aaaa,A) ************** /EMK
DOPOKE  JSR   GETPRMP    ;X Points to byte after "("
        JSR   CVTADDR    ;4 Char Address to BUFFER+32 & BUFFER+33  
        LDAA  5,X        ;X+9=v -> A
        JSR   GETVALU    ;Get 8bit Variable Value
        STAA  BUFFER+35  ;save for debugging
        LDX   BUFFER+32  ;X = Converted Address
        STAA  0,X        ;Store the value form v into memory at aaaa
        JMP   SYSCALX    ;Process Next Statement

NUMBER  JSR LINENO       ;Validate number and update PACKLN & BUFNXT
NUM1    JSR FINDNO       ;Is it an Existing Line# ?
        BCC DELREP       ; YES = Jump to DELREP
        LDX BUFNXT       ;
        JSR SKIPSP
        CMPA #$1E        ;Line# with no data following it?
        BEQ NEXIT        ; YES = Do Nothing Just exit        
        LDX WORKBA
        CPX NEXTBA       ;Adding A NEW LINE#
        BEQ CAPPEN       ; Yes = GOTO CAPPEN
        BSR INSERT       ;Otherwise ...Insert a new line
        BRA NEXIT        ;Print CR,LF & Exit
        
DELREP  LDX BUFNXT       
        JSR SKIPSP
        CMPA #$1E        ;Line# with no data following it?
        BNE REPLAC       ; NO= Do Replace  YES = Delete Line
        LDX NEXTBA         
        CPX SOURCE       
        BEQ NEXIT
        BSR DELETE
        BRA NEXIT

REPLAC  BSR DELETE       ;Replace Existing line
        BSR INSERT
NEXIT   JMP NEWLIN
CAPPEN  BSR INSERT
        LDX PACKLN
        STX HIGHLN
        BRA NEXIT
DELETE  STS SAVESP       ;Delete existing line
        LDX WORKBA
        LDS NEXTBA
        LDAB #2
        INX
        INX
        DES
        DES
DEL2    LDAA  0,X
        DES
        INX
        INCB
        CMPA #$1E
        BNE DEL2
        STS NEXTBA
        STS ARRTAB
        LDX WORKBA
        ;STAB DEL5+1      ;Writes B to Program Memory. Not ROM friendly
;* IN AT OBJECT TIME
DEL4    CPX  NEXTBA
        BEQ  DELEX
        STX  INDEX1        ;EMK  Save X
        ABX                ;EMK  X=B+X
DEL5    LDAA 0,X
        LDX  INDEX1        ;EMK  Restore Old X
        STAA 0,X
        INX
        BRA DEL4

DELEX   LDS SAVESP
        RTS

INSERT  LDX BUFNXT        ;Insert a line between 2 existing lines
        JSR  CCODE
INS1    STX  KEYWD
        LDAB ENDBUF+1
        SUBB BUFNXT+1
        ADDB #$04
        ;STAB OFFSET+1         ;Writes B to Program Memory. Not ROM friendly
        STAB INDEX2        ;EMK   Save B 
        ADDB NEXTBA+1
        LDAA #$00
        ADCA NEXTBA
        CMPA MEMEND
        BHI OVERFL
        STAB NEXTBA+1
        STAA NEXTBA
        LDX NEXTBA
        STX  ARRTAB
INS2    CPX  WORKBA
        BEQ BUFWRT
        DEX
        LDAA 0,X
        STX  INDEX1        ;EMK     Save X
        STAB INDEX3        ;EMK     Save B
        LDAB INDEX2        ;EMK     B = Saved B
        ABX                ;EMK     X=X+B        
OFFSET  STAA 0,X
        LDX  INDEX1        ;EMK     Restore X
        LDAB INDEX3        ;EMK     Restore B
        BRA  INS2
BUFWRT  LDX  WORKBA
        STS SAVESP
        LDAA PACKLN
        STAA 0,X
        INX
        LDAA PACKLN+1
        STAA 0,X
        INX
        LDAA KEYWD+1
        STAA 0,X
        INX
        LDS BUFNXT
        DES
BUF3    PULA
        STAA 0,X
        INX
        CMPA #$1E
        BNE BUF3
        LDS SAVESP
        RTS

OVERFL  LDAB #14
        JMP ERROR
BASIC   LDX BASLIN
        CPX NEXTBA
        BNE BASIC1
BASIC0  JMP READY
BASIC1  LDAA BASLIN      ; TST BASLIN  //EMK This change due to relocation: ORG $20 -> ORG $220
        CMPA #$02        ; // EMK If local variables are moved to a different page this must change as well
        BEQ BASIC0       ; Processed last line so just print "Ready"
        INX              ; Otherwise...
        INX              ; Step past Line#
        LDAA 0,X         ; Get keyword token
        INX
        STX  BASPNT      ;BASPNT=byte after keyword token
        LDX #COMMAN      ;X= Address of COMMAND lookup table
        STX KEYWD        ;KEYWD + KEYWD+1 = X
        STAA KEYWD+1     ;Change low KEYWD address = token
        LDX #ASTACK      
        STX AESTK
        LDX KEYWD        ;X=address of keyword in lookup table 
        LDX 0,X          ;X=address of keyword routine
BASIC2  JMP 0,X          ;Jump to keyword routine

GOSUB   LDX BASLIN
        STX INDEX1
        JSR NXTLIN
        LDX SBRPNT
        CPX #SBRSTK+16
        BNE  GOSUB1
        LDAB #9
        JMP  ERROR
GOSUB1  LDAA BASLIN
        STAA 0,X
        INX
        LDAA BASLIN+1
        STAA 0,X
        INX
        STX SBRPNT
        LDX INDEX1
        STX BASLIN
GOTO    LDX BASPNT
        JSR EXPR
        JSR FINDN1
        BCC GOTO2
        LDAB #7
        JMP  ERROR
GOTO2   STX BASLIN
        BRA  BASIC

RETURN  LDX  SBRPNT
        CPX #SBRSTK
        BNE RETUR1
        LDAB #10
        JMP  ERROR
RETUR1  DEX
        DEX
        STX SBRPNT
        LDX  0,X
        STX BASLIN
        JMP BASIC

PAUSE   LDX  #PAUMSG
        JSR OUTNCR
        JSR PRINSP
        LDX  BASLIN
        LDAA 0,X
        INX
        LDAB 0,X
        INX
        JSR  PRN0
PAUSE1  JSR  INCH
        CMPA #$0D
        BNE  PAUSE1
        JSR  CRLF
PAUSE2  JMP  REMARK
INPUT   LDAA  BASPNT
        BNE INPUT0
        LDAB #12
        BRA INPERR
INPUT0  JSR KEYBD
        LDX  #BUFFER
        STX BUFNXT
        LDX BASPNT
INPUT1  JSR TSTV
        BCS INPEX
        STX BASPNT
        LDX BUFNXT
INPUT2  BSR  INNUM
        BCC INPUT4
        DEX
        LDAA 0,X
        CMPA #$1E
        BEQ INPUTS
        LDAB #2
INPERR  JMP  ERROR
INPUTS  JSR  KEYBD
        LDX #BUFFER
        BRA INPUT2
INPUT4  JSR  STORE
        INX
        STX BUFNXT
        LDX BASPNT
        JSR SKIPSP
        INX
        CMPA #',
        BEQ INPUT1
INPEX   DEX
        CLR PRCNT
        CMPA #$1E
        BEQ PAUSE2
DBLLTR  LDAB #3
        JMP  ERROR
TSTN    BSR INTSTN
        BCS TSTN0
        JSR PULLAE
        TSTA
        BPL TSTN1
TSTN0   SEC
        RTS
TSTN1   JSR  PUSHAE
        RTS

INNUM   JSR  SKIPSP
        STAA TSIGN
        INX
        CMPA #'-
        BEQ  INNUM0
        DEX
INTSTN  CLR  TSIGN          ;Subroutine INTSTN - 
INNUM0  JSR   SKIPSP        ;Skip past spaces - X points to non-space
        JSR TESTNO          ;C=0 if '0'-'9'
        BCC INNUM1          ;IF NOT Number the return
        RTS
INNUM1  DEX                 ;Back up 1 byte
        CLRA                ;A=0
        CLRB                ;B=0
INNUM2  INX                 ;Forward 1 byte
        PSHA                ;Save A
        LDAA 0,X            ;Get Byte
        JSR TESTNO          ;C=0 if '0'-'9'
        BCS INNEX           ;If NOT Number then exit
        SUBA #$30
        STAA TNUMB          ;Save digit value in TNUMB
        PULA                ;Restore A
        ASLB                ;B <<
        ROLA                ;A <<
        BCS INNERR          ;If C got set ERROR 2 
        STAB BNUMB
        STAA ANUMB
        ASLB
        ROLA
        BCS INNERR
        ASLB
        ROLA
        BCS INNERR
        ADDB BNUMB
        ADCA ANUMB
        BCS INNERR
        ADDB TNUMB
        ADCA #0
        BCS  INNERR
        JMP  INNUM2
INNERR  LDAB #2
        JMP  ERROR
INNEX   PULA
        TST TSIGN
        BEQ INNEX2
        JSR NEGAB
INNEX2  JSR PUSHAE
        CLC
        RTS

PRINT   LDX  BASPNT
PRINT0  JSR  SKIPSP
        CMPA #'"
        BNE PRINT4
        INX
PRINT1  LDAA 0,X
        INX
        CMPA  #'"
        BEQ  PRIN88
        CMPA #$1E
        BNE PRINT2
        LDAB  #4
        BRA  PRINTE
PRINT2  JSR  OUTCH
        JSR ENLINE
        BRA PRINT1
PRINT4  CMPA #$1E
        BNE PRINT6
        DEX
        LDAA 0,X
        INX
        CMPA #';
        BEQ PRINT5
        JSR CRLF
        CLR PRCNT
PRINT5  INX
        STX BASLIN
        JMP BASIC
PRINT6  CMPA #'T
        BNE PRINT8
        LDAB 1,X
        CMPB #'A
        BNE PRINT8
        INX
        INX
        LDAA 0,X
        CMPA #'B
        BEQ PRINT7
        LDAB #11
PRINTE  JMP  ERROR
PRINT7  INX
        JSR EXPR
        JSR PULLAE
        SUBB PRCNT
        BLS PRIN88
PRIN77  JSR PRINSP
        BSR ENLINE
        DECB
        BNE PRIN77
        BRA PRIN88
PRINT8  JSR  EXPR
        JSR  PRN
PRIN88  JSR  SKIPSP
        CMPA #',
        BNE PRIN99
        INX
PRLOOP  LDAA PRCNT
        TAB
        ANDB #$F8
        SBA
        BEQ PRI999
        JSR PRINSP
        BSR ENLINE
        BRA PRLOOP
PRIN99  CMPA #';
        BNE PREND
        INX
PRI999  JMP  PRINT0
PREND   CMPA #$1E
        BEQ PRINT4
        LDAB #6
        BRA PRINTE
ENLINE  PSHA
        LDAA PRCNT
        INCA
        CMPA #MAXLIN
        BNE ENLEXT
        JSR CRLF
        CLRA
ENLEXT  STAA PRCNT
        PULA
        RTS
PRN     JSR PRINSP
        BSR ENLINE
        LDAA #$FF
        STAA TSIGN
        JSR PULLAE
        TSTA
        BPL PRN0
        JSR NEGAB
        PSHA
        LDAA #'-
        JSR OUTCH
        BSR ENLINE
        PULA
PRN0    JSR  PUSHX
        LDX #KIOK
PRN1    CLR  TNUMB
PRN2    SUBB 1,X
        SBCA 0,X
        BCS PRN5
        INC TNUMB
        BRA PRN2
PRN5    ADDB 1,X
        ADCA 0,X
        PSHA
        LDAA TNUMB
        BNE PRN6
        CPX #KIOK+8
        BEQ PRN6
        TST TSIGN
        BNE PRN7
PRN6    ADDA #$30
        CLR TSIGN
        JSR OUTCH
        BSR ENLINE
PRN7    PULA
        INX
        INX
        CPX #KIOK+10
        BNE PRN1
        JSR PULLX
        RTS

KIOK    dc.w 10000
        dc.w 1000
        dc.w 100
        dc.w 10
        dc.w 1

LET     LDX BASPNT
        JSR TSTV
        BCC LET1
LET0    LDAB #12
LET00   JMP  ERROR
LET1    JSR  SKIPSP
        INX
        CMPA #'=
        BEQ LET3
LET2    LDAB #6
        BRA LET00
LET3    JSR EXPR
        CMPA #$1E
        BNE LET2
        JSR STORE
        BRA REMARK
SIZE    LDAB ARRTAB+1
        LDAA ARRTAB
        SUBB SOURCE+1
        SBCA SOURCE
        JSR PRN0
        JSR PRINSP
        LDAB MEMEND+1
        LDAA MEMEND
        SUBB ARRTAB+1
        SBCA ARRTAB
        JSR PRN0
        JSR CRLF
REMARK  JSR NXTLIN
        JMP BASIC
DIM     LDX BASPNT
DIM1    JSR SKIPSP
        JSR TSTLTR
        BCC DIM111
        JMP DIMEX
DIM111  SUBA #$40
        STAA DIMVAR+1
        ASLA
        ADDA DIMVAR+1
        STAA DIMVAR+1
        JSR PUSHX
        LDX DIMVAR
        TST 0,X
        BNE DIMERR
        TST 1,X
        BNE DIMERR
        TST 2,X
        BNE DIMERR
        LDAA ARRTAB+1
        STAA 1,X
        LDAA ARRTAB
        STAA 0,X
        STAA 2,X
        JSR PULLX
        JSR INXSKP
        CMPA #'(
        BEQ  DIM2
DIMERR  LDAB #5
DIMER1  JMP ERROR
DIM2    INX
        JSR EXPR
        JSR PULPSH
        TSTB
        BEQ SUBERR
        TSTA
        BEQ  DIM3
SUBERR  LDAB #15
        BRA DIMER1
DIM3    BSR STRSUB
        LDAA 0,X
        CMPA #',
        BNE DIM6
        INX
        JSR EXPR
        JSR PULPSH
        TSTB
        BEQ SUBERR
        TSTA
        BNE SUBERR
        BSR STRSUB
        JSR MPY
DIM6    CLRA
        LDAB #2
        JSR PUSHAE
        JSR MPY
        LDAA 0,X
        CMPA #')
        BNE DIMERR
        INX
        LDAB ARRTAB+1
        LDAA ARRTAB
        JSR ADD1
        CLRA
        LDAB #2
        JSR ADD1
        JSR PULLAE
        CMPA MEMEND
        BLS DIM7
        JMP OVERFL
DIM7    STAA ARRTAB
        STAB ARRTAB+1
        JSR SKIPSP
        CMPA #',
        BNE DIMEX
        INX
        JMP DIM1
DIMEX   CMPA #$1E
        BNE DIMERR
        JMP REMARK
STRSUB  JSR PUSHX
        LDX DIMVAR
        LDX 0,X
STRSU2  TST 0,X
        BEQ STRSU3
        INX
        BRA STRSU2
STRSU3  STAB 0,X
        JSR PULLX
        RTS

FOR     LDX  BASPNT
        JSR TSTV
        BCC FOR1
        JMP LET0
FOR1    STX BASPNT
        JSR PULPSH
        LDX FORPNT
        CPX #FORSTK+48
        BNE FOR11
        LDAB #16
        JMP ERROR
FOR11   STAA 0,X
        INX
        STAB 0,X
        INX
        STX FORPNT
        LDX BASPNT
        JSR SKIPSP
        INX
        CMPA #'=
        BEQ  FOR3
FOR2    JMP  LET2
FOR3    JSR EXPR
        JSR STORE
        INX
        CMPA #'T
        BNE FOR2
        LDAA 0,X
        INX
        CMPA #'O
        BNE FOR2
        JSR EXPR
        JSR PULLAE
        STX BASPNT
        LDX FORPNT
        STAA 0,X
        INX
        STAB 0,X
        INX
        STX FORPNT
        LDX BASPNT
        LDAA 0,X
        CMPA #$1E
FOR8    BNE FOR2
        INX
        STX BASLIN
        LDX FORPNT
        LDAA BASLIN
        STAA 0,X
        INX
        LDAB BASLIN+1
        STAB 0,X
        INX
        STX FORPNT
        JMP BASIC

NEXT    LDX BASPNT
        JSR TSTV
        BCC NEXT1
        JMP LET0
NEXT1   JSR SKIPSP
        CMPA #$1E
        BNE FOR8
        INX
        STX  BASLIN
        LDX #FORSTK
        JSR PULPSH
NEXT2   CPX FORPNT
        BEQ NEXT6
        CMPA 0,X
        BNE NEXT5
        CMPB 1,X
        BNE NEXT5
        JSR IND
        JSR PULPSH
        SUBB 3,X
        SBCA 2,X
        BCS NEXT4
        STX  FORPNT
NEXT3   JMP  BASIC
NEXT4   JSR PULLAE
        ADDB #1
        ADCA #0
        JSR PUSHX
        LDX 0,X
        STAA 0,X
        STAB 1,X
        JSR PULLX
        LDX 4,X
        STX BASLIN
        BRA  NEXT3
NEXT5   INX
        INX
        INX
        INX
        INX
        INX
        BRA NEXT2
NEXT6   LDAB #17 
        JMP ERROR

IF      LDX BASPNT
        JSR EXPR
        BSR RELOP
        STAA NCMPR
        JSR EXPR
        STX BASPNT
        BSR CMPR
        BCC IF2
        JMP  REMARK
IF2     LDX  BASPNT
        JSR  CCODE
        LDX 0,X
        JMP 0,X
RELOP   JSR SKIPSP
        INX
        CMPA #'=
        BNE RELOP0
        LDAA #0
        RTS
RELOP0  LDAB 0,X
        CMPA #'<
        BNE RELOP4
        CMPB #'=
        BNE RELOP1
        INX
        LDAA #2
        RTS
RELOP1  CMPB #'>
        BNE RELOP3
RELOP2  INX
        LDAA #3
        RTS
RELOP3  LDAA #1
        RTS
RELOP4  CMPA #'>
        BEQ REL44
        LDAB #6
        JMP ERROR
REL44   CMPB  #'=
        BNE RELOP5
        INX
        LDAA #5
        RTS
RELOP5  CMPB #'<
        BEQ RELOP2
        LDAA #4
        RTS

CMPR    LDAA  NCMPR
        ASLA
        ASLA
        PSHB
        TAB
        LDX #CMPR1
        ABX
        PULB
        JSR SUB
        JSR PULLAE
        TSTA
FUNNY   JMP  0,X
CMPR1   BEQ MAYEQ
        BRA NOCMPR
        BMI OKCMPR
        BRA NOCMPR
        BMI OKCMPR
        BRA CMPR1
        BNE OKCMPR
        BRA MYNTEQ
        BEQ MYNTEQ
        BMI NOCMPR
        BPL OKCMPR
NOCMPR  SEC
        RTS
OKCMPR  CLC
        RTS
MAYEQ   TSTB
        BEQ OKCMPR
        BRA NOCMPR
MYNTEQ  TSTB
        BNE OKCMPR
        BRA NOCMPR

;******************************
;* REPLACEMENT FOR BREAK ROUTINE /EMK
CHKBRK	PSHA
        LDAA  REG_TRCSR1
        ANDA  #$C0	     ;FILTER OUT RDRF AND ORFE
	      CMPA	#$00		   ;IS THERE ANY CHARACTER?
	      BEQ	  CHKNBRK
        JSR   INCHR 
	      CMPA	#CANCEL		;IS CHARACTER AN ESCAPE?
	      BNE	  CHKNBRK
	      JMP	  READY		  ;BREAK. GOTO PROMPT
CHKNBRK	PULA	          ;NO BREAK. CONTINUE
	      RTS

;***************************************************************
; GETPRMP  
; Set X= 2nd Byte after Keyword or Keyword token (parm data)
;***************************************************************
GETPRMP LDX   BASPNT     ;X Points to end of keyword: (aaaa,v,v) in BUFFER  
        LDAA  BASPNT
        CMPA  #$02       ;If BASPNT=$02 then executing command directly
        BEQ   GETPRM1    ;Otherwise executing from stored source code
        LDX   BASLIN     ;X Points to statement: nnt(aaaa,v,v) in SOURCE
        INX
        INX
        INX
GETPRM1 INX              ;If exexuting directly just INC past the "(" 
        RTS

;***************************************************************
;* CVTADDR  
; Convert 4 ASCII Hex Chrs at X=4 to 2 Bytes in BUFFER+32 & BUFFER+33
;***************************************************************
CVTADDR LDAA  0,X        ;X=Address char1
        JSR   CHR2VAL    ;Convert to HEX
        LSLA             ;Shift 4x Left
        LSLA
        LSLA
        LSLA
        STAA  BUFFER+32  ;Save
        LDAA  1,X        ;X+4=Address char2
        JSR   CHR2VAL
        ORAA  BUFFER+32
        STAA  BUFFER+32
        LDAA  2,X        ;X+4=Address char3
        JSR   CHR2VAL
        LSLA
        LSLA
        LSLA
        LSLA
        STAA  BUFFER+33
        LDAA  3,X        ;X+4=Address char4
        JSR   CHR2VAL
        ORAA  BUFFER+33
        STAA  BUFFER+33
        RTS

;********************************************************************
;GETVARA  Set X to the address of the 8bit Value of the variable name(A-Y) from A 
;********************************************************************
GETVARA SUBA #$40
        STAA VARPNT+1
        ASLA
        ADDA VARPNT+1
        STAA VARPNT+1
        LDX VARPNT
        INX
        RTS

;********************************************************************
;GETVALU  Get the LOW 8bit Value of the variable name(A-Y) from A 
;********************************************************************
GETVALU PSHX
        JSR   GETVARA
        LDAA  0,X
        PULX
        RTS
;********************************************************************
;SETVALU Set the LOW 8bit Value of the variable name(A-Y) from A = B 
;********************************************************************
SETVALU PSHX
        JSR   GETVARA
        STAB  0,X
        PULX
        RTS

ENDBASIC     EQU *
;;************************************************************************
;;**** End of NAM MICRO  MICROBASIC V1.3C ********************************  
;;************************************************************************


 ;******************************************************************  
        org  $F840    ; Opcode Type Lookup Table (fixed ROM addr. $F840)
;******************************************************************
OPCDTYPE   dc.b $00,$00,$21,$00,$04,$08,$31,$22,$11,$21,$31,$22,$11,$21,$31,$22
OPCDEXCP   dc.b $62,$83,$8C,$8E,$C3,$CC,$CE,$00

        org  $F860    ; Mnemonic Lookup Table   0x02A5 (677)bytes  $F860-$FB05
;******************************************************************
;Mnemonic Lookup Table High Opcodes x40-xFF    (fixed ROM addr. $F860)
;******************************************************************
MNETBLH     dc.b "ADCA",$89,$99,$A9,$B9
            dc.b "ADCB",$C9,$D9,$E9,$F9
            dc.b "ADDA",$8B,$9B,$AB,$BB
            dc.b "ADDB",$CB,$DB,$EB,$FB
            dc.b "ADDD",$C3,$D3,$E3,$F3
            dc.b "ANDA",$84,$94,$A4,$B4
            dc.b "ANDB",$C4,$D4,$E4,$F4
            dc.b "BITA",$85,$95,$A5,$B5
            dc.b "BITB",$C5,$D5,$E5,$F5
            dc.b "BSR ",$8D,0  ,0  ,0  
            dc.b "CMPA",$81,$91,$A1,$B1
            dc.b "CMPB",$C1,$D1,$E1,$F1
            dc.b "CPX ",$8C,$9C,$AC,$BC
            dc.b "EORA",$88,$98,$A8,$B8
            dc.b "EORB",$C8,$D8,$E8,$F8
            dc.b "JSR ",1  ,$9D,$AD,$BD  
            dc.b "LDAA",$86,$96,$A6,$B6
            dc.b "LDAB",$C6,$D6,$E6,$F6
            dc.b "LDD ",$CC,$DC,$EC,$FC
            dc.b "LDS ",$8E,$9E,$AE,$BE
            dc.b "LDX ",$CE,$DE,$EE,$FE
            dc.b "ORAA",$8A,$9A,$AA,$BA
            dc.b "ORAB",$CA,$DA,$EA,$FA
            dc.b "SBCA",$82,$92,$A2,$B2
            dc.b "SBCB",$C2,$D2,$E2,$F2
            dc.b "STAA",1  ,$97,$A7,$B7  
            dc.b "STAB",1  ,$D7,$E7,$F7  
            dc.b "STD ",1  ,$DD,$ED,$FD  
            dc.b "STS ",1  ,$9F,$AF,$BF  
            dc.b "STX ",1  ,$DF,$EF,$FF  
            dc.b "SUBA",$80,$90,$A0,$B0
            dc.b "SUBB",$C0,$D0,$E0,$F0
            dc.b "SUBD",$83,$93,$A3,$B3
            dc.b 0,0,0,0,0,0,0,0
;******************************************************************            
; MNETBLM   Mnemonic Table M      (exception opcodes)     
;******************************************************************            
MNETBLM     dc.b "CLR ",$6F,$7F,$4F,$5F
            dc.b "COM ",$63,$73,$43,$53
            dc.b "NEG ",$60,$70,$40,$50
            dc.b "DEC ",$6A,$7A,$4A,$5A
            dc.b "INC ",$6C,$7C,$4C,$5C
            dc.b "ROL ",$69,$79,$49,$59
            dc.b "ROR ",$66,$76,$46,$56
            dc.b "ASL ",$68,$78,$48,$58
            dc.b "ASR ",$67,$77,$47,$57
            dc.b "LSR ",$64,$74,$44,$54
            dc.b "TST ",$6D,$7D,$4D,$5D
            dc.b "AIM ",1  ,$71,$61,0
            dc.b "OIM ",1  ,$72,$62,0
            dc.b "EIM ",1  ,$75,$65,0
            dc.b "TIM ",1  ,$7B,$6B,0
            dc.b "JMP ",$6E,$7E,$7E,$7E  
            dc.b 0,0,0,0,0,0,0,0
;******************************************************************
;MNETBLL   Mnemonic Table L  Opcodes x01-x3F   (0 or 1 parm)
;******************************************************************
MNETBLL     dc.b "ABA ",$1B
            dc.b "ABX ",$3A
            dc.b "ASLD",$05
            dc.b "BCC ",$24
            dc.b "BCS ",$25
            dc.b "BEQ ",$27
            dc.b "BGE ",$2C
            dc.b "BGT ",$2E
            dc.b "BHI ",$22
            dc.b "BLE ",$2F
            dc.b "BLS ",$23
            dc.b "BLT ",$2D
            dc.b "BMI ",$2B
            dc.b "BNE ",$26
            dc.b "BPL ",$2A
            dc.b "BRA ",$20
            dc.b "BRN ",$21
            dc.b "BVC ",$28
            dc.b "BVS ",$29
            dc.b "CBA ",$11
            dc.b "CLC ",$0C
            dc.b "CLI ",$0E
            dc.b "CLV ",$0A
            dc.b "DAA ",$19
            dc.b "DES ",$34
            dc.b "DEX ",$09
            dc.b "INS ",$31
            dc.b "INX ",$08
            dc.b "LSRD",$04
            dc.b "MUL ",$3D
            dc.b "NOP ",$01
            dc.b "PSHA",$36
            dc.b "PSHB",$37
            dc.b "PSHX",$3C
            dc.b "PULA",$32
            dc.b "PULB",$33
            dc.b "PULX",$38
            dc.b "RTI ",$3B
            dc.b "RTS ",$39
            dc.b "SBA ",$10
            dc.b "SEC ",$0D
            dc.b "SEI ",$0F
            dc.b "SEV ",$0B
            dc.b "SWI ",$3F
            dc.b "TAB ",$16
            dc.b "TAP ",$06
            dc.b "TBA ",$17
            dc.b "TPA ",$07
            dc.b "TSX ",$30
            dc.b "TXS ",$35
            dc.b "WAI ",$3E
            dc.b "XGDX",$18
            dc.b "SLP ",$1A            
MNETBLEND   dc.b 0,0,0,0,0

;;************************************************************************
;;  External Call Jump Table  
;;  Fixed locations in ROM map to ;subroutines that may re-locate
;;************************************************************************
JUMPTBL        org   $FBD0       ; FBD0-FBF9  (fixed ROM addr. $FBD0-$FBFA)
        JMP   DELAYX             ;Delay based on contents of X approx 10.5us/count
        JMP   OUTCHR             ;Send byte in A to Serial Port
        JMP   INCHR              ;wait for a serial byte and return in A
        JMP   INCHRE             ;wait for a serial byte and return in A with echo
        JMP   PUTS               ;Transmit data indexed by X
        JMP   OUTHEX             ;Output A as 2 HEX digits
        JMP   GETHEXB            ;Wait until a HEX byte is entered 
        JMP   INHEXB             ;Input 2 hex digits return with byte value in A
        JMP   GETADDR            ;Get 4 byte address, save in ADDR_HI & ADDR_LO
        JMP   DODUMP             ;Jump here to save regs, print regs and return 
        JMP   DMPREG             ;Save current state of registers in RAM
        JMP   PRTREGS            ;Send saved register values to terminal
        JMP   BEEP               ;Beep based on contents of A & B
        JMP   INCHRIF            ;Input char if available ..Return zero if none. 
;;************************************************************************
;;    NOTE: Messages Follow at $FC00 (see below after Interrupt Vectors) 
;;************************************************************************           
              
        org  $FC00    ; Messages   MUST BE LAST in FILE
;******************************************************************
; Messages                     (fixed ROM addr. $FC00-$FECA)
;******************************************************************
BOOTMSG     dc.b 10,13," *** HD6303 System Start v2.1 ***"
MSGNL       dc.b 10,13,END
MSGERR      dc.b 10,13,"ERROR",10,13,END
MSGOK       dc.b 10,13,"OK",10,13,END
MSGON       dc.b 10,13,"ON ",10,13,END
MSGOFF      dc.b 10,13,"OFF",10,13,END
MSG001      dc.b 10,13,"Enter Address:",END
MSGSTART    dc.b 10,13," Enter Start Address:",END
MSGENDAD    dc.b 10,13," Enter End   Address:",END
MSGUNKCMD   dc.b 10,13,"Unknown command",END
MSGPROMPT   dc.b 10,13,#'>,END
MSGPRMPT2   dc.b 10,13,#':,END
MSGASMERR2  dc.b "?"
MSGASMERR1  dc.b "?",END
MSGSPC4     dc.b "    ",END
MSGATNRSP   dc.b "$$$",END
MSGPRT      dc.b " Enter Port#:(2,5 or6)",END
MSGVAL      dc.b " Value:",END
MSGCLS      dc.b 32,27,91,50,74,32,27,91,72,END
MSGBASIC    dc.b 10,13," NAM MICRO  MICROBASIC V1.3C",END
MSG19200    dc.b 10,13," Baud Rate to 19200..",END
MSGHLP      dc.b 10,13," ****** Command Menu *****"
            dc.b " [V2.1 11/2016] **********"
            dc.b 10,13," d   Dump Memory(16 bytes)"
            dc.b "  D   Dump Memory(256 bytes)"
            dc.b 10,13," S   Set Memory           "
            dc.b "  T   ASCI bytes to Memory"
            dc.b 10,13," F   Fill Memory          "
            dc.b "  H   High Speed (19200 baud)"
            dc.b 10,13," L   LIST                 "
            dc.b "  A   ASSEMBLE"
            dc.b 10,13," G/g Go                   "
            dc.b "  @   Attention!"
            dc.b 10,13," O   Write I/O Port       "
            dc.b "  I   Read I/O Port"
            dc.b 10,13," f   Flash LEDs 10x       "          
            dc.b "  Z   Beep.."
            dc.b 10,13," :   Get iHEX Rec(no echo)"
            dc.b "  ;   Send iHEX Rec(no echo)"
            dc.b 10,13," B/b Start Basic          "      
            dc.b "  C   Clear Screen"                   
            dc.b 10,13," M/m Menu                 "
            dc.b "  %   Start/Stop 10ms Timer"              
            dc.b 10,13,END                
MSGEND      equ     .
        
;;************************************************************************
;;  Interrupt Vectors            (fixed ROM addr. $FFEA-$FFFF)
;;************************************************************************
        org   $FFEA       ; IRQ Vectors $FFEA - FFFF
        
        dc.w  IRQIRQ2         ;IRQ2    $0098   $FFEA & $FFEB
        dc.w  IRQCMI          ;CMI     $0095
        dc.w  TRAP01          ;TRAP    $FFEE & $FFEF
        dc.w  IRQSIO          ;SIO     $009B  $FFF0 & $FFF1   
        dc.w  IRQTOI          ;TOI     $0092
        dc.w  IRQOCI          ;OIC     $008F
        dc.w  IRQICI          ;ICI     $008C
        dc.w  IRQIRQ1         ;IRQ1    $0089
        dc.w  IRQSWI          ;SWI     $0086
        dc.w  IRQNMI          ;NMI     $0083
        dc.w  RESET           ;RESET   $FFFE & $FFFF
