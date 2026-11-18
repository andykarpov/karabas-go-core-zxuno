// iverilog -o tb_matrix.vvp tb_matrix.v ../rtl/kg/zxuno_matrix.v && vvp tb_matrix.vvp
`timescale 1ns/1ps
module tb;
	reg clk = 0; always #17.8 clk = ~clk;
	reg [15:0] al = -16'sd18432, ar = -16'sd18432;
	reg iowr = 0; reg [15:0] ioa = 0; reg [7:0] iod = 0;
	wire cmd_wr; wire [23:0] cmd;
	zxuno_matrix #(.PERIOD(1000)) m(.clk(clk), .reset(1'b0), .audio_l(al), .audio_r(ar),
		.iowr(iowr), .ioa(ioa), .iod(iod), .cmd_wr(cmd_wr), .cmd(cmd));
	task out(input [15:0] a, input [7:0] d); begin
		@(posedge clk); ioa = a; iod = d; iowr = 1; repeat (4) @(posedge clk); iowr = 0; repeat (4) @(posedge clk);
	end endtask
	integer n = 0, errs = 0;
	reg [23:0] got [0:63];
	always @(posedge clk) if (cmd_wr) begin got[n] = cmd; n = n + 1; end
	initial begin
		repeat (1100) @(posedge clk);                   // a silent period with the offset
		out(16'hFC3B, 8'hF0); out(16'hFD3B, 8'h01);      // F0: PZX, must be ignored
		out(16'hFC3B, 8'hE0); out(16'hFD3B, 8'h03);      // ctl
		out(16'hFC3B, 8'hE1); out(16'hFD3B, 8'h25);      // xy
		out(16'hFC3B, 8'hE2); out(16'hFD3B, 8'h02);      // pix
		al = -16'sd18432 + 16'sd1000; repeat (300) @(posedge clk);
		al = -16'sd18432 - 16'sd1000; repeat (900) @(posedge clk);
		#1;
		$display("%0d frames", n);
		for (integer i = 0; i < n; i = i + 1) $display("  %h", got[i]);
		// expected: 700000 710000 (silence), 600003, 612502, then 7007d0 (2000), 710000
		if (got[0] !== 24'h700000 || got[1] !== 24'h710000) errs = errs + 1;
		if (got[2] !== 24'h600003 || got[3] !== 24'h612502) errs = errs + 1;
		if (got[n-2] !== 24'h7007D0) errs = errs + 1;
		$display("%s", errs ? "FAIL" : "PASS");
		$finish;
	end
endmodule
