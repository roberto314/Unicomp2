;* monrom03.asm  *** 6800 Board Monitor  
;* V3.4 - Updated BASIC to eleminate use of SP as an index pointer.

    CPU 6800      ;turns additional opcodes off
   
OUTBYTE EQU   $80
INBYTE  EQU   $81
ADDRH   EQU   $82
ADDRL   EQU   $83
INDEX1  EQU   $84
INDEX2  EQU   $86
FLAGS_A EQU   $88
TEMP_01 EQU   $89          ; Temp Storage 1
TEMP_02 EQU   $8A          ; Temp Storage 2
TEMP_03 EQU   $8B          ; Temp Storage 3
REC_LEN EQU   $8C          ; iHex Record Length 
REC_TYPE EQU  $8D          ; iHex Record Type
REC_CSUM EQU  $8E          ; iHex Record Checksum
PORTAV  EQU   $90
COUNT_A EQU   $91
COUNT_B EQU   $92
COUNT_C EQU   $93
OPCD     EQU  $94          ; Opcode for disassembly
ROWADDH  EQU  $95          ; Mnemonic Table Row Address
ROWADDL  EQU  $96          
OPCFLAGS EQU  $97          ;Opcode flags
DISABUFP EQU  $98          ;Dissasmbly buffer pointer (2 bytes)
DISADD1  EQU  $9A          ;Disassembly start address (2 bytes)
DISADD2  EQU  $9C          ;Disassembly End address (2 bytes)
LINECT   EQU  $9E          ;Disassembly Line count 

DISABUF  EQU  $A0          ;Dissasmbly buffer (16 bytes $00-$AF) 
PARMBUF  EQU  $B0          ;Parameter buffer 5 bytes $B0-$B4
PARMLEN  EQU  $B5          ;Parameter Length
IRQVECT  EQU  $C0          ;IRQ Interrupt Vector in FFF8&9
SWIVECT  EQU  $C3          ;SWI Interrupt Vector in FFFA&B
CNTR5MS  EQU  $C6          ;Counts NMI Interrupt every 5ms


PORTA   EQU   $2000
CTLRA   EQU   $2001 
PORTB   EQU   $2002
CTLRB   EQU   $2003

;************************************************************************
;  External Call Jump Table  
;  Points to Fixed locations in ROM map to subroutines that may re-locate
;  Copy to Local RAM Programs and un-comment to access ROM functions
;************************************************************************
;DEL5A    EQU  $FFC8          ;Delay  A*5 ms
;DELAYA   EQU  $FFCB          ;Delay  A ms
;DELAYB   EQU  $FFCE          ;Delay B * 6 us
;OUTCHR   EQU  $FFD1          ;Send byte in A to Serial Port
;GETBYTE  EQU  $FFD4          ;wait for a serial byte and return in A
;INCHRE   EQU  $FFD7          ;wait for a serial byte and return in A with echo
;PUTS     EQU  $FFDA          ;Transmit data indexed by X
;OUTHEX   EQU  $FFDD          ;Output A as 2 HEX digits
;GETHEXB  EQU  $FFE0          ;Wait until a HEX byte is entered 
;INHEXB   EQU  $FFE3          ;Input 2 hex digits return with byte value in A
;GETADDR  EQU  $FFE6          ;Get 4 byte address, save in ADDRH & ADDRL 
;BEEPBA   EQU  $FFE9          ;BEEP A=Duration Count and B=Frequency Count
;TESTKEY  EQU  $FFEC          ; Return Z=1 if start bit encountered        
   
;************************************************************************
;************************************************************************              
     
    ORG $E000
    
 ;*************************************
 ; RESET  Start of main program
 ;**************************************
RESET   LDS	 #$07FF
        SEI
        
        LDAA #$3B     ;RTI Instruction  - Populate IRQ Vectors
        STAA IRQVECT
        STAA SWIVECT

        LDAA #$00
        STAA CNTR5MS    ;Reset 5ms counter LOW & HIGH
        STAA CNTR5MS+1
        
        STAA CTLRA    ;CA.4=0  DDRA Access
        STAA CTLRB    ;CB.4=0  DDRA Access
        LDAA #$FF
        STAA PORTA    ;Set DDRA = $FF  All OUTPUTS
        LDAA #$6F
        STAA PORTB    ;Set DDRB = $6F  All OUTPUTS(except Bit 7&4 =INPUT)
        LDAA #$04
        STAA CTLRA    ;CA.4=0  DDRA Access
        STAA CTLRB    ;CB.4=0  DDRA Access
        LDAA #$FF
        STAA PORTA    ;Set PORTA = $FF  All OUTPUTS HIGH (LEDS OFF)
        LDAA #$BF
        STAA PORTB    ;Set DDRB = $BF  All OUTPUTS HIGH (except Bit 6 = RXD)
        
        LDAA #$01     ;Set Echo Flag ON
        STAA FLAGS_A
        
        LDAB #8        ;Blink 8 times
        LDAA #25       ;25*5=125ms/state or 1/4 sec per blink
        JSR  BLINKBA
        
        LDAA #2        ; 1KHZ for 1/2 sec.
        LDAB #83
        JSR  BEEPBA        
        
        LDX  #BOOTMSG
        JSR  PUTS
        LDX  #MSGMENU
        JSR  PUTS
         
KEYCHK  LDX  #$6C80      ;Set Blink Delay  1/2 sec
KEYCHK1 LDAA PORTB       ;Start Bit encountered?
        ANDA #$80
        BEQ  GETMOPT     ;Read the key
        DEX              ;Time to blink?
        BNE  KEYCHK1     ;NO=Test Key again
        LDAA PORTB
        ANDA #$01        ;LED ON (PB0=0)
        BEQ  LEDOFF      ;NO=SET LED OFF (PB0=1)
        LDAA PORTB
        ANDA #$FE        
        STAA PORTB       ;SET LED ON (PB0=0)
        BRA  KEYCHK
LEDOFF  LDAA PORTB
        ORAA #$01
        STAA PORTB       ;SET LED OFF (PB0=1)
        BRA  KEYCHK
        
GETMOPT JSR  GETBYTE
        JSR  OUTCHR
CHK_X   LDAA INBYTE
        CMPA #'X'
        BNE  CHK_B
        JSR  DOINCA
        BRA  KEYCHK
CHK_B   CMPA #'B'        ;BASIC - Cold start
        BNE  CHK_BL
        LDX  #MSGBASIC
        JSR  PUTS
        JMP  COLDST
CHK_BL  CMPA #'b'        ;BASIC - Warm Start
        BNE  CHK_N
        JMP  READY
        
CHK_N   CMPA #'N'        ;BEEP (N=Noise)
        BNE  CHK_DL
        LDAA #12         ; 1KHZ for 3 sec.
        LDAB #83
        JSR  BEEPBA
        JMP  MENUXOK       
CHK_DL  CMPA #'d'        ;Dump 16
        BNE  CHK_D
        JSR  GETADDR     ;Enter Address
        LDX  #MSGNL
        JSR  PUTS
        JSR  DUMP16
        BRA  KEYCHK
CHK_D   CMPA #'D'        ;Dump 256
        BNE  CHK_S
        JSR  GETADDR     ;Enter Address
        LDX  #MSGNL
        JSR  PUTS
        JSR  DUMP256
        BRA  GETMOPT
CHK_S   CMPA  #'S'      ;******** Set Memory **********
        BNE   CHK_F
        JSR   GETADDR   ;Enter Start Address
        BCS   SETMEMX        
        LDX   #MSGNL
        JSR   PUTS      ;Newline        
SETMEM  JSR   INHEXB    ;Get 1 hex byte
        BCS   SETMEMX   ;If enter was pressed then exit
        LDX   ADDRH     ;Get address -> X     
        STAA  0,X       ;Store input byte
        INX             ;Point at next address
        STX   ADDRH     ;Save it
        LDAA  #$20
        JSR   OUTCHR    ;Output a space
        JMP   SETMEM    ;Do it again
SETMEMX JMP   MENUXOK   ;Print OK and resume main loop

CHK_F   CMPA  #'F'       ;******** Fill Memory *******
        BNE   CHK_G
        JSR   FILLMEM
        JMP   MENUXOK   ;Print OK and resume main loop
        
CHK_G   CMPA  #'G'      ;**** GO Command **** 
        BNE   CHK_GL
        JSR   GETADDR   ;Enter Address
        BCS   TXTMEMX        
        LDX   #MSGNL    ;Send Newline
        JSR   PUTS
        LDX   ADDRH
        JSR   0,X
        JMP   MENUXOK   ;Print OK and resume main loop
        
CHK_GL  CMPA  #'g'      ;******** go 0200 Command **** 
        BNE   CHK_T
        LDX   #$C000    ; Load address of $C000
        JSR   0,X
        JMP   MENUXOK   ;Print OK and resume main loop  
CHK_T   CMPA  #'T'      ;**** Text Chars to Memory ****
        BNE   CHK_L
        JSR   GETADDR   ;Enter Start Address
        BCS   TXTMEMX        
        LDX   #MSGNL
        JSR   PUTS      ;Newline        
TXTMEM  JSR   INCHRE    ;Get 1 character and echo
        CMPA  #$0D      ;Is it Return?
        BEQ   TXTMEMX   ;Exit 
        LDX   ADDRH     ;Get Address     
        STAA  0,X       ;Save byte
        INX             ;Inc Address
        STX   ADDRH     ;Save Address
        JMP   TXTMEM    ;Repeat
TXTMEMX JMP   MENUXOK   ;Print OK and resume main loop

CHK_L   CMPA  #'L'       ;**** List Memory (Dissamble)****
        BNE   CHK_A
        JSR   LISTMEM
        JMP   MENUXOK   ;Print OK and resume main loop
        
CHK_A   CMPA  #'A'       ;**** Assemble to Memory ****
        BNE   CHK_Z
        LDX   #MSGSTART   ;Enter Start Address:
        JSR   PUTS
        JSR   INHEXB      ;Get 2 hex digits
        BCS   CHK_AX      ; Exit if enter was pressed ...just exit
        STAA  ADDRH
        JSR   INHEXB      ;Get 2 hex digits
        STAA  ADDRL
        
        JSR   ASM2MEM   ;Assemble to memory
