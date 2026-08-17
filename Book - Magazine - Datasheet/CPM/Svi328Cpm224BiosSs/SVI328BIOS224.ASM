
;
; Rev 11/29/83 tmk
;
; 1) Supports new 80-column card if present (auto-detected) (new method)
; 2) Format implemented for XEROX 820-II
; 3) Translates cursor keys/joystick into WordStar (tm) cursor movement
; 4) Don't allow user to STAT the console to the 80-column board if it
;    isn't present as this will crash the system
; 5) Support user definitions of screen color and cursor translation
; 6) Support user definition of function keys & their screen display
; 7) Support user selection of screen size (39 or 40 columns)
; 8) Fix Centronics driver so won't go into BASIC if CTL-STOP is pressed
; 9) Add RS-232 card support as console, reader/punch, printer (all as TTY:)
;10) Add ADM-3A/ADM-31 emulation
;11) Patch CCP so we get 4-across DIR if on 80-column card
;
	TITLE	'BIOS for Spectravideo CP/M - 11/29/83'
;
;
;	Spectravideo CP/M BIOS	[Basic I/O System]
;
;	Originally written by H.Kawazoe (Dec 18, 1982)
;	Revised by Jey Suzuki (Mar 24, 1983)
;	Revised by Terry Kennedy (Jul 17, 1983 - Nov 29, 1983)
;       Revised by M.H. Kam (Oct 6, 1984)
;
	MACLIB	Z80
;
;	Jump vector definition
;
CHSNS	EQU	59
CHGET	EQU	CHSNS+3
CHPSTT	EQU	CHGET+3
CHPLPT	EQU	CHPSTT+3
INITXT	EQU	CHPLPT+3
;
CHPUT	EQU	24
HOKENT	EQU	38		;Where top address hook table is held
;
;	Work area of routines in ROM
;
LINLEN	EQU	0F543H
CNSDFG	EQU	0FA06H
;
;	Utility Macro Definition
;
DELAY	MACRO
	XTHL
	XTHL
	XTHL
	XTHL
	ENDM
MTIME	EQU	60*30		;Time to stop motor (30 sec)
;
;	Address definition
;
FD$CMD	EQU	30H		;Command to FDC
FD$STT	EQU	FD$CMD		;Status from FDC
FD$TRK	EQU	31H		;Track register
FD$SEC	EQU	32H		;Sector register
FD$DAT	EQU	33H		;Data register
;
;	Command definition
;
FRCRDY	EQU	11010001B	;Force ready
RESTRE	EQU	00000000B	;Restore command
SEEK	EQU	00010000B	;Seek commnad
STPIN	EQU	01010000B	;Step in command (updates track register)
STRATE	EQU	00000010B	;Steping motor rate
RDCMD	EQU	10000000B	;Sector read command
WRCMD	EQU	10100000B	;Sector write command
;
;	Status definition
;
NOREDY	EQU	10000000B	;Not ready
WRPRTC	EQU	01000000B	;Write protect
RTWF	EQU	00100000B	;Record type/write fault
RNF	EQU	00010000B	;Record not found
SEKERR	EQU	00010000B	;Seek error
CRCERR	EQU	00001000B	;CRC error
LOSTDT	EQU	00000100B	;Lost data
DTREQ	EQU	00000010B	;Data request
INDEX	EQU	00000010B	;Index hole
BUSY	EQU	00000001B	;Busy
;
;	Miscellaneous I/O ports
;
INTRQP	EQU	34H		;Address of INTRQ and DRQ
INTRQ	EQU	10000000B	;Interrupt request bit
DRQ	EQU	01000000B	;Data request bit
;
DSKSEL	EQU	34H		;Address of disk select and motor control
SD0	EQU	00000001B	;Select disk 0 bit
SD1	EQU	00000010B	;Select disk 1 bit
MOTOR0	EQU	00000100B	;Disk 0 motor on bit
MOTOR1	EQU	00001000B	;Disk 1 motor on bit
;
DENSEL	EQU	38H		;Address of density select flag
DESMFM	EQU	00000000B	;Density MFM bit
DESFM	EQU	00000001B	;Density FM bit
;
;	Bank switching ports
;
PSG$LW	EQU	88H		;PSG latch port
PSG$DW	EQU	8CH		;PSG write port
PSG$DR	EQU	90H		;PSG read port
;
;	CP/M size and entry definition
;
MSIZE	EQU	59
;
BIOSB	EQU	MSIZE*1024-3*512
CBASE	EQU	(MSIZE-20)*1024
CPMB	EQU	CBASE+3400H
DOSB	EQU	CBASE+3C06H
IOBYT	EQU	3
LOGDIS	EQU	4
MAXDRV	EQU	2
;
; CCP patch for directory display fix
;
	org	cpmb+430h+80h
;
	jmp	patch1		;go to patch area for fix
;
	org	cpmb+465h+80h
;
	jmp	patch2		;go to patch area for fix
;
	ORG	BIOSB
;
;	BIOS Body
;
START:
CBOOTE:	JMP	CBOOT		;Cold start
WBOOTE:	JMP	WBOOT		;Warm start
	JMP	CONST		;Console status
	JMP	CONIN		;Console input
	JMP	CONOUT		;Console outut
	JMP	LIST		;List output
	JMP	PUNCH		;Serial input
	JMP	READER		;Serial output
	JMP	HOME		;Go home position
	JMP	SELDSK		;Select drive
	JMP	SETTRK		;Set track
	JMP	SETSEC		;Set sector
	JMP	SETDMA		;Set DMA address
	JMP	READ		;Sector read
	JMP	WRITE		;Sector write
	JMP	LISTST		;List status
	JMP	SECTRA		;Translate logical to phisycal
	DS	10*3		;Reserved for future expansion
;
;	Entry vector into some useful routines of customized BIOS
;
	JMP	CALROM
	JMP	BLKRD
	JMP	BLKWRT
	JMP	DMOTOR
	JMP	SWITCH
