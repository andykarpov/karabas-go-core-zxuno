# ZX-Uno core for Karabas Go / Mini / Mini G

[Русская версия](README.ru.md)

ZX Spectrum for the Karabas Go board family (Xilinx Spartan-6 XC6SLX25), based on the ZX-Uno Spectrum core EXP28 ([zxtres/zxspectrum](https://github.com/zxtres/zxspectrum), GPL-3, (c) ZXUNO association, Miguel Angel Rodriguez Jodar and contributors), with the General Sound and the FM part of the MoonSound from the TS-Conf core of the Karabas.

| Board | Core file | Video | Sound |
|---|---|---|---|
| Karabas Go | `zxuno.kg` | VGA | I2S DAC (PCM5102) |
| Karabas Mini | `zxuno.kg` | HDMI | HDMI, analog output (sigma-delta) |
| Karabas Mini G | `zxuno.kg` | HDMI | HDMI, I2S DAC |

The core file is in `src/`. The 128K ROM, esxDOS 0.9.0 (the DivMMC firmware) and the GS ROM are in it (`core.json` "roms", loaded by the firmware: a new ROM does not need a new bitstream). There is no ZX-Uno BIOS: its settings are in the OSD.

Status: build 26111819. Mini G: the machine, the peripherals, the MIDI synth, the dot matrix and its meters, the GS, the OPL3 and the start screen were checked on a board. The Go and Mini builds have not been run on a board.

## Features

- **Machine:** ZX Spectrum 48K / 128K / Pentagon timings, CPU at 3.5 / 7 / 14 / 28 MHz, contention, keyboard issue 2 / 3; ULAplus, Timex hi-colour / hi-res, Radastan; the DMA, the PZX tape player and the register file (FC3B / FD3B) of ZX-Uno.
- **Storage:** DivMMC with esxDOS 0.9.0 on SD2 (NMI: the esxDOS browser).
- **Sound:** two AY (Turbosound), SAA1099, Specdrum / Covox, beeper and tape; the **General Sound** (ports BB / B3, its Z80 and 2 MB of memory in the SDRAM); the **OPL3**: the FM part of the ZXM-MoonSound (ports C4..C7, no wavetable part); the MIDI synth of the board on the AY port A (`PLAY "Y1..."` of the 128K BASIC), on the Mini / Mini G its sound comes back through the ADC into the mix.
- **Dot matrix** (the add-on on the I2C of the board): the audio meters, and drawing from the Spectrum through the ZX-Uno registers **E0 / E1 / E2** (karabas-go-firmware `docs/matrix.md`).
- **ESP8266** (Wi-Fi) on the UART registers C6 / C7 of ZX-Uno.
- **Clock:** the RTC of the board as the Gluk CMOS (ports EFF7 / DFF7 / BFF7) and as a DS1307 on the I2C of ZX-Uno (register F8).
- **Controllers:** the USB keyboard, two joysticks (Kempston, Sinclair 1 / 2, cursor, Fuller), the Kempston mouse (ports FBDF / FFDF / FADF).
- **Video:** the picture of the ULA line-doubled to 720 x 576 at 50 Hz; colour or a green / amber / grey monitor.

Not done: the ZX-Uno BIOS, the wavetable part of the OPL4, the raw PS/2 registers of the mouse.

## Getting started

1. Copy `zxuno.kg` (one file for Go, Mini and Mini G) to the root of the SD card of the firmware.
2. SD2 (the card of the DivMMC): the `SYS` and `BIN` folders of [esxDOS 0.9.0](https://www.esxdos.org/) ([esxdos090.zip](https://www.esxdos.org/files/esxdos090.zip)) and your programs. See [esxDOS 0.9.0 on SD2](#esxdos-090-on-sd2) when the card has an older esxDOS.
3. Choose ZX-Uno in the core menu: the start screen, then esxDOS starts the 48K BASIC. **F11** opens the esxDOS browser.

"Menu" is the Windows key of the keyboard. esxDOS 0.9.0 always starts the 48K ROM: for the 128K menu set DivMMC to Off and press **F12**.

### esxDOS 0.9.0 on SD2

Since build 26112002 the core has the esxDOS 0.9.0 ROM. This ROM checks the version of `SYS/ESXDOS.SYS` and does not start with the system files of 0.8.x, so update SD2 together with the core:

- copy the `SYS` and `BIN` folders of [esxdos090.zip](https://www.esxdos.org/files/esxdos090.zip) to the root of SD2 (the system commands are in `SYS/BIN` now; their old copies in `BIN` are not used any more);
- long file names: take the new `SYS/CONFIG/ESXDOS.CFG` or add the line `LFN=1` to yours;
- ZX Next on the same card: replace `machines/next/ESXMMC.BIN` with `ROMS/esxdos-0.9.0-divmmc.bin` of the archive, renamed to `ESXMMC.BIN` (the Next machines with DivMMC need the same version as `SYS`);
- `NMI.SYS` / `RTC.SYS` made for older esxDOS versions must be rebuilt for the new addresses ($2000 / $2F00);
- the ROM itself is in `zxuno.kg`: do not flash it with the `FLASHERS` tapes of the archive.

## OSD menu

| Page | Item | Values | Hotkey |
|---|---|---|---|
| | Timing | 48K / 128K / Pentagon | Menu+F1 |
| | CPU speed | 3.5 / 7 / 14 / 28 MHz | Menu+F2 |
| | Contention | On / Off | |
| | Keyboard | Issue 3 / Issue 2 | |
| | DivMMC | On / Off | |
| | NMI | the esxDOS browser | F11 |
| | Reset | | F12 |
| | Hard reset | the boot of ZX-Uno again (start screen) | Menu+F12 |
| Video | ULAplus, Timex, Radastan | On / Off | |
| Video | Palette | Colour / Green / Amber / Grey | |
| Sound | AY, Turbosound, SAA1099, Specdrum, GS, OPL3 | On / Off | |
| Sound | Stereo | ABC / ACB / Mono | |
| Input | Joystick L, Joystick R | Kempston / Sinclair1 / Sinclair2 / Cursor / Fuller / Off | |
| Input | Mouse | On / Off | |

## Ports

| Device | Ports |
|---|---|
| ZX-Uno registers | FC3B (register) / FD3B (data) |
| Dot matrix | registers E0 (control), E1 (x / y), E2 (colour) |
| ESP8266 | registers C6 (data), C7 (status) |
| RTC | Gluk: EFF7 (bit 7 = on), DFF7 (address), BFF7 (data); DS1307: I2C on register F8 |
| General Sound | BB (command / status), B3 (data) |
| OPL3 (FM of MoonSound) | C4 / C5 bank 0, C6 / C7 bank 1 (address / data) |
| Kempston mouse | FBDF (x), FFDF (y), FADF (buttons) |

While the OPL3 is on, C4..C7 are taken by it: the ULA, 7FFD and the AY of ZX-Uno do not see these ports.

## Building

Clone with `--recursive` (the `modules` submodule). ISE 14.7: `cd src && make` for all boards or `make minig` for one. The Go and Mini tops are made from the Mini G top by `src/tools/mktop.py`. The boot stub (`src/rtl/zxuno/memory/bootloader_karabas.asm`, the start screen `zxuno_logo.scr`) is built with sjasmplus. Simulations (iverilog): `src/sim/tb_matrix.v`, `src/sim/tb_opl3.v`; the bench tests for the board: `src/test/*.asm` (`.sna` for the esxDOS browser). The plan and the design notes are in [docs/PLAN.md](docs/PLAN.md) (Russian).

## Licence

GPL v3 ([LICENSE](LICENSE)). ZX-Uno: (c) ZXUNO association and the authors of its files; opl3_fpga: LGPL-3 (`src/rtl/opl3/COPYING.LESSER`); z80-silicon: GPL-3 (`src/rtl/z80-silicon/LICENSE`). The 128K ROM is (c) Amstrad, which allows its distribution with emulators; esxDOS and the GS ROM belong to their authors. Imported files keep the licence headers of their authors.
