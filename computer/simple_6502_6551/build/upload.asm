; upload.asm   (hooked into SbcOS at $fa00-feff)
; By Daryl Rictor & Ross Archer  Aug 2002
;
; 21st century code for 20th century CPUs (tm?)
; 
; A simple file transfer program to allow upload from a serial
; port to the SBC.
; As soon as the receiver sees an Intel Hex
; character ':' coming in, it aborts the XMODEM-CRC upload attempt and
; tries to accept Intel Hex instead.  This is the format used natively
; by a lot of generic tools such as TASM.

; Note: testing shows that no end-of-line delay is required for Intel Hex
; uploads, but in case your circumstances differ and you encounter
; error indications from a download (especially if you decided to run the
; controller under 1 Mhz), adding a 10-50 mS delay after each line is 
; harmless and will ensure no problems even at low clock speeds
;
;
; Style conventions being tried on this file for possible future adoption:
; 1. Constants known at assembly time are ALL CAPS
; 2. Variables are all lower-case, with underscores used as the word separator
; 3. Labels are PascalStyleLikeThis to distinguish from constants and variables
; 4. Old labels from external modules are left alone.  We may want
;    to adopt these conventions and retrofit old source later.
; 5. Op-codes are lower-case
; 6. Comments are free-style but ought to line up with similar adjacent comments

