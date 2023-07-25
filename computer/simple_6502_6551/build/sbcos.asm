;---------------------------------------------------------------------
;  SBC Firmware V5.1.1, 7-4-13, by Daryl Rictor
;
; ----------------- assembly instructions ---------------------------- 
;               *=   $E800                ; start of operating system
;Start_OS:         jmp   MonitorBoot         ; easy access to monitor program
;
;
;*********************************************************************       
;  local Zero-page variables
;
xsav           :=     $30               ; 1 byte
ysav           :=     $31               ; 1 byte
Prompt         :=     $32               ; 1 byte   
Linecnt        :=     $33               ; 1 byte
Modejmp        :=     $34               ; 1 byte
Hexdigcnt      :=     $35               ; 1 byte
OPCtxtptr      :=     $36               ; 1 byte
Memchr         :=     $37               ; 1 byte
;Startaddr      :=     $38               ; 2 bytes
;Startaddr_H    :=     $39
Addrptr        :=     $3a               ; 2 bytes
Addrptr_H      :=     $3b
Hexdigits      :=     $3c               ; 2 bytes
Hexdigits_H    :=     $3d
Memptr         :=     $3e               ; 2 bytes
Memptr_H       :=     $3f
;
; Local Non-Zero Page Variables
;
Buffer         :=     $0300             ; keybd Input Buffer (127 chrs max)
PCH            :=     $03e0             ; hold program counter (need PCH next to PCL for Printreg routine)
PCL            :=     $03e1             ;  ""
ACC            :=     $03e2             ; hold Accumulator (A)
XREG           :=     $03e3             ; hold X register
YREG           :=     $03e4             ; hold Y register
SPtr           :=     $03e5             ; hold stack pointer
Preg           :=     $03e6             ; hold status register (P)
;
                  ;.org $7800
                  ;.org $F000
Start_OS:         jmp Reset
                  jmp Interrupt
                  jmp NMIjump
Input_chr:        jmp ACIA1_Input       ; wait for Input character
Scan_Input:       jmp ACIA1_Scan        ; scan for Input (no wait), C=1 char, C=0 no character
Output:           jmp ACIA1_Output      ; send 1 character
;
;               
; *************************************************************************
; kernal commands
; *************************************************************************
; PrintRegCR   - subroutine prints a CR, the register contents, CR, then returns
; PrintReg     - same as PrintRegCR without leading CR
; Print2Byte   - prints AAXX hex digits
; Print1Byte   - prints AA hex digits
; PrintDig     - prints A hex nibble (low 4 bits)
; Print_CR     - prints a CR (ASCII 13)and LF (ASCII 10)
; PrintXSP     - prints # of spaces in X Reg
; Print2SP     - prints 2 spaces
; Print1SP     - prints 1 space
; Input_assem  - Alternate Input prompt for Assember
; Input        - print <CR> and prompt then get a line of Input, store at Buffer
; Input_chr    - get one byte from Input port, waits for Input
; Scan_Input   - Checks for an Input character (no waiting)
; Output       - send one byte to the Output port
; Bell         - send ctrl-g (Bell) to Output port
; Delay        - delay loop
; *************************************************************************
;
Regdata: .byte" PC=  A=  X=  Y=  S=  P= (NVRBDIZC)="
;
PrintReg:         jsr   Print_CR          ; Lead with a CR
                  ldx   #$ff              ;
                  ldy   #$ff              ;
Printreg1:        iny                     ;
                  lda   Regdata,y         ;
                  jsr   Output            ;
                  cmp   #$3D              ; "="
                  bne   Printreg1         ;
Printreg2:        inx                     ;
                  cpx   #$07              ;
                  beq   Printreg3         ; done with first 6
                  lda   PCH,x             ;  
                  jsr   Print1Byte        ;
                  cpx   #$00              ;
                  bne   Printreg1         ;
                  beq   Printreg2         ;
Printreg3:        dex                     ;
                  lda   PCH,x             ; get Preg
                  ldx   #$08              ; 
Printreg4:        rol                     ;
                  tay                     ;
                  lda   #$31              ;
                  bcs   Printreg5         ;
                  sbc   #$00              ; clc implied:subtract 1
Printreg5:        jsr   Output            ;
                  tya                     ;
                  dex                     ;
                  bne   Printreg4         ;
; fall into the print cR routine
Print_CR:         pha                     ; Save Acc
                  lda   #$0D              ; "cr"
                  jsr   Output            ; send it
                  lda   #$0A              ; "lf"
                  jsr   Output            ; send it
                  pla                     ; Restore Acc
                  rts                     ; 

