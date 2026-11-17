# План ядра ZX-Uno для Karabas Go / Mini / Mini G

Цель: ZX Spectrum в варианте ZX-Uno (48K / 128K / Pentagon, ULAplus, Radastan, Timex, DivMMC + esxDOS, turbo, DMA, растровое прерывание, Turbosound, SAA1099, Specdrum / Covox, PZX-плеер, Kempston-мышь, UART ESP8266) на платах Karabas (XC6SLX25, ISE 14.7). К нему добавляем то, что есть в наших ядрах: индикаторы уровня звука (peaks) и порты матрицы, MIDI, ESP8266 через регистры ZX-Uno, General Sound и OPL4 (MoonSound). Файлы идут через прошивку (OSD, `FL`, `F`, burst); BIOS ZX-Uno и soft-CPU в ядре нет.

## Что изучено (2026-11-18)

| Источник | Что даёт |
|---|---|
| **zxtres/zxspectrum `exp28/`** (база, GPL-3, 2023-09-09, `EXP28-080923`) | Самый свежий исходник ядра. Надмножество EXP27-050822: RTC по i2c, SAA1099 вместе с PZX, Timex AY (рег. F5 / F6), заморозка MASTERCONF при configrom, esxDOS 0.8.9, второй UART, фильтры звука, RGB 24 бит. Xilinx-примитивы только в `rtl/artix7` и `rtl/zxtres_wrapper` (DisplayPort), остальное — обычный Verilog + T80 (VHDL). Такт 28 МГц |
| zxdos/zxuno `cores/Spectrum` (EXP27-030422), spark2k06/zxuno (EXP27-050822) | Старые деревья под Spartan-6 (ZX-Uno v4 LX9, ZXDOS LX16): справка по UCF, PLL, DRP. Варианты конфигурации `pzx_nosaa` / `saa_nopzx` — на LX9 всё сразу не влезало |
| SVN svn.zxuno.com/svn/zxuno (guest / zxuno) | Жив: r1585 (2024-05), последняя правка ядра r1584 (2024-04, exp27 с внешней RAM) |
| Utodev/smartROM, sy2002/zxuno4mega65, rampa069/ZXUNO_Mister | Примеры ядра без SPI-флеша: как стартовать без BIOS |
| core-tsconf | GS (`sound/gs*`), OPL4 (`sound/opl4`, YRW801 через `FL`, SDRAM), матрица + peaks (`mcu/dot_matrix.v`), MIDI, ESP, звуковой тракт (`audio_mixer`, `audio_lpf`) |

## Решения

- 2026-11-18 (пользователь): база — EXP28 (zxtres/zxspectrum).
- 2026-11-18: без BIOS ZX-Uno; ПЗУ 128K и esxDOS грузит прошивка в SRAM, настройки — в OSD. Регистры ZX-Uno (FC3B / FD3B) остаются для софта.
- 2026-11-18: матрица переезжает на новые номера регистров во всех ядрах (tsconf, profi, zxuno): в ZX-Uno F0–F3 заняты PZX-плеером (SRAMADDR / SRAMADDRINC / SRAMDATA / VDECKCTRL). Номера E0 / E1 / E2 (пользователь, 2026-11-18): в EXP28 свободны, в списке регистров ZXTRES не значатся (C8–DF там «reserved»). Правим везде: zxuno, tsconf, profi, next и `docs/matrix*.md` прошивки.
- 2026-11-18: GS и OPL4 — копией из tsconf (общий модуль потом).
- 2026-11-18: ПЗУ 128K и esxDOS зашиваем в `.kg` (и в репо). Репо публичный, id ядра `zxuno`.
- Правки в импортированном коде помечаем `// karabas:`.

## Ф0. Импорт и замер (ветка f0-import)

Импорт `exp28/rtl` без `artix7/` и `zxtres_wrapper/` в `src/rtl/zxuno/`, README и changelog upstream — в `upstream/`. Замер XST (XC6SLX25-2, `-iobuf NO`) модуля `zxuno` на заглушках: полный `config.vh` EXP28 минус флеш / multiboot / AD724 / joysplitter / DRP. Рядом — цифры из карт tsconf: GS, OPL4 (~4,7k LUT вместе с `audio_lpf` и контроллером SDRAM), матрица + peaks, обвязка платы (HDMI, OSD, `kg_mcu2`, ~15–20 %).

**Это ворота:** по цифрам решаем, влезают ли GS и OPL4 на каждую плату и что выключать, если нет (SAA, PZX, DMA, Radastan…).

## Ф1. ZX-Uno на Mini G

- Топ и тактирование из tsconf (28 МГц + HDMI + MIDI 12 МГц), `kg_mcu2` / link v2, `FT_CLK_OUT` ведётся всегда, `FLASH_CS_N` = 1.
- Память: SRAM ZX-Uno (512K / 2 МБ) в SRAM платы; ПЗУ 128K + esxDOS — `FL`-пункты `.kg` (загрузка при старте, ядро в сбросе на время загрузки). `128en.rom` и `esxdos089.bin` — в репо и в `.kg` (решение 2026-11-18).
- Клавиатура: USB HID из `kg_mcu2` → матрица ZX (как tsconf); для софта ZX-Uno — регистр SCANCODE (04) с PS/2-сканкодами, сделанными из HID. Сброс — F12.
- SD: DivMMC / ZXMMC на SD2 (порты E7 / EB, 1F / 3F).
- Видео: ULA 15 кГц → удвоитель строк → HDMI 720x576@50 / VGA; ULAplus / Radastan / Timex / монохромные палитры.
- Звук: PCM берём до PWM-выхода `audio_management`, дальше `audio_mixer` / HDMI / DAC как в tsconf.
- OSD (экран — на одобрение пользователю): тайминги 48 / 128 / Pentagon, turbo, ULAplus / Radastan / Timex, AY / Turbosound / SAA, DivMMC, клавиатура, видео.
- Симуляция до приглашения BASIC 128 и esxDOS.

## Ф2. Периферия

ESP8266 через регистры UART ZX-Uno C6 / C7 (`UART_CTS`, сброс ESP по F11 → `ESP_RESET_N`), MIDI (порт A AY → `MIDI_TX` синтезатора платы), RTC (регистры ZX-Uno ↔ RTC прошивки), джойстики (Kempston / Fuller / Sinclair), мышь Kempston, PZX-плеер, DMA, Specdrum / Covox.

## Ф3. Матрица и peaks

`dot_matrix` + `audio_peaks` (из karabas-go-modules) на новых регистрах, матрица только на Mini G (на Go / Mini её нет). Переезд tsconf, profi и next на E0 / E1 / E2 и правка `docs/matrix.md` / `matrix.ru.md` прошивки — отдельные PR в их репо; сборки и выпуски этих ядер — вместе, одним заходом.

## Ф4. General Sound

Копия GS из tsconf (Z80 + ROM GS + SDRAM), порты BB / B3, OSD вкл. / выкл., громкость в общий микшер.

## Ф5. OPL4 (MoonSound)

Копия `opl4` из tsconf: порты C4..C7 / 7E / 7F, YRW801 как `FL`-пункт (не в репо), SDRAM вторым клиентом рядом с GS, домен 84 МГц, `audio_lpf`. Только если Ф0 показал, что влезает.

## Ф6. Go и Mini, выпуск

Топы Go / Mini, сборка всех плат (`map -t 2`), README.md + README.ru.md, `cores.json` karabas-go.

## Открыто

- Какой софт для матрицы уже есть у пользователя на F0 / F1 / F2 (его тоже переделать).
