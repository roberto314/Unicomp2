*--------------------------------------------------------
* FLEXLOAD.ASM
*    Double-sided compatible FLEX 2/3 loader for the
*    SWTPC DC-X series of controllers
*
*    Mike Douglas, 11/14/2020
*--------------------------------------------------------
BOOTLOC	equ	$2400		;FLEX loader runs here
SSTACK	equ	$A07F		;system stack location

* Disk controller equates

DRQ	equ	$02		;DRQ bit mask
BUSY	equ	$01		;busy bit mask
RDMSK	equ	$1C		;read errors bit mask

RDCMND	equ	$8C		;read sector
RSCMND	equ	$0B		;restore to track 0
SKCMND	equ	$1B		;seek

DRVREG	equ	$8014		;drive select register
COMREG	equ	$8018		;1771 command register
TRKREG	equ	$8019		;1771 track register
SECREG	equ	$801A		;1771 sector register
DATREG	equ	$801B		;1771 data register

*--------------------------------------------------------
* Boot ROM jumps here after loading this from sector 0
*--------------------------------------------------------
	org	BOOTLOC		;boot ROM loads us here

flxBoot	lds	#SSTACK		;init stack pointer
	bra	loadFlx		;go load Flex

flexTrk	fcb	1		;track for FLEX2.SYS
flexSec	fcb	10		;sector to find FLEX2.SYS
			
pFlex	rmb	2		;pointer to FLEX entry
pDest	rmb	2		;pointer to destination
pSource	rmb	2		;pointer to data in secBuf

*--------------------------------------------------------
* loadFlx - Entry point for loading FLEX from disk. The 
*    drive that loaded this program is used to load FLEX.
*    This allows booting from any drive.
*--------------------------------------------------------
loadFlx	ldaa	#RSCMND		;issue restore to track zero
	staa	COMREG
	jsr	delay		;wait for command acceptance
	jsr	wait		;wait for command completion

	bsr	read1st		;read first sector of Flex

load1	jsr	getByte		;get next byte
	cmpa	#$02		;data record header?
	beq	load2

	cmpa	#$16		;transfer address header?
	bne	load1		;loop if neither

	jsr	getByte		;get transfer address
	staa	pFlex		;MSB
	jsr	getByte		;LSB
	staa	pFlex+1

	ldx	pFlex		;jump to Flex
	jmp	0,x

load2	jsr	getByte		;A=load address MSB
	psha
	jsr	getByte		;A=load address LSB
	pulb			;B=load address MSB

	staa	pDest+1		;save load address LSB
	stab	pDest		;MSB

	jsr	getByte		;A=byte count
	tab			;B=byte count
	beq	load1		;byte count was zero

load3	pshb
	jsr	getByte		;get next data byte
	pulb

	ldx	pDest		;X->where to put the data
	staa	0,x
	inx
	stx	pDest

	decb
	bne	load3		;loop for byte count in B

	bra	load1		;get next record

*--------------------------------------------------------
* readSec 
*--------------------------------------------------------
read1st	ldaa	flexTrk		;read 1st sector of Flex
	ldab	flexSec

readSec	bsr	seek		;seek to track, set sector
	ldaa	#RDCMND
	staa	COMREG
	bsr	delay
	
	ldab	#0		;B=sector length (256 bytes)
	ldx	#secBuf		;X->sector buffer

rdLoop	ldaa	COMREG		;wait for data ready
	bita	#DRQ
	bne	rdByte		;have a byte

	bita	#BUSY		;still busy?
	bne	rdLoop		;yes

	bra	loadFlx		;failed, start over

rdByte	ldaa	DATREG		;get data byte and store it
	staa	0,x
	inx
	decb
	bne	rdLoop

	bsr	wait		;wait for 1771 to say done
	bitb	#RDMSK		;any read errors?
	bne	loadFlx		;yes, start over
	
	ldx	#secBuf+4	;data starts at offset 4
	stx	pSource		;pSource->data in secBuf
	rts

* seek - seek to track in A, set sector to hunt from B

seek	cmpa	TRKREG		;on correct track already?
	beq	skDone		;yes, seek already done

	staa	DATREG		;give track to the 1771
	bsr	delay

	ldaa	#SKCMND		;issue seek command
	staa	COMREG
	bsr	delay

	pshb			;perserve B
	bsr	wait		;wait for seek to complete
	pulb

skDone	stab	SECREG		;set sector to look for
	clra			;assume side 0, drive 0
	cmpb	#10		;side 0 or 1?
	bls	setSide		;side 0

	ldaa	#$40		;else, set side 1, drive 0

setSide	staa	DRVREG

* delay - delay 52us to let 1771 accept command

delay	bsr	delay2
delay2	bsr	sbrRts
sbrRts	rts

* wait - wait for 1771 command to finish execution

wait	ldab	COMREG		;loop while busy
	bitb	#BUSY
	bne	wait

	rts

*--------------------------------------------------------
* getByte - Get next byte from sector buffer. Retrieve next
*    sector as needed.
*--------------------------------------------------------
getByte	ldx	pSource		;X->next byte 
	cpx	#secBuf+256	;reached end of sector?
	beq	nextSec		;yes, get the next sector

	ldaa	0,x		;else, return next byte
	inx
	stx	pSource		;save updated pointer
	rts

nextSec	ldaa	secBuf		;A=next track
	ldab	secBuf+1	;B=next sector
	bsr	readSec
	bra	getByte

* Sector buffer starts here

secBuf	equ	*

	end
