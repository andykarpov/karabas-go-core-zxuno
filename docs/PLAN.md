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
- 2026-11-18: ПЗУ 128K и esxDOS — в репо и в `.kg`, загружаемые (`roms` в `core.json`), не в битстриме. Репо публичный, id ядра `zxuno`.
- 2026-11-18 (после Ф0): клавиатура и мышь — через нашу HID-обвязку (`kg_mcu2`) напрямую, без PS/2 и без лишних преобразований; SAA, PZX и DMA остаются; из OPL4 берём только FM-часть (OPL3, `opl3_fm` из tsconf, ~1,2k LUT), волновой части и YRW801 нет. Оценка: ~13k LUT (~86 %).
- Правки в импортированном коде помечаем `// karabas:`.

## Ф0. Импорт и замер (ветка f0-import)

Импорт `exp28/rtl` без `artix7/` и `zxtres_wrapper/` в `src/rtl/zxuno/`, README и changelog upstream — в `upstream/`. Замер XST (XC6SLX25-2, `-iobuf NO`) модуля `zxuno` на заглушках: полный `config.vh` EXP28 минус флеш / multiboot / AD724 / joysplitter / DRP. Рядом — цифры из карт tsconf: GS, OPL4 (~4,7k LUT вместе с `audio_lpf` и контроллером SDRAM), матрица + peaks, обвязка платы (HDMI, OSD, `kg_mcu2`, ~15–20 %).

**Это ворота:** по цифрам решаем, влезают ли GS и OPL4 на каждую плату и что выключать, если нет (SAA, PZX, DMA, Radastan…).

### Результат Ф0 (2026-11-18)

Импорт: `exp28/rtl` zxtres/zxspectrum c525f16 → `src/rtl/zxuno/` (список файлов — из Vivado-проекта upstream; лишний `io/spi.v` удалён). В `config.vh` выключены MULTIBOOT, JOYSPLITTER, AD724, генерация цветовой поднесущей, пасхалка (`// karabas:`). В `new_memory.v` убран цикл обнуления VRAM (XST: «Loop count limit exceeded»). Замер: `src/measure/` (`make`, `make report`; иерархия — `zxuno_measure_h.xst` + `netgen` + `tools/lutcount.py`), около 3 мин.

| Сборка | LUT | FF | RAMB16 | DSP48 | XST, нс |
|---|---|---|---|---|---|
| `zxuno` EXP28, всё остальное включено (SAA, PZX, DMA, RTC, UART, Radastan, ULAplus, Timex, Turbosound, Specdrum) | **7 214 (47 %)** | 3 220 | 19 | 4 | 36,5 |

Разбивка (`keep_hierarchy Yes`, 6 689 LUT): T80 + DMA 1905 (T80 1659, DMA 217), SAA1099 759, Turbosound 744 (2×AY 365), PS/2-клавиатура 723, PZX-плеер 652, ULA 491 (синхро 181), микшер 283, память 208, PS/2-мышь 191, UART 176. RAMB16: VRAM 32K (две копии страниц 5 / 7) = 16, остальное — загрузочное ПЗУ и раскладки.

Оценка с добавками (LUT, Mini G):

| Блок | LUT | Откуда |
|---|---|---|
| ZX-Uno EXP28 | 7 200 | замер выше |
| Обвязка платы (`kg_mcu2`, OSD, HDMI, удвоитель) | ~2 700 | specialist Ф1: 23 % всего при ядре 870 |
| Матрица + peaks | ~200 | `dot_matrix.v` |
| GS | ~2 000 | T80 ~1 700 + порты / микшер (оценка) |
| OPL4 | ~4 700 | карта tsconf Go (см. заметку opl4-sources) |
| **Итого** | **~16 800 из 15 032** | не влезает на ~1 800 + запас под упаковку |

Что можно вынуть: PS/2-клавиатура и мышь (723 + 191) заменяются нашими HID-путями (несколько сотен LUT вместо них), SAA 759, PZX 652, DMA 217. Без OPL4 (только GS) — ~12 100 (80 %), влезает. Худший путь XST 36,5 нс при такте 28 МГц (35,7 нс): процессор и ULA работают по clock enable, проверить в Ф1 по PAR.

