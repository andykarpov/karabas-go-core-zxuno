`timescale 1ns / 1ps
/*-------------------------------------------------------------------------------------------------------------------
-- ZX-Uno core (EXP28 of zxtres/zxspectrum, GPL-3) for Karabas Mini rev.G
--
-- Clocks (the PLL of core-tsconf): clk_bus 28.03 MHz = sysclk of ZX-Uno (CPU, ULA, memory, sound, MCU link, OSD,
-- the line doubler, HDMI in the mode of the core), clk_sys 84.09 MHz (for the General Sound later), clk_8 7.97 MHz
-- (FT_CLK_OUT, DCM_CLKGEN of HDMI), 12 MHz (unused on the Mini G).
-- Memory: the 2 MB of ZX-Uno on the low byte of the SRAM (MD[7:0], MWR_N[0], MRD_N[0]); the ROMs (128K, esxDOS)
-- are loaded by the firmware (core.json "roms") into their SRAM banks; the boot stub of ZX-Uno only sets
-- MASTERCONF (no flash, no BIOS).
-- Video: the ULA (PAL timing of 48K / 128K / Pentagon) -> zxuno_scandbl (line doubler with DE) -> OSD -> HDMI.
-- Input: USB keyboard (hid_parser -> the Spectrum matrix), USB mouse (kg_cursor -> Kempston), joysticks of
-- kg_mcu2 on the DB9 inputs of ZX-Uno (joystick_protocols: Kempston / Fuller / Sinclair / cursor by JOYCONF).
-- SD card: DivMMC of ZX-Uno on SD2.
------------------------------------------------------------------------------------------------------------------*/


module karabas_minig_top (
	//------------------ global clock --------
	input wire 				CLK_50MHZ,

	//------------------ esp8266 uart --------
	inout wire 				UART_RX,
	inout wire 				UART_TX,
	inout wire 				UART_CTS,

	//------------------ sram ----------------
	output wire [20:0] 	MA,
	inout wire [15:0] 	MD,
	output wire [1:0] 	MWR_N,
	output wire [1:0] 	MRD_N,

	//------------------ sdram ---------------
	output wire [1:0] 	SDR_BA,
	output wire [12:0] 	SDR_A,
	output wire 			SDR_CLK,
	output wire [1:0] 	SDR_DQM,
	output wire 			SDR_WE_N,
	output wire 			SDR_CAS_N,
	output wire 			SDR_RAS_N,
	inout wire [15:0] 	SDR_DQ,

	//------------------ sd2 -----------------
	output wire 			SD_CS_N,
	output wire 			SD_CLK,
	inout wire 				SD_DI,
	inout wire 				SD_DO,
	input wire 				SD_DET_N,

	//------------------ ft812 rgb + sync ----
	input wire [7:0] 		VGA_R,
	input wire [7:0] 		VGA_G,
	input wire [7:0] 		VGA_B,
	input wire 				VGA_HS,
	input wire 				VGA_VS,

	//------------------ dvi / hdmi ----------
	output wire [3:0] 	TMDS_P,
	output wire [3:0] 	TMDS_N,

	//------------------ ft812 spi and ctl ---
	inout wire 				FT_SPI_CS_N,
	inout wire 			FT_SPI_SCK,
	input wire 				FT_SPI_MISO,
	inout wire 			FT_SPI_MOSI,
	input wire 				FT_INT_N,
	input wire 				FT_CLK,
	input wire 				FT_DE,
	output wire 			FT_CLK_OUT,

	//------------------ cf card -------------
	output wire [2:0] 	WA,
	output wire [1:0] 	WCS_N,
	output wire 			WRD_N,
	output wire 			WWR_N,
	output wire 			WRESET_N,
	inout wire [15:0] 	WD,

	//------------------ analog in/out -------	
	output wire 			TAPE_OUT,
	input wire 				TAPE_IN,

   //------------------ i2s dac -------------
	output wire          DAC_BCK,
	output wire          DAC_WS,
	output wire          DAC_DAT,

	//------------------ adc -----------------
	output wire 			ADC_CLK,
	inout wire 				ADC_BCK,
	inout wire 				ADC_LRCK,
	input wire 				ADC_DOUT,
	
	//------------------ esp32 i2s and cs ----
	inout wire           ESP32_SPI_CS_N,
	input wire           ESP32_PCM_BCK,
	input wire           ESP32_PCM_RLCK,
	input wire           ESP32_PCM_DAT,	

	//------------------ mcu spi -------------
	input wire 				MCU_CS_N,
	input wire 				MCU_SCK,
	input wire 				MCU_MOSI,
	output wire 			MCU_MISO,
	inout wire [5:0] 		MCU_IO,  // [0] burst cs_n, [1] burst ready, [2] sd2 cs_n, [3] ft cs_n

	//------------------ midi ----------------
	output wire 			MIDI_TX,

	//------------------ optional flash ------
	output wire 			FLASH_CS_N,
	input wire  			FLASH_DO,
	output wire 			FLASH_DI,
	output wire 			FLASH_SCK,
	output wire 			FLASH_WP_N,
	output wire 			FLASH_HOLD_N
);

// unused yet
assign FLASH_CS_N   = 1'b1;
assign FLASH_DI     = 1'b1;
assign FLASH_SCK    = 1'b0;
assign FLASH_WP_N   = 1'b1;
assign FLASH_HOLD_N = 1'b1;

assign SDR_BA = 2'b11;
assign SDR_A = 13'h1FFF;
assign SDR_CLK = 1'b0;
assign SDR_DQM = 2'b11;
assign SDR_WE_N = 1'b1;
assign SDR_CAS_N = 1'b1;
assign SDR_RAS_N = 1'b1;
assign SDR_DQ = 16'hZZZZ;

assign WA = 3'b000;
assign WCS_N = 2'b11;
assign WRD_N = 1'b1;
assign WWR_N = 1'b1;
assign WRESET_N = 1'b1;
assign WD = 16'hZZZZ;

assign TAPE_OUT = 1'b0;
assign ADC_CLK = 1'b0;
assign ADC_BCK = 1'bz;
assign ADC_LRCK = 1'bz;
assign ESP32_SPI_CS_N = 1'b1;

// ---------- clocks: VCO 50 * 37 / 2 = 925 MHz: clk_sys /11 84.09, clk_8 /116 7.97, clk_bus /33 28.03, /77 12.01
wire clk_sys, clk_8mhz, clk_bus, clk_bus_pll, clk_12mhz;
wire locked, areset;
wire [5:0] pll_clk;
kg_pll #(
	.DIVCLK_DIVIDE(2), .CLKFBOUT_MULT(37),
	.CLKOUT0_DIVIDE(11), .CLKOUT1_DIVIDE(116), .CLKOUT2_DIVIDE(33), .CLKOUT3_DIVIDE(77),
	.BUFG_MASK(6'b001011)
) pll (
	.clk_in			(CLK_50MHZ),
	.rst				(1'b0),
	.clk_out			(pll_clk),
	.locked			(locked)
);
assign clk_sys = pll_clk[0];
assign clk_8mhz = pll_clk[1];
assign clk_bus_pll = pll_clk[2];
assign clk_12mhz = pll_clk[3];
BUFG bufg_clk_bus(.I(clk_bus_pll), .O(clk_bus));

// the FT812 must always get a clock (karabas-go-notes ft-clk-out-required)
ODDR2 u_ft_clk (.Q(FT_CLK_OUT), .C0(clk_8mhz), .C1(~clk_8mhz), .CE(1'b1), .D0(1'b1), .D1(1'b0), .R(1'b0), .S(1'b0));

assign areset = ~locked;

// power-on reset of ZX-Uno: ~37 ms after the PLL locked (as tld_zxtres.v) and after the firmware loaded the
// ROMs (core.json "roms", LD kind 0): the boot stub then sets MASTERCONF and starts the ROM from the SRAM
wire ld_rom_act;
reg [19:0] por_cnt = 20'h00000;
reg por_n = 1'b0;
always @(posedge clk_bus) begin
	por_n <= (por_cnt == 20'hFFFFF);
	if (!locked || ld_rom_act)
		por_cnt <= 20'h00000;
	else if (por_cnt != 20'hFFFFF)
		por_cnt <= por_cnt + 1'd1;
end

// tape in
reg tape_in_r = 1'b0;
always @(posedge clk_bus) tape_in_r <= TAPE_IN;

// ---------- MCU (link v2) ----------
wire mcu_int;
assign MCU_IO[1] = mcu_int;
assign MCU_IO[0] = 1'bz;
assign MCU_IO[5:2] = 4'bzzzz;

// MCU_SCK on a global buffer (see core-tsconf); FT_SPI_SCK takes it before the BUFG
wire mcu_sck_ibufg, mcu_sck;
IBUFG ibufg_mcu_sck(.I(MCU_SCK), .O(mcu_sck_ibufg));
BUFG bufg_mcu_sck(.I(mcu_sck_ibufg), .O(mcu_sck));

wire [55:0] mcu_kbd;
wire [7:0] mcu_ps2_code;
wire mcu_ps2_kind, mcu_ps2_wr;
wire [7:0] ms_x, ms_y, mcu_ms_z, mcu_ms_b;
wire mcu_ms_wr;
wire [15:0] mcu_joy_l, mcu_joy_r;
wire [5:0] mcu_btns;
wire mcu_busy, dvi_only;
wire [7:0] hwid;
wire osd_wr, osd_en, osd_zoom;
wire [11:0] osd_waddr;
wire [7:0] osd_wdata;
wire [23:0] osd_fg, osd_bg;
wire [1:0] osd_alpha, osd_place;
wire [4:0] osd_px, osd_ph;
wire [3:0] osd_py;
wire [5:0] osd_pw;
wire mcu_ft_spi_on, mcu_ft_vga_on, mcu_ft_reset, mcu_ft_sck, mcu_ft_mosi, mcu_ft_cs_n;
wire [1:0] ld_kind;
wire ld_active, ld_wr;
wire [31:0] ld_addr;
wire [7:0] ld_data;
wire ld_ready;

localparam SW_N = 4;
wire [SW_N*8-1:0] softsw;

kg_mcu2 #(
	.CAPS(16'h0000),
	.SW_N(SW_N),
	.CS_FILTER(3),
	.ENABLE_OSD(1),
	.ENABLE_IMG(0),
	.ENABLE_PORTS(4'b0000),
	.ENABLE_RTC(0),
	.ENABLE_AUX(0),
	.ENABLE_FT(1),
	.ENABLE_SD2(0)
) mcu(
	.CLK				(clk_bus),
	.N_RESET			(~areset),
	.MCU_SCK			(mcu_sck),
	.MCU_MOSI		(MCU_MOSI),
	.MCU_MISO		(MCU_MISO),
	.MCU_SS			(MCU_CS_N),
	.MCU_INT			(mcu_int),
	.MCU_SPI_FT_SS	(MCU_IO[3]),
	.MCU_SPI_SD2_SS(1'b1),
	.SW				(softsw),
	.SW_WR			(),
	.SW_INDEX		(),
	.SW_VALUE		(),
	.HW_ID			(hwid),
	.DVI_ONLY		(dvi_only),
	.CORE_BUILD		(),
	.FW_BUILD		(),
	.BUSY				(mcu_busy),
	.BTNS				(mcu_btns),
	.RELOAD_REQ		(1'b0),
	.RELOAD_CORE	(8'd0),
	.BK_MOUNT		(1'b0),
	.BK_FLUSHED		(1'b0),
	.BK_SLOT			(3'd0),
	.BK_SIZE			(32'd0),
	.BK_KIND			(8'd0),
	.BK_RESULT		(8'd0),
	.KBD				(mcu_kbd),
	.KBD_WR			(),
	.PS2_CODE		(mcu_ps2_code),
	.PS2_KIND		(mcu_ps2_kind),
	.PS2_WR			(mcu_ps2_wr),
	.MS_X				(ms_x),
	.MS_Y				(ms_y),
	.MS_Z				(mcu_ms_z),
	.MS_B				(mcu_ms_b),
	.MS_WR			(mcu_ms_wr),
	.JOY_L			(mcu_joy_l),
	.JOY_R			(mcu_joy_r),
	.JOY_WR			(),
	.PS2_CMD			(16'h0000),
	.PS2_CMD_WR		(1'b0),
	.LD_KIND			(ld_kind),
	.LD_SLOT			(),
	.LD_SIZE			(),
	.LD_START		(),
	.LD_ACTIVE		(ld_active),
	.LD_END			(),
	.LD_ADDR			(ld_addr),
	.LD_DATA			(ld_data),
	.LD_WR			(ld_wr),
	.LD_READY		(ld_ready),
	.OSD_WR			(osd_wr),
	.OSD_WADDR		(osd_waddr),
	.OSD_WDATA		(osd_wdata),
	.OSD_EN			(osd_en),
	.OSD_FG			(osd_fg),
	.OSD_BG			(osd_bg),
	.OSD_ALPHA		(osd_alpha),
	.OSD_PX			(osd_px),
	.OSD_PY			(osd_py),
	.OSD_PW			(osd_pw),
	.OSD_PH			(osd_ph),
	.OSD_PLACE		(osd_place),
	.OSD_ZOOM		(osd_zoom),
	.SDC_IMG_MOUNTED(),
	.SDC_IMG_SIZE	(),
	.SDC_RD			(8'd0),
	.SDC_WR			(8'd0),
	.SDC_SECTOR		(32'd0),
	.SDC_BUSY		(),
	.SDC_DONE		(),
	.SDC_ERROR		(),
	.SDC_SLOT		(),
	.SDC_BYTE_IN_STROBE(),
	.SDC_BYTE_ADDR	(),
	.SDC_BYTE_IN_DATA(),
	.SDC_BYTE_OUT_DATA(8'd0),
	.IMG_WP			(),
	.IMG_PHYS_WR	(),
	.IMG_PHYS		(),
	.IMG_FLUSH		(),
	.FDD_CHNG_WR	(),
	.FDD_CHNG		(),
	.FDD_CHNG_REQ	(1'b0),
	.FDD_CHNG_DS	(2'd0),
	.IMG_ACTIVE		(),
	.PORT_OUT_DATA	(),
	.PORT_OUT_WR	(),
	.PORT_OUT_READY(4'b1111),
	.PORT_IN_DATA	(32'd0),
	.PORT_IN_WR		(4'b0000),
	.PORT_CFG		(128'd0),
	.PORT_IN_FULL	(),
	.PORT_STAT		(),
	.PORT_STAT_WR	(),
	.RTC_A			(8'd0),
	.RTC_DI			(8'd0),
	.RTC_CS			(1'b1),
	.RTC_WR_N		(1'b1),
	.MATRIX_CMD		(24'd0),
	.MATRIX_CMD_WR	(1'b0),
	.DEBUG_ADDR		(16'd0),
	.DEBUG_DATA		(16'd0),
	.RTC_DO			(),
	.FT_SPI_ON		(mcu_ft_spi_on),
	.FT_VGA_ON		(mcu_ft_vga_on),
	.FT_RESET		(mcu_ft_reset),
	.FT_SCK			(mcu_ft_sck),
	.FT_MOSI			(mcu_ft_mosi),
	.FT_MISO			(FT_SPI_MISO),
	.FT_CS_N			(mcu_ft_cs_n),
	.SD2_SCK			(),
	.SD2_MOSI		(),
	.SD2_MISO		(1'b1),
	.SD2_CS_N		()
);

// the FT812 belongs to the mcu (its menus): the core does not use it
assign FT_SPI_CS_N = mcu_ft_spi_on ? mcu_ft_cs_n : 1'b1;
assign FT_SPI_SCK = mcu_ft_spi_on ? mcu_sck_ibufg : 1'b1;
assign FT_SPI_MOSI = mcu_ft_spi_on ? mcu_ft_mosi : 1'b1;

// ---------- OSD switches (core.json "osd", in this order): switch n = softsw[n*8 +: 8] ----------
wire sw_reset = softsw[0];        // 0 Reset (F12)
wire sw_nmi = softsw[8];          // 1 NMI (F11): the esxDOS browser
wire sw_hard_reset = softsw[16];  // 2 Hard reset: the master reset of ZX-Uno (boot stub again)
wire [1:0] hw_btn = mcu_btns[1:0];

wire kbd_rst_n = ~(sw_reset | hw_btn[0] | mcu_busy);
wire kbd_mrst_n = ~sw_hard_reset;
reg kbd_nmi_n = 1'b1;
always @(posedge clk_bus) kbd_nmi_n <= ~(sw_nmi | hw_btn[1]);

// ---------- keyboard: USB report -> the Spectrum matrix ----------
wire [7:0] kbd_rows;
wire [5:0] kbd_do;
wire [7:0] hid_joy_do;
hid_parser hid_parser(
	.CLK				(clk_bus),
	.RESET			(areset),
	.KB_STATUS		(mcu_kbd[7:0]),
	.KB_DAT0			(mcu_kbd[15:8]),
	.KB_DAT1			(mcu_kbd[23:16]),
	.KB_DAT2			(mcu_kbd[31:24]),
	.KB_DAT3			(mcu_kbd[39:32]),
	.KB_DAT4			(mcu_kbd[47:40]),
	.KB_DAT5			(mcu_kbd[55:48]),
	.KB_SCANCODE	(8'd0),
	.KB_SCANCODE_UPD(1'b0),
	.JOY_TYPE_L		(3'd7),          // no joystick on the keys: the joysticks go to the DB9 inputs of ZX-Uno
	.JOY_TYPE_R		(3'd7),
	.JOY_L			(13'd0),
	.JOY_R			(13'd0),
	.KB_TYPE			(1'b1),
	.A					(kbd_rows),
	.JOY_DO			(hid_joy_do),
	.KB_DO			(kbd_do),
	.RTC_A			(8'd0),
	.RTC_DI			(8'd0),
	.RTC_DO_IN		(8'd0),
	.RTC_DO_OUT		(),
	.RTC_WR			(1'b0),
	.RTC_RD			(1'b0)
);

// ---------- mouse: USB -> kg_cursor -> Kempston ----------
reg ms_upd = 1'b0;
always @(posedge clk_bus) if (mcu_ms_wr) ms_upd <= ~ms_upd;
wire [7:0] cursor_x, cursor_y;
wire [3:0] cursor_z;
wire [2:0] cursor_b;
kg_cursor #(.Z_W(4), .Z_NEG(1), .Z_ACC(1)) cursor(
	.clk				(clk_bus),
	.ms_x				(ms_x),
	.ms_y				(ms_y),
	.ms_z				(mcu_ms_z[3:0]),
	.ms_b				(mcu_ms_b[2:0]),
	.ms_upd			(ms_upd),
	.x					(cursor_x),
	.y					(cursor_y),
	.z					(cursor_z),
	.b					(cursor_b)
);

// ---------- ZX-Uno ----------
wire [2:0] zx_r, zx_g, zx_b;
wire zx_hsync, zx_vsync, zx_blank, clk14en;
wire [15:0] audio_l, audio_r;
wire [7:0] sram_d8;
wire sram_we_n, sram_oe_n;
wire uart_rts;
wire i2c_sda;

zxuno #(.MASTERCLK(28000000), .FPGA_MODEL(3'b000)) zxuno (
	.sysclk				(clk_bus),
	.clk_icap			(1'b0),
	.power_on_reset_n	(por_n),
	.r						(zx_r),
	.g						(zx_g),
	.b						(zx_b),
	.hsync				(zx_hsync),
	.vsync				(zx_vsync),
	.csync				(),
	.vrampage			(),
	.monochrome_switcher(),
	.interlace_mode	(),
	.kbd_rows			(kbd_rows),
	.kbd_cols			(kbd_do[4:0]),
	.kbd_rst_n			(kbd_rst_n),
	.kbd_mrst_n			(kbd_mrst_n),
	.kbd_nmi_n			(kbd_nmi_n),
	.ps2_code			(mcu_ps2_code),
	.ps2_kind			(mcu_ps2_kind),
	.ps2_wr				(mcu_ps2_wr),
	.ear_ext				(tape_in_r),
	.audio_left			(audio_l),
	.audio_right		(audio_r),
	.midi_out			(MIDI_TX),
	.clkbd				(1'b0),
	.wsbd					(1'b0),
	.dabd					(1'b0),
	.i2c_scl				(),
	.i2c_sda				(i2c_sda),
	.uart_tx				(UART_TX),
	.uart_rx				(UART_RX),
	.uart_rts			(uart_rts),
	.uart_reset			(),
	.sram_addr			(zx_sram_a),
	.sram_data			(MD[7:0]),
	.sram_we_n			(sram_we_n),
	.sram_oe_n			(sram_oe_n),
	.flash_cs_n			(),
	.flash_clk			(),
	.flash_di			(),
	.flash_do			(1'b1),
	.sd_cs_n				(SD_CS_N),
	.sd_clk				(SD_CLK),
	.sd_mosi				(SD_DI),
	.sd_miso				(SD_DO),
	// the DB9 inputs are active low; kg_mcu2: 1 up, 2 down, 3 left, 4 right, 6 A, 7 B
	.joy1up				(~mcu_joy_l[1]),
	.joy1down			(~mcu_joy_l[2]),
	.joy1left			(~mcu_joy_l[3]),
	.joy1right			(~mcu_joy_l[4]),
	.joy1fire1			(~mcu_joy_l[7]),
	.joy1fire2			(~mcu_joy_l[6]),
	.joy2up				(~mcu_joy_r[1]),
	.joy2down			(~mcu_joy_r[2]),
	.joy2left			(~mcu_joy_r[3]),
	.joy2right			(~mcu_joy_r[4]),
	.joy2fire1			(~mcu_joy_r[7]),
	.joy2fire2			(~mcu_joy_r[6]),
	.joy1fire3			(),
	.kmouse_x			(cursor_x),
	.kmouse_y			(cursor_y),
	.kmouse_b			(cursor_b),
	.video_blank		(zx_blank),
	.clk14en_tovga		(clk14en),
	.vga_enable			(),
	.scanlines_enable	(),
	.freq_option		(),
	.ula_mode			(),
	.ula_hcont			(),
	.ula_vcont			(),
	.ad724_xtal			(),
	.ad724_mode			(),
	.ad724_enable_gencolorclk(),
	.mb_uart_tx			(),
	.mb_uart_rx			(1'b1)
);
// ---------- the ROM loader: core.json "roms" (LD kind 0) into the SRAM of ZX-Uno ----------
// The SRAM addresses are those of ZX-Uno (21 bits): 128K ROM banks 8..11 at 0x20000, esxDOS at 0x30000.
// ZX-Uno is held in reset (por_n) while the loader owns the SRAM. A byte: address + data out, /WE low for two
// clocks of clk_bus (71 ns), one clock after it with /WE high; LD_READY low meanwhile.
assign ld_rom_act = ld_active && ld_kind == 2'd0;
reg [20:0] ld_a = 21'd0;
reg [7:0] ld_d = 8'd0;
reg [1:0] ld_st = 2'd0;
reg ld_we_n = 1'b1;
always @(posedge clk_bus) begin
	case (ld_st)
		2'd0: if (ld_wr && ld_rom_act) begin ld_a <= ld_addr[20:0]; ld_d <= ld_data; ld_st <= 2'd1; end
		2'd1: begin ld_we_n <= 1'b0; ld_st <= 2'd2; end
		2'd2: begin ld_st <= 2'd3; end
		2'd3: begin ld_we_n <= 1'b1; ld_st <= 2'd0; end
	endcase
end
assign ld_ready = (ld_st == 2'd0);

wire [20:0] zx_sram_a;
assign MA = ld_rom_act ? ld_a : zx_sram_a;
assign MD[7:0] = ld_rom_act ? ld_d : 8'hZZ;   // ZX-Uno does not drive the bus in reset
assign MD[15:8] = 8'hZZ;
assign MWR_N = { 1'b1, ld_rom_act ? ld_we_n : sram_we_n };
assign MRD_N = { 1'b1, ld_rom_act ? 1'b1 : sram_oe_n };
assign UART_CTS = uart_rts;

// ---------- video: line doubler, OSD, HDMI ----------
wire [7:0] video_r, video_g, video_b, osd_r, osd_g, osd_b;
wire video_hs, video_vs, video_de, osd_hs, osd_vs, osd_de;
// a new line length of the ULA (timing 48K / 128K / Pentagon): HDMI off for ~150 ms so that the sink detects
// the new mode (the capture of the bench kept the old line length and slanted the picture)
wire video_mode_change;
reg [22:0] hdmi_rst_cnt = 23'd0;
always @(posedge clk_bus)
	if (video_mode_change)
		hdmi_rst_cnt <= 23'h7FFFFF;
	else if (hdmi_rst_cnt != 23'd0)
		hdmi_rst_cnt <= hdmi_rst_cnt - 1'd1;
wire hdmi_restart = (hdmi_rst_cnt != 23'd0);
zxuno_scandbl #(.CLKVIDEO(28030)) scandbl (
	.clk				(clk_bus),
	.clk14en			(clk14en),
	.ri				(zx_r),
	.gi				(zx_g),
	.bi				(zx_b),
	.blank_i			(zx_blank),
	.hsync_ext_n	(zx_hsync),
	.vsync_ext_n	(zx_vsync),
	.ro				(video_r),
	.go				(video_g),
	.bo				(video_b),
	.hsync			(video_hs),
	.vsync			(video_vs),
	.de				(video_de),
	.mode_change	(video_mode_change)
);

kg_l2_osd_overlay overlay(
	.wclk				(clk_bus),
	.osd_wr			(osd_wr),
	.osd_waddr		(osd_waddr),
	.osd_wdata		(osd_wdata),
	.osd_en			(osd_en),
	.osd_fg			(osd_fg),
	.osd_bg			(osd_bg),
	.osd_alpha		(osd_alpha),
	.osd_px			(osd_px),
	.osd_py			(osd_py),
	.osd_pw			(osd_pw),
	.osd_ph			(osd_ph),
	.osd_place		(osd_place),
	.osd_zoom		(osd_zoom),
	.icon_on			(8'd0),
	.icon_act		(8'd0),
	.clk				(clk_bus),
	.rgb_i			({video_r, video_g, video_b}),
	.hs_i				(video_hs),
	.vs_i				(video_vs),
	.de_i				(video_de),
	.rgb_o			({osd_r, osd_g, osd_b}),
	.hs_o				(osd_hs),
	.vs_o				(osd_vs),
	.de_o				(osd_de)
);

// FT_CLK: the pixel clock of the FT812 (the menus of the mcu on HDMI)
wire ft_clk_ibufg, ft_clk_int;
IBUFG ibufg_ft_clk(.I(FT_CLK), .O(ft_clk_ibufg));
BUFG bufg_ft_clk(.I(ft_clk_ibufg), .O(ft_clk_int));

wire [7:0] hdmi_freq;
kg_hdmi_ft #(.CLKRATE(28030303), .REF_MHZ(8'd28), .SAMPLERATE(48000), .OUTPUT_REG(1)) hdmi_top(
	.clk				(ft_clk_int),
	.clk_ref			(clk_bus),
	.clk_ref_pll	(clk_bus_pll),
	.clk_8			(clk_8mhz),
	.reset			(areset || hdmi_restart),
	.vga_rgb			({osd_r, osd_g, osd_b}),
	.vga_hs			(osd_hs),
	.vga_vs			(osd_vs),
	.vga_de			(osd_de),
	.ft_rgb			({VGA_R, VGA_G, VGA_B}),
	.ft_hs			(VGA_HS),
	.ft_vs			(VGA_VS),
	.ft_de			(FT_DE),
	.ft_sel			(mcu_ft_vga_on),
	.audio_en		(~dvi_only),
	.audio_l			(audio_l),
	.audio_r			(audio_r),
	.tmds_p			(TMDS_P),
	.tmds_n			(TMDS_N),
	.freq				(hdmi_freq)
);

// ---------- i2s DAC ----------
kg_pcm5102 #(.DIV_BITS(2)) PCM5102(
	.clk				(clk_bus),
	.reset			(areset),
	.left				(audio_l),
	.right			(audio_r),
	.din				(DAC_DAT),
	.bck				(DAC_BCK),
	.lrck				(DAC_WS)
);

endmodule
