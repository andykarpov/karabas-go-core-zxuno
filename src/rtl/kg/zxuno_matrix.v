// karabas: the dot matrix of Mini G for ZX-Uno, after rtl/mcu/dot_matrix.v of core-tsconf / profi / next
// (karabas-go-firmware docs/matrix.md). Two changes:
//  - the registers are E0 / E1 / E2 of the ZX-Uno register file (FC3B / FD3B): F0..F3 are the PZX player
//    of ZX-Uno. All the cores moved from F0 / F1 / F2 to E0 / E1 / E2 (2026-11-18);
//  - the peaks are (max - min) / 2 of each channel over the period, not the highest absolute sample: the
//    mixer of ZX-Uno is not centred at 0 in silence (AY, SAA, beeper are offset: about -18432), so the
//    absolute value would show a meter at half the scale with no sound.
// E0 control: bit 0 clear, bit 1 update, bit 2 brightness from bits 7..4, bit 3 1 = audio meter / 0 = draw
// E1 x / y of the next pixel, E2 colour of the pixel (0 off, 1 red, 2 yellow, 3 green).
module zxuno_matrix #(
	parameter [31:0] PERIOD = 560000          // clocks per peak frame (20 ms at 28 MHz)
) (
	input wire clk,
	input wire reset,
	input wire [15:0] audio_l,                // two's complement, any offset
	input wire [15:0] audio_r,
	input wire iowr,                          // CPU I/O write (level, IORQ & WR)
	input wire [15:0] ioa,
	input wire [7:0] iod,
	output wire cmd_wr,
	output wire [23:0] cmd
);
	localparam [7:0] CMD_MATRIX_CTL    = 8'h60;
	localparam [7:0] CMD_MATRIX_PIX    = 8'h61;
	localparam [7:0] CMD_AUDIO_PEAKS_L = 8'h70;
	localparam [7:0] CMD_AUDIO_PEAKS_R = 8'h71;

	localparam [7:0] REG_CTL = 8'hE0, REG_XY = 8'hE1, REG_PIX = 8'hE2;

	// ---- peaks: half the peak-to-peak range, 0..65535 on the link ----
	reg signed [15:0] max_l = 16'sh8000, min_l = 16'sh7FFF, max_r = 16'sh8000, min_r = 16'sh7FFF;
	reg [15:0] peak_l = 16'd0, peak_r = 16'd0;
	reg peak_l_wr = 1'b0, peak_r_wr = 1'b0;
	reg [19:0] pcnt = 20'd0;
	wire signed [15:0] sl = audio_l, sr = audio_r;
	wire [16:0] span_l = {max_l[15], max_l} - {min_l[15], min_l};   // 0..65535 when max >= min
	wire [16:0] span_r = {max_r[15], max_r} - {min_r[15], min_r};
	always @(posedge clk) begin
		peak_l_wr <= 1'b0;
		peak_r_wr <= 1'b0;
		if (pcnt == PERIOD[19:0]) begin
			peak_l <= (max_l >= min_l) ? span_l[15:0] : 16'd0;   // (max - min) / 2, shifted up 1 = max - min
			peak_r <= (max_r >= min_r) ? span_r[15:0] : 16'd0;
			pcnt <= pcnt + 20'd1;
		end
		else if (pcnt == PERIOD[19:0] + 20'd1) begin
			peak_l_wr <= 1'b1;
			pcnt <= pcnt + 20'd1;
		end
		else if (pcnt == PERIOD[19:0] + 20'd2) begin
			peak_r_wr <= 1'b1;
			pcnt <= 20'd0;
			max_l <= sl; min_l <= sl;
			max_r <= sr; min_r <= sr;
		end
		else begin
			pcnt <= pcnt + 20'd1;
			if (sl > max_l) max_l <= sl;
			if (sl < min_l) min_l <= sl;
			if (sr > max_r) max_r <= sr;
			if (sr < min_r) min_r <= sr;
		end
	end

	// ---- matrix registers on the ZX-Uno ports ----
	wire reg_port = iowr && ioa == 16'hFC3B;
	wire data_port = iowr && ioa == 16'hFD3B;
	reg [7:0] zxuno_reg = 8'hFF;
	always @(posedge clk) begin
		if (reset)
			zxuno_reg <= 8'hFF;
		else if (reg_port)
			zxuno_reg <= iod;
	end

	wire ctl_port = data_port && zxuno_reg == REG_CTL;
	wire xy_port = data_port && zxuno_reg == REG_XY;
	wire pix_port = data_port && zxuno_reg == REG_PIX;
	reg ctl_prev = 1'b0, pix_prev = 1'b0;
	reg ctl_wr = 1'b0, pix_wr = 1'b0;
	reg [7:0] ctl = 8'h00, xy = 8'h00;
	reg [15:0] pix = 16'h0000;
	always @(posedge clk) begin
		ctl_prev <= ctl_port;
		pix_prev <= pix_port;
		ctl_wr <= 1'b0;
		pix_wr <= 1'b0;
		if (reset) begin
			ctl <= 8'h00;
			pix <= 16'h0000;
		end
		else begin
			if (ctl_port) begin
				ctl <= iod;
				if (!ctl_prev) ctl_wr <= 1'b1;
			end
			if (xy_port)
				xy <= iod;
			if (pix_port) begin
				pix <= { xy, iod };
				if (!pix_prev) pix_wr <= 1'b1;
			end
		end
	end

	// one frame per clock: a register write and a peak frame never fall in the same clock in practice;
	// the register write wins, the peak is sent again 20 ms later
	assign cmd_wr = ctl_wr | pix_wr | peak_l_wr | peak_r_wr;
	assign cmd = ctl_wr ? { CMD_MATRIX_CTL, 8'h00, ctl } :
	             pix_wr ? { CMD_MATRIX_PIX, pix } :
	             peak_l_wr ? { CMD_AUDIO_PEAKS_L, peak_l } :
	             peak_r_wr ? { CMD_AUDIO_PEAKS_R, peak_r } : 24'h000000;
endmodule