## Ф1. ZX-Uno на Mini G (ветка f1-minig)

- Топ и тактирование — из tsconf Mini G без изменений (PLL 84 / 28 / 8 / 12 МГц: `sysclk` ZX-Uno = `clk_bus` 28 МГц, 84 МГц понадобится GS), `kg_mcu2` / link v2 (подмодуль 6483689: AUX / матрица уже есть), OSD `kg_l2_osd_overlay`, `kg_hdmi_ft`, `kg_pcm5102`, `FT_CLK_OUT` всегда, `FLASH_CS_N` = 1. SDRAM пока не используется (выходы в покое).
- Старт без BIOS и без флеша: ПЗУ — загружаемые, секция `roms` в `core.json` (решение пользователя 2026-11-18: «загружаемой ПЗУ, как и все, чтобы не пересобирать ядро»). Прошивка при старте ядра пишет их в SRAM по адресам ZX-Uno: `roms/128en.rom` в банки 8 / 9 (0x20000) и копией в 10 / 11 (0x28000), `roms/esxdos089.bin` (ESXMMC.BIN 0.8.9 — та же версия, что `/SYS` на SD2 у других ядер) в 0x30000. ZX-Uno на это время в сбросе. Загрузочная заглушка ZX-Uno (`bootloader_copy_bram_to_sram`, 247 байт в BRAM) пропатчена: её переход по контрольной сумме (`jp nz` → `jp`, `bootloader_karabas.hex`) — она ничего не копирует, только пишет MASTERCONF = 10010010b (128K, DivMMC + esxDOS, конфигурация заблокирована) и стартует ПЗУ из SRAM; VRAM без начального содержимого.
- SRAM: 21-битный байтовый адрес ZX-Uno (2 МБ) — прямо на `MA[20:0]`, младший байт шины (`MD[7:0]`, `MWR_N[0]`, `MRD_N[0]`), старший байт не используется. Формирование `/WE` сверить с заметками profi (ODDR2) и pcxt.
- Клавиатура: `ps2_keyb` заменяется своим модулем: матрица ZX из USB-отчёта (`hid_parser.vhd` из tsconf, если замер покажет, что он дешевле PS/2-цепочки, иначе свой), сброс / NMI / мастер-сброс — из OSD и F12 / кнопки платы, SCANCODE / KBSTATUS (04 / 05) — из `PS2_CODE` прошивки (защёлка E0 / F0), KEYMAP (07) — нет. Мышь: Kempston (FBDF / FFDF / FADF) из `kg_cursor`, MOUSEDATA / MOUSESTATUS — в Ф2. Джойстики: родной `joystick_protocols` ZX-Uno, на входы DB9 — `JOY_L` / `JOY_R`.
- Видео: свой удвоитель строк с гашением (DE для HDMI) после `pal_sync_generator`. Тайминг на выходе — удвоенный тайминг ULA (48K 448 × 312, 128K 456 × 311, Pentagon 448 × 320 при пикселе 7 МГц → строка ~32 мкс, ~50 Гц), как у tsconf / baseconf, а не точный CEA 720x576: точный 576p требует кадрового буфера (у ZXTRES это framescaler), иначе пропадут тайминги машин ZX-Uno. Риск: придирчивый монитор пользователя; если не покажет — отдельная задача на кадровый буфер.
- Звук: `audio_left` / `audio_right` [15:0] EXP28 → HDMI, DAC, peaks (знаковость проверить).
- OSD (экран — на одобрение пользователю): тайминги 48 / 128 / Pentagon, turbo, ULAplus / Radastan / Timex, AY / Turbosound / SAA, DivMMC, видео; настройки, которые раньше ставил BIOS, — в MASTERCONF / DEVOPTIONS / SCANDBLCTRL после заглушки.
- Проверка: XST / PAR Mini G, затем плата (с разрешения пользователя). Длинную симуляцию загрузки ПЗУ не гоняем без спроса.

### Результат Ф1 (2026-11-18, сборка 26111808, Mini G)