CHK_AX  JMP   MENUXOK   ;Print OK and resume main loop

CHK_Z   CMPA #'Z'        ;Blink
        BNE  CHK_IHR
        LDAB #20         ;Blink 25 times
        LDAA #25         ;25*5=125ms/state or 1/4 sec per blink
        JSR  BLINKBA
        JMP  MENUXOK 

CHK_IHR CMPA  #$3A       ;**** Get IHEX Rec (no echo) ****
        BNE   CHK_AT
        JSR   GETIHEX
        LDX   #MSGNL
        JSR   PUTS      ;Newline
        JMP   GETMOPT
        
CHK_AT  CMPA  #'@'       ;**** Attention Command - Response = "$$$" ****
        BNE   CHK_ML
        LDX   #MSGATNR
        JSR   PUTS      ;Attention Response Message = "$$$"
        JMP   GETMOPT                     

CHK_ML  CMPA  #'m'       ;Display Menu
        BEQ   DOMENU
  
CHK_M   CMPA  #'M'       ;Display Menu
        BNE   CHK_??
DOMENU  LDX   #MSGMENU
        JSR   PUTS
        JMP   KEYCHK
        
MENUXOK LDX   #MSGOK
        JSR   PUTS       
CHK_??  JMP   KEYCHK 
 
;*************************************
;DOINCA
;*************************************        
DOINCA  DEC  PORTA
        LDX  #$6C80      ;Set Blink Delay  1/2 sec
DOINCA1 LDAA PORTB       ;Start Bit encountered?
        ANDA #$80
        BEQ  DOINCAX     ;Exit if key pressed
        DEX              ;Time to blink?
        BNE  DOINCA1     ;NO=Test Key again
        BRA  DOINCA
DOINCAX RTS 

 ;*************************************
 ; DEL5A 
 ;**************************************
DEL5A   PSHB          ; DEL5A  DELAY A*5 milliseconds (4-1024ms)
DEL5A1  LDAB  #00     ; 6us per loop (+14us overhead) (256*6)+14 = 1550us (1.55ms)
        JSR   DELAYB
        JSR   DELAYB  ; Just call again for another 1.55ms   (total is now 3.1ms)
        JSR   DELAYB  ; Just call again for another 1.55ms   (total is now 4.65ms)
        LDAB  #56     ; delay the remaining 350us     
        JSR   DELAYB  
        DECA  
        CMPA  #$00
        BNE   DEL5A1 
        PULB
        RTS   
                      
 ;*************************************
 ; DELAYA 
 ;**************************************
DELAYA   PSHB          ; DELAYA  DELAY A milliseconds
DELAYA1 LDAB  #164     ; 6us per loop (= 14us overhead) 164= 998us
        JSR   DELAYB    
        DECA  
        CMPA  #$00
        BNE   DELAYA1 
        PULB
        RTS   

 ;*************************************
 ; DELAYB 
 ;**************************************
DELAYB  DECB              ;  DELAYB   6us per count (DECB=2 cycles)
        BNE   DELAYB      ; (BNE=4 cycles)
        RTS               ; (RTS = 5 cycles)   (* JSR=9 cycles)

;*************************************
; BLINKBA Blink LED ob PB0 B times with 
;         a delay of (A*10)ms   
;************************************* 
BLINKBA PSHB
        PSHA
BLINKB1 LDAA PORTB
        ANDA #$FE      ; PORTB PB0=0 LED ON
        STAA PORTB
        PULA 
        PSHA
        JSR  DEL5A    
        LDAA PORTB
        ORAA #$01      ; PORTB PB0=1 LED OFF 
        STAA PORTB
        PULA
        PSHA
        JSR  DEL5A    
        DECB
        BNE  BLINKB1
        PULA
        PULB
        RTS
;******************************************************************
; BEEPBA 
; Call With A=Duratuon Count  B=Frequency Count
; Frequency = (1/12)*Frequency Count or 0.0833 * Frequency Count
; Duration = Frequency Count * 3072 * Duration Count (in microseconds)
;     or Frequency Count * 12 * 256 * Duration Count   
; 7KHz=0x0C 5KHz=0x10 2KHz=0x2A 1KHz=0x53 400Hz=0xD0 327Hz=0xFF                                   
;******************************************************************
BEEPBA STAA  COUNT_A   ;Save Duration Count
       
DOBEEP DEC   COUNT_A   ;Dec Duration
       BEQ   DOBEPX    ;If=0  EXIT
DOBEP1 LDAA  PORTB
       ANDA  #$DF
       STAA  PORTB     ;PB5=LOW
       PSHB
       JSR   DELAYB
       PULB
       LDAA  PORTB
       ORAA  #$20
       STAA  PORTB    ;PB5=HIGH
       PSHB
       JSR   DELAYB
       PULB
       DEC   COUNT_B  ;DEC EXTEND DELAY
       BNE   DOBEP1 
       JMP   DOBEEP
DOBEPX RTS

 ;*************************************
 ;OUTCHR  Send Serial 1 byte  
 ; Delay count: 60 worked for 2400b  8/7 for 9600 
 ;              25 worked for 4800b 
 ; * PB6 is INVERTED
 ;**************************************
OUTCHR  PSHA
        PSHB
        STAA OUTBYTE      ; Save OUTBYTE
        LDAA PORTB
        ORAA #$40         ;Set PIN LOW*  (Start Bit)
        STAA PORTB
        LDAB #8       ; B=Bit Count
        PSHB          ; DELAY 1 bit (416us-2400b 104us =9600) (4 cycles)
        LDAB #8      ; LDAB 2 cycles
        JSR  DELAYB   ; (6us / count + 14us for JSR & RTS)
        PULB
OUTCHR1 LDAA OUTBYTE
        CLC
        RORA
        STAA OUTBYTE
        LDAA PORTB        
        BCS  OUTCHR2
        ORAA #$40         ;Set PIN LOW*
        BRA  OUTCHR3         
OUTCHR2 ANDA #$BF         ;Set PIN HIGH*
OUTCHR3 STAA PORTB
        
        PSHB          ; DELAY 1 bit (416.6us=2400b) (4 cycles)
        LDAB #7       ;                LDAB 2 cycles
        JSR  DELAYB   ; 88us   (6us / count + 14us for JSR & RTS)
        PULB
        
        DECB
        BNE  OUTCHR1
        
        LDAA PORTB   ; *** Send 2 stop bits
        ANDA #$BF         ;Set PIN HIGH*
        STAA PORTB 
           
        LDAB #124      
        JSR  DELAYB   ; 120us   (6us / count + 14us for JSR & RTS)
        
        PULB
        PULA
        RTS
        
;*****************************************************
; TESTKEY
; Return Z=1 if start bit encountered
; Remember to delay at least 1ms after this call 
; returns with Z=1 (keypress must be discarded) 
;*****************************************************
TESTKEY LDAA PORTB    ;Read PORTB
        ANDA #$80
        TSTA
        RTS
        
 ;*************************************
 ;GETBYTE  Get 1 Serial 1 byte  
 ; 80/60 worked for 2400 (bit count=8)
 ; 42/28 worked for 4800
 ; Used 10/8 with bit count 9 for 9600??
 ;**************************************
GETBYTE PSHB

GETBT1  LDAA PORTB    ;Read PORTA
        ANDA #$80
        TSTA
        BNE  GETBT1   ;No Start Bit - Keep looking
        
        LDAB #21      ;Delay 1.5 bit time  ** Was 11 **
GETBT2  JSR  DELAYB    
        LDAB #8       ;Set Bit count
        
GETBT3  LDAA PORTB    ;Read PORTA
        ROLA
        LDAA INBYTE
        RORA
        STAA INBYTE      ; Save INBYTE

        PSHB          ; DELAY 1 bit (416us=2400 104us=9600) (4 cycles)
        LDAB #9       ; LDAB 2 cycles
        JSR  DELAYB   ; 54us   (6us / count + 14us for JSR & RTS)
        PULB
        
        DECB
        BNE  GETBT3
        
        LDAA INBYTE   ; Get INBYTE -> A
        PULB
        RTS
;**********************************************************
; INCHRE  wait for a serial byte and return in A with echo
;**********************************************************
INCHRE  JSR   GETBYTE
        JSR   OUTCHR
        LDAA  INBYTE
        RTS        
;*****************************************************
; GETHEXB    Wait for 2 HEX chars to be entered, 
;            return with value in A 
;*****************************************************
GETHEXB JSR   GETBYTE    ;Get 1 char
        CMPA  #$0D       ; Is it CR?
        BEQ   GETHEX5    ; Return with C=1
        CMPA  #$1B       ; is it Esc?
        BEQ   GETHEX5    ; Return with C=1
;        CMPA  #$20
;        BEQ   GETHEX5
         
        CMPA  #"0"        ; < '0'  ?
        BMI   GETHEXB     ; Get another keystroke
        CMPA  #"g"        ; > 'f'  ?
        BPL   GETHEXB     ; Get another keystroke
        CMPA  #$3A        ; <= '9' ?
        BPL   GETHEX1     ; NO = continue  else...
        JMP   GETHEX3     ; Echo & Return
GETHEX1 ANDA  #$4F        ;Convert to Uppercase          
        CMPA  #"G"        ; > 'F' ?
        BPL   GETHEXB     ; Get another keystroke
        CMPA  #$40        ; < 'A' 
        BLS   GETHEXB     ; Get another keystroke
        STAA  INBYTE      ; Save Uppercase version in RX_BYTE
GETHEX3 LDAA  FLAGS_A
        ANDA  #$01        ;Is ECHO ON?
        BEQ   GETHEX4     ;NO = Skip OUTCHR
        LDAA  INBYTE        
        JSR   OUTCHR
GETHEX4 LDAA  INBYTE     ;Get Input byte
        CLC               ;Return with C=0  OK
        RTS 
GETHEX5 SEC               ;Return with C=1  Exit Char entered (Esc or CR)
        RTS
   
