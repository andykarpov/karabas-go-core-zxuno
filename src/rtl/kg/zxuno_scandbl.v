// karabas: line doubler for the HDMI / VGA output of the boards, after vga_scandoubler.v of ZX-Uno
// (Miguel Angel Rodriguez Jodar, GPL-3): the same two-line buffer, written with clk14en (each 7 MHz ULA
// pixel twice) and read at the full clock, so one ULA line of ~64 us gives two lines of ~32 us. Changes:
//  - DE for HDMI is a fixed window of 720 x 576 counted from the output syncs (HSYNC 64 clocks, back porch 72,
//    front 40; VSYNC 8 lines, back porch 24, front 16 of the 624 lines of 48K): the blanking of the ULA alone
//    (vblank 8 ULA lines, VSYNC right after the last line) gave 704 x 610 with no front porch, which the HDMI
//    capture of the bench did not take (26111802: no signal). About 8 ULA lines of border are cut top and
//    bottom. The blanking bit of the ULA is kept in the buffer: those points are black inside the window;
//  - VSYNC changes only at the start of an output line (the original counted 114 us from the ULA vsync
//    edge, anywhere in a line);
//  - HSYNC and VSYNC positive, as core-tsconf and core-baseconf give them to kg_hdmi_ft (896 x 624, DE 720 x 576
//    there too): with negative ones (26111803) the capture of the bench showed the picture slanted;
//  - mode_change: one clock when the length of the ULA line changes (48K / Pentagon 896 <-> 128K 912 clocks
//    per output line), for the top to restart HDMI: the capture of the bench locked on the 896 of the boot
//    stub (48K timing) and showed the picture slanted after MASTERCONF set the 128K timing (26111804);
//  - no 15 kHz mode, no scanlines; the outputs are registered and 8 bits per colour.
//  - Pentagon (26112301, Caasper911: black band with a step at the top, the paper shifted right, the picture
//    blinking): its ULA has VSYNC 16 lines and VBLANK 32 lines (vs 4 / 8), hsync at the start of hblank, so the
//    window of 48K gave no back porch after VSYNC (32 lines of VSYNC, DE right after), 16 ULA lines of vblank
//    inside the window and the paper 24 points right of the centre. Now VSYNC is 8 lines counted from the
//    VSYNC edge of the ULA in all modes, and with a frame of 640 lines (Pentagon) VSYNC is at lines 16..23 and
//    the window at 64..639 (vertical), 152..871 (horizontal): front porch 16, back porch 40, paper centred
//    (border 52 points left / right, 48 ULA lines top / bottom). A change of the frame length also restarts HDMI;
// The timing on the output is the doubled timing of the ULA: 48K 448 x 312, 128K 456 x 311, Pentagon
// 448 x 320 (7 MHz pixels) -> 896 / 912 clocks of 28 MHz per line, 624 / 622 / 640 lines, ~50 Hz.
module zxuno_scandbl #(
	parameter [31:0] CLKVIDEO = 28000          // kHz of clk
) (
	input wire clk,
	input wire clk14en,
	input wire [2:0] ri,
	input wire [2:0] gi,
	input wire [2:0] bi,
	input wire blank_i,
	input wire hsync_ext_n,
	input wire vsync_ext_n,
	output reg [7:0] ro = 8'd0,
	output reg [7:0] go = 8'd0,
	output reg [7:0] bo = 8'd0,
	output reg hsync = 1'b0,   // positive
	output reg vsync = 1'b0,   // positive
	output reg de = 1'b0,
	output reg mode_change = 1'b0
);
	localparam [9:0] HSYNC_COUNT = 10'd64;     // as 576p and the BaseConf core (the original: 3.36 us)
	localparam [9:0] H_DE_BEG = 10'd136;       // the visible ULA points start at 144 (48K)
	localparam [9:0] H_DE_END = H_DE_BEG + 10'd720;
	localparam [9:0] V_DE_BEG = 10'd32;        // output lines from the start of VSYNC of the ULA
	localparam [9:0] V_DE_END = V_DE_BEG + 10'd576;
	localparam [9:0] V_VS_BEG = 10'd0;         // output VSYNC, 8 lines
	// Pentagon: hsync of the ULA at hc 320 (not 344), the paper at point 256 of the line; vsync at vc 240,
	// vblank to vc 271, 640 lines
	localparam [9:0] H_DE_BEG_P = 10'd152;
	localparam [9:0] H_DE_END_P = H_DE_BEG_P + 10'd720;
	localparam [9:0] V_DE_BEG_P = 10'd64;
	localparam [9:0] V_DE_END_P = V_DE_BEG_P + 10'd576;
	localparam [9:0] V_VS_BEG_P = 10'd16;
	reg pent = 1'b0, frame_change = 1'b0;                        // the last frame had more than 630 output lines

	reg [10:0] addrvideo = 11'd0, addrvga = 11'd0;
	reg [9:0] totalhor = 10'd0;

	reg [9:0] scan [0:2047];   // two lines of up to 1024 points: { blank, r, g, b }
	reg [9:0] dout = 10'h200;
	always @(posedge clk) begin
		dout <= scan[addrvga];
		if (clk14en)
			scan[addrvideo] <= { blank_i, ri, gi, bi };
	end

	// write side: a new half of the buffer at each falling edge of the ULA hsync
	reg hsync_ext_n_prev = 1'b1;
	always @(posedge clk) begin
		mode_change <= frame_change;
		if (clk14en) begin
			hsync_ext_n_prev <= hsync_ext_n;
			if (hsync_ext_n == 1'b0 && hsync_ext_n_prev == 1'b1) begin
				totalhor <= addrvideo[9:0];
				if (totalhor != addrvideo[9:0])
					mode_change <= 1'b1;
				addrvideo <= { ~addrvideo[10], 10'd0 };
			end
			else
				addrvideo <= addrvideo + 11'd1;
		end
	end

	// read side at twice the speed: the half being written is read twice
	reg hsync_ext_n_prev2 = 1'b1;
	reg line_start = 1'b0;
	always @(posedge clk) begin
		hsync_ext_n_prev2 <= hsync_ext_n;
		line_start <= 1'b0;
		if (addrvga[9:0] == totalhor && hsync_ext_n == 1'b1 && hsync_ext_n_prev2 == 1'b1) begin
			addrvga <= { addrvga[10], 10'd0 };
			line_start <= 1'b1;
		end
		else if (hsync_ext_n == 1'b0 && hsync_ext_n_prev2 == 1'b1) begin
			addrvga <= { addrvideo[10], 10'd0 };
			line_start <= 1'b1;
		end
		else
			addrvga <= addrvga + 11'd1;
	end

	// syncs one clock late, as the buffer data; VSYNC taken from the ULA at the start of each output line
	reg hs_d = 1'b1, vs_ula = 1'b1, vs_line = 1'b1, h_win = 1'b0, v_win = 1'b0;
	reg [9:0] vline = 10'd0;
	wire [9:0] vline_n = (vs_ula && !vsync_ext_n) ? 10'd0 : (vline != 10'h3FF) ? vline + 10'd1 : vline;
	wire [9:0] vs_beg = pent ? V_VS_BEG_P : V_VS_BEG;
	always @(posedge clk) begin
		hs_d <= (addrvga[9:0] < HSYNC_COUNT) ? 1'b0 : 1'b1;
		h_win <= pent ? (addrvga[9:0] >= H_DE_BEG_P && addrvga[9:0] < H_DE_END_P)
		              : (addrvga[9:0] >= H_DE_BEG && addrvga[9:0] < H_DE_END);
		frame_change <= 1'b0;
		if (line_start) begin
			vs_ula <= vsync_ext_n;
			if (vs_ula && !vsync_ext_n) begin   // vline: the last line of the frame
				pent <= (vline >= 10'd630);
				frame_change <= (pent != (vline >= 10'd630));
			end
			vline <= vline_n;
			vs_line <= ~(vline_n >= vs_beg && vline_n < vs_beg + 10'd8);
			v_win <= pent ? (vline_n >= V_DE_BEG_P && vline_n < V_DE_END_P)
			              : (vline_n >= V_DE_BEG && vline_n < V_DE_END);
		end
	end

	always @(posedge clk) begin
		ro <= dout[9] ? 8'd0 : { dout[8:6], dout[8:6], dout[8:7] };
		go <= dout[9] ? 8'd0 : { dout[5:3], dout[5:3], dout[5:4] };
		bo <= dout[9] ? 8'd0 : { dout[2:0], dout[2:0], dout[2:1] };
		de <= h_win & v_win;
		hsync <= ~hs_d;
		vsync <= ~vs_line;
	end
endmodule
