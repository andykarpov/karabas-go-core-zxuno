// karabas: the FM part of the ZXM-MoonSound (OPL3 of the YMF278B) for ZX-Uno, from opl4_kg.v / opl4.v of
// core-tsconf without the wavetable part (it does not fit, Ф0): opl3_fm (opl3_fpga of Greg Taylor, LGPL-3,
// rtl/opl3/opl3_fm_gen.v) and the host side of opl4.v for the FM: the address of the two banks, NEW / NEW2,
// the timers and the status, the read back of the FM registers. All of it on clk (clk_bus, 28.03 MHz).
//
// Ports (low address byte, M1 = 1), as the ZXM-MoonSound:
//   #C4 W FM address bank 0 / R status     #C5 W FM data bank 0 / R the register
//   #C6 W FM address bank 1                #C7 W FM data bank 1 / R the register
// The wave ports #7E / #7F are not there. SEL: the ports are taken (the top hides them from the devices of
// ZX-Uno: ULA at A0 = 0, 7FFD at A1 = 0, ...).
//
// The FM engine makes a sample at clk / 566.3 = 49.5 kHz (the rate of the YMF278B: 33.87 MHz / 684): a phase
// accumulator of 7587096 / 2^32 per clk (the 2529032 of opl4_kg at 84.09 MHz times 3). OUT_L / OUT_R: the
// sample of each FM tick, with SAMPLE_T toggled (for audio_interp in the top). Level: FM x 0.375, about the
// default FM mix of the YMF278B (register F8 = 1B: x 0.705) and the OPL4 at half in the mixer of core-tsconf.
module zxuno_opl3 (
	input  wire        clk,
	input  wire        reset,
	input  wire        en,           // OSD On
	input  wire  [7:0] a,
	input  wire  [7:0] di,
	output reg   [7:0] dout,
	input  wire        iorq_n,
	input  wire        m1_n,
	input  wire        rd_n,
	input  wire        wr_n,
	output wire        sel,
	output wire        oe,
	output reg signed [15:0] out_l = 16'sd0,
	output reg signed [15:0] out_r = 16'sd0,
	output reg         sample_t = 1'b0
);
	assign sel = en && !iorq_n && m1_n && (a[7:2] == 6'b110001);
	assign oe = sel && !rd_n;

	// one write per OUT: the clock after the start of WR within SEL
	reg wr_p = 1'b0, rd_p = 1'b0;
	wire wr_now = sel && !wr_n;
	wire rd_now = sel && !rd_n;
	reg [1:0] off_rd = 2'd0;
	always @(posedge clk) begin
		wr_p <= wr_now;
		rd_p <= rd_now;
		if (rd_now) off_rd <= a[1:0];
	end
	wire wr = wr_now && !wr_p;
	wire rd_done = rd_p && !rd_now;     // the end of a read (side effects)

	// ---- the host side of opl4.v for the FM ----
	reg new1 = 1'b0, new2 = 1'b0, status_id = 1'b1;
	reg [8:0] fm_addr = 9'd0;
	reg fm_w = 1'b0;
	reg [16:0] fm_wword = 17'd0;
	wire [8:0] fm_a = (!new1 && {1'b1, di} != 9'h105) ? {1'b0, di} : {1'b1, di};
	always @(posedge clk) begin
		fm_w <= 1'b0;
		if (reset) begin
			new1 <= 1'b0; new2 <= 1'b0; status_id <= 1'b1; fm_addr <= 9'd0;
		end
		else begin
			if (wr) begin
				case (a[1:0])
					2'd0: fm_addr <= {1'b0, di};
					2'd2: fm_addr <= fm_a;
					default: begin
						fm_w <= 1'b1;
						fm_wword <= {fm_addr, di};
						if (fm_addr == 9'h105) begin
							new1 <= di[0];
							new2 <= di[1];
							if (!new2 && di[1]) status_id <= 1'b1;
						end
					end
				endcase
			end
			if (rd_done && off_rd == 2'd0) status_id <= 1'b0;
		end
	end

	// timers (OPL3): reg 2 timer 1 (80.7 us steps), reg 3 timer 2 (323 us), reg 4 RST / MASK1 / MASK2 / ST2 / ST1
	reg [7:0] t1_val = 8'd0, t2_val = 8'd0, t1_cnt = 8'd0, t2_cnt = 8'd0;
	reg t1_st = 1'b0, t2_st = 1'b0, t1_mask = 1'b0, t2_mask = 1'b0, ft1 = 1'b0, ft2 = 1'b0;
	reg [11:0] t_pre = 12'd0;           // 28.03 MHz / 2262 = 80.7 us
	reg [1:0] t_pre2 = 2'd0;
	wire t_tick = (t_pre == 12'd2261);
	wire fm_wr = wr && a[0] && !fm_addr[8];
	always @(posedge clk) begin
		if (reset) begin
			t1_val <= 8'd0; t2_val <= 8'd0; t1_cnt <= 8'd0; t2_cnt <= 8'd0;
			t1_st <= 1'b0; t2_st <= 1'b0; t1_mask <= 1'b0; t2_mask <= 1'b0;
			ft1 <= 1'b0; ft2 <= 1'b0; t_pre <= 12'd0; t_pre2 <= 2'd0;
		end
		else begin
			t_pre <= t_tick ? 12'd0 : t_pre + 12'd1;
			if (t_tick) begin
				t_pre2 <= t_pre2 + 2'd1;
				if (t1_st) begin
					if (t1_cnt == 8'hFF) begin t1_cnt <= t1_val; if (!t1_mask) ft1 <= 1'b1; end
					else t1_cnt <= t1_cnt + 8'd1;
				end
				if (t2_st && t_pre2 == 2'd3) begin
					if (t2_cnt == 8'hFF) begin t2_cnt <= t2_val; if (!t2_mask) ft2 <= 1'b1; end
					else t2_cnt <= t2_cnt + 8'd1;
				end
			end
			if (fm_wr) begin
				case (fm_addr[7:0])
					8'h02: t1_val <= di;
					8'h03: t2_val <= di;
					8'h04:
						if (di[7]) begin
							ft1 <= 1'b0; ft2 <= 1'b0;
						end
						else begin
							t1_mask <= di[6]; t2_mask <= di[5];
							if (di[6]) ft1 <= 1'b0;
							if (di[5]) ft2 <= 1'b0;
							t1_st <= di[0]; t2_st <= di[1];
							if (di[0] && !t1_st) t1_cnt <= t1_val;
							if (di[1] && !t2_st) t2_cnt <= t2_val;
						end
					default: ;
				endcase
			end
		end
	end
	wire [7:0] fm_status = { ft1 | ft2, ft1, ft2, 5'd0 };

	// the FM registers read back through the data ports (opl4.v: the MFM player keys notes off by IN / AND / OUT)
	reg [7:0] fmreg [0:511];
	reg [7:0] fmreg_q = 8'd0;
	integer i;
	initial for (i = 0; i < 512; i = i + 1) fmreg[i] = 8'd0;
	always @(posedge clk) begin
		if (fm_w) fmreg[fm_wword[16:8]] <= fm_wword[7:0];
		fmreg_q <= fmreg[fm_addr];
	end

	always @* begin
		case (a[1:0])
			2'd0: dout = status_id ? (new2 ? 8'h02 : (new1 ? 8'h00 : 8'h06)) : fm_status;
			2'd1, 2'd3: dout = fmreg_q;
			default: dout = 8'hFF;
		endcase
	end

	// ---- the FM engine ----
	reg fm_wtgl = 1'b0, fm_ttgl = 1'b0;
	reg [16:0] fm_word_r = 17'd0;
	reg [31:0] fm_ph = 32'd0;
	wire [32:0] fm_ph_n = {1'b0, fm_ph} + 33'd7587096;
	wire signed [19:0] fm_out_l, fm_out_r;
	always @(posedge clk) begin
		if (reset) begin
			fm_wtgl <= 1'b0; fm_ttgl <= 1'b0; fm_ph <= 32'd0;
		end
		else begin
			if (fm_w) begin fm_word_r <= fm_wword; fm_wtgl <= ~fm_wtgl; end
			fm_ph <= fm_ph_n[31:0];
			if (fm_ph_n[32]) begin
				// an FM tick: the sample of the last tick is finished (it takes 5.7 us of 20.2)
				fm_ttgl <= ~fm_ttgl;
				out_l <= sat16((fm_out_l >>> 2) + (fm_out_l >>> 3));
				out_r <= sat16((fm_out_r >>> 2) + (fm_out_r >>> 3));
				sample_t <= ~sample_t;
			end
		end
	end

	function signed [15:0] sat16(input signed [19:0] v);
		sat16 = (v > 20'sd32767) ? 16'sh7FFF : (v < -20'sd32768) ? 16'sh8000 : v[15:0];
	endfunction

	opl3_fm fm(
		.clk      (clk),
		.reset_a  (reset),
		.wr_tgl   (fm_wtgl),
		.wr_word  (fm_word_r),
		.tick_tgl (fm_ttgl),
		.out_l    (fm_out_l),
		.out_r    (fm_out_r)
	);
endmodule