;;*****************************************************
;; GETADDR Prompt for & input 4 hex chars save value in
;;         ADDR_HI & ADDR_LO
;;*****************************************************
GETADDR LDX   #MSGENTA   ;Enter Address:
        JSR   PUTS
GETADR1 JSR   INHEXB
        BCS   GETADDX
        STAA  ADDRH
        JSR   INHEXB
        BCS   GETADDX
        STAA  ADDRL
        CLC
GETADDX RTS
;;*****************************************************
;; INHEXB   Input 2 hex digits return with byte value 
;;          in A    If C=1  exit char was entered
;;*****************************************************
INHEXB  JSR   GETHEXB
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

;;*****************************************************
;; INHEXB2  Input 2 hex digits return with byte value in A    
;; No range or error checking - assumes input is HEX char
;;*****************************************************
INHEXB2 JSR   GETBYTE    ;Get 1 char
        JSR   CHR2VAL
        ASLA
        ASLA
        ASLA
        ASLA
        ANDA  #$F0
        STAA  TEMP_01
        JSR   GETBYTE    ;Get 1 char
        JSR   CHR2VAL
        ORAA  TEMP_01
        STAA  TEMP_01
        CLC
        RTS
;;*****************************************************
;; CHR2VAL   Convert ASCII hex char to value in A
;;*****************************************************
CHR2VAL CMPA  #"A"         ; < 'A'
        BPL   CHR2VL1        
        ANDA  #$0F
        RTS
CHR2VL1 SUBA  #55         ; 'A'-'F'
        RTS        
       
;;*************************************
;; PUTS                                    
;; PRINT DATA POINTED AT BY X-REG
;;*************************************
PUTS2   JSR   OUTCHR
        INX
PUTS    LDAA  0,X
        CMPA  #$00
        BNE   PUTS2   ;GO ON IF NOT EOT
        RTS

;;*************************************
;; OUTNIBH
;; OUTPUT High 4 bits of A as 1 HEX Digit
;; OUTNIBL
;; OUTPUT Low 4 bits of A as 1 HEX Digit
;;*************************************
OUTNIBH LSRA          ;OUT HEX LEFT HEX DIGIT
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
OUTHEX  PSHB            ;Save B
        TAB             ;Save A in B 
        JSR   OUTNIBH   ;Print High 4 bits
        TBA             ;Get A from B 
        JSR   OUTNIBL   ;Print Low 4 Bits
        PULB            ;Restore B
        RTS
  
        
;;************************************************************************
;; DUMP16                                                              OK
;; Call with start address in ADDR_HI & ADDR_LO
;;************************************************************************
DUMP16  LDAA  ADDRH    ;Print Address as 4 HEX chrs
        JSR   OUTHEX   
        LDAA  ADDRL
        JSR   OUTHEX   
        LDAA  #$20       ;Print 2 spaces
        JSR   OUTCHR   
        JSR   OUTCHR
        LDX   ADDRH
        LDAB  #16        ;Set Byte count
DUMP161 LDAA  0,X        ;Get Data byte
        JSR   OUTHEX     ;Print as HEX
        LDAA  #$20        
        DECB
        CMPB  #8         ;On 8th byte print '-' instead of space 
        BNE   DUMP162
        LDAA  #"-"
DUMP162 JSR   OUTCHR
        INX 
        CMPB  #00        ; Done?
        BNE   DUMP161    ; Do next byte
        JSR   OUTCHR     ; print 3 spaces
        JSR   OUTCHR
        JSR   OUTCHR
        LDX   ADDRH
        LDAB  #16        ;Set Byte count
DUMP163 LDAA  0,X        ;Get Data byte
        CMPA  #$20       ;Less than blank? 
        BPL   DUMP164
        LDAA  #"."
DUMP164 CMPA  #$7F       ;Greater than `~`  
        BMI   DUMP165
        LDAA  #"."
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
DUMP256 LDAA  #16
        STAA  COUNT_A
DMP2561 JSR   DUMP16
        LDAA  COUNT_A
        DECA
        CMPA  #00
        BEQ   DMP256X
        STAA  COUNT_A
        CLC
        LDAA  ADDRL
        ADCA   #16
        STAA  ADDRL
        BCC   DMP2561
        INC   ADDRH
        JMP   DMP2561
DMP256X RTS        
;******************************************************************
; GETIHEX:
; the ':' command - wait for an iHEX record and store it
;                   verify checksum and respond with '*' if OK 
;******************************************************************             
GETIHEX LDAA  #00     
        STAA  COUNT_C    ;Clear Checksum
        STAA  COUNT_A    ;Byte Counter
        STAA  FLAGS_A    ;Echo Off
             
        JSR   INHEXB2    ;GET RECORD LENGTH
        STAA  REC_LEN    ;Save REC LEN
        STAA  COUNT_A    ;Save in Byte counter
                  
        JSR   INHEXB2     ;Get Address save in ADDR_HI & ADDR_LO
        STAA  ADDRH
        JSR   INHEXB2
        STAA  ADDRL        

        JSR   INHEXB2     ;GET RECORD TYPE
        STAA  REC_TYPE   ;Save REC TYPE
             
        LDX   ADDRH      ;Get Address 
                                        
NEXTIHB JSR   INHEXB2     ;Get Data Byte
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

GIHCSUM JSR   INHEXB2    ; GET INPUT CHECKSUM 
        STAA  REC_CSUM   ;Save Checksum
        LDAB  COUNT_C    ; Get Checksum counter ->B
        LDAA  REC_LEN    ; Get Rec Len 
        ABA              ; Add Total  B+A->A
        TAB              ; Save New Total A->B
        LDAA  REC_TYPE   ; Get Rec Type
        ABA              ; Add Total  B+A->A
        TAB              ; Save New Total A->B
        LDAA  ADDRH      ; Address HI
        ABA              ; Add Total  B+A->A
        TAB              ; Save New Total A->B
        LDAA  ADDRL      ; Address LO
        ABA              ; Add Total
        NEGA             ; 2's complement 
        STAA  COUNT_C   ; Save in Checksum counter
        TAB              ; also in B 
              
        CMPB  REC_CSUM  ; Get Input Checksum
        BNE   GIHERR2   ; Checksum Error
                                  ; Otherwise 
        JMP   GIHEXIT  ; Good Record - Exit
             
      
GIHERR2 LDAA  #'E'      ; Checksum Error
        JMP   GIHEXX1 
             
GIHEXIT LDAA  #'*'
GIHEXX1 JSR   OUTCHR
        LDAA  #$01
        STAA  FLAGS_A   ; Turn ECHO BACK ON
        RTS
    
;******************************************************
; FILLMEM  Fill Memory routine (F fill)
;******************************************************
FILLMEM LDX   #MSGSTART   ;Enter Start Address:
        JSR   PUTS
        JSR   INHEXB
        BCS   FILLEX
        STAA  ADDRH
        JSR   INHEXB
        BCS   FILLEX
        STAA  ADDRL
        
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
        LDX   ADDRH      ;Get address
FILL01  STAA  0,X        ;Store the Value
        CPX   DISADD1    ;Match on End Adress?
        BEQ   FILLEX     ;Exit
        INX
        JMP   FILL01
FILLEX  RTS    
        
;;******************************************************************
;; LISTMEM  Disassemble code routine (L List)
;;******************************************************************
LISTMEM LDX   #MSGSTART   ;Enter Start Address:
        JSR   PUTS
        JSR   INHEXB
        STAA  DISADD1
        JSR   INHEXB
        STAA  DISADD1+1
        
        LDAA  #$FF
        STAA  LINECT   ;Default line count to indicate use end address         
        
        LDX   #MSGENDAD   ;Enter End Address:
        JSR   PUTS
        JSR   INHEXB
        STAA  DISADD2
        BCC   LIST01      ;If Enter NOT pressed skip ahead else set LINECT=16 
        LDAA  #16
        STAA  LINECT
        JMP   LIST02
LIST01  JSR   INHEXB
        STAA  DISADD2+1
        BCC   LIST02      ;If Enter NOT pressed skip ahead else set LINECT=16  
        LDAA  #16
        STAA  LINECT
                          ;Start of disassembly
LIST02  LDX   DISADD1     ;Get address of opcode
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
        LDAA  #'?'        ;If not found report error
        JSR   OUTCHR
        JSR   OUTCHR
        JMP   LISTEX           
        
LIST05  LDAA  #$20        ;Print a space
        JSR   OUTCHR   
                        ;DEBUG1
        JSR   CLRDABUF  ;Clear the disassembly buffer & reset pointer
        JSR   PUTMNEM   ;Transfer the mnemonic for the opcode found to the disassembly buffer
                        ;DEBUG2
        LDAA  DISADD1   ;Print Address
        JSR   OUTHEX  
        LDAA  DISADD1+1
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
        LDX   DISADD1     ;GET opcode address in X
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

        LDX   DISADD1     ;GET opcode address
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
        STX   DISADD1     ;Save new address
        LDAA  OPCFLAGS    ;Get OPCFLAGA
        ANDA  #$30        ;Mask for type (0, 1 or 2)
        CMPA  #$30      
        BNE   LISTNXT     ;If Not type 3 just continue otherwise add ",X" to output
        LDAA  #','
        JSR   OUTCHR
        LDAA  #'X'
        JSR   OUTCHR

LISTNXT LDAA  LINECT
        CMPA  #$FF        ;Using END Address?
        BEQ   LSTCKEA 
        DECA
        STAA  LINECT
        CMPA  #00
        BEQ   LISTEX
        JMP   LIST02 
         
LSTCKEA LDAA  DISADD2     ;Get the end address ->X
        CMPA  DISADD1     ;Subtract current address (next opcode to process)
        BGT   LSTCKE3     ;End HI > Current Hi keep going
        LDAA  DISADD2+1
        CMPA  DISADD1+1
        BCC   LSTCKE3     ;End LO > Current LO keep going
        BRA   LISTEX
LSTCKE3 JMP   LIST02      ;   process the next opcode                            
LISTEX  RTS

;******************************************************************
;CLRDABUF
;******************************************************************
CLRDABUF LDX  #DISABUF
        LDAA  #$20