- 8 295 LUT (55 %), 75 % слайсов, 23 RAMB16; тайминг выполнен в режиме FT и в режиме ядра.
- Плата (стенд + монитор пользователя): логотип ZX-Uno из BIOS при старте и после Hard reset, ПЗУ из `core.json`, 48K BASIC (DivMMC On) или меню 128K (DivMMC Off + Reset), клавиатура, NMI (F11) → браузер esxDOS 0.8.9 на SD2, OSD всех страниц (схема одобрена пользователем), палитры.
- Видео: окно DE 720 × 576 от синхроимпульсов, синхро положительные, строка 896 (48K / Pentagon) или 912 (128K) тактов 28 МГц, кадр ~624 строки. Захват стенда при смене длины строки на ходу косит картинку (монитор ровный; лечится передёргиванием HDMI); при смене длины строки ядро перезапускает HDMI на ~150 мс.
- esxDOS 0.8.9 сам включает 48K ПЗУ: отсюда пункт OSD DivMMC; патченое 128K ПЗУ — в бэклоге.
- Тест: `src/sim/tb_video.v` (iverilog, секунды): длины строк / кадров, синхро и окно DE в трёх таймингах.

## Ф2. Периферия

ESP8266 через регистры UART ZX-Uno C6 / C7 (`UART_CTS`, сброс ESP по F11 → `ESP_RESET_N`), MIDI (порт A AY → `MIDI_TX` синтезатора платы), RTC (регистры ZX-Uno ↔ RTC прошивки), джойстики (Kempston / Fuller / Sinclair), мышь Kempston, PZX-плеер, DMA, Specdrum / Covox.

### Результат Ф2 (2026-11-18, сборка 26111810, Mini G)

Проверено на плате тестами `src/test/rtcesp.asm` и `src/test/periph.asm` (sjasmplus → `.sna`, запуск из NMI-браузера esxDOS):

- RTC: порты Gluk (EFF7 / DFF7 / BFF7 → регистры DS1307 часов прошивки, `rtc_mode` 1) и DS1307 по I2C (регистр F8, эмуляция `ds1307.vhd` из core-next) показывают одно и то же время;
- ESP8266: на «AT» через C6 / C7 отвечает «OK» (сброса ESP по F11 нет: на Mini G нет `ESP_RESET_N`);
- MIDI: `PLAY "Y1..."` из 128 BASIC → `MIDI_TX` → синтезатор платы; его звук через АЦП PCM1808 подмешан в микшер ZX-Uno на место входа синтезатора ZXUNO+ (половина шкалы АЦП: микшер 16 бит без насыщения);
- DMA (память → память), PZX-плеер (SRAM через F0–F2, проигрывание F3: 1000 импульсов = 1000 фронтов на EAR), Specdrum (порт DF), джойстики Kempston / Sinclair / Fuller, мышь Kempston;
- MIC → `TAPE_OUT`.

8639 LUT (57 %), тайминги выполнены.

## Ф3. Матрица и peaks

`dot_matrix` + `audio_peaks` (из karabas-go-modules) на новых регистрах, матрица только на Mini G (на Go / Mini её нет). Переезд tsconf, profi и next на E0 / E1 / E2 и правка `docs/matrix.md` / `matrix.ru.md` прошивки — отдельные PR в их репо; сборки и выпуски этих ядер — вместе, одним заходом.

## Ф4. General Sound

Копия GS из tsconf (Z80 + ROM GS + SDRAM), порты BB / B3, OSD вкл. / выкл., громкость в общий микшер.

## Ф5. OPL3 (FM-часть MoonSound)

Копия `opl3_fm` из tsconf (FM-часть OPL4): порты FM MoonSound C4..C7, таймеры, `audio_lpf`. Волновой части (7E / 7F, YRW801, SDRAM) нет: не влезает (Ф0).

## Ф6. Go и Mini, выпуск

Топы Go / Mini, сборка всех плат (`map -t 2`), README.md + README.ru.md, `cores.json` karabas-go.

## Открыто

- Какой софт для матрицы уже есть у пользователя на F0 / F1 / F2 (его тоже переделать).