; zero page variables (Its ok to stomp on the monitor's zp vars)
;
;
;crc               := $38      ; CRC lo byte
;crch              := $39      ; CRC hi byte
strptr            := $40
strptrh           := $41      ; temporary string pointer (not preserved across calls)
chksum            := $42      ; record checksum accumulator
reclen            := $43      ; record length in bytes
start_lo          := $44
start_hi          := $45
retry             := $46      ; retry counter
retry2            := $47      ; 2nd counter
rectype           := $48
dlfail            := $49      ; flag for upload failure
temp              := $4A      ; save hex value

;
;  tables and constants
;
                                             ; (uses the Monitor's input buffer)
CR                := 13
LF                := 10
ESC               := 27          ; ESC to exit

;****************************************************
;
; Intel-hex 6502 upload program
; Ross Archer, 25 July 2002
;
; 
HexUpLd:          lda     #CR
                  jsr     Output
                  lda     #LF
                  jsr     Output
                  lda     #0
                  sta     dlfail          ;Start by assuming no D/L failure
                  ;beq     IHex              
HdwRecs:          jsr     GetSer          ; Wait for start of record mark ':'
                  cmp     #$3A ;":"
                  bne     HdwRecs         ; not found yet
                                          ; Start of record marker has been found
IHex:             jsr     GetHex          ; Get the record length
                  sta     reclen          ; save it
                  sta     chksum          ; and save first byte of checksum
                  jsr     GetHex          ; Get the high part of start address
                  sta     start_hi
                  clc
                  adc     chksum          ; Add in the checksum       
                  sta     chksum          ; 
                  jsr     GetHex          ; Get the low part of the start address
                  sta     start_lo
                  clc
                  adc     chksum
                  sta     chksum  
                  jsr     GetHex          ; Get the record type
                  sta     rectype         ; & save it
                  clc
                  adc     chksum
                  sta     chksum   
                  lda     rectype
                  bne     HdEr1           ; end-of-record
                  ldx     reclen          ; number of data bytes to write to memory
                  ldy     #0              ; start offset at 0
HdLp1:            jsr     GetHex          ; Get the first/next/last data byte
                  sta     (start_lo),y    ; Save it to RAM
                  clc
                  adc     chksum
                  sta     chksum          ; 
                  iny                     ; update data pointer
                  dex                     ; decrement count
                  bne     HdLp1
                  jsr     GetHex          ; get the checksum
                  clc
                  adc     chksum
                  bne     HdDlF1          ; If failed, report it
                                          ; Another successful record has been processed
                  lda     #$40 ; @ ;"#"       ; Character indicating record OK = '#'
                  sta     ACIA1dat        ; write it out but don't wait for Output 
                  jmp     HdwRecs         ; get next record     
HdDlF1:           lda     #$46 ;"F"       ; Character indicating record failure = 'F'
                  sta     dlfail          ; upload failed if non-zero
                  sta     ACIA1dat        ; write it to transmit buffer register
                  jmp     HdwRecs         ; wait for next record start
HdEr1:            cmp     #1              ; Check for end-of-record type
                  beq     HdEr2
                  lda     #>MsgUnknownRecType
                  ldx     #<MsgUnknownRecType
                  jsr     PrintStrAX      ; Warn user of unknown record type
                  lda     rectype         ; Get it
                  sta     dlfail          ; non-zero --> upload has failed
                  jsr     Print1Byte      ; print it
                  lda     #CR             ; but we'll let it finish so as not to 
                  jsr     Output          ; falsely start a new d/l from existing 
                  lda     #LF             ; file that may still be coming in for 
                  jsr     Output          ; quite some time yet.
                  jmp     HdwRecs
                                          ; We've reached the end-of-record record
HdEr2:            jsr     GetHex          ; get the checksum 
                  clc
                  adc     chksum          ; Add previous checksum accumulator value
                  beq     HdEr3           ; checksum = 0 means we're OK!
                  lda     #>MsgBadRecChksum
                  ldx     #<MsgBadRecChksum
                  jmp     PrintStrAX
HdEr3:            lda     dlfail
                  beq     HdErOK
                                          ;A upload failure has occurred
                  lda     #>MsgUploadFail
                  ldx     #<MsgUploadFail
                  jmp     PrintStrAX
HdErOK:           lda     #>MsgUploadOK
                  ldx     #<MsgUploadOK
                  jsr     PrintStrAX
                                          ; Eat final characters so monitor doesn't cope with it
                  jsr     Flush           ; flush the input buffer
HdErNX:           rts
;
;  subroutines
;
                     
GetSer:           jsr     Input_chr      ; get input from Serial Port            
                  cmp     #ESC            ; check for abort 
                  bne     GSerXit         ; return character if not
                  brk
GSerXit:          rts

GetHex:           lda     #$00
                  sta     temp
                  jsr     GetNibl
                  asl     a
                  asl     a
                  asl     a
                  asl     a               ; This is the upper nibble
                  sta     temp
GetNibl:          jsr     GetSer
                                          ; Convert the ASCII nibble to numeric value from 0-F:
                  cmp     #$3A ;"9"+1     ; See if it's 0-9 or 'A'..'F' (no lowercase yet)
                  bcc     MkNnh           ; If we borrowed, we lost the carry so 0..9
                  sbc     #7+1            ; Subtract off extra 7 (sbc subtracts off one less)
                                          ; If we fall through, carry is set unlike direct entry at MkNnh
MkNnh:            sbc     #$2F ;"0"-1     ; subtract off '0' (if carry clear coming in)
                  and     #$0F            ; no upper nibble no matter what
                  ora     temp
                  rts                     ; return with the nibble received



;Print the string starting at (AX) until we encounter a NULL
;string can be in RAM or ROM.  It's limited to <= 255 bytes.
;
PrintStrAX:       sta     strptr+1
                  stx      strptr
                  tya
                  pha
                  ldy      #0
PrintStrAXL1:     lda     (strptr),y
                  beq     PrintStrAXX1      ; quit if NULL
                  jsr      Output
                  iny
                  bne     PrintStrAXL1      ; quit if > 255
PrintStrAXX1:     pla
                  tay
                  rts

; Checksum messages
;                                            
MsgUnknownRecType:  
                  .byte   CR,LF,CR,LF
                  .byte   "Unknown record type $"
                  .byte    0                 ; null-terminate every string
MsgBadRecChksum:  .byte   CR,LF,CR,LF
                  .byte   "Bad record checksum!"
                  .byte   0                  ; Null-terminate  
MsgUploadFail:    .byte   CR,LF,CR,LF
                  .byte   "Upload Failed",CR,LF
                  .byte   "Aborting!"
                  .byte   0               ; null-terminate every string or crash'n'burn
MsgUploadOK:      .byte   CR,LF,CR,LF
                  .byte   "Upload Successful!"
                  .byte   0                  
;
; subroutines
;
;                                            ;
GetByte:          lda      #$00              ; wait for chr input and cycle timing loop
                  sta      retry             ; set low value of timing loop
StartCrcLp:       jsr      Scan_Input        ; get chr from serial port, don't wait 
                  bcs      GetByte1          ; got one, so exit
                  dec      retry             ; no character received, so dec counter
                  bne      StartCrcLp        ;
                  dec      retry2            ; dec hi byte of counter
                  bne      StartCrcLp        ; look for character again
                  clc                        ; if loop times out, CLC, else SEC and return
GetByte1:         rts                        ; with character in "A"
;                                            ;
Flush:            lda      #$70              ; flush receive buffer
                  sta      retry2            ; flush until empty for ~1 sec.
Flush1:           jsr      GetByte           ; read the port
                  bcs      Flush
                  rts      