CLRDAB1 STAA  0,X
        INX
        CPX   #DISABUF+15
        BNE   CLRDAB1
        LDAA  #$00
        STAA  0,X
        LDX   #DISABUF
        STAA  DISABUFP
        RTS 

;******************************************************************
; PUTMNEM
; transfer the mnemonic for the opcode found to the disassembly buffer
; populate the parameter format that will be used
;******************************************************************
PUTMNEM LDX   #DISABUF
        STX   DISABUFP 
PUTMNE1 LDX   ROWADDH
        LDAA  0,X
        INX
        STX   ROWADDH
        LDX   DISABUFP
        STAA  0,X
        INX 
        STX   DISABUFP
        CPX   #DISABUF+4
        BNE   PUTMNE1
        
        LDAA  OPCFLAGS   ;Add 'A' or 'B' if indicated by flags
        ANDA  #$0C
        CMPA  #$04
        BNE   PUTMNE2
        LDAA  #'A'
        STAA  DISABUF+3
        JMP   PUTMNE3
PUTMNE2 CMPA  #$08
        BNE   PUTMNE3
        LDAA  #'B'
        STAA  DISABUF+3
PUTMNE3 LDAA  OPCFLAGS
        ANDA  #$30
        CMPA  #$00
        BNE   PUTMNE4
        LDAA  #$00
        STAA  DISABUF+6
        RTS         
PUTMNE4 CMPA  #$10
        BNE   PUTMNE5
        LDAA  #'#'
        STAA  DISABUF+6         
        LDAA  #'$'
        STAA  DISABUF+7
        LDAA  #$00
        STAA  DISABUF+8
        RTS
PUTMNE5 LDAA  #'$'
        STAA  DISABUF+6
        LDAA  #$00        
        STAA  DISABUF+7
        RTS

;******************************************************************
;OPCTYPE  Set OPCFLAGS indicating type, action and parm count 
;         RETURN with OPCFLAGS in A
;******************************************************************
OPCTYPE LDX   #OPCDTYPE ;Get address of OPCDTYPE lookup table in X
        LDAB  OPCD      ;Get opcode
        LSRB            ;Shift hi bits to low 4 bits 
        LSRB
        LSRB
        LSRB                        
        ANDB  #$0F      ;mask high 4 bits
        JSR   ADDB2X    ;add B to X (replaces ABX)
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
SRCHMNH LDX   #MNETBLH   ;Get Table Start Address
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
SRCHMNL LDX   #MNETBLL   ;Get Table Start Address
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
ASM2MEM LDAA  #$00        ;Reset line count
        STAA  LINECT
        
        LDX   #MSGNL
        JSR   PUTS      ;Newline
        
        LDAA  ADDRH     ;Print Address
        JSR   OUTHEX
        LDAA  ADDRL
        JSR   OUTHEX
        LDAA  #$20      ;Print a space
        JSR   OUTCHR
        
        JSR   CLRDABUF  ; Clear input buffer
        JSR   GETSTR    ; Input 1 line of text
        STX   DISABUFP  ; save buffer exit position
        LDAA  DISABUFP+1 
        CMPA  #DISABUF+3
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
        BEQ   ASM2ERX     ;if not found --> ERROR exit 
        LDAB  DISABUF+3  ;Check 4th mnemonic byte
        CMPB  #'A'
        BNE   ASM2SM1
        LDAA  6,X       ;if='A' use opcode col#2
        JMP   ASM2PR
ASM2SM1 CMPB  #'B'
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
        LDX   ADDRH     ;Store opcode..
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
        STX   ADDRH
        JMP   ASM2MEM   ; process another line of input

ASM2ERX LDX   #MSGERR   ;print ERROR message
        JSR   PUTS
ASM2END RTS

;******************************************************************
; OUTPRMS  Output values in PARMBUF move parm data to target memory 
;  Call with X=target address 
;  returns with X updated to next target address
;******************************************************************
OUTPRMS INX             ;Skip past opcode location
        LDAA  PARMLEN   ;Get Parm buffer pointer
        CMPA  #PARMBUF  ; $70 = NO PARMS
        BNE   OUTPRM1
        RTS             ; exit if no parms
OUTPRM1 LDAA  PARMBUF   ; get 1st parm byte
        STAA  0,X       ; save to target address
        INX             ; point to next address
        JSR   OUTHEX    ; print parm byte
        LDAA  #$20      ;Print a space
        JSR   OUTCHR
        LDAA  PARMLEN   ;Get Parm buffer pointer
        CMPA  #PARMBUF+4      ; $74= 2 bytes of parm data
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
CVTPRMS LDAB  PARMLEN    ;Get parm buffer pointer
        CMPB  #PARMBUF   ;$70 = NO PARMS
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
        CMPB  #PARMBUF+4   ; PARMLEN = $74 = 2 parm bytes
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
SETTYPE LDAA  PARMLEN   ;Get Parmlen  
        CMPA  #PARMBUF      ;$70 = zero length NO PARMs
        BNE   SETTYP4   
        LDAA  #$00      ;set type=0
        JMP   SETTYPA   ;Save type & exit
SETTYP4 LDAA  OPCFLAGS
        CMPA  #$04       ;Indexed flag set? (set in DESPACE)
        BNE   SETTYP1
        RTS
SETTYP1 LDAA  DISABUF+4  
        CMPA  #'#'        ;'#' indicates immediate instruction  
        BNE   SETTYP2
        LDAA  DISABUF+5  ;Next byte MUST be '$' else ERROR     
        CMPA  #'$'
        BNE   SETTYPX
        LDAA  #$01       ;set type=1
        JMP   SETTYPA        
SETTYP2 LDAA  DISABUF+4        
        CMPA  #'$'        ;If 1st byte afer mnemonic is not '#' it MUST be '$'
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
ASMSH4  JSR   ASMSH3
        CMPA  #$00
        BEQ   ASMSH4X
        LDAA  DISABUF+3
        CMPA  3,X
        BNE   ASMSH4N
        LDAA  4,X
ASMSH4X STAA  OPCD
        RTS
ASMSH4N CLC
        JSR   ADDB2X    ;add B to X (replaces ABX)
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
ASMSH3  JSR   ASMCMP3  ;compare 3 byte of mnemonic data
        BNE   ASMSH3N  ;match failed try next row
        LDAA  3,X      ;match found
ASMSH3X STAA  OPCD     ;save last matched byte in OPCD and exit A!=0 
        RTS             
ASMSH3N JSR   ADDB2X    ;add B to X (replaces ABX) Point X at start of next table row
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
ASMCMP3 LDAA  DISABUF
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
MOVPRM  LDAA  #PARMBUF        
        STAA  PARMLEN    ;Reset parm length pointer
        LDAA  #$00
        STAA  DISABUF+15  ;Make sure buffer is terminated
        LDX   #DISABUF+3  ;Set X = start of data-1
MOVPRM1 INX               ;Next byte
        LDAA   0,X        ;Get Byte
        CMPA  #$00        ;Is it = 0 (end of buffer)
        BEQ   MOVPRMX     ; Done        
        CMPA  #$2F        ;Is it < '0'
        BLS   MOVPRM1     ;Keep looking
        CMPA  #'G'        ;Is it >'F'
        BCC   MOVPRMX     ; Done 
        STX   INDEX1      ;Save X
        LDAB  PARMLEN     ;Get parm buf pointer
        CMPB  #PARMBUF+4  ;Parm Buffer Full?
        BEQ   MOVPRM3
        LDX   #$0000
        JSR   ADDB2X    ;add B to X (replaces ABX) parm buf pointer -> X
        STAA  0,X         ;Save parm byte in parm buf
        INC   PARMLEN     ;inc parmlen
        LDAA  #$00        ;Terminate parm buffer
        STAA  1,X 
MOVPRM3 LDX   INDEX1       ;restore x
        CPX   #DISABUF+16  ;end of buffer reached?
        BNE   MOVPRM1     ; keep going ... otherwise return
MOVPRMX RTS        

;******************************************************************
; DESPACE  Remove spaces from buffer  detect 'X' in buffer
;******************************************************************
DESPACE LDAA  #00
        STAA  OPCFLAGS      ;CLEAR ALL FLAGS 
        LDX   #DISABUF+4       
DSPACE1 LDAA   0,X          ;Get A Byte
        CMPA  #'X'          ;If we encounter an 'X' set bit 2 of OPCFLAGS
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
        CMPA  #$00
        BNE   DESPACX
        LDAA  #$20
        STAA  DISABUF+3  
DESPACX RTS

;******************************************************************
; SHIFTBL  Shift DISABUF left 1 position
;******************************************************************
SHIFTBL STX   INDEX1
SHFTBL1 LDAA  1,X
        STAA  0,X
        INX
        CPX   #DISABUF+15
        BNE   SHFTBL1
        LDX   INDEX1
        RTS
        
;******************************************************************
; GETSTR  Input up to 16bytes and store in DISABUF
;******************************************************************
GETSTR  LDX   #DISABUF
GETSTR1 JSR   GETBYTE       ;Get a byte
        CMPA  #$0D        ;Is It CR?  
        BEQ   GETSTRX     ; if so then exit
        CMPA  #$7F        ; Backspace?
        BNE   GETSTR2
        CPX   #DISABUF
        BEQ   GETSTR1
        DEX
        JSR   OUTCHR
        JMP   GETSTR1
GETSTR2 CMPA  #'Z'         ;  <=Z?
        BMI   GETSTR3     ; dont convert
        ANDA  #$5F        ;Convert to UPPERCASE
GETSTR3 JSR   OUTCHR      ;echo it
        STAA  0,X         ; Save the byte
        INX               ;Inc buffer pointer
        CPX   #DISABUF+16  ;Buffer Full?
        BNE   GETSTR1     ; If not then get another byte else exit
GETSTRX LDAA  #$00        ; Terminate buffer with $00
        STAA  0,X
        RTS
;*************************************
; ADDB2X
; Use in place of ABX instruction
;*************************************
ADDB2X  PSHB            ; Save B
        STX   INDEX2    ; X -> INDEX1
        ADDB  INDEX2+1  ;Add X-LOW to B 
        STAB  INDEX2+1  ;Put Results in INDEX1_LO
        BCC   ADDB2X1   ;Overflow?  
        INC   INDEX2    ;Add 1 to INDEX1_HI
