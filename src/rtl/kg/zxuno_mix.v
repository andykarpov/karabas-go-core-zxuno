// karabas: the audio of the board = the mixer of ZX-Uno + the General Sound + the OPL3 (FM of MoonSound) + the ADC
// (the MIDI synth of the board on the Mini / Mini G).
//  - the mixer of ZX-Uno is offset in silence (AY, SAA, beeper: about -18432, it changes with the OSD and
//    the ports): a DC blocker takes the offset out (one pole, the mean follows with a time constant of
//    64 x 4096 clocks = 9.4 ms at 28 MHz: -3 dB at 17 Hz), else the sum with the other sources would clip;
//  - the sum in 19 bits, saturated to 16 (signed).
// The GS and the OPL3 come here already interpolated to clk (audio_interp of core-tsconf).
module zxuno_mix (
	input wire clk,
	input wire [15:0] zx_l,           // the mixer of ZX-Uno: two's complement, offset
	input wire [15:0] zx_r,
	input wire signed [15:0] gs_l,
	input wire signed [15:0] gs_r,
	input wire signed [15:0] fm_l,
	input wire signed [15:0] fm_r,
	input wire signed [15:0] ext_l,   // the ADC (MIDI synth): not through the mixer of ZX-Uno, which does not saturate
	input wire signed [15:0] ext_r,
	output reg signed [15:0] out_l = 16'sd0,
	output reg signed [15:0] out_r = 16'sd0
);
	// DC blocker: mean in 16.12 fixed point, updated every 64 clocks by 1/4096 of the error
	reg [5:0] div = 6'd0;
	always @(posedge clk) div <= div + 6'd1;
	reg signed [27:0] mean_l = 28'sd0, mean_r = 28'sd0;
	wire signed [15:0] xl = zx_l, xr = zx_r;
	wire signed [27:0] err_l = {xl, 12'd0} - mean_l;
	wire signed [27:0] err_r = {xr, 12'd0} - mean_r;
	always @(posedge clk) if (div == 6'd0) begin
		mean_l <= mean_l + (err_l >>> 12);
		mean_r <= mean_r + (err_r >>> 12);
	end
	wire signed [16:0] ac_l = {xl[15], xl} - {mean_l[27], mean_l[27:12]};
	wire signed [16:0] ac_r = {xr[15], xr} - {mean_r[27], mean_r[27:12]};

	wire signed [18:0] sum_l = {{2{ac_l[16]}}, ac_l} + {{3{gs_l[15]}}, gs_l} + {{3{fm_l[15]}}, fm_l} + {{3{ext_l[15]}}, ext_l};
	wire signed [18:0] sum_r = {{2{ac_r[16]}}, ac_r} + {{3{gs_r[15]}}, gs_r} + {{3{fm_r[15]}}, fm_r} + {{3{ext_r[15]}}, ext_r};

	function signed [15:0] sat(input signed [18:0] v);
		sat = (v > 19'sd32767) ? 16'sd32767 : (v < -19'sd32768) ? -16'sd32768 : v[15:0];
	endfunction

	always @(posedge clk) begin
		out_l <= sat(sum_l);
		out_r <= sat(sum_r);
	end
endmodule
