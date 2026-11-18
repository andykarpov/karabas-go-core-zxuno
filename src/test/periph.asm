; Bench test of Ф2 (ZX-Uno core), part 2: DMA, PZX player, Specdrum, joysticks, Kempston mouse.
; Builds periph.sna (48K) for the esxDOS NMI browser:  /opt/sjasmplus/sjasmplus periph.asm
; No ROM calls (no BASIC system variables in the snapshot), DI.
;   row 0  DMA  OK / ERR nnnn   768 bytes ROM 3D00h -> 9000h, burst memory to memory (regs A0..A4)
;   row 1  PZX  xx xx xx xx xx xx E nnnn   (SRAM through F0 / F1 / F2, VDECKCTRL F3 play,
;          a PULSE block of 1000 pulses of 1000 T: ~1000 edges on EAR, port FE bit 6)
;   row 2  DRUM done                 (~2 s square wave of 500 Hz on the Specdrum port DF)
;   rows 4..  live: KEMP (1F), FULL (7F), SIN1 (EFFE row, keys 6..0), SIN2 (F7FE row, keys 1..5),
;          MOUSE X (FBDF) Y (FFDF) B (FADF); refreshed forever

	DEVICE ZXSPECTRUM48

ZXUNO_ADDR	equ 0FC3Bh
ZXUNO_DATA	equ 0FD3Bh

	org 8000h
start:
	di
	ld sp, 0BFF0h
	xor a
	out (0FEh), a
	ld hl, 4000h
	ld de, 4001h
	ld bc, 6143
	ld (hl), 0
	ldir
	ld hl, 5800h
	ld de, 5801h
	ld bc, 767
	ld (hl), 47h
	ldir

; ---- DMA: 3D00h -> 9000h, 768 bytes, burst ----
	ld hl, 0
	ld (cur), hl
	ld hl, t_dma
	call pstr
	ld hl, 9000h		; clear the target
	ld de, 9001h
	ld bc, 767
	ld (hl), 0
	ldir
	ld a, 0A1h		; DMASRC
	ld hl, 3D00h
	call wreg16
	ld a, 0A2h		; DMADST
	ld hl, 9000h
	call wreg16
	ld a, 0A3h		; DMAPRE
	ld hl, 0
	call wreg16
	ld a, 0A4h		; DMALEN
	ld hl, 768
	call wreg16
	ld a, 0A0h		; DMACTRL: memory to memory, burst
	ld e, 01h
	call wreg
	ld b, 0
	djnz $			; the burst holds the CPU anyway
	ld a, 0A0h
	ld e, 0
	call wreg
	ld hl, 3D00h		; compare
	ld de, 9000h
	ld bc, 768
	ld ix, 0
.cmp:	ld a, (de)
	cp (hl)
	jr z, .eq
	inc ix
.eq:	inc hl
	inc de
	dec bc
	ld a, b
	or c
	jr nz, .cmp
	ld a, ixh
	or ixl
	jr nz, .derr
	ld hl, t_ok
	call pstr
	jr pzx
.derr:	ld hl, t_err
	call pstr
	ld a, ixh
	call phex
	ld a, ixl
	call phex

; ---- PZX ----
pzx:
	ld hl, 0100h
	ld (cur), hl
	ld hl, t_pzx
	call pstr
	call pzx_addr0
	ld hl, pzxdata
	ld b, pzxlen
.w:	push bc
	ld a, 0F2h		; SRAMDATA
	ld e, (hl)
	call wreg
	ld a, 0F1h		; SRAMADDRINC
	ld e, 0
	call wreg
	pop bc
	inc hl
	djnz .w
	call pzx_addr0		; read back the first 6 bytes
	ld b, 6
.r:	push bc
	ld a, 0F2h
	call rreg
	call phex
	ld a, ' '
	call pchar
	ld a, 0F1h
	ld e, 0
	call wreg
	pop bc
	djnz .r
	call pzx_addr0
	ld a, 0F3h		; VDECKCTRL: play = bit 0 going 1 -> 0
	ld e, 1
	call wreg
	ld a, 0F3h
	ld e, 0
	call wreg
	ld hl, 0		; edges
	ld de, 0		; samples: 65536 x ~60 T = ~1.1 s
	ld bc, 0FEFEh
	in a, (c)
	and 40h
	ld (last), a
.s:	in a, (c)
	and 40h
	push hl
	ld hl, last
	cp (hl)
	ld (hl), a
	pop hl
	jr z, .n
	inc hl
.n:	dec de
	ld a, d
	or e
	jr nz, .s
	push hl
	ld hl, t_edges
	call pstr
	pop hl
	ld a, h
	call phex
	ld a, l
	call phex

; ---- Specdrum ----
	ld hl, 0200h
	ld (cur), hl
	ld hl, t_drum
	call pstr
	ld de, 1000		; half periods of ~3500 T: 500 Hz, ~1 s