Print2Byte:       jsr   Print1Byte        ;  prints AAXX hex digits
                  txa                     ;
Print1Byte:       pha                     ;  prints AA hex digits
                  lsr                     ;  MOVE UPPER NIBBLE TO LOWER
                  lsr                     ;
                  lsr                     ;
                  lsr                     ;
                  jsr   PrintDig          ;
                  pla                     ;
PrintDig:         sty   ysav              ;  prints A hex nibble (low 4 bits)
                  and   #$0F              ;
                  tay                     ;
                  lda   Hexdigdata,Y      ;
                  ldy   ysav              ;
                  jmp   Output            ;
PrintXSP1:        jsr   Print1SP          ;
                  dex                     ;
PrintXSP:         cpx   #$00              ;
                  bne   PrintXSP1         ;
                  rts                     ;
Print2SP:         jsr   Print1SP          ; print 2 SPACES
Print1SP:         lda   #$20              ; print 1 SPACE
                  jmp   Output            ;
;
Input:            lda   #$3E              ; Monitor Prompt ">"
                  sta   Prompt            ; save prompt chr 
Input1:           jsr   Print_CR          ; New Line
                  lda   Prompt            ; get prompt
                  jsr   Output            ; Print Prompt
                  ldy   #$ff              ; pointer
InputWait:        jsr   Input_chr         ; get a character
                  cmp   #$20              ; is ctrl char?
                  bcs   InputSave         ; no, echo chr 
                  cmp   #$0d              ; cr
                  beq   InputDone         ; done
                  cmp   #$1B              ; esc
                  beq   Input1            ; cancel and new line
                  cmp   #$08              ; bs
                  beq   backspace         ;
                  cmp   #$09              ; TAB key
                  beq   tabkey            ;
                  cmp   #$02              ; Ctrl-B
                  bne   InputWait         ; Ignore other codes
                  brk                     ; Force a keyboard Break cmd
backspace:        cpy   #$ff              ;
                  beq   InputWait         ; nothing to do
                  dey                     ; remove last char
                  lda   #$08              ; backup one space
                  jsr   Output            ;
                  lda   #$20              ; Print space (destructive BS)
                  jsr   Output            ;
                  lda   #$08              ; backup one space
                  jsr   Output            ;
                  jmp   InputWait         ; ready for next key
tabkey:           lda   #$20              ; convert tab to space
                  iny                     ; move cursor
                  bmi   InputTooLong      ; line too long?
                  sta   Buffer,y          ; no, save space in Buffer
                  jsr   Output            ; print the space too
                  tya                     ; test to see if tab is on multiple of 8
                  and   #$07              ; mask remainder of cursor/8
                  bne   tabkey            ; not done, add another space
                  beq   InputWait         ; done. 
InputSave:        cmp   #$61              ;   ucase
                  bcc   InputSave1        ;
                  sbc   #$20              ;
InputSave1:       iny                     ;
                  bmi   InputTooLong      ; get next char (up to 127)
                  sta   Buffer,y          ;
                  jsr   Output            ; OutputCharacter
                  jmp   InputWait         ;
InputDone:        iny                     ;
InputTooLong:     lda   #$0d              ; force CR at end of 128 characters 
                  sta   Buffer,y          ;
                  jsr   Output            ;
;                 lda   #$0a              ; lf Char   
;                 jsr   Output            ;
                  rts                     ;
;
Bell:             lda  #$07               ; Ctrl G Bell
                  jmp  Output             ; 
;
BRKroutine:       sta   ACC               ; save A    Monitor"s break handler
                  stx   XREG              ; save X
                  sty   YREG              ; save Y
                  pla                     ; 
                  sta   Preg              ; save P
                  pla                     ; PCL
                  tay
                  pla                     ; PCH
                  tax
                  tya 
                  sec                     ;
                  sbc   #$02              ;
                  sta   PCL               ; backup to BRK cmd
                  bcs   Brk2              ;
                  dex                     ;
Brk2:             stx   PCH               ; save PC
                  tsx                     ; get stack pointer
                  stx   SPtr              ; save stack pointer
                  jsr   Bell              ; Beep speaker
                  jsr   PrintReg          ; dump register contents 
                  ldx   #$FF              ; 
                  txs                     ; clear stack
                  cli                     ; enable interrupts again
                  jmp   Monitor           ; start the monitor

