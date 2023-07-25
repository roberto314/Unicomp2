;      *= $8002			; create exact 32k bin image

;
; prefill 32k block from $8002-$ffff with 'FF'
;
;      .rept 2047
;         .byte  $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff ;
;      .next 
;      .byte  $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff  ;

;
; compile the sections of the OS
   .setcpu "6502"
   ;.org $7800
   .org $FC00
   .export LOADADDR = *
   
   .include "sbcos.asm"       ; OS 
   .include "ACIA1.asm"   	   ; ACIA init (19200,n,8,1)
   ;.include "upload.asm"        ; $FA00  Intel Hex & Xmodem-CRC uploader
   .include "reset.asm"       ; Reset & IRQ handler

