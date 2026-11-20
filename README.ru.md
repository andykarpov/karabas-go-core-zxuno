# Ядро ZX-Uno для Karabas Go / Mini / Mini G

[English version](README.md)

ZX Spectrum для плат семейства Karabas Go (Xilinx Spartan-6 XC6SLX25) на основе Spectrum-ядра ZX-Uno EXP28 ([zxtres/zxspectrum](https://github.com/zxtres/zxspectrum), GPL-3, (c) ZXUNO association, Miguel Angel Rodriguez Jodar и соавторы), с General Sound и FM-частью MoonSound из ядра TS-Conf для Karabas.

| Плата | Файл ядра | Видео | Звук |
|---|---|---|---|
| Karabas Go | `zxuno.kg` | VGA | I2S ЦАП (PCM5102) |
| Karabas Mini | `zxuno.kg` | HDMI | HDMI, аналоговый выход (сигма-дельта) |
| Karabas Mini G | `zxuno.kg` | HDMI | HDMI, I2S ЦАП |

Файл ядра лежит в `src/`. В нём ПЗУ 128K, esxDOS 0.9.0 (прошивка DivMMC) и ПЗУ GS (`core.json` «roms», их загружает прошивка платы: для новой ПЗУ не нужна новая прошивка FPGA). BIOS ZX-Uno нет: его настройки — в OSD.

Состояние: сборка 26111819. Mini G: машина, периферия, MIDI-синтезатор, матрица и её индикаторы, GS, OPL3 и стартовый экран проверены на плате. Сборки для Go и Mini на плате не запускались.

## Возможности

- **Машина:** тайминги ZX Spectrum 48K / 128K / Pentagon, процессор 3.5 / 7 / 14 / 28 МГц, конфликты памяти, клавиатура issue 2 / 3; ULAplus, Timex hi-colour / hi-res, Radastan; DMA, PZX-плеер ленты и регистры ZX-Uno (FC3B / FD3B).
- **Накопитель:** DivMMC с esxDOS 0.9.0 на SD2 (NMI — браузер esxDOS).
- **Звук:** два AY (Turbosound), SAA1099, Specdrum / Covox, бипер и лента; **General Sound** (порты BB / B3, его Z80 и 2 МБ памяти в SDRAM); **OPL3** — FM-часть ZXM-MoonSound (порты C4..C7, без волновой части); MIDI-синтезатор платы на порту A AY (`PLAY "Y1..."` 128K BASIC), на Mini / Mini G его звук возвращается через АЦП в общую смесь.
- **Светодиодная матрица** (дополнительная плата на I2C): индикаторы уровня звука и рисование со стороны Спектрума через регистры ZX-Uno **E0 / E1 / E2** (karabas-go-firmware `docs/matrix.ru.md`).
- **ESP8266** (Wi-Fi) на регистрах UART ZX-Uno C6 / C7.
- **Часы:** RTC платы как CMOS Gluk (порты EFF7 / DFF7 / BFF7) и как DS1307 на I2C ZX-Uno (регистр F8) и ZX Next (порты 103B / 113B).
- **Управление:** USB-клавиатура, два джойстика (Kempston, Sinclair 1 / 2, курсорный, Fuller), Kempston-мышь (порты FBDF / FFDF / FADF).
- **Видео:** картинка ULA с удвоением строк, 720 x 576, 50 Гц; цветная или как на зелёном / янтарном / сером мониторе.

Не сделано: BIOS ZX-Uno, волновая часть OPL4, «сырые» PS/2-регистры мыши.

## Как начать

1. Скопируйте `zxuno.kg` (один файл для Go, Mini и Mini G) в корень SD-карты прошивки.
2. SD2 (карта DivMMC): папки `SYS` и `BIN` из [esxDOS 0.9.0](https://www.esxdos.org/) ([esxdos090.zip](https://www.esxdos.org/files/esxdos090.zip)) и ваши программы. Если на карте старый esxDOS — см. [esxDOS 0.9.0 на SD2](#esxdos-090-на-sd2).
3. Выберите ZX-Uno в меню ядер: стартовый экран, затем esxDOS запускает 48K BASIC. **F11** открывает браузер esxDOS.

«Menu» — клавиша Windows. esxDOS 0.9.0 всегда запускает ПЗУ 48K: чтобы попасть в меню 128K, выключите DivMMC и нажмите **F12**.

### esxDOS 0.9.0 на SD2

Начиная со сборки 26112002 в ядре ПЗУ esxDOS 0.9.0. Эта ПЗУ проверяет версию `SYS/ESXDOS.SYS` и не стартует с системными файлами 0.8.x, поэтому SD2 нужно обновить вместе с ядром:

- скопируйте папки `SYS` и `BIN` из [esxdos090.zip](https://www.esxdos.org/files/esxdos090.zip) в корень SD2 (системные команды теперь лежат в `SYS/BIN`, их старые копии в `BIN` больше не используются);
- длинные имена файлов: возьмите новый `SYS/CONFIG/ESXDOS.CFG` или добавьте в свой строку `LFN=1`;
- ZX Next на той же карте: замените `machines/next/ESXMMC.BIN` на `ROMS/esxdos-0.9.0-divmmc.bin` из архива, переименовав его в `ESXMMC.BIN` (машинам Next с DivMMC нужна та же версия, что и в `SYS`);
- `NMI.SYS` / `RTC.SYS`, сделанные для старых версий esxDOS, нужно пересобрать под новые адреса ($2000 / $2F00). `RTC.SYS` для 0.9.0 (RTC.SYS от Next, порты 103B / 113B, по адресу $2F00) лежит в [karabas-go software/esxdos](https://github.com/andykarpov/karabas-go/tree/master/software/esxdos): скопируйте его в `SYS` SD2;
- сама ПЗУ лежит в `zxuno.kg`: прошивать её лентами `FLASHERS` из архива не нужно.

## Меню OSD

| Страница | Пункт | Значения | Клавиша |
|---|---|---|---|
| | Timing | 48K / 128K / Pentagon | Menu+F1 |
| | CPU speed | 3.5 / 7 / 14 / 28 MHz | Menu+F2 |
| | Contention | On / Off | |
| | Keyboard | Issue 3 / Issue 2 | |
| | DivMMC | On / Off | |
| | NMI | браузер esxDOS | F11 |
| | Reset | | F12 |
| | Hard reset | загрузка ZX-Uno заново (стартовый экран) | Menu+F12 |
| Video | ULAplus, Timex, Radastan | On / Off | |
| Video | Palette | Colour / Green / Amber / Grey | |
| Sound | AY, Turbosound, SAA1099, Specdrum, GS, OPL3 | On / Off | |
| Sound | Stereo | ABC / ACB / Mono | |
| Input | Joystick L, Joystick R | Kempston / Sinclair1 / Sinclair2 / Cursor / Fuller / Off | |
| Input | Mouse | On / Off | |

## Порты

| Устройство | Порты |
|---|---|
| Регистры ZX-Uno | FC3B (регистр) / FD3B (данные) |
| Матрица | регистры E0 (управление), E1 (x / y), E2 (цвет) |
| ESP8266 | регистры C6 (данные), C7 (состояние) |
| Часы | Gluk: EFF7 (бит 7 — включить), DFF7 (адрес), BFF7 (данные); DS1307: I2C на регистре F8 и на портах ZX Next 103B (SCL) / 113B (SDA) |
| General Sound | BB (команда / состояние), B3 (данные) |
| OPL3 (FM MoonSound) | C4 / C5 банк 0, C6 / C7 банк 1 (адрес / данные) |
| Kempston-мышь | FBDF (x), FFDF (y), FADF (кнопки) |

Пока OPL3 включён, порты C4..C7 заняты им: ULA, 7FFD и AY ZX-Uno эти порты не видят.

## Сборка

Клонируйте с `--recursive` (подмодуль `modules`). ISE 14.7: `cd src && make` — все платы, `make minig` — одна. Топы Go и Mini делает из топа Mini G скрипт `src/tools/mktop.py`. Загрузочная заглушка (`src/rtl/zxuno/memory/bootloader_karabas.asm`, стартовый экран `zxuno_logo.scr`) собирается sjasmplus. Симуляции (iverilog): `src/sim/tb_matrix.v`, `src/sim/tb_opl3.v`; тесты для платы: `src/test/*.asm` (`.sna` для браузера esxDOS). План и заметки — в [docs/PLAN.md](docs/PLAN.md).

## Лицензия

GPL v3 ([LICENSE](LICENSE)). ZX-Uno: (c) ZXUNO association и авторы его файлов; opl3_fpga: LGPL-3 (`src/rtl/opl3/COPYING.LESSER`); z80-silicon: GPL-3 (`src/rtl/z80-silicon/LICENSE`). ПЗУ 128K — (c) Amstrad, разрешено распространять с эмуляторами; esxDOS и ПЗУ GS принадлежат их авторам. Импортированные файлы сохраняют лицензионные заголовки своих авторов.
