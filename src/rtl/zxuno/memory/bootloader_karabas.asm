; karabas: the boot stub of the ZX-Uno core for the Karabas boards, after bootloader_copy_bram_to_sram.asm
; (ZX-Uno, GPL-3). The firmware has already written the ROMs into the SRAM (core.json "roms": 128K ROM in banks
; 8..11, esxDOS at 0x30000), so nothing is copied from block RAM. The stub shows the ZX-Uno logo of the BIOS
; (zxdos/zxuno firmware/logo256x192.rcs.zx7b, unpacked to zxuno_logo.scr) for about 1.5 s, then sets
; MASTERCONF (128K, DivMMC + esxDOS, locked, boot mode off), clears the DivMMC RAM and starts the 128K ROM.
; Build: sjasmplus --raw=bootloader_karabas.bin bootloader_karabas.asm (then bin -> hex, see the Makefile)

ZXUNOADDR             equ 0FC3Bh
ZXUNODATA             equ 0FD3Bh
MAPPER128K            equ 7FFDh
MAPPERPLUS3           equ 1FFDh
DIVIDECTRL            equ 0E3h
MASTERCONF            equ 0
SCANDBLCTRL           equ 0Bh

                      org 0
                      di
                      xor a
                      out (254),a               ; black border
                      ld bc,ZXUNOADDR           ; 28 MHz
                      ld a,SCANDBLCTRL
                      out (c),a
                      inc b
                      in a,(c)
                      or 0C0h
                      out (c),a

                      ld hl,Logo                ; the logo to the screen (4000h = video RAM in boot mode)
                      ld de,4000h
                      ld bc,6912
                      ldir

                      ld d,24                   ; ~1.5 s at 28 MHz: 24 x 65536 x 26 T
Delay1                ld bc,0
Delay2                dec bc
                      ld a,b
                      or c
                      jr nz,Delay2
                      dec d
                      jr nz,Delay1

                      ld hl,UltimaFaseEnRAM     ; the rest runs from RAM: MASTERCONF pages the ROM out
                      ld de,8000h
                      ld bc,LongUltimaFase
                      ldir
                      jp 8000h

UltimaFaseEnRAM       ld bc,ZXUNOADDR
                      ld a,MASTERCONF
                      out (c),a
                      inc b
                      ld a,10010010b            ; 128K, DivMMC + esxDOS, locked, no boot
                      out (c),a
                      ld bc,MAPPER128K
                      ld a,00010000b
                      out (c),a
                      ld bc,MAPPERPLUS3
                      ld a,00000100b
                      out (c),a

                      ld a,80h                  ; clear the 16 pages of DivMMC RAM (CONMEM), forces a restart
BucleEraseDivMMC      out (DIVIDECTRL),a
                      ld hl,2000h
                      ld de,2001h
                      ld bc,1FFFh
                      ld (hl),l
                      ldir
                      inc a
                      cp 90h
                      jr nz,BucleEraseDivMMC
                      xor a
                      out (DIVIDECTRL),a

                      ld bc,ZXUNOADDR           ; back to 3.5 MHz, start the 128K ROM
                      ld a,SCANDBLCTRL
                      out (c),a
                      inc b
                      in a,(c)
                      and 3Fh
                      out (c),a
                      jp 0
LongUltimaFase        equ $-UltimaFaseEnRAM

Logo                  incbin "zxuno_logo.scr"
