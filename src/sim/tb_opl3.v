// iverilog -g2012 -o tb_opl3.vvp tb_opl3.v ../rtl/kg/zxuno_opl3.v ../rtl/opl3/opl3_fm_gen.v && vvp tb_opl3.vvp
// OUT / IN through C4..C7: status (ID 06 then timers), register read back, a note on channel 0 -> FM output
`timescale 1ns/1ps
module tb;
	reg clk = 0; always #17.84 clk = ~clk;
	reg reset = 1;
	reg [7:0] a = 0, di = 0; reg iorq_n = 1, rd_n = 1, wr_n = 1;
	wire [7:0] dout; wire sel, oe; wire signed [15:0] l, r; wire st;
	zxuno_opl3 u(.clk(clk), .reset(reset), .en(1'b1), .a(a), .di(di), .dout(dout), .iorq_n(iorq_n), .m1_n(1'b1),
		.rd_n(rd_n), .wr_n(wr_n), .sel(sel), .oe(oe), .out_l(l), .out_r(r), .sample_t(st));
	task out(input [7:0] p, input [7:0] d); begin
		@(posedge clk); a = p; di = d; iorq_n = 0; wr_n = 0; repeat (8) @(posedge clk); iorq_n = 1; wr_n = 1; repeat (8) @(posedge clk);
	end endtask
	reg [7:0] v;
	task inp(input [7:0] p); begin
		@(posedge clk); a = p; iorq_n = 0; rd_n = 0; repeat (8) @(posedge clk); v = dout; iorq_n = 1; rd_n = 1; repeat (8) @(posedge clk);
	end endtask
	task fm(input [7:0] r, input [7:0] d); begin out(8'hC4, r); out(8'hC5, d); end endtask
	integer errs = 0, maxv = 0, i;
	initial begin
		repeat (20) @(posedge clk); reset = 0; repeat (1000) @(posedge clk);   // opl3_fm writes its init values for 512 clocks
		inp(8'hC4); $display("status first %h (06)", v); if (v !== 8'h06) errs = errs + 1;
		inp(8'hC4); $display("status then  %h (00)", v); if (v !== 8'h00) errs = errs + 1;
		fm(8'h20, 8'h01); fm(8'h40, 8'h10); fm(8'h60, 8'hF0); fm(8'h80, 8'h77); fm(8'hE0, 8'h00);
		fm(8'h23, 8'h01); fm(8'h43, 8'h00); fm(8'h63, 8'hF0); fm(8'h83, 8'h77);
		fm(8'hC0, 8'h31); fm(8'hA0, 8'h98); fm(8'hB0, 8'h31);   // channel 0: L+R, key on
		out(8'hC4, 8'hA0); inp(8'hC5); $display("reg A0 read %h (98)", v); if (v !== 8'h98) errs = errs + 1;
		for (i = 0; i < 300000; i = i + 1) begin @(posedge clk); if (l > maxv) maxv = l; if (i % 30000 == 0) $display("t %0d fm_out %0d l %0d wt %b tt %b", i, u.fm_out_l, l, u.fm_wtgl, u.fm_ttgl); end
		$display("max FM out %0d", maxv); if (maxv < 500) errs = errs + 1;
		$display("%s", errs ? "FAIL" : "PASS");
		$finish;
	end
endmodule