ADDB2X1 LDX   INDEX2    ;Load X with results
        PULB            ;Restore B
        RTS 

;*************************************
; NMI Interrupt Service Routine every 5ms
;*************************************
NMIISR  INC  CNTR5MS+1
        BNE  NMIISRX
        INC  CNTR5MS
NMIISRX RTI           
        
;*************************************
; Messages
;*************************************
BOOTMSG  FCB  $0D,$0A  
         FCC  "** 6800 CPU Board ROM V03.4 11/30/17 **"
         FCB  $0D,$0A,$00
MSGMENU  FCB  $0D,$0A
         FCC  " ** 6800 MPU Main Menu **"
         FCB  $0D,$0A
         FCC  " d  Dump 16 Bytes        D  Dump 256 Bytes"
         FCB  $0D,$0A
         FCC  " S  Set Memory           F  Fill Memory"
         FCB  $0D,$0A
         FCC  " T  Text to Memory     G/g  Execute"
         FCB  $0D,$0A
         FCC  " B/b BASIC               N  Beep"
         FCB  $0D,$0A
         FCC  " L  List(Dis-Assemble)   A  Assemble"
         FCB  $0D,$0A
         FCC  " Z  Blink LEDs           M/m Re-Display Menu"
         
MSGNL    FCB  $0D,$0A,$00         
MSGOK    FCB  $0D,$0A,$4F,$4B,$0D,$0A,$00   ;CRLF OK CRLF
MSGERR   FCB  $0D,$0A
         FCC  "ERROR"
         FCB  $0D,$0A,$00
MSGENTA  FCC  " Enter Address:"
         FCB  $00 
MSGSTART FCB $0A,$0D
         FCC " Enter Start Address:"
         FCB $00
MSGENDAD FCB $0A,$0D
         FCC " Enter End   Address:"
         FCB $00   
MSGVAL   FCC " Value:"
         FCB  $00                
MSGATNR  FCC  "$$$"
         FCB  $00 
MSGBASIC FCB $0A,$0D
         FCC "  NAM MICRO  MICROBASIC  V2.3A"
         FCB  $0D,$0A,$00 


    ORG $EB00          ;**** BASIC on even page address *****

;*******************************************************
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
;* Updated for 6800 Board by Eric M. Klaus  11/28/2017
;**********************************************************
MAXLIN    EQU    $72	 ; dc.b 72     ; Max Line Length
BACKSP    EQU    $7F	 ; dc.b $7F    ;// EMK puTTY backspace = 127
CANCEL    EQU    $1B	 ; dc.b $1B    ;// EMK Use ESC as cancel
       
;  **** ORG $0120  *** MEMORY VARIABLES *****
LOCAL     EQU    $01     ;Make this match Temp storage High Byte Address
INDEX_1   EQU    $0120     
INDEX_2   EQU    $0122
INDEX_3   EQU    $0124	  
INDEX_4   EQU    $0126	  
SAVEXP    EQU    $0128	  
NEXTBA    EQU    $012A	 ;  dc.w END  
WORKBA    EQU    $012C	 ;  dc.w END  
SOURCE    EQU    $012E	 ;  dc.w END  
PACKLN    EQU    $0130	  
HIGHLN    EQU    $0132	  
BASPNT    EQU    $0134	  
BASLIN    EQU    $0136	  
PUSHTX    EQU    $0138	  
XSTACK    EQU    $013A	 ; dc.w $707F 
RNDVAL    EQU    $013C	  
DIMPNT    EQU    $013E	  
DIMCAL    EQU    $0140	  
PRCNT     EQU    $0142	 ; Print counter
MEMEND    EQU    $0146	 ; dc.w $6FFF 	;FDB $1FFF 			#### /DTU
ARRTAB    EQU    $0148	  
KEYWD     EQU    $014A	  
TSIGN     EQU    $014C	   
NCMPR     EQU    $014D	   
TNUMB     EQU    $014E	   
ANUMB     EQU    $014F	   
BNUMB     EQU    $0150	   
AESTK     EQU    $0151	 ; dc.w ASTACK 
FORPNT    EQU    $0153	 ; dc.w FORSTK 
VARPNT    EQU    $0155	 ; dc.w VARTAB 
SBRPNT    EQU    $0157	 ; dc.w SBRSTK 
SBRSTK    EQU    $0159	   
FORSTK    EQU    $0169	 
DIMVAR    EQU    $0199	 ;dc.w VARTAB      
BUFNXT    EQU    $01AC	 ;dc.w $00B0 
ENDBUF    EQU    $01AE	 ;dc.w $00B0
BUFFER    EQU    $01B0	 
VARTAB    EQU    $0200	 
ASTACK    EQU    $028C
INDEX_5   EQU    $028E
INDEX_6   EQU    $0290
PUSHXP    EQU    $0292
SRCHPA    EQU    $0294
SRCHPB    EQU    $0296
DESTPA    EQU    $0298
DESTPB    EQU    $029A

BASICTOP	EQU    $02B0   ;Use this in ROM implementation	 
          
;;     ORG $C000
       
COLDST  LDX  #INDEX_1
        CLRA
CLRVMEM STAA 0,X
        INX
        CPX  #ASTACK
        BNE  CLRVMEM
        
INITVM  LDX  #BASICTOP     ;Init the menory variables(USE #BASICTOP for ROM version $03B0)
        STX  NEXTBA          
        STX  WORKBA          
        STX  SOURCE        
        LDX  #$077F         ;Was $707F, $D07f
        STX  XSTACK        
        LDX  #$06FF         ;Was $6FFF  $CFFF
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
        LDX  #BUFFER 
        STX  BUFNXT         
        STX  ENDBUF        
        
PROGM   JMP  START		;	Start Basic
COMMAN  FCC "RUN"
        FCB $1E
        FDB RUN
        FCC "LIST"
        FCB $1E
        FDB CLIST 
        FCC "NEW"
        FCB $1E
        FDB START
        FCC "PAT"
        FCB $1E
        FDB PATCH
        FCC "SYS"
        FCB $1E
        FDB SYSCALL
        FCC "PEEK"
        FCB $1E
        FDB DOPEEK        
        FCC "POKE"
        FCB $1E
        FDB DOPOKE        
GOLIST  FCC "GOSUB"
        FCB $1E
        FDB GOSUB
        FCC "GOTO"
        FCB $1E
        FDB GOTO
        FCC "GO TO"
        FCB $1E
        FDB GOTO
        FCC "SIZE"
        FCB $1E
        FDB SIZE
        FCC "THEN"
        FCB $1E
        FDB IF2
        FCC "PRINT"
        FCB $1E
        FDB PRINT
        FCC "LET"
        FCB $1E
IMPLET  FDB LET
        FCC "INPUT"
        FCB $1E
        FDB INPUT
        FCC "IF"
        FCB $1E
        FDB IF
        FCC "END"
        FCB $1E
        FDB READY
        FCC "RETURN"
        FCB $1E
        FDB RETURN
        FCC "DIM"
        FCB $1E
        FDB DIM
        FCC "FOR"
        FCB $1E
        FDB FOR
        FCC "NEXT"
        FCB $1E
        FDB NEXT
        FCC "REM"
        FCB $1E
        FDB REMARK
PAUMSG  FCC "PAUSE"
        FCB $1E
        FDB PAUSE
        FCB $20
COMEND  FCB $1E
        FDB LET
        
RDYMSG  FCB $0D
        FCB $0A
        FCC "READY"
        FCB $1E
PROMPT  FCB $23
        FCB $1E
        FCB $1E
PGCNTL  FCB $10
        FCB $16
        FCB $1E
        FCB $1E
        FCB $1E
ERRMS1  FCC "ERROR# "
        FCB $1E
ERRMS2  FCC " IN LINE "
        FCB $1E

        ; *** SUBROUTINE KEYBD  GET Keyboard Input  ***
KEYBD   LDAA #$3F         ; Print "?"
        BSR OUTCH
KEYBD0  LDX #BUFFER       ; X= Start of input buffer
        LDAB #10          ; B=10
KEYBD1  BSR INCH          ; Wait for 1 byte of keyboard input
        CMPA #$00         ; Is it Break ?  Timeout? 
        BNE KEYB11        ; NO = Continue
        DECB              ; Count it ...
        BNE KEYBD1	      ; If we don't have 10 then continue - otherwise  
KEYB10  JMP READY         ; Warm start - wait for new input line
KEYB11  CMPA #CANCEL      ; Is it Cancel? (Esc)
        BEQ DEL           ; Yes = Discard all input and keep waiting
        CMPA #$0D         ; Is it Enter?
        BEQ IEXIT         ; YES = Exit
KEYBD2  CMPA #$0A         ; Is it LF?
        BEQ KEYBD1        ; Ignore
        CMPA #$15         ; Is it  NAK ?
        BEQ KEYBD1        ; Ignore
        CMPA #$13         ; Is it DC3?
        BEQ KEYBD1        ; Ignore
KEYB55  CMPA #BACKSP      ; Is it Backspace?
        BNE KEYBD3        ; No = Continue
        CPX #BUFFER       ; Yes = process Backspace
        BEQ KEYBD1        ; If At startof buffer just ignore BS 
        DEX               ; Back up X
        BRA KEYBD1        ; Continue waiting...
KEYBD3  CPX #BUFFER+71    ; End of input buffer reached?
        BEQ KEYBD1        ; Ignore input, keep waiting for input...
        STAA 0,X          ; Save the input byte
        INX               ; Inc pointer
        BRA KEYBD1        ; Keep waiting for input...
        
DEL     BSR CRLF          ;Print Newline
CNTLIN  LDX #PROMPT       ;Print "#"
        BSR OUTNCR
        BRA KEYBD0        ;Clear input and keep waiting....
          
IEXIT   LDAA #$1E         ;Got Enter key   
        STAA ,X           ; store EOT marker $1E
        STX ENDBUF        ; Save End of input in ENDBUF
        BSR CRLF          ;Print Newline and exit
        RTS               

