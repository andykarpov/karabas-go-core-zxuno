; Bench test of Ф2 (ZX-Uno core): RTC through the Gluk ports, RTC through the DS1307 on the ZX-Uno I2C
; register F8, ESP8266 through the ZX-Uno UART registers C6 / C7. Builds rtcesp.sna (48K) for the esxDOS
; NMI browser:  /opt/sjasmplus/sjasmplus rtcesp.asm
; No ROM calls (the snapshot has no BASIC system variables): own print with the ROM font at 3D00h, DI.
;   row 0  GLUK hh:mm:ss      (MC146818 registers 4 / 2 / 0 through EFF7 / DFF7 / BFF7, BCD)
;   row 1  I2C  hh:mm:ss  ACK a b c d   (DS1307 at D0h, ACK 0 = acked)
;   row 3  ESP: reply to "AT" CR LF, CR / LF shown as '.'

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
	ld (hl), 47h		; bright white on black
	ldir

; ---- Gluk ----
	ld hl, 0
	ld (cur), hl
	ld hl, t_gluk
	call pstr
	ld bc, 0EFF7h
	ld a, 80h
	out (c), a
	ld a, 4
	call gluk_rd
	call phex
	ld a, ':'
	call pchar
	ld a, 2
	call gluk_rd
	call phex
	ld a, ':'
	call pchar
	ld a, 0
	call gluk_rd
	call phex
	ld bc, 0EFF7h
	xor a
	out (c), a

; ---- DS1307 over I2C ----
	ld hl, 0100h
	ld (cur), hl
	ld hl, t_i2c
	call pstr
	call i2c_sel
	call i2c_start
	ld a, 0D0h
	call i2c_out
	ld (acks+0), a
	xor a
	call i2c_out
	ld (acks+1), a
	ld a, 1			; repeated start
	call i2c_set
	ld a, 3
	call i2c_set
	ld a, 2
	call i2c_set
	xor a
	call i2c_set
	ld a, 0D1h
	call i2c_out
	ld (acks+2), a
	ld a, 0
	call i2c_in		; seconds, ACK
	ld (tm+0), a
	ld a, 0
	call i2c_in		; minutes, ACK
	ld (tm+1), a
	ld a, 1
	call i2c_in		; hours, NACK
	ld (tm+2), a
	call i2c_stop
	ld a, (tm+2)
	and 3Fh
	call phex
	ld a, ':'
	call pchar
	ld a, (tm+1)
	call phex
	ld a, ':'
	call pchar
	ld a, (tm+0)
	call phex
	ld hl, t_ack
	call pstr
	ld a, (acks+0)
	call phex
	ld a, ' '
	call pchar
	ld a, (acks+1)
	call phex
	ld a, ' '
	call pchar
	ld a, (acks+2)
	call phex

; ---- ESP ----
	ld hl, 0300h
	ld (cur), hl
	ld hl, t_esp
	call pstr
	call flush		; anything left in the receiver
	ld hl, t_at
.tx:	ld a, (hl)
	or a
	jr z, .rx
	call uart_tx
	inc hl
	jr .tx
.rx:	ld ix, 0		; bytes received
	ld de, 0		; idle timeout
	ld a, 8			; x 65536 loops
	ld (tmo), a
.rxl:	call uart_st
	bit 7, a
	jr z, .idle
	call uart_rd
	cp ' '
	jr nc, .pr
	ld a, '.'
.pr:	call pchar
	inc ix
	ld de, 0
	jr .rxl
.idle:	dec de
	ld a, d
	or e
	jr nz, .rxl
	ld hl, tmo
	dec (hl)
	jr nz, .rxl
	ld hl, 0A00h
	ld (cur), hl
	ld hl, t_cnt
	call pstr
	ld a, ixl
	call phex
	ld hl, t_done
	call pstr
	jr $

; ---- Gluk: A = register -> A = value ----
gluk_rd:
	ld bc, 0DFF7h
	out (c), a
	ld bc, 0BFF7h
	in a, (c)
	ret

; ---- I2C on ZX-Uno register F8: bit 1 SCL, bit 0 SDA; read bit 7 = SDA ----
i2c_sel:
	ld bc, ZXUNO_ADDR
	ld a, 0F8h
	out (c), a
	ret
i2c_set:			; A = {scl, sda}
	ld bc, ZXUNO_DATA
	out (c), a
	push bc
	ld b, 20
	djnz $
	pop bc
	ret
i2c_start:
	ld a, 3
	call i2c_set
	ld a, 2
	call i2c_set
	xor a
	jp i2c_set
i2c_stop:
	xor a
	call i2c_set
	ld a, 2
	call i2c_set
	ld a, 3
	jp i2c_set
i2c_out:			; A = byte -> A = ACK bit (0 = acked)
	ld l, a
	ld h, 8
.b:	xor a
	rl l
	rla			; A = data bit
	call i2c_set		; SCL low
	or 2
	call i2c_set		; SCL high
	and 1
	call i2c_set		; SCL low
	dec h
	jr nz, .b
	ld a, 1
	call i2c_set
	ld a, 3
	call i2c_set
	in a, (c)
	rlca
	and 1
	push af
	ld a, 1
	call i2c_set
	pop af
	ret
i2c_in:				; A = 0 ACK / 1 NACK -> A = byte
	push af
	ld l, 0
	ld h, 8
.b:	ld a, 1
	call i2c_set
	ld a, 3
	call i2c_set
	in a, (c)
	rla
	rl l
	ld a, 1
	call i2c_set
	dec h
	jr nz, .b
	pop af
	push af
	call i2c_set		; SDA = ack bit, SCL low
	pop af
	push af
	or 2
	call i2c_set
	pop af
	call i2c_set
	ld a, 1
	call i2c_set		; release SDA
	ld a, l
	ret

; ---- UART: C7 status (bit 7 rx data, bit 6 tx busy), C6 data ----
uart_st:
	ld bc, ZXUNO_ADDR
	ld a, 0C7h
	out (c), a
	ld bc, ZXUNO_DATA
	in a, (c)
	ret
uart_rd:
	ld bc, ZXUNO_ADDR
	ld a, 0C6h
	out (c), a
	ld bc, ZXUNO_DATA
	in a, (c)
	ret
uart_tx:			; A = byte
	push af
.w:	call uart_st
	bit 6, a
	jr nz, .w
	ld bc, ZXUNO_ADDR
	ld a, 0C6h
	out (c), a
	ld bc, ZXUNO_DATA
	pop af
	out (c), a
	ret
flush:
	ld d, 0
.l:	call uart_st
	bit 7, a
	ret z
	call uart_rd
	dec d
	jr nz, .l
	ret

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
	ex de, hl		; DE = glyph
	ld hl, (cur)		; L = col, H = row
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

cur:	dw 0
tmo:	db 0
tm:	db 0, 0, 0
acks:	db 0, 0, 0
t_gluk:	db "GLUK ", 0
t_i2c:	db "I2C  ", 0
t_ack:	db " ACK ", 0
t_esp:	db "ESP: ", 0
t_at:	db "AT", 13, 10, 0
t_cnt:	db "ESP BYTES ", 0
t_done:	db "  DONE", 0

	SAVESNA "rtcesp.sna", start
