#!/usr/bin/env python3
"""Makes rtl/karabas_go_top.v and rtl/karabas_mini_top.v from rtl/karabas_minig_top.v: the machine (ZX-Uno, GS,
OPL3, matrix, mixer), kg_mcu2, the OSD and the inputs are those of Mini G; the ports are those of the boards
(tools/ports/<board>.v, taken from core-tsconf); the board glue differs:

Mini:
- no i2s DAC: sigma-delta DACs on AUDIO_L / AUDIO_R (as core-tsconf);
- MCU_IO is 4 bits ([1] INT of link v2, [3] the FT812 select), FT_RESET from the mcu;
- ESP_RESET_N / ESP_BOOT_N high-Z (no reset of the ESP: as the Mini G), MIDI_CLK 12 MHz, MIDI_RESET_N high.
Go:
- no HDMI, no FT_CLK_OUT, no PCM1808 ADC (the MIDI synth goes to the audio out of the board directly): the FPGA
  and the FT812 share the video DAC (VGA_*, V_CLK of bus_ce or FT_CLK; FT_OE_N), the FT812 when the firmware
  (FT_VGA_ON) asks for it;
- MCU_SCK straight (not on a clock pin), INT of link v2 on MCU_SPI_IO[0] (N9), the FT812 select on MCU_SPI_FT_CS_N;
- the i2s DAC with DAC_LRCK / DAC_MUTE, MIDI_CLK 12 MHz, MIDI_RESET_N high, the floppy connector idle (all 0:
  the Go has inverters on FDC_*), BEEPER 0.
Every replacement must match once, else this stops. Run in src/: python3 tools/mktop.py
"""
import os
import sys

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def sub(s, old, new, what):
    if s.count(old) != 1:
        sys.exit("mktop.py: %s: %d matches of %r" % (what, s.count(old), old[:70]))
    return s.replace(old, new)


def cut(s, start, end, new, what):
    if s.count(start) != 1:
        sys.exit("mktop.py: %s: %d matches of %r" % (what, s.count(start), start[:70]))
    i = s.index(start)
    j = s.index(end, i) + len(end)
    return s[:i] + new + s[j:]


g = open(os.path.join(SRC, "rtl/karabas_minig_top.v"), encoding="latin-1").read()
i = g.index("module karabas_minig_top")
pre = g[:i]
body = g[g.index("\n);\n", i) + 4:]


def ports(board):
    p = open(os.path.join(SRC, "tools/ports/%s.v" % board)).read()
    return p[p.index("module"):]


def header(board, name):
    h = pre.replace("for Karabas Mini rev.G", "for " + name)
    return h + ports(board) + "\n// karabas: made by src/tools/mktop.py from karabas_minig_top.v (do not edit it, change Mini G)\n"


# ------------------------------------------------------------------ Mini
b = body
b = sub(b, "assign ESP32_SPI_CS_N = 1'b1;\n",
        "assign ESP_RESET_N = 1'bZ;\nassign ESP_BOOT_N = 1'bZ;\nassign MIDI_RESET_N = 1'b1;\n", "esp")
b = sub(b, "ODDR2 u_ft_clk (.Q(FT_CLK_OUT), .C0(clk_8mhz), .C1(~clk_8mhz), .CE(1'b1), .D0(1'b1), .D1(1'b0), .R(1'b0), .S(1'b0));\n",
        "ODDR2 u_ft_clk (.Q(FT_CLK_OUT), .C0(clk_8mhz), .C1(~clk_8mhz), .CE(1'b1), .D0(1'b1), .D1(1'b0), .R(1'b0), .S(1'b0));\n"
        "// the clock of the MIDI synth (SAM2695): 12 MHz\n"
        "ODDR2 u_midi_clk (.Q(MIDI_CLK), .C0(clk_12mhz), .C1(~clk_12mhz), .CE(1'b1), .D0(1'b1), .D1(1'b0), .R(1'b0), .S(1'b0));\n",
        "midi clk")
b = sub(b, "assign MCU_IO[5:2] = 4'bzzzz;\n", "assign MCU_IO[3:2] = 2'bzz;\n", "mcu io")
b = sub(b, "assign FT_SPI_MOSI = mcu_ft_spi_on ? mcu_ft_mosi : 1'b1;\n",
        "assign FT_SPI_MOSI = mcu_ft_spi_on ? mcu_ft_mosi : 1'b1;\nassign FT_RESET = ~mcu_ft_reset;\n", "ft reset")
b = cut(b, "// ---------- i2s DAC ----------\n", "	.lrck				(DAC_WS)\n);\n",
        """// ---------- sigma-delta DACs (the analog audio out of the Mini) ----------
kg_sigma_delta_dac #(.MSBI(15)) dac_l(
	.clk				(clk_bus),
	.reset			(areset),
	.din				({2'b00, !audio_l[15], audio_l[14:4], 2'b00}),
	.dout				(AUDIO_L)
);
kg_sigma_delta_dac #(.MSBI(15)) dac_r(
	.clk				(clk_bus),
	.reset			(areset),
	.din				({2'b00, !audio_r[15], audio_r[14:4], 2'b00}),
	.dout				(AUDIO_R)
);
""", "dac")
open(os.path.join(SRC, "rtl/karabas_mini_top.v"), "w", encoding="latin-1").write(
    header("mini", "Karabas Mini") + b.replace("karabas_minig_top", "karabas_mini_top"))