.d:	ld a, e
	and 1
	jr z, .lo
	ld a, 0E0h
	jr .o
.lo:	ld a, 20h
.o:	out (0DFh), a
	ld b, 0
.dl:	djnz .dl		; 256 x 13 T
	dec de
	ld a, d
	or e
	jr nz, .d
	ld a, 80h
	out (0DFh), a
	ld hl, t_done
	call pstr

; ---- live ports ----
live:
	ld hl, 0400h
	ld (cur), hl
	ld hl, t_kemp
	call pstr
	in a, (1Fh)
	call phex
	ld hl, 0500h
	ld (cur), hl
	ld hl, t_full
	call pstr
	in a, (7Fh)
	call phex
	ld hl, 0600h
	ld (cur), hl
	ld hl, t_sin1
	call pstr
	ld bc, 0EFFEh
	in a, (c)
	call phex
	ld hl, 0700h
	ld (cur), hl
	ld hl, t_sin2
	call pstr
	ld bc, 0F7FEh
	in a, (c)
	call phex
	ld hl, 0800h
	ld (cur), hl
	ld hl, t_mouse
	call pstr
	ld bc, 0FBDFh
	in a, (c)
	call phex
	ld a, ' '
	call pchar
	ld bc, 0FFDFh
	in a, (c)
	call phex
	ld a, ' '
	call pchar
	ld bc, 0FADFh
	in a, (c)
	call phex
	ld hl, (frames)
	inc hl
	ld (frames), hl
	ld hl, 0900h
	ld (cur), hl
	ld hl, t_loop
	call pstr
	ld hl, (frames)
	ld a, h
	call phex
	ld a, l
	call phex
	jp live

; ---- ZX-Uno registers ----
wreg:				; A = register, E = value
	ld bc, ZXUNO_ADDR
	out (c), a
	ld bc, ZXUNO_DATA
	out (c), e
	ret
rreg:				; A = register -> A = value
	ld bc, ZXUNO_ADDR
	out (c), a
	ld bc, ZXUNO_DATA
	in a, (c)
	ret
wreg16:				; A = register, HL = value (low byte first)
	push af
	ld e, l
	call wreg
	pop af
	ld e, h
	jp wreg
pzx_addr0:			; SRAMADDR = 0 (three writes: a = {a[12:0], din})
	ld a, 0F0h
	ld e, 0
	call wreg
	ld a, 0F0h
	call wreg
	ld a, 0F0h
	jp wreg

; ---- print: (cur) = col (low) / row (high) ----
pstr:	ld a, (hl)
	or a
	ret z
	push hl
	call pchar
	pop hl
	inc hl
	jr pstr
phex:	push af
	rrca
	rrca
	rrca
	rrca
	call .n
	pop af
.n:	and 0Fh
	add a, '0'
	cp '9'+1
	jr c, pchar
	add a, 7
pchar:				; A = char, keeps BC, DE, IX
	push bc
	push de
	push hl
	sub ' '
	ld l, a
	ld h, 0
	add hl, hl
	add hl, hl
	add hl, hl
	ld de, 3D00h
	add hl, de
	ex de, hl
	ld hl, (cur)
	ld a, h
	and 18h
	or 40h
	ld b, a
	ld a, h
	and 7
	rrca
	rrca
	rrca
	or l
	ld l, a
	ld h, b
	ld b, 8
.r:	ld a, (de)
	ld (hl), a
	inc de
	inc h
	djnz .r
	ld hl, (cur)
	inc l
	ld a, l
	cp 32
	jr c, .s
	ld l, 0
	inc h
	ld a, h
	cp 24
	jr c, .s
	ld h, 23
.s:	ld (cur), hl
	pop hl
	pop de
	pop bc
	ret

; PZX of the ZX-Uno player: tag, 32-bit length, data. PULSE: word 8000h | count, word duration (T).
pzxdata:
	db 2, 4, 0, 0, 0
	dw 8000h | 1000, 1000
	db 0, 0, 0, 0, 0	; FULLSTOP
pzxlen	equ $ - pzxdata

cur:	dw 0
last:	db 0
frames:	dw 0
t_dma:	db "DMA  ", 0
t_ok:	db "OK", 0
t_err:	db "ERR ", 0
t_pzx:	db "PZX  ", 0
t_edges: db "E ", 0
t_drum:	db "DRUM ", 0
t_done:	db "done", 0
t_kemp:	db "KEMP  ", 0
t_full:	db "FULL  ", 0
t_sin1:	db "SIN1  ", 0
t_sin2:	db "SIN2  ", 0
t_mouse: db "MOUSE ", 0
t_loop:	db "LOOP  ", 0

	SAVESNA "periph.sna", start
