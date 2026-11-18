// karabas: Gluk CMOS clock ports (Pentagon / ZX Evo style, as core-tsconf / core-profi): EFF7 bit 7 enables
// them, DFF7 = MC146818 register number, BFF7 = data. The RTC of the board is kept by the firmware in the
// DS1307 layout (core.json rtc_mode 1, BCD, also used by the DS1307 on I2C, ds1307.vhd), so the MC146818
// registers are translated:
//   time 0 / 2 / 4 / 6 / 7 / 8 / 9 (sec, min, hour, day of week, day, month, year) -> DS1307 0..6 (BCD, 24 h)
//   A = 20h (no update in progress), B = 02h (24 h, BCD), C = 00h, D = 80h (battery ok), alarms = 00h:
//   constants, writes ignored (so the data mode is always BCD)
//   0Eh..3Fh (CMOS RAM, 50 bytes) -> DS1307 RAM 08h..39h; 40h.. read FFh
// The audio mixer of ZX-Uno decodes port xxF7 on 8 bits: the top keeps it off EFF7 always and off BFF7 / DFF7
// while EFF7 bit 7 is set (mixer_block).
module zxuno_cmos (
	input wire clk,
	input wire rst_n,
	input wire [15:0] a,
	input wire iorq_n,
	input wire rd_n,
	input wire wr_n,
	input wire m1_n,
	input wire [7:0] din,
	output reg [7:0] dout,
	output wire oe,
	output wire mixer_block,
	// to the RTC registers of kg_mcu2 (shared with ds1307.vhd in the top)
	output wire rtc_sel,             // the CPU reads or writes BFF7: rtc_a below is the address
	output reg [7:0] rtc_a,
	output wire [7:0] rtc_di,
	output reg rtc_wr = 1'b0,        // one clock
	input wire [7:0] rtc_do
);
	reg [7:0] eff7 = 8'h00;
	reg [7:0] mc_addr = 8'h00;
	wire io = !iorq_n && m1_n;
	wire p_eff7 = io && a == 16'hEFF7;
	wire p_dff7 = io && a == 16'hDFF7 && eff7[7];
	wire p_bff7 = io && a == 16'hBFF7 && eff7[7];
	assign mixer_block = (a == 16'hEFF7) || (eff7[7] && (a == 16'hDFF7 || a == 16'hBFF7));
	assign oe = p_bff7 && !rd_n;
	assign rtc_sel = p_bff7;
	assign rtc_di = din;

	// MC146818 register -> DS1307 address (map = 1) or a constant
	reg map;
	reg [7:0] konst;
	always @* begin
		map = 1'b1; konst = 8'hFF; rtc_a = 8'h3F;
		case (mc_addr)
			8'h00: rtc_a = 8'h00;
			8'h02: rtc_a = 8'h01;
			8'h04: rtc_a = 8'h02;
			8'h06: rtc_a = 8'h03;
			8'h07: rtc_a = 8'h04;
			8'h08: rtc_a = 8'h05;
			8'h09: rtc_a = 8'h06;
			8'h01, 8'h03, 8'h05: begin map = 1'b0; konst = 8'h00; end
			8'h0A: begin map = 1'b0; konst = 8'h20; end
			8'h0B: begin map = 1'b0; konst = 8'h02; end
			8'h0C: begin map = 1'b0; konst = 8'h00; end
			8'h0D: begin map = 1'b0; konst = 8'h80; end
			default:
				if (mc_addr >= 8'h0E && mc_addr <= 8'h3F)
					rtc_a = mc_addr - 8'h06;
				else
					map = 1'b0;
		endcase
		dout = !map ? konst : (mc_addr == 8'h04) ? (rtc_do & 8'h3F) : rtc_do;
	end

	reg io_wr_d = 1'b0;
	always @(posedge clk) begin
		io_wr_d <= io && !wr_n;
		rtc_wr <= 1'b0;
		if (!rst_n) begin
			eff7 <= 8'h00;
		end
		else if (io && !wr_n && !io_wr_d) begin   // once per OUT
			if (p_eff7) eff7 <= din;
			if (p_dff7) mc_addr <= din;
			if (p_bff7 && map) rtc_wr <= 1'b1;
		end
	end
endmodule