OUTCH   JSR CHKBRK	     ; Test for key press otherwise output 1 byte
ECHO    JMP OUTCHR       

INCH    JSR  GETBYTE     ; * SUBROUTINE INCH  get 1 byte of keyboard input ***
        CMPA #CANCEL     ; ESC = EXIT
        BNE  ECHO        ; Otherwise print it and return
        RTS

                                 
OUTPUT  BSR  OUTNCR  ;Send chars based on X, to terminal until $1E is encountered
        BRA  CRLF    ;Output Newline and return

OUTPU2  BSR  OUTCH   ; Output 1 byte 
OUTPU3  INX          ; Advance byte pointer
OUTNCR  LDAA 0,X     ; Get byte pointed to by X
        CMPA #$1E    ; EOL?
        BNE  OUTPU2  ; NO = Output It
        RTS          ; YES = Return

CRLF    BSR PUSHX    ; * SUBROUTINE CRLF * Send CR & LF (X is retained)
        LDX #CRLFST
        BSR OUTNCR
        BSR PULLX
        RTS

CRLFST  FCB $0D      ; CR LF + EOL storage
        FCB $0A
CREND   FCB $1E
        FCB $FF,$FF
        FCB $FF,$FF
        FCB $1E
        
PUSHX   STX PUSHTX      ;PUSH X into  XSTACK  (A & X unchanged) 
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

STORE   PSHA           ; subroutine:STORE A & B at address from AESTK
        PSHB           ;Save A & B
        BSR PUSHX      ;Save X in XSTACK
        JSR PULLAE     ;Get A & B from AESTK 
        LDX AESTK      ;Increment AESTK pointer
        INX            
        INX
        STX AESTK
        DEX            ;X= Original AESTK pointer+1
        LDX 0,X        ;Get X from AESTK
        STAA 0,X       ;STORE A
        STAB 1,X       ;STORE B
        BSR PULLX      ;Restore X,B,A and return
        PULB
        PULA
        RTS

IND     BSR PUSHX      ; subroutine: PUSH 16bit value pointed by AESTK onto AESTK
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

LIST    LDX NEXTBA    ; SUBROUTINE LIST 
        STX WORKBA    ; WORKBA = NEXTBA (End of code buffer)
        LDX SOURCE    ; X = SOURCE (Start of code buffer)
        BRA LIST1