;
; user parameters live here
;
; NOTE: The length and order of the following items must NOT be changed.
;	Make additions by using one or more of the 'reserved for future
;	expansion' bytes and reducing the DS.
;
uparms:	db	0		;set -1 if cursor translation not desired
	db	15		;foreground color, default is white
	db	4		;background color, default is blue
	db	7		;screen border color, default is cyan
	db	0		;set -1 if screen width of 39 is desired
	db	0		;set -1 if function key display is desired
	db	0		;set -1 if ADM-3A emulation is desired
	dw	20		;RS-232 card baud rate (see 8250 manual)
	db	0		;set -1 if hardware H/S on RS-232 desired (pin 5)
	db	83h		;default IOBYTE (LST:=LPT:; RDR:,PUN:=TTY:; CON:=[dynamic]
	ds	10		;reserved for future expansion
;
fundef:	db	'dir a:',0dh,0		;F1
	db	0,0,0,0,0,0,0,0
;
	db	'stat',0dh,0,0,0	;F2
	db	0,0,0,0,0,0,0,0
;
	db	'stat a:*.*',0dh	;F3
	db	0,0,0,0,0
;
	db	'copy',0dh,0,0,0	;F4
	db	0,0,0,0,0,0,0,0
;
	db	'svmbasic fkset'	;F5
	db	0dh,0
;
	db	'dir b:',0dh,0		;F6
	db	0,0,0,0,0,0,0,0
;
	db	'stat',0,0,0,0		;F7
	db	0,0,0,0,0,0,0,0
;
	db	'stat b:*.*',0dh	;F8
	db	0,0,0,0,0
;
	db	'format',0dh,0		;F9
	db	0,0,0,0,0,0,0,0
;
	db	'svmbasic setup'	;F10
	db	0dh,0
;
; This is the end of the area whose length may not vary
;
; This is the patch area for the CCP
;
patch1:	push	d		;see CCP.ASM for details
	push	b		;save CCP's [BC]
	call	getwid		;get the width code, either 1 or 3
	ana	b
	pop	b		;restore CCP's [BC]
	jmp	cpmb+433h+80h	;and return
;
patch2:	push	psw		;see CCP.ASM for details
	push	b		;save CCP's [BC]
	call	getwid		;get the width code, either 1 or 3
	cmp	b
	pop	b		;restore CCP's [BC]
	jmp	cpmb+468h+80h	;and return
;
getwid:	push	psw		;save input state
	lda	iobyt		;get the IOBYTE
	ani	3		;only look at the CON: assignment
	cpi	1		;on the 40-column display?
	jz	wexit		;if so
	mvi	a,3		;all else are 80-column devices
wexit:	mov	b,a		;result to [B]
	pop	psw		;restore input state
	ret
;
;	DISKS	2
;
;	DISKDEF 0,1,34,,1024,157,64,64,2
;	DISKDEF 1,0
;
XLT0	EQU	0		;No translation necessary
XLT1	EQU	0
;
DPBASE:				;Base of disk parameter block
DPE0:	DW	XLT0,0000	;Translate table
	DW	0000,0000	;Scratch area
	DW	DIRBUF,DPB0	;Dir buff,parm block
	DW	CSV0,ALV0	;Check alloc vectors
;
DPE1:	DW	XLT1,0000	;Translate table
	DW	0000,0000	;Scratch area
	DW	DIRBUF,DPB0	;Dir buff,parm block
DRBDPB	EQU	$-2
	DW	CSV1,ALV1	;Check alloc vectors
;
DPB0:	DW	34		;Sectors per track
	DB	3		;Block shift
	DB	7		;Block mask
	DB	0		;Extent mask
	DW	156		;Disk size - 1
	DW	63		;Directory max
	DB	192		;Alloc0
	DB	0		;Alloc1
	DW	16		;Check size
	DW	3		;Reserved track
;
;	Table to generate PC8001 format disk
;
DPB1:	DW	32		;Sectors per track
	DB	3		;Block shift
	DB	7		;Block mask
	DB	0		;Extent mask
	DW	131		;Disk size - 1
	DW	63		;Directory max
	DB	192		;Alloc0
	DB	0		;Alloc1
	DW	16		;Check size
	DW	2		;Reserved track
;
;	Switch between PC8001 format and XEROX 820 format
;
SWITCH:	LDA	DRBDPB
	LXI	H,DPB0
	CMP	L
	JRNZ	SWTCH1
	LXI	H,DPB1
SWTCH1:	SHLD	DRBDPB
	RET
;
;	Logical device handler
;
;	Dispatcher
;
DSPCON:	MVI	B,1
	DB	00010001B
DSPRDR:	MVI	B,7
	DB	00010001B
DSPPUN:	MVI	B,5
	DB	00010001B
DSPLST:	MVI	B,3
	LDA	IOBYT		;Get IOBYTE
DSPLOP:	RLC
	DJNZ	DSPLOP
	ANI	00000110B	;Get offset into table
	XTHL
	MOV	E,A
	MOV	D,B
	DAD	D
	MOV	A,M
	INX	H
	MOV	H,M
	MOV	L,A
	XTHL
	RET			;GOTO DEST ADDRESS
;
;	((( console status )))
;
CONST:	CALL	DSPCON		;Check console field [bit 0,1]
	DW	TTYSTI		;[TTY:]
	DW	CRTSTI		;[CRT:]
	DW	BATSTI		;[BAT:]
	DW	UC1STI		;[UC1:]
;
;	((( console input )))
;
CONIN:	CALL	DSPCON		;Check console field [bit 0,1]
	DW	TTYIN		;[TTY:]
	DW	CRTIN		;[CRT:]
	DW	BATIN		;[BAT:]
	DW	UC1IN		;[UC1:]
;
;	((( console output )))
;
CONOUT:	CALL	DSPCON		;Check console field [bit 0,1]
	DW	TTYOUT		;[TTY:]
	DW	CRTOUT		;[CRT:]
	DW	BATOUT		;[BAT:]
fudge:	DW	UC1OUT		;[UC1:] (will get patched if no 80-col)
;
;	((( list status )))
;
LISTST:	CALL	DSPLST		;Check console field [bit 6,7]
	DW	TTYSTO		;[TTY:]
	DW	CRTSTO		;[CRT:]
	DW	LPTSTO		;[LPT:]
	DW	UL1STO		;[UL1:]
;
;	((( list outptut )))
;
LIST:	CALL	DSPLST		;Check console field [bit 6,7]
	DW	TTYOUT		;[TTY:]
	DW	CRTOUT		;[CRT:]
	DW	LPTOUT		;[LPT:]
	DW	UL1OUT		;[UL1:]
;
;	((( punch output )))
;
PUNCH:	CALL	DSPPUN		;Check punch field [bit 4,5]
	DW	TTYOUT		;[TTY:]
	DW	PTPOUT		;[PTP:]
	DW	UP1OUT		;[UP1:]
	DW	UP2OUT		;[UP2:]
;
;	((( reader input )))
;
READER:	CALL	DSPRDR		;Check reader field [bit 2,3]
	DW	TTYIN		;[TTY:]
	DW	CRTIN		;[CRT:]
	DW	UR1IN		;[UR1:]
	DW	UR2IN		;[UR2:]
;
;	Physical handler
;
;	CRT:
;
CRTSTI:	LXI	H,CHSNS
	JR	CALROM
;
CRTIN:	LXI	H,CHGET
	call	CALROM		;%% for WS cursor keys, till next ;%%
	mov	b,a		;save in [B] for now
	lda	uparms
	ora	a		;function key translation desired?
	mov	a,b		;get keypress back to [A]
	jz	transl		;yes
	ret			;if not, just exit
;
transl:	cpi	30
	jrnz	notu
	mvi	a,'E'-40h
	ret
notu:	cpi	31
	jrnz	notd
	mvi	a,'X'-40h
	ret
notd:	cpi	28
	jrnz	notr
	mvi	a,'D'-40h
	ret
notr:	cpi	29
	rnz
	mvi	a,'S'-40h
	ret			;%% all done
;
CRTSTO:	MVI	A,255		;CRT: is always ready
	RET
;
CRTOUT:	LXI	H,CHPUT
	JR	LPTOU1
;
;	LPT:
;
lptdw	equ	10h		;printer data write port
lptsb	equ	11h		;printer strobe port
lptst	equ	12h		;printer status port
;
LPTSTO:	in	lptst		;get status data
	rrc			;and massgae
	cmc
	sbb	a
	ret
;
LPTOUT:	call	lptsto		;get status
	jrz	lptout		;loop if busy
	mov	a,c		;character to [A]
	out	lptdw		;send to data port
	xra	a
	out	lptsb		;set strobe low
	dcr	a
	out	lptsb		;and high
	ret			;and exit
;
lptou1:	mov	a,c		;vestigal, still used by other drivers
;
;	Call a subroutine of ROM
;
;	The address should be passed via [HL]
;
CALROM:	SHLD	CALLA+1		;Set up jump address
	SSPD	STKSAV+1	;Save current value of stack pointer
				;'cause the stack pointer may be
				;pointing inside of ROM
	LXI	SP,BIOSTK
	PUSH	PSW
	DI
	MVI	A,15
	OUT	PSG$LW
	IN	PSG$DR
	ORI	00000010B	;Enable BASIC ROM
	OUT	PSG$DW
	EI
	POP	PSW
CALLA:	CALL	0		;Dummy, modified each time
	PUSH	PSW
	DI
	MVI	A,15
	OUT	PSG$LW
	IN	PSG$DR
	ANI	11111101B	;Enable BK21
	OUT	PSG$DW
	EI
	POP	PSW
STKSAV:	LXI	SP,0		;Dummy, modified each time
	RET
;
INTRPT:	PUSH	PSW
	IF	0
	PUSH	H
	LHLD	ISTKSV+1	;Is this the second interrupt?
	MOV	A,H
	ORA	L
	POP	H
	JRNZ	INTIGN		;Yes, ignore this
	ENDIF
	SSPD	ISTKSV+1
	LXI	SP,INTSTK
	MVI	A,15
	OUT	PSG$LW
	IN	PSG$DR
	ORI	00000010B	;Enable BASIC ROM
	OUT	PSG$DW
	CALL	56		;Call interrupt entry in ROM
	DI
	IF	0
	XRA	A
	STA	ISTKSV+1
	STA	ISTKSV+2
	ENDIF
	MVI	A,15
	OUT	PSG$LW
	IN	PSG$DR
	ANI	11111101B	;Enable BK21
	OUT	PSG$DW
ISTKSV:	LXI	SP,0
	POP	PSW
	EI
	RET
	IF	0
INTIGN:	POP	PSW
	RET
	ENDIF
;
;	Check the status of floppy disk motor
;
CHKMOT:	LHLD	MTRCNT		;Get motor counter
	MOV	A,H		;Is counter already 0? (i.e. stopped)
	ORA	L
	RZ			;Yes, do nothing
	DCX	H		;Update counter
	SHLD	MTRCNT		;Set updated value
	MOV	A,H		;Gone to 0?
	ORA	L
	RNZ			;Not yet
	OUT	DSKSEL		;Yes, stop motor
	RET
;
;	TTY:
;
TTYSTI:	in	ttstat		;get status byte
	ani	1		;is RxRdy set?
	rz			;nope, exit
	xra a ! dcr a		;yes, set FF and exit
	ret
;
TTYIN:	call	ttysti		;get status
	jz	ttyin		;if not there yet
	in	ttdata		;else get data
	ani	7fh		;mask parity
	ret			;and return
;
TTYSTO:	in	ttstat		;get status byte
	ani	20h		;is TxRdy set?
	rz			;nope, exit
	lda	uparms+9	;is H/W H/S enabled?
	ora	a
	jz	setrdy		;nope, go signal ready state
	in	ttmodst		;else get modem status
	ani	10h		;look at CTS pin
	rz			;exit if not ready
setrdy:	xra a ! dcr a		;else set FF and exit
	ret
;
TTYOUT:	call	ttysto		;get status
	jz	ttyout		;if not ready yet
	mov	a,c		;get character to send
	out	ttdata		;send it out
	ret			;and exit
;
;	BAT:
;
BATSTI:	JMP	CRTSTI
BATIN:	JMP	CRTIN
BATOUT:	JMP	CRTOUT
;
;	UC1:
;
UC1STI:	JMP	CRTSTI
UC1IN:	JMP	CRTIN
UC1OUT:	jmp	ch8put		;80-column driver
;
;*************************************************************************
;
;       Macro definition for Z80 opcodes
;       Unnecessary as long as you're using Z80 assembler
;
RL      MACRO   R
        DB      11001011B
        DB      00010000B+R
        ENDM
RR      MACRO   R
        DB      11001011B
        DB      00011000B+R
        ENDM
;
;       External references
;

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;                           ;
        ;       Port definition     ;
        ;                           ;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       CRTC port definition
;
CRT$AD  EQU     50H             ;Address latch port (50H)
CRT$DA  EQU     51H             ;Data port (51H)
CRT$BK  EQU     58H             ;Bank select port (LSB should be 1 to enable VRAM)
;
VRAM    EQU     0F000H
CRTCNT  EQU     24
CRTWDT  EQU     80

;       SUBTTL  CH8PUT  - output a character to CRT -
;
CH8PUT:
        PUSH    H
        PUSH    D
        PUSH    B
        PUSH    PSW
        CALL    CHPUT1
        CALL    CKDPCS          ;Display new cursor if cursor enabled
        POP     PSW
        POP     B
        POP     D
        POP     H
        RET
;
CHPUT1: LXI     H,ESCCNT
        MOV     A,M             ;Are we executing escape sequence?
        ANA     A
        JNZ     INESC           ;Yes
        MOV     A,C             ;Restore character
        CPI     ' '             ;Control code?
        JRC     CNTPUT          ;Yes
        LHLD    CSRY
        CPI     127             ;Rubout?
        JZ      RUBOUT          ;Yes
        CALL    PUTCOD          ;Convert to raw code and write to VRAM
        CALL    RIGHT           ;Advance cursor
        RNZ                     ;All done if not wrapped to next line
        MVI     H,1             ;Go to start of the next line
;
;       Line feed
;
LF:     CALL    DOWN            ;Down cursor
        RNZ                     ;Exit if not at bottom
        CALL    STOCSR
        MVI     L,1             ;L:=window top line
        JMP     DELLN0          ;Scroll up by deleting the first line
;
;       Following control codes are supported in VT-52 mode
;
;        7      Bell
;        8      Back space
;        9      Tab
;        10     Line feed
;        11     Cursor home
;        12     Clear screen
;        13     Carriage return
;
;        27     Enter escape sequence
;        28     Cursor right
;        29     Cursor left
;        30     Cursor up
;        31     Cursor down
;
CNTPUT:	push	psw		;save character
	lda	uparms+6	;get emulation mode
	ora	a
	jz	emlv52		;if emulating a VT-52
	lxi	h,cnatbl-2	;else set ADM-3A tables
	mvi	c,cnamax
	pop	psw		;restore character
	jmp	indjmp
;
emlv52:	LXI     H,CNTTBL-2
        MVI     C,CNTMAX
	pop	psw		;restore character
indjmp:	INX     H
        INX     H
        ANA     A               ;Make sure carry is cleared
        DCR     C
        RM                      ;Undefined function
        CMP     M               ;Found?
        INX     H
        JRNZ    INDJMP          ;No
        MOV     C,M             ;Get routine address in BC
        INX     H               ;
        MOV     B,M             ;
        LHLD    CSRY            ;Jump to each routine with cursor pos
        PUSH    B
        RET
;
;       Function dispatch table - VT-52
;
CNTTBL: DB      7               ;Beep
        DW      fBEEP		;fake a beep for now
        DB      8               ;Back space
        DW      BS
        DB      9               ;Tabulation
        DW      TAB
        DB      10              ;Line feed
        DW      LF
        DB      11              ;Home
        DW      CSHOME
        DB      12              ;Clear
        DW      CLRTXT
        DB      13              ;Carriage return
        DW      CR
        DB      27              ;Enter escape sequence
        DW      ENTESC
        DB      28              ;Cursor right   (^\)
        DW      ADVCUR
        DB      29              ;Cursor left    (^])
        DW      BS
        DB      30              ;Cursor up      (^^)
        DW      UP
        DB      31              ;Cursor down    (^_)
        DW      DOWN