print("mktop.py: rtl/karabas_mini_top.v")

# ------------------------------------------------------------------ Go
b = body
b = sub(b, "assign ESP32_SPI_CS_N = 1'b1;\n",
        "assign ESP_RESET_N = 1'bZ;\nassign ESP_BOOT_N = 1'bZ;\nassign MIDI_RESET_N = 1'b1;\nassign BEEPER = 1'b0;\n"
        "// the floppy connector (no drive in ZX-Uno): idle = all 0, the Go has inverters on FDC_*\n"
        "assign FDC_DRIVE = 2'b00;\nassign FDC_MOTOR = 1'b0;\nassign FDC_DIR = 1'b0;\nassign FDC_STEP = 1'b0;\n"
        "assign FDC_WDATA = 1'b0;\nassign FDC_WGATE = 1'b0;\nassign FDC_SIDE_N = 1'b0;\n", "esp")
b = sub(b, "// the FT812 must always get a clock (karabas-go-notes ft-clk-out-required)\n"
           "ODDR2 u_ft_clk (.Q(FT_CLK_OUT), .C0(clk_8mhz), .C1(~clk_8mhz), .CE(1'b1), .D0(1'b1), .D1(1'b0), .R(1'b0), .S(1'b0));\n",
        "// the clock of the MIDI synth (SAM2695): 12 MHz; the Go has no FT_CLK_OUT (the FT812 has its own crystal)\n"
        "ODDR2 u_midi_clk (.Q(MIDI_CLK), .C0(clk_12mhz), .C1(~clk_12mhz), .CE(1'b1), .D0(1'b1), .D1(1'b0), .R(1'b0), .S(1'b0));\n"
        "// clk_sys enables of the edges of clk_bus: v_clk for the V_CLK pin (the clock of the video DAC)\nwire ce_28m, v_clk;\n"
        "bus_ce bus_ce(.clk_sys(clk_sys), .clk_bus(clk_bus), .ce(ce_28m), .v_clk(v_clk));\n", "ft clk")
b = cut(b, "// PCM1808 ADC (as core-tsconf)", "ODDR2 oddr_adc(.Q(ADC_CLK), .C0(clk_bus), .C1(~clk_bus), .CE(1'b1), .D0(1'b1), .D1(1'b0), .R(1'b0), .S(1'b0));\n",
        "// no ADC on the Go: the MIDI synth goes to the audio out of the board directly\n"
        "wire [15:0] adc_mix_l = 16'd0;\nwire [15:0] adc_mix_r = 16'd0;\n", "adc")
b = sub(b, "assign MCU_IO[1] = mcu_int;\nassign MCU_IO[0] = 1'bz;\nassign MCU_IO[5:2] = 4'bzzzz;\n",
        "assign MCU_SPI_IO[0] = mcu_int;   // INT of link v2 on N9 (IO1 of the firmware)\nassign MCU_SPI_IO[1] = 1'bz;\n", "mcu io")
b = sub(b, "// MCU_SCK on a global buffer (see core-tsconf); FT_SPI_SCK takes it before the BUFG\n"
           "wire mcu_sck_ibufg, mcu_sck;\nIBUFG ibufg_mcu_sck(.I(MCU_SCK), .O(mcu_sck_ibufg));\nBUFG bufg_mcu_sck(.I(mcu_sck_ibufg), .O(mcu_sck));\n",
        "// MCU_SCK is not on a clock pin on the Go (CLOCK_DEDICATED_ROUTE = FALSE in the ucf)\n"
        "wire mcu_sck = MCU_SCK, mcu_sck_ibufg = MCU_SCK;\n", "mcu sck")
b = sub(b, "	.MCU_SPI_FT_SS	(MCU_IO[3]),", "	.MCU_SPI_FT_SS	(MCU_SPI_FT_CS_N),", "ft ss")
b = cut(b, "// FT_CLK: the pixel clock of the FT812 (the menus of the mcu on HDMI)\n", "	.lrck				(DAC_WS)\n);\n",
        """// the FT812 and the FPGA share the video DAC: the FT812 drives it when the firmware (FT_VGA_ON) asks for it
assign FT_OE_N = ~mcu_ft_vga_on;
assign VGA_R = mcu_ft_vga_on ? 8'bZZZZZZZZ : osd_r;
assign VGA_G = mcu_ft_vga_on ? 8'bZZZZZZZZ : osd_g;
assign VGA_B = mcu_ft_vga_on ? 8'bZZZZZZZZ : osd_b;
assign VGA_HS = mcu_ft_vga_on ? 1'bZ : osd_hs;
assign VGA_VS = mcu_ft_vga_on ? 1'bZ : osd_vs;
assign V_CLK = mcu_ft_vga_on ? FT_CLK : v_clk;

// ---------- i2s DAC ----------
kg_pcm5102 #(.DIV_BITS(1)) PCM5102(
	.clk				(clk_bus),
	.reset			(areset),
	.left				(audio_l),
	.right			(audio_r),
	.din				(DAC_DAT),
	.bck				(DAC_BCK),
	.lrck				(DAC_LRCK)
);
assign DAC_MUTE = 1'b1;   // 0 = mute
""", "video and audio")
open(os.path.join(SRC, "rtl/karabas_go_top.v"), "w", encoding="latin-1").write(
    header("go", "Karabas Go") + b.replace("karabas_minig_top", "karabas_go_top"))
print("mktop.py: rtl/karabas_go_top.v")