;*************************************************************************
;     
;  Monitor Program 
;
;**************************************************************************
MonitorBoot:      
                  ;jsr   Bell              ; beep ready
                  jsr   Version           ;
SYSjmp:  ; Added for ehBASIC
Monitor:          ldx   #$FF              ; 
                  txs                           ;  Init the stack
                  jsr   Input             ;  line Input
                  lda   #$00              ;
                  tay                     ;  set to 1st character in line
                  sta   Linecnt           ; normal list vs range list 
Mon01:            sta   Memchr            ;
Mon02:            lda   #$00              ;
                  sta   Hexdigits         ;  holds parsed hex
                  sta   Hexdigits+1       ;
                  jsr   ParseHexDig       ;  Get any Hex chars
                  ldx   #CmdCount         ;  get # of cmds currently used
Mon08:            cmp   CmdAscii,X        ;  is non hex cmd chr?
                  beq   Mon09             ;  yes x= cmd number
                  dex                     ;
                  bpl   Mon08             ;
                  bmi   Monitor           ;  no
Mon09:            txa
                  pha 
                  tya
                  pha 
                  txa                     ;
                  asl                     ;  ptr * 2
                  tax                     ;  
                  jsr   Mon10             ;  Execute cmd
                  pla
                  tay
                  pla
                  tax 
                  beq   Monitor           ;  done
                  lda   Cmdseccode,X      ;  
                  bmi   Mon02             ;
                  bpl   Mon01             ;
Mon10:   
                  lda   Cmdjmptbl,X
                  sta   Modejmp 
                  inx
                  lda   Cmdjmptbl,X 
                  pha
                  lda   Modejmp 
                  pha
                  rts
;                 jmp   (Cmdjmptbl,X)     ;
;--------------- Routines used by the Monitor commands ----------------------
ParseHexDig:      lda   #$00
                  sta   Hexdigcnt         ;  cntr
                  jmp   ParseHex05        ;
ParseHex03:       txa                     ;  parse hex dig
                  ldx   #$04              ;  
ParseHex04:       asl   Hexdigits         ;
                  rol   Hexdigits+1       ;
                  dex                     ;
                  bne   ParseHex04        ;
                  ora   Hexdigits         ;
                  sta   Hexdigits         ;
                  dec   Hexdigcnt         ;
ParseHex05:       lda   Buffer,Y          ;
                  ldx   #$0F              ;   is hex chr?
                  iny                     ;
ParseHex07:       cmp   Hexdigdata,X      ;
                  beq   ParseHex03        ;   yes
                  dex                     ;
                  bpl   ParseHex07        ;
                  rts                     ; Stored in Hexdigits if HexDigCnt <> 0
;
Version:          jsr   Print_CR          ; 
                  ldx   #$FF              ; set txt pointer
                  lda   #$0d              ; 
PortReadyMsg:     inx                     ;
                  jsr   Output            ; put character to Port
                  lda   Porttxt,x         ; get message text
                  bne   PortReadyMsg      ; 
                  rts                     ;

Excute_cmd:       jsr   exe1              ;
                  ldx   #$FF              ; reset stack
                  txs                     ;
                  jmp   Monitor           ;
exe1:             jmp   (Hexdigits)       ;
;
DOT_cmd:          ldx   Hexdigits         ; move address to Addrptr
                  lda   Hexdigits+1       ;
                  stx   Addrptr           ;
                  sta   Addrptr+1         ;
                  inc   Linecnt           ; range list command
                  rts                     ;
;
CR_cmd:           cpy   #$01              ;
                  bne   SP_cmd            ;
                  lda   Addrptr           ; CR alone - move Addrptr to Hexdigits
                  ora   #$0F              ;  to simulate entering an address
                  sta   Hexdigits         ; *** change 07 to 0f for 16 byte/line
                  lda   Addrptr+1         ;
                  sta   Hexdigits+1       ;
                  jmp   SP_cmd2           ;
SP_cmd:           lda   Hexdigcnt         ; Space command entry
                  beq   SP_cmd5           ; any digits to process? no - done
                  ldx   Memchr            ; yes - is sec cmd code 0 ? yes - 
                  beq   SP_cmd1           ; yes - 
                  dex                     ; Is sec cmd = 1?       
                  beq   SP_cmd3           ;       yes - is sec cmd code 1 ?
                  lda   Hexdigits         ;             no - ":" cmd processed
                  ldx   #$00
                  sta   (Addrptr,x)       ;
                  jmp   Inc_Addrptr       ; set to next address and return