CNTMAX  EQU     ($-CNTTBL)/3
;
;       Function dispatch table - ADM-3A
;
CNaTBL: DB      7               ;Beep (^G)
        DW      fBEEP		;fake a beep for now
        DB      8               ;Back space (^H)
        DW      BS
        DB      9               ;Tabulation (^I)
        DW      TAB
        DB      10              ;Line feed (^J)
        DW      LF
	db	11		;Cursor up (^K)
	dw	up
	db	12		;Cursor right (^L)
	dw	right
        DB      13              ;Carriage return (^M)
        DW      CR
	db	26		;Clear screen (^Z)
	dw	clrtxt
        DB      27              ;Enter escape sequence (^[)
        DW      ENTESC
        DB      30              ;Cursor home (^^)
        DW      CSHOME
CNaMAX  EQU     ($-CNaTBL)/3
;
fbeep:	mvi	c,7		;send beeps to old handler
	jmp	crtout		;like so...
;
;	SUBTTL	Escape sequence handler (VT-52)
;
ESCTBL: DB      'j'             ;Clear screen
        DW      CLRTXT
        DB      'E'             ;Clear screen
        DW      CLRTXT          ; To maintain compatibility with VT52
        DB      'K'             ;Erase to end-of-line
        DW      EOL
        DB      'J'             ;Erase to end-of-page
        DW      EOP
        DB      'l'             ;Erase entire line
        DW      ELN
        DB      'L'             ;Insert a line
        DW      ILN
        DB      'M'             ;Delete a line
        DW      DLN
        DB      'Y'             ;Locate cursor
        DW      LOC
        DB      'A'             ;Cursor up
        DW      UP
        DB      'B'             ;Cursor down
        DW      DOWN
        DB      'C'             ;Cursor right
        DW      RIGHT
        DB      'D'             ;Cursor left
        DW      LEFT
        DB      'H'             ;Cursor home
        DW      CSHOME
        DB      'p'             ;Enter reverse mode
        DW      ENTREV
        DB      'q'             ;Exit reverse mode
        DW      EXTREV
        DB      'x'             ;Set modes
        DW      SETMOD
        DB      'y'             ;Reset modes
        DW      RSTMOD
ESCMAX  EQU     ($-ESCTBL)/3
;
;       SUBTTL  Escape sequence handler (ADM-3A / ADM-31)
;
ESaTBL: DB      '*'             ;Clear screen
        DW      CLRTXT
        DB      ':'             ;Clear screen
        DW      CLrtxt
	db	'+'		;Clear screen
	dw	clrtxt
        DB      'y'             ;Erase to end-of-page
        DW      EOP
        DB      'T'             ;Erase to end of line
        DW      Eol
        DB      'E'             ;Insert a line
        DW      ILN
        DB      'R'             ;Delete a line
        DW      DLN
        DB      '='             ;Locate cursor
        DW      LOC
        DB      ')'             ;Enter reverse mode
        DW      ENTREV
        DB      '('             ;Exit reverse mode
        DW      EXTREV
ESaMAX  EQU     ($-ESaTBL)/3
;
SETMOD: MVI     A,1
        DB      01H
RSTMOD: MVI     A,2
        DB      01H
LOC:    MVI     A,4             ;Say row is expected next
        DB      01H             ;'LXI B' instruction
ENTESC: MVI     A,255           ;Tell him we're in escape sequence
        STA     ESCCNT
        RET
;
INESC:  JP      INESC1          ;Arguments expected
        MVI     M,0             ;Exit from escape sequence
        MOV     A,C             ;Restore character
	push	psw		;save
	lda	uparms+6	;get emulation mode
	ora	a
	jz	emnv52		;if emulating a VT-52
	lxi	h,esatbl-2
	mvi	c,esamax
	pop	psw		;restore character
	jmp	indjmp		;and jump
;
emnv52: LXI     H,ESCTBL-2
        MVI     C,ESCMAX
       	pop	psw		;restore character
	JMP     INDJMP
;
INESC1: DCR     A               ;Set modes?
        JRZ     GOSET           ;Yes
        DCR     A               ;Reset modes?
        JRZ     GORSET
        DCR     A
        MOV     M,A             ;Update ESCCNT
        MVI     A,CRTWDT
        LXI     D,CSRX          ;
        JRZ     INESC2          ;Column expected
        MVI     M,3
        MVI     A,CRTCNT        ;Row expected
        DCX     D               ;Point CSRY
INESC2: MOV     B,A             ;Get max limit in B
        MOV     A,C             ;Restore character
        SUI     ' '             ;0-xx
        CMP     B
        INR     A
        STAX    D
        RC                      ;Legal value
        MOV     A,B             ;Substitute by possible largest value
        STAX    D
        RET
;
;       Set various modes
;
GOSET:  MOV     M,A             ;Exit from escape sequence
        MOV     A,C             ;Restore character
        SUI     '4'             ;Block cursor?
        JRNZ    GOSET1          ;No
BLKCSR: LXI     B,11100000B
        jr    STRG10
;
GOSET1: DCR     A               ;Cursor off?
        RNZ                     ;Unimplemented feature
OFFCSR: LXI     B,256*00100000B+10011111B
        jr    STRG10
;
;       Reset various modes
;
GORSET: MOV     M,A             ;Exit from escape sequence
        MOV     A,C             ;Restore character
        SUI     '4'             ;Underscore cursor?
        JRNZ    GORST1          ;No
UNDCSR: LXI     B,256*00000101B+11100000B
        jr    STRG10
;
GORST1: DCR     A               ;Cursor on?
        RNZ                     ;No, unimplemented feature
ONCSR:  LXI     B,256*01000000B
STRG10: MVI     A,10            ;Select 'cursor-start-raster'
        OUT     CRT$AD
        LDA     CREG10          ;Get what is currently output
        ANA     C               ;Strip off some bits
        ORA     B               ;Add some bits
        STA     CREG10          ;Remember this value
        OUT     CRT$DA          ;Set CRTC's register
        RET
;
;       Enter reverse mode
;
ENTREV: DB      3EH             ;'MVI A,' instruction
;
;       Exit reverse mode
;
EXTREV: XRA     A
        STA     REVFLG
        RET
;
;       Display a cursor
;
CKDPCS:
DSPCSR: PUSH    PSW
        LHLD    CSRY            ;Get current cursor position
        CALL    GETOFS          ;Calculate offset from screen top
        MVI     A,14
        OUT     CRT$AD
        MOV     A,H
        OUT     CRT$DA
        MVI     A,15
        OUT     CRT$AD
        MOV     A,L
        OUT     CRT$DA
        POP     PSW
        RET

;       SUBTTL  Cursor move operations
;
;       Cursor right
;
RIGHT:
        MVI     A,CRTWDT
        CMP     H               ;Are we at the right-end of line?
        RZ                      ;Yes, return with Z flag
        INR     H               ;Go to next column
        jr    STOCSR
;
;       Back space
;
BS:     CALL    LEFT
        RNZ                     ;Not at left-end
        MVI     H,CRTWDT
        DB      11H             ;'LXI D,' instruction
;
;       Cursor left
;
LEFT:   DCR     H               ;Are we at the left-end of line?
        DB      3EH             ;'MVI A,' instruction
;
;       Cursor up
;
UP:     DCR     L               ;Are we at the top of any window?
        RZ                      ;Yes, return with Z flag
        jr    STOCSR
;
;       Advance cursor
;
ADVCUR: CALL    RIGHT
        RNZ
        MVI     H,1
;
;       Cursor down
;
DOWN:   MVI     A,CRTCNT        ;Get an actual bottom of screen
        CMP     L               ;Are we at the bottom of screen?
        RZ                      ;Yes, return with Z flag
        JRC     DOWN1           ;We're below screen bottom!
        INR     L               ;Go to next line
STOCSR: SHLD    CSRY
        RET
;
DOWN1:  DCR     L
        XRA     A
        jr    STOCSR
;
;       Tabulation
;
TAB:    MVI     A,' '
        CALL    CHPUT1
        LDA     CSRX
        DCR     A
        ANI     00000111B
        JRNZ    TAB
        RET
;
;       Cursor home
;
CSHOME: MVI     L,1
;
;       Carriage return
;
CR:     MVI     H,1             ;CR only, not new-line
        jr    STOCSR

;       SUBTTL  Line delete & line insert stuff of CRT
;
;       Delete a line specified by L
;
;       Cursor should be set at the top of line
;
DLN:    CALL    CR
DELLN0: MVI     A,CRTCNT        ;Get an actual height of screen
        SUB     L
        RC                      ;Something is wrong
        JZ      ELN             ;Delete the bottom line only
;
;       We move line by line because we don't want interrupts disabled
;       for long period of time.
;
DELLN1: PUSH    PSW             ;Save counter
        INR     L
        CALL    MOVUP
        POP     PSW             ;Restore counter
        DCR     A
        JRNZ    DELLN1
        JMP     ELN             ;Blank bottom line
;
;       Insert a line
;
;       Cursor should be set at the top of line
;
ILN:    CALL    CR
INSLN0: MVI     A,CRTCNT        ;Get an actual height of screen
        MOV     H,A
        SUB     L
        RC                      ;Something is wrong!!
        JZ      ELN
        MOV     L,H
;
;       We move line by line because we don't want interrupts disabled
;       for long period of time.
;
INSLN1: PUSH    PSW             ;Save counter
        DCR     L
        CALL    MOVDWN
        POP     PSW             ;Restore counter
        DCR     A
        JRNZ    INSLN1
        jr    ELN

;       SUBTTL  Erasing stuff
;
;       Erase previous character
;
RUBOUT: CALL    BS              ;Back space
        RZ                      ;We're at the top of screen
        MVI     C,0             ;Overstrike with a space
        JMP     PUTVRM          ;0 is a raw code for ' '
;
;       Erase entire line
;
;       Cursor should remain unchanged
;
ELN:    MVI     H,1
;
;       Erase to end-of-line
;
;       Cursor should remain unchanged
;
EOL:
        PUSH    H               ;Save current position (column)
        PUSH    H               ;Ditto
        CALL    VADDR           ;Get VRAM address to [HL]
        POP     D               ;Restore current position
        MVI     A,1
        DI                      ;Interrupts should be disabled
        OUT     CRT$BK          ;Connect VRAM
        MVI     A,CRTWDT
EREOL1: MVI     M,0             ;Overstrike with a space
        INX     H
        INR     D
        CMP     D
        JRNC    EREOL1
        XRA     A               ;Disconnect VRAM
        OUT     CRT$BK
        EI                      ;End of critical section
        POP     H
        RET
;
CLRTXT: CALL    CSHOME
;
;       Erase to end-of-page
;
;       Cursor should remain unchanged
;
EOP:    CALL    EOL             ;Erase to end-of-line
        MVI     A,CRTCNT        ;Get an actual height of CRT
        CMP     L
        RC                      ;Something is wrong!
        RZ                      ;All done
        MVI     H,1
        INR     L
        jr    EOP

;       SUBTTL  Low level subroutines
;
;       Move a line specified by [L] upward
;
MOVUP:  PUSH    H               ;Save cursor position
        MVI     H,1
        CALL    VADDR
        XCHG
        LXI     H,-80
        jr    MOVDN1
;
;       Move a line specified by [L] downward
;
MOVDWN: PUSH    H
        MVI     H,1
        CALL    VADDR
        XCHG
        LXI     H,80
MOVDN1: DAD     D
        XCHG                    ;Now [DE]=destination, [HL]=source
        LXI     B,80
        MVI     A,1
        DI                      ;Interrupts should be disabled
        OUT     CRT$BK          ;Connect VRAM
        LDIR
        XRA     A
        OUT     CRT$BK
        EI
        POP     H
        RET
;
GETCOD: CALL    GETVRM
        CPI     60H             ;Normal ASCII? (00H - 5FH)
        JRC     GETCD1          ;Yes
        SUI     60H
        CPI     60H             ;Reverse ASCII? (60H - 0BFH)
        JRC     GETCD1          ;Yes
        ADI     40H             ;Graphic character (0C0H - 0FFH)
        RET
;
GETCD1: ADI     ' '             ;Make it 20H - 7FH
        RET
;
GETVRM: PUSH    H               ;Save coordinate
        CALL    VADDR           ;Calculate VRAM address
        MVI     A,1
        DI                      ;Interrupts should be disabled
        OUT     CRT$BK          ;Connect VRAM
        MOV     C,M             ;Get from VRAM
        XRA     A
        OUT     CRT$BK          ;Disconnect VRAM
        EI                      ;End of critical section
        MOV     A,C             ;Pass code to [Acc] also
        POP     H               ;Restore coordinate
        RET
;
;       Convert an ASCII code in [C] register to a raw code
;
;       020H - 07EH are mapped to 000H - 05EH (normal)
;                                 060H - 0BEH (reverse)
;       0A0H - 0DEH are mapped to 0C0H - 0FFH
;
;       Note that 0BFH is reserved for cursor
;
CNVCOD: MOV     A,C
        SUI     ' '             ;Control character?
        JRC     CNVCD1          ;Yes, illegal character. Return blank
        CPI     127-' '         ;Less then 7FH?
        JRC     CNVCD2          ;Yes, legal ASCII character
        CPI     160-' '         ;Less then 0A0H?
        JRC     CNVCD1          ;Yes, illegal character. Return blank
        CPI     224-' '         ;Greater than 0DFH?
        JRNC    CNVCD1          ;Yes, illegal character. Return blank
        ADI     64
        MOV     C,A
        RET
;
CNVCD1: XRA     A
CNVCD2: MOV     C,A
        LDA     REVFLG          ;Are we in reverse mode?
        ANA     A
        RZ
        MOV     A,C
        ADI     60H             ;Make it a reverse pattern
        MOV     C,A
        RET
;
PUTCOD: CALL    CNVCOD          ;Convert code and pass result to [C]
PUTVRM: PUSH    H               ;Save cursor position
        CALL    VADDR           ;Calculate actual address
        MVI     A,1
        DI                      ;Interrupts should be disabled
        OUT     CRT$BK          ;Connect VRAM
        MOV     M,C             ;Put code there
        XRA     A               ;Disconnect VRAM
        OUT     CRT$BK
        EI                      ;End of critical section
        POP     H               ;Restore cursor position
        RET
;
;       Calculate buffer address out of H,L (column,row)
;
;       address returned in HL
;
VADDR:  CALL    GETOFS
        LXI     D,VRAM
        DAD     D
        RET
;
GETOFS: MOV     A,L             ;Get row in A
        MOV     E,H             ;Get column in E
        MVI     H,0
        MOV     D,H
        ADD     A               ;*2
        ADD     A               ;*4
        ADD     L               ;*5
        ADD     A               ;*10
        ADD     A               ;*20
        RL      H
        ADD     A               ;*40
        RL      H
        ADD     A               ;*80
        RL      H
        MOV     L,A
        DAD     D
        LXI     D,-80-1
        DAD     D
        RET
;
CREG10: DB      01100000B       ;Cursor start raster
CSRY:   DB      1
CSRX:   DB      1
ESCCNT: DB      0
REVFLG: DB      0

;
; 80-Column init code (updated version)
;
nit80:	di
	mvi	a,15		;set to write to cursor address low byte
	out	50h
	xra	a		;set to 0
	out	51h		;and send it
	mov	b,a		;copy to [B]
	in	51h		;get it back
	cmp	b		;same?
	jnz	not80c		;if not, it's not there
	inr	a
	jnz	presnt		;if wasn't FF, all is fine
not80c:	lxi	h,crtout
	shld	fudge		;this will keep him from re-assigning
	lda	iobyt		;re-assign console to CRT:
	ani	0fch		;leave all but CON:
	ori	1		;force CON: to 40-column card (CRT:)
	sta	iobyt
	ret
;
presnt:	mvi	a,0ffh
	out	58h
	lxi	h,0f000h
	lxi	b,7ffh
loop1:	mvi	a,0
	mov	m,a
	inx	h
	dcx	b
	mov	a,b
	ora	c
	jnz	loop1
;
	mvi	c,0
	lxi	h,crtbl
next:	mov	a,c
	cpi	10h
	jz	eint
	out	50h
	mov	a,m
	out	51h
	inx	h
	inr	c
	jmp	next
;
eint:	xra	a
	out	58h
	ei
	ret
;
crtbl:	db	107
	db	80
	db	88
	db	8
	db	38
	db	5
	db	24
	db	30
	db	0
	db	7
	db	0
	db	7
	db	0
	db	0
	db	0
	db	0
;
; RS-232 init code (test version)
;
ttdata	equ	28h		;data port of WD8250
ttier	equ	ttdata+1	;interrupt enable register
ttident	equ	ttdata+2	;interrupt ident register
ttlcr	equ	ttdata+3	;line control register
ttmcr	equ	ttdata+4	;modem control register
ttstat	equ	ttdata+5	;line status register
ttmodst	equ	ttdata+6	;modem status register
dll	equ	ttdata		;divisor latch low
dlh	equ	ttdata+1	;divisor latch high
;
nit232:	xra	a		;burp 8250
	out	ttstat
	mvi	a,0fh		;activate all modem control lines
	out	ttmcr
	xra	a		;disable all interrupts
	out	ttier
	mvi	a,83h		;enable divisor latch
	out	ttlcr
	lhld	uparms+7	;get baud rate
	mov	a,l		;send low first
	out	dll
	mov	a,h		;and then high
	out	dlh
	mvi	a,3		;select 8 data bits, 1 stop bit, no parity
	out	ttlcr
	xra	a		;burp it again
	out	ttstat
	ret			;all done
;
;*************************************************************************
;
;	UL1:
;
UL1STO:	JMP	CRTSTO
UL1OUT:	JMP	CRTOUT
;
;	PTR:
;
PTRIN:	JMP	CRTIN
;
;	UR1:
;
UR1IN:	JMP	CRTIN
;
;	UR2:
;
UR2IN:	JMP	CRTIN
;
;	PTP:
;
PTPOUT:	JMP	CRTOUT
;
;	UP1:
;
UP1OUT:	JMP	CRTOUT
;
;	UP2:
;
UP2OUT:	JMP	CRTOUT
;
;	Disk handler
;
;
;	((( Ask sector translate table )))
;
;
SECTRA:	MOV	H,B		;Return with original value.
	MOV	L,C		;Because "skew" is not used.
	INX	H		;Set it from sector-1
	RET
;
;
;	((( Select specified drive )))
;
;
SELDSK:	MVI	A,MAXDRV-1	;Get maximum drive #
	CMP	C		;Must be between 0 and max
	JRC	SELERR		;Invalid drive number.
	MOV	A,C		;Save it for the future.
	STA	LOGDRV		;Just save, now.
	MOV	L,C		;[L]=disk drive #
	MVI	H,0		;High order zero.
	DAD	H
	DAD	H
	DAD	H
	DAD	H
	LXI	D,DPBASE	;Set table adrs.
	DAD	D		;Make dpbase+(disk# * 16)
	RET
;
SELERR:	XRA	A
	STA	LOGDIS		;Clear LOGDIS to avoid infinite loop
	MOV	L,A
	MOV	H,A
	RET
;
;
;	((( Set head to track 0 )))
;
;
HOME:	MVI	C,0
;
;
;	((( Set desired track )))
;
;
SETTRK:	MOV	A,C		;Given by [C].
	STA	LOGTRK		;Save the track.
	RET
;
;
;	((( Set desired sector )))
;
;
SETSEC:	MOV	A,C
	ANA	A
	INR	A		;You know that.
	RAR			;Make it as [0-..]
	STA	LOGSEC		;Save logical sector.
	LXI	H,SECFLG	;Set to "secflg".
	MVI	M,0		;Should be odd.
	RNC			;Return, if so.
	INR	M		;Set it as even sector.
	RET
;
;
;	((( Set DMA address )))
;
;
SETDMA:	SBCD	BUFADR
	RET
;
;	*********************************
;	*** disk read / write routine ***
;	***   with sector  blocking   ***
;	***    logical to physical    ***
;	*********************************
;
;
;	((( Read logical one block )))
;
;
READ:	LXI	H,IFACT	 	;Select active flag.
	MOV	B,M		;Pick it up.
	MVI	M,1		;Always becomes active
	LXI	H,LOGTRK	;Check if directory track
	MVI	A,3		;Reading directory track?
	CMP	M
	JRNZ	SKIPS		;Skip if not
	INX	H		;Bump to the LOGSEC
	MOV	A,M		;Pick up the sector
	DCR	A		;Is it sector-01?
	JRZ	ACTIO		;If so, be sure to read
SKIPS:	MOV	A,B		;
	ORA	A		;Buff active?
	JRZ	ACTIO		;No, do actual io
	CALL	CHKNEW		;Check new blcock or not.
	JRNZ	ACTIO		;New disk! skip read disk
;
;	Read has been issued to the same position
;
	LDA	ODDFLG		;Has been "write odd"
	ORA	A		;
	JRZ	RDOK		;Do not pre-read, just move from buffer
;
;	Check dflag and if DFLAG then write BUFF1
;
ACTIO:	CALL	OLDWR		;If DFLAG then write
	CALL	OLDNEW		;Set up parameters for read
	CALL	DSKRD		;
;
;	Set-up buff pointer for data transfer
;
RDOK:	LXI	D,IFBUFF	;Source as SCA
	CALL	SCTAB		;Is it odd ?
	JRNC	TRANDAT	 	;If so, as it is.
	LXI	D,IFBUFF+128	;Set SCB as source.
;
;	Transfer to buffer specified by DOS
;
TRANDAT:LHLD	BUFADR		;Bufadr as destination.
	XCHG			;Xchange it.
	JMP	TRAN		;
;
;
;	((( Write logical one block )))
;
;
WRITE:	MOV	A,C		;Check write for "dir"
	STA	DIRFLG		;Save it.
	CALL	CHKNEW		;Preread is necessary ?
	JZ	OLDCAS		;Save old block.
;
;	Write has been issued to different position
;
	CALL	OLDWR		;If DFLAG then write
	CALL	OLDNEW		;
	CALL	SCTAB		;
	JNC	DF0NA		;
;
;	(((( Read (NEW) to IFBUFF ))))
;
	CALL	DSKRD		;Perform physical read.
DF1NB:	LXI	D,SCB		;Transfer DMA to SCB.
	CALL	TRNDMA		;Moving on.
	JMP	OLDWR1		;
;
OLDCAS:	CALL	SCTAB		;
	JC	DF1NB		;
;
;	(((( DMA to SCA ))))
;
DF0NA:	LXI	D,SCA		;Transfer DMA to SCA.
	CALL	TRNDMA		;Moving on.
	LDA	DIRFLG		;Is there "dir" area
	DCR	A		;Has been so ?
	JRZ	DIRWR		;Write "dir"
	MVI	A,1		;How lonely you wre.
	STA	ODDFLG		;
	JR	OLDWR2		;Perform in general.(D/D)
;
;	(((( If DFLAG is on, then write old block ))))
;
OLDWR:	LDA	DFL		;Check buffer remains or not.
	ANA	A		;Has been empty ?
	RZ			;If so, get back soon.
DIRWR:	LXI	H,SCA		;Move SCA to BUF2.
	LXI	D,BUF2		;Save for a while.
	CALL	TRAN		;Moving on.
	CALL	DSKRD		;
	LXI	H,BUF2		;Move BUF2 to SCA.
	LXI	D,SCA		;Set it back to SCA.
OLDWR0:	CALL	TRAN		;Moving on.
OLDWR1:	CALL	DSKWR		;
OLDWR2:	STA	DFL		;Set buffer empty.
	XRA	A		;Set non error code.
	RET
;
;	(((( Check if odd sector or even ))))
;
SCTAB:	LDA	SECFLG		;Check odd or even.
	RAR			;Set the answer in carry.
	RET
;
;	((( Check if NEWPRM=OLDPRM )))
;		Z flag means same
;
CHKNEW:	MVI	B,3		;Set 3 times as check.
	LXI	D,NEWPRM	;Check with newprm.
	LXI	H,OLDPRM	;And oldprm.
CHKLOP:	LDAX	D		;Pick up new one.
	CMP	M		;Is it looks like ?
	RNZ			;If not so, let him know.
	INX	H		;Bump the pointer.
	INX	D		;Bump it also.
	DJNZ	CHKLOP		;Loop until done.
	RET
;
;	((( OLD PRM=NEWPRM )))
;
OLDNEW:	LXI	H,NEWPRM	;Put old pram.
	LXI	D,OLDPRM	;Into new parameter block.
	LXI	B,3		;Should be 3 times.
	LDIR
	RET
;
;	Transfer DMA to buffer
;
TRNDMA:	LHLD	BUFADR
TRAN:	LXI	B,128
	LDIR
	IF	0
	LDA	RTYCNT
	CPI	10
	RNC
	XRA	A		;
	ENDIF
	RET
;
;	Disk read (physical)
;
DSKRD:	XRA	A		;Set read flag
	STA	ODDFLG		;
	DB	3EH		;Skip 1 byte
;
;	Disk write (physical)
;
DSKWR:	STC			;Set write flag
	LDA	OLDDRV		;Get selected drive name
	STA	PHDRIV
	LDA	OLDTRK
	STA	PHTRCK
	LDA	OLDSEC		;Pick up old sector.
	STA	PHSECT
	LXI	H,IFBUFF	;Set source/destination address
DISKIO:	JNC	PHYRD		;Do read operation.
;
;	Write a sector
;
PHYWRT:	XRA	A
	STA	RTYCNT
PHYWR1:	PUSH	H		;Save source address
	CALL	SELPDR		;Select physical drive
	CALL	PHSEEK		;Select physical track
	LDA	PHSECT		;Get selected sector
	OUT	FD$SEC		;Write sector register
	CALL	BSYCHK
	MVI	A,WRCMD	 	;Sector write command
	DI
	OUT	FD$CMD		;Issue write command
	POP	H		;Load source address
	PUSH	H		;Save it back
	MVI	C,FD$DAT
	DELAY
WRLOP:	IN	INTRQP		;Read data request port
	ADD	A
	JRC	WDONE		;Write confirmed
	JP	WRLOP		;No data required
	OUTI
	JR	WRLOP
;
WDONE:	EI
	POP	H		;Restore source address
	IN	FD$STT
	ANI	11111100B	;Any errors detected?
	RZ			;No, all done
	CALL	RETRY		;Recalibrate drive and bump retry counter
	JRC	PHYWR1		;Retry
	PUSH	H
	LXI	H,WREMSG
	CALL	FATAL		;Fatal error has been detected
	POP	H
	JRNC	PHYWRT		;User asked for retry
	RET
;
WREMSG:	DB	'write',0
;
;	Read a sector
;
PHYRD:	XRA	A
	STA	RTYCNT
PHYRD1:	PUSH	H		;Save destination address
	CALL	SELPDR		;Select physical drive
	CALL	PHSEEK		;Select physical track
	LDA	PHSECT		;Get selected sector
	OUT	FD$SEC		;Write sector register
	CALL	BSYCHK
	MVI	A,RDCMD	 	;Sector read command
	DI
	OUT	FD$CMD		;Issue read command
	MVI	C,FD$DAT
	POP	H		;Load destination address
	PUSH	H
	DELAY
RDLOP:	IN	INTRQP		;Read data request port
	ADD	A
	JRC	RDONE		;Read confirmed
	JP	RDLOP		;No data valid
	INI
	JR	RDLOP
;
RDONE:	EI
	POP	H		;Restore destination address
	IN	FD$STT
	ANI	00011100B	;Any errors detected?
	RZ			;No, all done
	CALL	RETRY		;Recalibrate and bump retry counter
	JRC	PHYRD1		;Try again
	PUSH	H
	LXI	H,RDEMSG
	CALL	FATAL		;Fatal error has been detected
	POP	H
	JRNC	PHYRD		;User asked for retry
	RET
;
RDEMSG:	DB	'read',0
;
;	Recalibrate target drive, and bump error counter
;
RETRY:	LDA	RTYCNT		;Bump error counter
	INR	A
	STA	RTYCNT
	RRC
	RC			;Return if RTYCNT odd
	PUSH	PSW
	MVI	A,RESTRE+STRATE
	OUT	FD$CMD
	DELAY
	CALL	BSYCHK
	POP	PSW
	CPI	5
	RET
;
FATAL:	PUSH	H
	LXI	H,CRLFMS
	CALL	STROUT
	POP	H
	CALL	STROUT
	LXI	H,ERRMSG
	CALL	STROUT
FATAL1:	LXI	H,PROMSG
	CALL	STROUT
	CALL	CONIN
	PUSH	PSW
	MOV	C,A
	CALL	CONOUT
	MVI	C,0DH
	CALL	CONOUT
	MVI	C,0AH
	CALL	CONOUT
	POP	PSW
	CPI	'a'
	JRC	NOTLOW
	CPI	'z'+1
	JRNC	NOTLOW
	ANI	11011111B
NOTLOW:	CPI	'A'
	JZ	0
	CPI	'I'
	STC
	RZ
	CPI	'R'
	JRNZ	FATAL1
	RET
;
CRLFMS:	DB	0DH,0AH,0AH
	DB	'Fatal '
	DB	0
ERRMSG:	DB	' error.'
	DB	0
PROMSG:	DB	0DH,0AH
	DB	'Abort, Retry, Ignore? '
	DB	0
;
;	Select physical drive
;
SELPDR: CALL    SPDR            ;SELECT DRIVE AND TURN ON MOTOR
        LHLD    MTRCNT          ;LOAD MOTOR COUNTER
        MOV     A,H
        ORA     L               ;MOTOR COUNTER = 0 ?
        CZ      DELAY2          ;DELAY IF MOTOR REALLY OFF
        LXI     H,MTIME         ;RESET MOTOR COUNTER
        SHLD    MTRCNT          
        RET
;                    
SPDR:	LDA	PHDRIV		;0 or 1
	MOV	E,A		;Save physical drive number to [E]
	INR	A		;Make it 1 or 2 (01 or 10)
	ORI	00001100B
	OUT	DSKSEL		;Select PHDRIV
	LDA	CURDRV		;Get currently selected drive no.
	CMP	E		;Same?
	RZ			;Yes no action needs done
;
;	Other drive selected, so update track register
;
	LXI	H,TRKTBL
	PUSH	H
	MOV	C,A		;[BC]=currently selected drive
	MVI	B,0
	DAD	B		;Calculate address of track table
	IN	FD$TRK		;Read current track position
	MOV	M,A		;Set it
	POP	H		;Load track table address
	MOV	D,B		;[DE]=newly selected drive
	DAD	D		;Calculate address of track table
	MOV	A,M		;Get selected drive's cureent track #
	OUT	FD$TRK		;Say to FDC
	MOV	A,E		;Get selected drive no.
	STA	CURDRV		;Update curdrv
	INR	A
	ORI	00001100B
	OUT	DSKSEL
	RET
;
;	Cancel down-count timer for motor
;
DMOTOR:	LXI	H,MTIME
	SHLD	MTRCNT
	RET
;
;	Seek track
;
PHSEEK:	CALL	BSYCHK		;Make sure FDC is ready for command
	LDA	PHTRCK		;Get physical track
	MOV	B,A
	ANA	A		;Track 0?
	MVI	A,0		;Assume not (i.e., double density)
	JRNZ	SELDBL		;Good assumption
	INR	A
SELDBL:	OUT	DENSEL
	IN	FD$TRK		;Get track # held in FDC's register
	CMP	B		;Compare them
	RZ			;Looks same, no action necessary
	MOV	A,B		;Different, seek operation must be done
	OUT	FD$DAT
	MVI	A,SEEK+STRATE
	OUT	FD$CMD		;Issue seek command
	CALL	BSYCHK		;Wait till FDC finishes seek
	ANI	10011000B	;Any errors?
	JZ      DELAY1	        ;No
	CALL	RETRY		;Recalibrate drive and bump retry counter
	JRC	PHSEEK		;Try again
	RET
;
DELAY2: LXI     H,40000         ;DELAY 0.5 SEC FOR MOTOR ON
        JMP     DELAY0
DELAY1º LXÉ     H,160°          ;DELAÙ 2° MSEÃ FOÒ SELECÔ TRACË STABLE
DELAY0: DCX     H
        EI                      ;ALLOW INTERRUPT TO UPDATE
        NOP                     ;KEYBOARD OR OTHER
        DI                      ;COUNTERS
        MOV     A,H
        ORA     L
        JRNZ    DELAY0
        RET
;
;	Wait until FDC is ready for new command
;
BSYCHK:	IN	FD$STT		;Get FDC status
	RAR			;Look busy bit [LSB]
	JRC	BSYCHK		;Wait
	RAL			;Remake status byte
	RET
;
;	****************************************
;	*** Boot program & set up parameters ***
;	****************************************
;
;
;	((( Cold boot routine )))
;
;
CBOOT:	DI
	LXI	SP,128		;Set temporary stack pointer
	XRA	A
	STA	LOGDIS		;Log to drive A
	STA	CURDRV		;Drive A is always selected at this point
	IN	FD$TRK
	STA	TRKTBL		;Set track table for drive A
	lda	uparms+10	;get default IOBYTE
	STA	IOBYT
	MVI	A,0C3H
	LXI	H,INTRPT	;Set interrupt vector
	STA	38H
	SHLD	39H
	MVI	A,15
	OUT	PSG$LW
	IN	PSG$DR
	ORI	00000010B	;Enable BASIC ROM
	OUT	PSG$DW
	LHLD	HOKENT
	ANI	11111101B	;Enable BK21
	OUT	PSG$DW
	LXI	D,75*3
	DAD	D
	MVI	M,0C3H		;Set up a hook
	INX	H
	LXI	D,CHKMOT
	MOV	M,E
	INX	H
	MOV	M,D
;
;	Modify screen parameters
;
	XRA	A		;Disable function key display
	STA	CNSDFG
	lda	uparms+4	;get line length
	ora	a
	jz	len40
	mvi	a,39		;set screen size to 39
	jmp	lenmor
;
len40:	MVI	A,40		;Set screen size to 40
lenmor:	STA	LINLEN
;
	lxi	h,uparms+1	;copy screen color information
	lxi	d,0fa0ah	;to BASIC ROM RAM work area
	mvi	b,3		;3 bytes
colors:	mov	a,m
	stax	d
	inx	h
	inx	d
	dcr	b
	jnz	colors		;if more to go
	lxi	h,fundef	;next, copy function key definitions
	lxi	d,0fa1eh	;to BASIC
	mvi	b,16*10
fkeys:	mov	a,m
	stax	d
	inx	h
	inx	d
	dcr	b
	jnz	fkeys		;if more to go
	lda	uparms+5	;set Fkey display mode
	sta	0fa06h
	LXI	H,INITXT
	CALL	CALROM		;Initialize VDP for text mode
	call	nit80		;init 80-column board
	call	nit232		;init RS-232 card
	LXI	H,HEDING
	CALL	STROUT
	JR	SETUP
;
HEDING:	DB	0ch,1ah,'Spectravideo CP/M-80 Revision 2.24'
	DB	0DH,0AH
	DB	'Copyright (C) by Digital Research'
	DB	0DH,0AH
	DB	0
;
;
;	((( Warm boot routine )))
;
;
WBOOT:	CALL	OLDWR		;Write a sector, if it remains.
;
;	Set up jump vector for system
;
SETUP:	MVI	A,0C3H		;Set jmp instruction.
	LXI	H,WBOOTE	;Set warm boot entry adrs.
	STA	0	 	;Put it into 0000H.
	SHLD	1		;Put them into 0001H
	LXI	H,DOSB		;Set up bdos function call.
	STA	5	 	;Set it into 0005H.
	SHLD	6		;Set operand, also.
	LXI	SP,128		;Set temporary stack pointer
;
;	Read CCP and BDOS
;
	CALL	BLKRD		;Read ccp & bdos
	DW	CPMB		;The start adrs.
	DB	13		;Set sector 13
	DB	1		;Set track 1
	DB	0		;Set drive A:
	DB	22		;(BIOSB-CPMB)/256
	LXI	B,128		;Set default DMA adrs.
	CALL	SETDMA
	XRA	A		;To wipe out them.
	STA	IFACT		;Reset buff active flag
	STA	DFL
	LDA	LOGDIS		;Get log disk.
	MOV	C,A		;Tell CCP drive=(C)
	JMP	CPMB		;Get into CP/M main.
;
;	((( Block read/write utility )))
;
;	Calling sequence
;
;		CALL	BLKRD / BLKWRT
;		DW	Start address
;		DB	Sector
;		DB	Track
;		DB	Drive
;		DB	# of sectors to be read / written
;
BLKRD:	DB	11100110B	;Clear carry for read
BLKWRT:	STC			;Set carry for write
	XTHL
	MOV	E,M
	INX	H
	MOV	D,M
	SDED	PHADDR
	INX	H
	LXI	D,PHSECT
	LXI	B,3
	LDIR
	MOV	B,M		;Grab counter.
	INX	H		;Make final adrs.
	XTHL			;Save bumped adrs.
RELOOP:	PUSH	B		;Save sector count
	PUSH	PSW		;Save read/write flag
	LHLD	PHADDR		;Get target address
	CALL	DISKIO		;Do disk read/write
	CALL	UPDATE		;Update parameters
	POP	PSW		;Restore read/write flag
	POP	B		;Restore sector count
	DJNZ	RELOOP
	RET
;
UPDATE:	LDA	PHTRCK
	ANA	A		;Track 0?
	LXI	D,256		;Assume not
	MVI	C,17+1
	JRNZ	UPDDBL		;Good assumption
	LXI	D,128
	INR	C
UPDDBL:	LHLD	PHADDR
	DAD	D
	SHLD	PHADDR
	LXI	H,PHSECT
	INR	M
	MOV	A,M
	CMP	C		;Wrapped to next sector?
	RC			;No
	MVI	M,1		;Set sector 1
	INX	H		;Point to PHTRCK
	INR	M		;Bump track # also
	RET
;
STROUT:	MOV	A,M		;Get string
	ORA	A		;End of string?
	RZ			;Yes
	MOV	C,A		;Character should be passed via [C]
	PUSH	H
	CALL	CONOUT
	POP	H
	INX	H
	JR	STROUT
;
;	**************************
;	*** Work area for BIOS ***
;	**************************
;
MTRCNT:	DW	0	;Downcount timer for motor
;
DIRFLG:	DB	0
ODDFLG:	DB	0
SECFLG:	DB	0	;To check odd or even.
;
;	Logical disk paramters
;
NEWPRM:
LOGDRV:	DB	0	;Logical drive number.
LOGTRK:	DB	0	;Logical track number.
LOGSEC:	DB	1	;Logical sector number.
;
;	Old disk parameters
;
OLDPRM:
OLDDRV:	DB	0	;Old drive number.
OLDTRK:	DB	0	;Old track number.
OLDSEC:	DB	1	;Old sector number.

;
;
CURDRV:	DB	0	;Current selected drive#
TRKTBL:	DS	2	;Track # of each drive
CSV0:	DS	35
ALV0:	DS	35
CSV1:	DS	35
ALV1:	DS	35
DIRBUF:	DS	128
;
;	****************************
;	*** Blocking buffer area ***
;	****************************
;
;	(((( Blocking buffer diagram ))))
;
;	Physical sector:	Temporary buff:
;	(256 bytes):IFBUFF	(128 bytes):BUF2
;	]----------------[	]--------------[
;	] Logical sector [	] Tempo. buff. [
;	]  (odd	sector)  [	]  at pre-read [
;	]----------------[	]--------------[
;	] Logical sector [
;	]  (even sector) [
;	]----------------[
;
;	)))((( This part will be used as blocking buffer )))(((
;
;
IFBUFF:	DS	256
BUF2:	DS	128
SCA	EQU	IFBUFF
SCB	EQU	IFBUFF+128
;
;	Following 4 variables are parameters	passed to physical disk
;	driver.	The order must be exactly as shown.
;
PHADDR:	DS	2	;Desired DMA address
PHSECT:	DS	1	;Desired sector #
PHTRCK:	DS	1	;Desired track #
PHDRIV:	DS	1	;Desired drive #
;
RTYCNT:	DS	1	;Retry counter
DFL:	DS	1	;Buffer-remain flag
IFACT:	DS	1	;Buffer activate flag.
BUFADR:	DS	2	;Dma adrs for logical transfer.
	DS	2*50	;Stack area when calling ROM routines
BIOSTK:
	DS	2*50	;Stack area when interrupt occured
INTSTK:

	END