LIST0   LDX INDEX_3   ; Get X from INDEX_3 (enter here to list a specific line#)
LIST1   CPX WORKBA    ; X= End of code buffer?
        BEQ LEXIT     ; YES = EXIT 
        BSR OUTLIN    ; NO= Output 1 line of code 
        INX           ; X=X+1
        BRA LIST1     ; Keep Going until X=WORKBA
LEXIT   RTS

OUTLIN  LDAA 0,X      ; SUBROUTINE OUTLIN Output 1 line of code (call with X=start of code line)
        CLR PRCNT     ; Reset print column counter
        INX           ; X=X+1
        LDAB 0,X      ; Get Line# (Low Byte)
        INX
        CLR TSIGN
        JSR PRN0       ;Print Line#
        BSR PRINSP     ;Print a space
OUTLI1  LDAA 0,X       ;Get Keyword Token
        INX
        JSR PUSHX      ;Save X
        LDX #COMMAN    
        STX KEYWD      ;KEYWD = Start of Table
        STAA KEYWD+1   ;KEYWD Low byte = keyword token (offset into table)
        LDX KEYWD      ;X = Address of Keyword execution address
        DEX
OUTLI2  DEX            ;X = Address of end of keyword text
        LDAA 0,X       ;Get 1 byte of keyword text
        CMPA #$1E      ;EOL?
        BNE OUTLI2     ; NO = Continue search for start of keyword text... 
        INX            ; Yes = skip X past EOL & address pointer
        INX
        INX             
        JSR OUTNCR     ; Print byte till EOL. (NO CR)
        JSR PULLX      ; Restore X
        JMP OUTPUT     ; Advance X and print newline then exit.

PRINSP  PSHA         ;SUBROUTINE Print a space (A is unchanged)
        LDAA #$20
        JSR OUTCH
        PULA
        RTS

RANDOM  INX
        INX
        LDAA 0,X
        CMPA #'D'
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
        STX  INDEX_1
        LDAA INDEX_1
        LDAB INDEX_1+1
        JMP   TSTV9

TSTV    JSR   SKIPSP
	      JSR   CHKBRK              ;JSR BREAK			#### /DTU
        JSR   TSTLTR
        BCC   TSTV1
        RTS

TSTV1   CMPA #'R'
        BNE TSTV2
        LDAB 1,X
        CMPB #'N'
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
        CMPA #'('
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
        CMPA #','
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
TSTV8   CMPA  #')'
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

PULPSH  BSR PULLAE        ;PULL A & B from AESTK without removing the values
PUSHAE  STX SAVEXP        ;PUSH A & B onto AESTK (Using SP as 16bit pointer)
        LDX AESTK         ;AESTK -> X
        STAB 0,X          ;Save B
        DEX
        STAA 0,X          ;Save A
        DEX
        STX AESTK         ;Save new pointer to AESTK
        LDX SAVEXP        ;Restore original X
        RTS

PULLAE  STX SAVEXP        ;PULL A & B from AESTK (Using SP as 16bit pointer)
        LDX AESTK         ;AESTK -> SP
        INX
        LDAA 0,X          ;Get A
        INX
        LDAB 0,X          ;Get B
        STX AESTK         ;Save new pointer to AESTK
        LDX SAVEXP        ;Restore original X
        RTS

FACT    JSR SKIPSP
        JSR TSTV
        BCS FACT0
        JSR IND
        RTS

FACT0   JSR TSTN
        BCS FACT1
        RTS

FACT1   CMPA #'('
        BNE FACT2
        INX
        BSR  EXPR
        JSR  SKIPSP
        CMPA #')'
        BNE FACT2
        INX
        RTS

FACT2   LDAB #13
        JMP  ERROR

TERM    BSR  FACT
TERM0   JSR SKIPSP
        CMPA #'*'
        BNE TERM1
        INX
        BSR FACT
        BSR MPY
        BRA TERM0

TERM1   CMPA #'/'
        BNE TERM2
        INX
        BSR FACT
        JSR DIV
        BRA TERM0

TERM2   RTS

EXPR    JSR SKIPSP
        CMPA #'-'
        BNE EXPR0
        INX
        BSR TERM
        JSR NEG
        BRA EXPR1
EXPR0   CMPA #'+'
        BNE EXPR00
        INX
EXPR00  BSR TERM
EXPR1   JSR SKIPSP
        CMPA #'+'
        BNE EXPR2
        INX
        BSR TERM
        JSR ADD
        BRA EXPR1
EXPR2   CMPA #'-'
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
FINDN1  LDX  SOURCE    ;X = Start of code buffer
FIND0   JSR  PULPSH    ;Save A & B
        SUBB 1,X
        SBCA 0,X
        BCS  FIND3     ;Found A Line# > Search value
        BNE  FIND1     ;Current Line Not = Search Value 
        TSTB           ;
        BEQ  FIND4     ;Search line# found (return C=0) 
FIND1   INX
FIND2   BSR  INXSKP     ;Advance X to next non-space character
        CMPA #$1E       ; EOL?
        BNE  FIND2      ; NO = Keep looking
        INX             ; Yes = Skip past it
        CPX NEXTBA      ; X = NEXTBA
        BNE FIND0       ; NO = Keep looking...
HIBALL  LDX  NEXTBA     ; X = Next Line
FIND3   SEC             ; Line# NOt Found (C=1)
FIND4   STX WORKBA      ; Save code buffer position 
        JSR PULLAE      ; Restore A & B
        RTS             ; Return

SKIPSP  LDAA 0,X         ;Get the next non-space character (advances X)
        CMPA #$20
        BNE  SKIPEX
INXSKP  INX              ; Point to next byte
        BRA SKIPSP       ; Skip X past spaces
SKIPEX  RTS              ; Return

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

                     ; ** SUBROUTINE CCODE lookup keyword in COMMAN table **
                     ;*   Return with X=pointer to function execution address              
                     ;*   If command not found then point to LET command. 
                     ;*   Updates BUFNXT and BASPNT
                     ;* //EMK: modified to eliminate use of SP as 16bit pointer
CCODE   BSR SKIPSP     ; Skip X past leading spaces
        DEX            ; Back up One byte
        STX INDEX_4    ; Save X (points to start of non-blank input)
        LDX #COMMAN-1  ; X= Start of lookup table   
LOOP3   LDAA  INDEX_4   ; SRCHPB = Keyword input Buffer pointer
        STAA  SRCHPA
        LDAA  INDEX_4+1
        STAA  SRCHPA+1
LOOP4   INX            ; X=X+1
        JSR   SRCHAI   ; Inc pointer and Get 1 input buffer byte -> A
        LDAB 0,X       ; Get 1 Lookup Table byte -> B
        CMPB #$1E      ; EOL?
        BEQ LOOP7      ; YES = GOTO Found Keyword 
        CBA            ; B=A?
        BEQ  LOOP4     ; Yes = Continue...
LOOP5   INX            ; X=X+1
        CPX #COMEND    ; End of Table? (Keyword Not Found)
        BEQ CCEXIT     ; YES = Exit using implied LET command 
        LDAB 0,X       ; No = Continue.. Get 1 Lookup Table byte -> B
        CMPB #$1E      ; EOL?
        BNE  LOOP5     ; No = Continue...
LOOP6   INX            ; YES = X=X+2
        INX
        BRA LOOP3      ; Compare input buffer to next keyword in table..
        
LOOP7   INX            ; Keyword Found point to keyword execution address
        STX SAVEXP     ; Save X
        LDX SRCHPA     ; Get Buffer search index -> X
        STX BUFNXT     ; X -> Next buffer search location BUFNXT
        STX BASPNT     ; X -> BASPNT (temp storage??)
        LDX SAVEXP     ; Restore X (keyword execution address)
LOOP8   RTS 
            

CCEXIT  LDX #BUFFER    ; Keyword NOT Found.  EMK  - Command lookup failed - Reset BASPNT 
        STX BASPNT     ;EMK
        LDX #IMPLET    ;Command lookup failed - Use LET
        RTS
                       ; ***** BASIC Cold Start ***** 
START   LDX SOURCE     ;Reset pointer to start of source workspace  ($03B0)
        STX NEXTBA
        STX WORKBA
        STX ARRTAB
        DEX
        CLRA
START2  INX            ;Fill workspace with zeros
        STAA 0,X
        CPX MEMEND     ;$06FF
        BNE  START2
START1  CLRA           ;Reset Line# pointers & counters 
        STAA PACKLN
        STAA PACKLN+1
        STAA PRCNT       ;Reset Print counter
        LDX PACKLN
        STX HIGHLN
        
READY   LDS #$07FF       ;WARM START HERE  *Was $7045, $D045
        LDX #RDYMSG      ; Print "READY"
        JSR OUTPUT
                         ; ** NEWLIN ** Get a new line of input from user
NEWLIN  LDS #$07FF       ;Reset Stack Pointer   *Was $7045
        LDX #$077F       ;                      *Was $707F
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
        JSR CCODE      ;Lookup Command, return with X=address that holds execution address  
        LDX 0,X        ;X = execution address
        JMP  0,X       ;Jump to execution addtess

ERROR   LDS #$07FF     ;Reset Stack Pointer   *Was $7045
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
        CMPA #LOCAL      ;// EMK changed due to Relocation of zero page storage: 
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
        LDX #$077F            ;Was $707F
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
        STX INDEX_3
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
        STX   SAVEXP
        SEI              ;Disable interrupts
        LDS   #$07FF     ;Set Stack Pointer (top of external RAM - 16bytes)
        JMP   RESET     ;EXIT & RESTART 6800 Board (in ROM code use RESET)
        
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
                         ;***** POKE(aaaa,A) ************** /EMK
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
        
DELREP  LDX BUFNXT       ;Delete or Replace input line
        JSR SKIPSP
        CMPA #$1E        ;Line# with no data following it?
        BNE REPLAC       ; NO= Do Replace  YES = Do Delete
        LDX NEXTBA         
        CPX SOURCE       ;If No lines entered yet, just exit
        BEQ NEXIT        ; Otherwise DELETE
        BSR DELETE       ;   Delete existing line
        BRA NEXIT        ;   Goto NEWLIN (input a new line) 

REPLAC  BSR DELETE       ;Replace Existing line  (First Delete Existing line)
        BSR INSERT       ; Then Insert a new line
NEXIT   JMP NEWLIN       ; GOTO NEWLIN  (input a new line)

CAPPEN  BSR INSERT       ; Insert a new Line
        LDX PACKLN       ; Get PACKLN
        STX HIGHLN       ; Store To HIGHLN
        BRA NEXIT        ; Goto NEWLIN (input a new line)
        
DELETE  LDX NEXTBA      ; SUBROUTINE: Delete existing program line 
        STX SRCHPA      ; NEXTBA -> SRCHPA  Start of next available line storage (END of LAST Line of code) 
        LDX WORKBA      ; X = Start of line of code to DELETE
        LDAB #2         ; B=2
        INX
        INX             ; Skip X past Line# (X=X+2)
        JSR  DECSCHA    ; 
        JSR  DECSCHA    ; Decrement SRCHPA 2x 
                        ;[This llop measures the sixe of code to move up -> B]
DEL2    LDAA  0,X       ; A=byte from code buffer 
        JSR  DECSCHA    ; Decrement SRCHPA
        INX             ; X=next byte of code
        INCB            ; B=B+1
        CMPA #$1E       ; EOL ? 
        BNE DEL2        ; NO Keep Looking...
        
        LDX SRCHPA      ; X = SRCHPA
        STX NEXTBA      ; NEXTBA Now = Start of just deleted line 
        STX ARRTAB      ; ARRTAB = NEXTBA (temp storage?)
        LDX WORKBA      ; X= Start of LAST line of code  (B=Length of last line of code)
        ;STAB DEL5+1      ;Writes B to Program Memory. Not ROM friendly
DEL4    CPX  NEXTBA     ; Start = End?
        BEQ  DELEX      ; DONE? YES=GOTO EXIT
        
        STX  SAVEXP     ;EMK  Save X
        JSR  ADDB2X     ;EMK  X=B+X  (replaces ABX) (X=WORKBA + LINE LENGTH) 
DEL5    LDAA 0,X        ; Get Source Byte (X + B = Dest + OFFSET) 
        LDX  SAVEXP     ;EMK  Restore Old X
        STAA 0,X        ;  Store  in Dest (X without offset)
        INX             ; X=X+1
        BRA DEL4        ; Continue...

DELEX   RTS             ; Return
        
                        ; ** Subroutine: Insert a line  ***
INSERT  LDX BUFNXT      ; X = KEYWORD Search location in BUFFER   
        JSR  CCODE      ;Lookup Connamd, returns X=address of pointer to execution address
INS1    STX  KEYWD      ;KEYWD = Result of call to CCODE  (pointer to execution address)
        LDAB ENDBUF+1   ; B= End of Input Buffer
        SUBB BUFNXT+1   ; Subtract pointer to byte after keyword
        ADDB #$04       ; Add 4 bytes to accomodate Line#, token and EOL
        ;STAB OFFSET+1         ;Writes B to Program Memory. Not ROM friendly
        STAB INDEX_2    ;EMK   Save B  (Size of parameter data +4) 
        CLC                    
        ADDB NEXTBA+1      ;Add NEXTBA (low) to B (Size of parameter data +4)
        LDAA #$00
        ADCA NEXTBA        ;A= High Byte of NEXTBA adjusted for carry
        CMPA MEMEND        ;OUT of MEMORY?
        BHI  OVERFL        ;ERROR #14
        STAB NEXTBA+1      ; Otherwise Save B-> NEXTBA (low byte)
        STAA NEXTBA        ;           Save A-> NEXTBA (high byte)
        LDX  NEXTBA        ; X = Next Line Storage Location
        STX  ARRTAB        ; ARRTAB =  Next Line Storage Location (temp save??)
INS2    CPX  WORKBA       ;Done?   
        BEQ BUFWRT        ;YES = Write Buffer to code storage
        DEX               ;NO X=X-1  
        LDAA 0,X          ;Get Source Byte 
        STX  INDEX_1        ;EMK     Save X
        STAB INDEX_6        ;EMK     Save B
        LDAB INDEX_2        ;EMK     B = Saved B
        JSR  ADDB2X         ;EMK     X=X+B  Replaces ABX
OFFSET  STAA 0,X          ;Store in destination
        LDX  INDEX_1        ;EMK     Restore X
        LDAB INDEX_6        ;EMK     Restore B
        BRA  INS2        ; Loop until X=WORKBA..
        
BUFWRT  LDX  BUFNXT      ; GET BUFNXT (Input buffer pointer)
        DEX              ; Back up 1 (we will increment in call to SRCHAI)
        STX  SRCHPA      ; BUFNXT-1 -> SRCHPA
        LDX  WORKBA      ; X= Next Available storage location
        LDAA PACKLN      ;A = Line# (high)
        STAA 0,X         ;Store
        INX
        LDAA PACKLN+1    ;A= Line# (low)
        STAA 0,X         ;Store
        INX
        LDAA KEYWD+1     ;A= TOKEN
        STAA 0,X         ;Store
        INX
BUF3    JSR  SRCHAI      ;Increment pointer and Get input data
        STAA 0,X         ;Store in code buffer
        INX
        CMPA #$1E        ;EOL?
        BNE BUF3         ;NO = Continue
        RTS              ;Exit

OVERFL  LDAB #14         ;OUT of Memory Error
        JMP ERROR
        
                         ;SUBROUTINE: Execute a BASIC Statement
BASIC   LDX BASLIN       
        CPX NEXTBA       ;Last Line of code?
        BNE BASIC1       ;NO = Process It
BASIC0  JMP READY        ;Otherwise Print Ready and pronpt for more input...

BASIC1  LDAA BASLIN      ; TST BASLIN  //EMK This change due to relocation: ORG $20 -> ORG $220
        CMPA #LOCAL      ; // EMK If local variables are moved to a different page this must change as well
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
        STX INDEX_1
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
        LDX INDEX_1
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
        CMPA #','
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
        CMPA #'-'
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
INNERR  LDAB #2             ;Return ERROR #2
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
        CMPA #'"'
        BNE PRINT4
        INX
PRINT1  LDAA 0,X
        INX
        CMPA  #'"'
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
        CMPA #';'
        BEQ PRINT5
        JSR CRLF
        CLR PRCNT
PRINT5  INX
        STX BASLIN
        JMP BASIC
PRINT6  CMPA #'T'
        BNE PRINT8
        LDAB 1,X
        CMPB #'A'
        BNE PRINT8
        INX
        INX
        LDAA 0,X
        CMPA #'B'
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
        CMPA #','
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
PRIN99  CMPA #';'
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
        LDAA #'-'
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

KIOK    FDB 10000
        FDB 1000
        FDB 100
        FDB 10
        FDB 1

LET     LDX BASPNT
        JSR TSTV
        BCC LET1
LET0    LDAB #12
LET00   JMP  ERROR
LET1    JSR  SKIPSP
        INX
        CMPA #'='
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
        CMPA #'('
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
        CMPA #','
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
        CMPA #')'
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
        CMPA #','
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
        CMPA #'='
        BEQ  FOR3
FOR2    JMP  LET2
FOR3    JSR EXPR
        JSR STORE
        INX
        CMPA #'T'
        BNE FOR2
        LDAA 0,X
        INX
        CMPA #'O'
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
        CMPA #'='
        BNE RELOP0
        LDAA #0
        RTS
RELOP0  LDAB 0,X
        CMPA #'<'
        BNE RELOP4
        CMPB #'='
        BNE RELOP1
        INX
        LDAA #2
        RTS
RELOP1  CMPB #'>'
        BNE RELOP3
RELOP2  INX
        LDAA #3
        RTS
RELOP3  LDAA #1
        RTS
RELOP4  CMPA #'>'
        BEQ REL44
        LDAB #6
        JMP ERROR
REL44   CMPB  #'='
        BNE RELOP5
        INX
        LDAA #5
        RTS
RELOP5  CMPB #'<'
        BEQ RELOP2
        LDAA #4
        RTS

CMPR    LDAA  NCMPR
        ASLA
        ASLA
        PSHB
        TAB
        LDX #CMPR1
        JSR ADDB2X      ;(replaces ABX)
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
;CHKBRK	RTS
CHKBRK	PSHA
        JSR   TESTKEY
	      BNE	  CHKNBRK
        JSR   GETBYTE 
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
        CMPA  #LOCAL     ;If BASPNT=$02 then executing command directly
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
GETVALU STX   SAVEXP
        JSR   GETVARA
        LDAA  0,X
        LDX   SAVEXP
        RTS
;********************************************************************
;SETVALU Set the LOW 8bit Value of the variable name(A-Y) from A = B 
;********************************************************************
SETVALU STX   SAVEXP
        JSR   GETVARA
        STAB  0,X
        LDX   SAVEXP
        RTS

;*************************************
; SRCHA
; Get the byte pointed to by SRCHPA in A
; Optionally Increment SRCHPA first
;*************************************
SRCHAI  JSR   INCSCHA   ; Increment 16 bit pointer SRCHPA
SRCHA   STX   PUSHXP    ; Save X
        LDX   SRCHPA    ; SRCHPA->X
        LDAA  0,X       ; Get Value -> A
        LDX   PUSHXP    ; Restore X
        RTS
 
; SUBROUTINE Increment 16bit pointer SRCHPA          
INCSCHA INC   SRCHPA+1
        BNE   IECSHAX
        INC   SRCHPA
IECSHAX RTS

; SUBROUTINE Decrement 16bit pointer SRCHPA
DECSCHA SEC 
        TST   SRCHPA+1
        BNE   DECSHA1       
        DEC   SRCHPA
DECSHA1 DEC   SRCHPA+1       
        RTS
        
ENDBASIC NOP         
;***********************************************************************
;******************************************************************  
        ORG  $FB00    ; ##RAM## Opcode Type Lookup Table (fixed ROM addr. $FB00)
;******************************************************************
OPCDTYPE   FCB $00,$00,$21,$00,$04,$08,$31,$22,$11,$21,$31,$22,$11,$21,$31,$22
OPCDEXCP   FCB $62,$83,$8C,$8E,$C3,$CC,$CE,$00

        ORG  $FB20    ; Mnemonic Lookup Table   0x02A5 (677)bytes  $FB20-$FD72
;******************************************************************
;Mnemonic Lookup Table High Opcodes x40-xFF    (fixed ROM addr. $FB20)
;******************************************************************
MNETBLH     FCC "ADCA"
            FCB $89,$99,$A9,$B9
            FCC "ADCB"
            FCB $C9,$D9,$E9,$F9
            FCC "ADDA"
            FCB $8B,$9B,$AB,$BB
            FCC "ADDB"
            FCB $CB,$DB,$EB,$FB
            FCC "ADDD"
            FCB $C3,$D3,$E3,$F3            
            FCC "ANDA"
            FCB $84,$94,$A4,$B4
            FCC "ANDB"
            FCB $C4,$D4,$E4,$F4            
            FCC "BITA"
            FCB $85,$95,$A5,$B5                        
            FCC "BITB"
            FCB $C5,$D5,$E5,$F5                        
            FCC "BSR "
            FCB $8D,0  ,0  ,0                          
            FCC "CMPA"
            FCB $81,$91,$A1,$B1                        
            FCC "CMPB"
            FCB $C1,$D1,$E1,$F1                        
            FCC "CPX "
            FCB $8C,$9C,$AC,$BC                        
            FCC "EORA"
            FCB $88,$98,$A8,$B8                        
            FCC "EORB"
            FCB $C8,$D8,$E8,$F8                        
            FCC "JSR "
            FCB $01,$9D,$AD,$BD                          
            FCC "LDAA"
            FCB $86,$96,$A6,$B6                        
            FCC "LDAB"
            FCB $C6,$D6,$E6,$F6                        
            FCC "LDS "
            FCB $8E,$9E,$AE,$BE                        
            FCC "LDX "
            FCB $CE,$DE,$EE,$FE                        
            FCC "ORAA"
            FCB $8A,$9A,$AA,$BA                        
            FCC "ORAB"
            FCB $CA,$DA,$EA,$FA                        
            FCC "SBCA"
            FCB $82,$92,$A2,$B2                        
            FCC "SBCB"
            FCB $C2,$D2,$E2,$F2                        
            FCC "STAA"
            FCB $01,$97,$A7,$B7                          
            FCC "STAB"
            FCB $01,$D7,$E7,$F7                          
            FCC "STD "
            FCB $01,$DD,$ED,$FD                          
            FCC "STS "
            FCB $01,$9F,$AF,$BF                          
            FCC "STX "
            FCB $01,$DF,$EF,$FF                          
            FCC "SUBA"
            FCB $80,$90,$A0,$B0                        
            FCC "SUBB"
            FCB $C0,$D0,$E0,$F0                        
            FCB 0,0,0,0,0,0,0,0
;******************************************************************            
; MNETBLM   Mnemonic Table M      (exception opcodes)     
;******************************************************************            
MNETBLM     FCC "CLR "
            FCB $6F,$7F,$4F,$5F            
            FCC "COM "
            FCB $63,$73,$43,$53                        
            FCC "NEG "
            FCB $60,$70,$40,$50                        
            FCC "DEC "
            FCB $6A,$7A,$4A,$5A                        
            FCC "INC "
            FCB $6C,$7C,$4C,$5C                        
            FCC "ROL "
            FCB $69,$79,$49,$59                        
            FCC "ROR "
            FCB $66,$76,$46,$56                        
            FCC "ASL "
            FCB $68,$78,$48,$58                        
            FCC "ASR "
            FCB $67,$77,$47,$57                        
            FCC "LSR "
            FCB $64,$74,$44,$54                        
            FCC "TST "
            FCB $6D,$7D,$4D,$5D                        
            FCC "JMP "
            FCB $6E,$7E,$7E,$7E                          
            FCB 0,0,0,0,0,0,0,0
;******************************************************************
;MNETBLL   Mnemonic Table L  Opcodes x01-x3F   (0 or 1 parm)
;******************************************************************
MNETBLL     FCC "ABA "
            FCB $1B            
            FCC "ABX "
            FCB $3A                        
            FCC "BCC "
            FCB $24                        
            FCC "BCS "
            FCB $25                        
            FCC "BEQ "
            FCB $27                        
            FCC "BGE "
            FCB $2C                        
            FCC "BGT "
            FCB $2E                        
            FCC "BHI "
            FCB $22                        
            FCC "BLE "
            FCB $2F                        
            FCC "BLS "
            FCB $23                        
            FCC "BLT "
            FCB $2D                        
            FCC "BMI "
            FCB $2B                        
            FCC "BNE "
            FCB $26                        
            FCC "BPL "
            FCB $2A                        
            FCC "BRA "
            FCB $20                        
            FCC "BRN "
            FCB $21                        
            FCC "BVC "
            FCB $28                        
            FCC "BVS "
            FCB $29                        
            FCC "CBA "
            FCB $11                        
            FCC "CLC "
            FCB $0C                        
            FCC "CLI "
            FCB $0E                        
            FCC "CLV "
            FCB $0A                        
            FCC "DAA "
            FCB $19                        
            FCC "DES "
            FCB $34                        
            FCC "DEX "
            FCB $09                        
            FCC "INS "
            FCB $31                        
            FCC "INX "
            FCB $08                        
            FCC "NOP "
            FCB $01                        
            FCC "PSHA"
            FCB $36                        
            FCC "PSHB"
            FCB $37                        
            FCC "PULA"
            FCB $32                        
            FCC "PULB"
            FCB $33                        
            FCC "RTI "
            FCB $3B                        
            FCC "RTS "
            FCB $39                        
            FCC "SBA "
            FCB $10                        
            FCC "SEC "
            FCB $0D                        
            FCC "SEI "
            FCB $0F                        
            FCC "SEV "
            FCB $0B                        
            FCC "SWI "
            FCB $3F                        
            FCC "TAB "
            FCB $16                        
            FCC "TAP "
            FCB $06                        
            FCC "TBA "
            FCB $17                        
            FCC "TPA "
            FCB $07                        
            FCC "TSX "
            FCB $30                        
            FCC "TXS "
            FCB $35                        
            FCC "WAI "
            FCB $3E                        
MNETBLEND   FCB 0,0,0,0,0
        

;;************************************************************************
;;  External Call Jump Table  
;;  Fixed locations in ROM map to subroutines that may re-locate
;;************************************************************************
JUMPTBL        org   $FFC8       ; FFC8-FFF*  (fixed ROM addr.)
        JMP   DEL5A              ;Delay  A*5 ms
        JMP   DELAYA             ;Delay  A ms
        JMP   DELAYB             ;Delay B * 6 us
        JMP   OUTCHR             ;Send byte in A to Serial Port
        JMP   GETBYTE            ;wait for a serial byte and return in A
        JMP   INCHRE             ;wait for a serial byte and return in A with echo
        JMP   PUTS               ;Transmit data indexed by X
        JMP   OUTHEX             ;Output A as 2 HEX digits
        JMP   GETHEXB            ;Wait until a HEX byte is entered 
        JMP   INHEXB             ;Input 2 hex digits return with byte value in A
        JMP   GETADDR            ;Get 4 byte address, save in ADDRH & ADDRL
        JMP   BEEPBA             ;BEEP A=Duration Count and B=Frequency Count
        JMP   TESTKEY            ; Return Z=1 if start bit encountered        
        
;*************************************
; Vector Table  Not for local version
;*************************************
    ORG $FFF8
    FCB $00        ;IRQ Vector
    FCB IRQVECT
    FCB $00        ;SW IRQ Vector
    FCB SWIVECT
    FDB NMIISR     ;NMI Vector
    FDB RESET      ;Reset Address


    END