SP_cmd1:          jsr   DOT_cmd           ; sec dig = 0  move address to Addrptr
                  jmp   SP_cmd3           ;
SP_cmd2:          lda   Addrptr           ; CR cmd entry 
                  and   #$0F              ; *** changed 07 to 0F for 16 bytes/line
                  beq   SP_cmd3           ; if 16, print new line
                  cpy   #$00              ; if TXT cmd, don"t print the - or spaces between chrs
                  beq   TXT_Cmd1          ;
                  lda   Addrptr           ; CR cmd entry 
                  and   #$07              ; if 8, print -
                  beq   SP_cmd33          ;
                  bne   SP_cmd4           ; else print next byte
SP_cmd3:          jsr   Print_CR          ; "." cmd - display address and data 
                  jsr   Scan_Input        ; see if brk requested
                  bcs   SP_brk            ; if so, stop 
                  lda   Addrptr+1         ; print address
                  ldx   Addrptr           ;
                  jsr   Print2Byte        ;
SP_cmd33:         lda   #$20              ; " " print 1 - 16 bytes of data
                  jsr   Output            ;
                  lda   #$2D              ; "-"
                  jsr   Output            ;
SP_cmd4:          lda   #$20              ; " " 
                  jsr   Output            ;
                  cpy   #$00              ;
                  beq   TXT_Cmd1          ;
                  ldx   #$00              ;
                  lda   (Addrptr,x)       ;
                  jsr   Print1Byte        ;
SP_cmd44:         sec                     ;  checks if range done
                  lda   Addrptr           ;
                  sbc   Hexdigits         ;
                  lda   Addrptr+1         ;
                  sbc   Hexdigits+1       ;
                  jsr   Inc_Addrptr       ;
                  bcc   SP_cmd2           ; loop until range done
SP_brk:           lda   #$00
                  sta   Memchr            ; reset sec cmd code
SP_cmd5:          rts                     ; done or no digits to process
;
TXT_cmd:          sty   ysav              ;
                  ldy   #$00              ;
                  jsr   SP_cmd            ;
                  ldy   ysav              ;
                  rts                     ;
TXT_Cmd1:         ldx   #$00 
                  lda   (Addrptr,x)       ;
                  and   #$7F              ;
                  cmp   #$7F              ;
                  beq   TXT_Cmd2          ;
                  cmp   #$20              ; " "
                  bcs   TXT_Cmd3          ;
TXT_Cmd2:         lda   #$2E              ; "." use "." if not printable char
TXT_Cmd3:         jsr   Output            ;
                  jmp   SP_cmd44          ;
;
Inc_Addrptr:      inc   Addrptr           ;  increments Addrptr
                  bne   Inc_addr1         ;
                  inc   Addrptr+1         ;
Inc_addr1:        rts                     ;
;
Insert_Cmd:       lda   Linecnt           ;  "I" cmd code
                  beq   Insert_3          ; abort if no . cmd entered
                  sec                     ;
                  lda   Hexdigits         ;
                  sbc   Addrptr           ;
                  tax                     ;
                  lda   Hexdigits+1       ;
                  sbc   Addrptr+1         ;
                  tay                     ;
                  bcc   Insert_3          ;
                  clc                     ;
                  txa                     ;
                  adc   Memptr            ;
                  sta   Hexdigits         ;
                  tya                     ;
                  adc   Memptr+1          ;
                  sta   Hexdigits+1       ;
Insert_0:         ldx   #$00
                  lda   (Memptr,x)        ;
                  sta   (Hexdigits,x)     ;
                  lda   #$FF              ;
                  dec   Hexdigits         ;  
                  cmp   Hexdigits         ;  
                  bne   Insert_1          ;
                  dec   Hexdigits+1       ;
Insert_1:         dec   Memptr            ;  
                  cmp   Memptr            ;
                  bne   Insert_2          ;
                  dec   Memptr+1          ;
Insert_2:         sec                     ;  
                  lda   Memptr            ;
                  sbc   Addrptr           ;
                  lda   Memptr+1          ;
                  sbc   Addrptr+1         ;
                  bcc   Insert_3          ;
                  jsr   Scan_Input        ; see if brk requested
                  bcc   Insert_0          ; if so, stop List
Insert_3:         rts                     ;
;
Move_cmd:         lda   Linecnt           ; *** any changes to this routine affect EEPROM_WR too!!!
                  bne   Move_cmd3         ; abort if no . cmd was used
