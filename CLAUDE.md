# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A ZX-Uno ZX Spectrum core for the Karabas Go, Mini and Mini G boards (Xilinx Spartan-6 XC6SLX25, ISE 14.7, XST): a port of the ZX-Uno Spectrum core EXP28 ([zxtres/zxspectrum](https://github.com/zxtres/zxspectrum) `exp28/`, GPL-3, ZXTRES Artix-7 version; the generic RTL without `artix7/` and `zxtres_wrapper/`). Added on top: audio peaks + dot matrix, MIDI, ESP8266 through the ZX-Uno UART registers, General Sound and OPL4 copied from core-tsconf (behind the Ф0 fit gate). Docs, in Russian: `docs/PLAN.md` (research, decisions, phases). Follow the phases; record a changed decision in PLAN.md.

User decisions (2026-11-18): base EXP28; no ZX-Uno BIOS, the 128K ROM and esxDOS 0.8.9 are loadable ROMs (`roms` of `core.json`, in the `.kg`, NOT in the bitstream), written by the firmware into their ZX-Uno SRAM banks, settings in the OSD; the dot matrix moves to ZX-Uno registers E0 / E1 / E2 in ALL cores (zxuno, tsconf, profi, next + firmware docs/matrix*.md), because F0-F3 are the PZX player registers of the ZX-Uno; GS and OPL4 are copies from core-tsconf. Public repo, core id `zxuno`.

## Rules of the core

The rules of the other karabas-go cores apply: standard video timing with syncs always present, `FT_CLK_OUT` driven on Mini / Mini G, Go `FDC_*` outputs 0 when unused, `FLASH_CS_N` as in core-tsconf, OSD switch index = item position unless `"index"`, an OSD value shows 10 characters at most, FL slots 0..7 only, Verilog-2001 for XST, imported code marked `// karabas:` / `-- karabas:`.

- **Ask the user before every check on the board** (and the HDMI capture). Ask before a firmware flash. OSD screens need the user's yes.
- One branch per phase of `docs/PLAN.md`, one PR at its end.
- Heavy builds: Mini G only while working on one feature, all boards for a release; map with cost table 2 first.

## Memory

The Claude Code memory of this repo is shared with all karabas-go repos: `~/.claude/projects/<this project>/memory` is a symlink to `../karabas-go-notes` (private repo `andykarpov/karabas-go-notes`). Its `MEMORY.md` is split by repo; commit and push it after every memory change.