Move_brk:         rts                     ;
Move_cmd1:        inc   Addrptr           ;  increments Addrptr
                  bne   Move_cmd2         ;
                  inc   Addrptr+1         ;
Move_cmd2:        inc   Hexdigits         ;  "M" cmd code
                  bne   Move_cmd3         ;
                  inc   Hexdigits+1       ;
Move_cmd3:        sec                     ;  checks if range done
                  lda   Memptr            ;
                  sbc   Addrptr           ;
                  lda   Memptr+1          ;
                  sbc   Addrptr+1         ;
                  bcc   Move_brk          ;  exit if range done
                  jsr   Scan_Input        ; see if brk requested
                  bcs   Move_brk          ; 
                  ldx   #$00
                  lda   (Addrptr,x)       ;  Moves one byte
                  sta   (Hexdigits,x)     ;
                  jmp   Move_cmd1         ; (zapped after move from eeprom_wr)
;
Dest_cmd:         ldx   Hexdigits         ;  ">" cmd code
                  lda   Hexdigits+1       ;
                  stx   Memptr            ;  move address to Memptr
                  sta   Memptr+1          ;
                  rts                     ;  
                  ;
;
;-----------DATA TABLES ------------------------------------------------
;
Hexdigdata:       .byte "0123456789ABCDEF" ; hex char table 
;     
;CmdCount          := $0b                    ; number of commands to scan for
CmdCount          := $0a                    ; number of commands to scan for
CmdAscii:         .byte $0D               ; 0 enter    cmd codes
                  .byte $20               ; 1 SPACE
                  .byte $2E               ; 2 .
                  .byte $3A               ; 3 :
                  .byte $3E               ; 4 >  
                  .byte $47               ; 5 g - Go
                  .byte $49               ; 6 i - Insert
                  .byte $4D               ; 7 m - Move
                  .byte $51               ; 8 q - Query memory (text dump)
                  .byte $52               ; 9 r - Registers
                  .byte $56               ; a v - Version
                  ;.byte $55               ; b u - upload

;     
Cmdjmptbl:        .addr CR_cmd-1            ; 0  enter   cmd jmp table
                  .addr SP_cmd-1            ; 1   space
                  .addr DOT_cmd-1           ; 2    .
                  .addr DOT_cmd-1           ; 3    :
                  .addr Dest_cmd-1          ; 4    >  
                  .addr Excute_cmd-1        ; 5    g
                  .addr Insert_Cmd-1        ; 6    i
                  .addr Move_cmd-1          ; 7    m
                  .addr TXT_cmd-1           ; 8    q
                  .addr PrintReg-1          ; 9    r
                  .addr Version-1           ; a    v
                  ;.addr HexUpLd-1           ; b    u
;     
Cmdseccode:       .byte $00               ; 0   enter       secondary command table
                  .byte $FF               ; 1   sp
                  .byte $01               ; 2   .
                  .byte $02               ; 3   :
                  .byte $00               ; 4   > 
                  .byte $00               ; 5   g
                  .byte $00               ; 6   i
                  .byte $00               ; 7   m
                  .byte $00               ; 8   q
                  .byte $00               ; 9   r
                  .byte $00               ; a   v
;                  .byte $00               ; b   u
;
;
Porttxt:          .byte "6502 Monitor v2.1 by ROB"
                  .byte  $0d, $0a
                  .byte $00
;
; *** VERSION Notes ***
; 3.5 added the text dump command, "q"
; 4.0 reorganized structure, added RAM vectors for chrin, scan_in, and chrout
; 4.1 fixed set time routine so 20-23 is correct    
; 4.2 RST, IRQ, NMI, BRK all jmp ind to 02xx page to allow user prog to control
; 4.3 added status register bits to printreg routine
; 4.4 refined set time to reduce unneeded sec"s and branches, disp time added CR,
;     and added zeromem to the reset routine, ensuring a reset starts fresh every time!
;     continued to re-organize - moved monitor"s brk handler into mon area.
; 4.5 nop out the jsr Scan_Input in the eeprom write routine to prevent BRK"s
; 4.6 added version printout when entering assember to show ? prompt
; 4.7 added Lee Davison's Enhanced Basic to ROM Image 
; 4.9 Added all of the WDC opcodes to the disassembler and mini-assembler
; 5.0 Added TAB key support to the Input routine, expands tabs to spaces
; 5.1 Added jump table at the start of the monitor to commonly used routines
; 5.1.1 Lite Version - removed List and Mini-Assembler & Help
;end of file
