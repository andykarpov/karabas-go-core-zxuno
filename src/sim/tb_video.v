// The video path of the core alone: clk_enables + pal_sync_generator (ZX-Uno) + zxuno_scandbl, 2 frames of each
// ULA timing; prints the line / frame lengths, the sync pulses and the DE window seen at the output.
`timescale 1ns/1ps
module tb_video;
	reg clk = 0; always #17.84 clk = ~clk;   // 28.03 MHz
	wire clk14en, clk7en, clk7en_n, clk35en, clk35en_n, clk175en, cpuen;
	clk_enables ce(.clk(clk), .CPUContention(1'b0), .cpu_speed(4'd0), .clk14en(clk14en), .clk7en(clk7en),
		.clk7en_n(clk7en_n), .clk35en(clk35en), .clk35en_n(clk35en_n), .clk175en(clk175en), .clkcpu_enable(cpuen));
	reg [1:0] mode = 2'b00;
	wire [2:0] ro, go, bo; wire hs, vs, cs, intn, blank, rip; wire [8:0] hc, vc, endv;
	pal_sync_generator ps(.clk(clk), .clken(clk7en), .mode(mode), .rasterint_enable(1'b0), .vretraceint_disable(1'b0),
		.raster_line(9'd0), .raster_int_in_progress(rip), .csync_option(1'b0),
		.hinit48k(9'd0), .vinit48k(9'd0), .hinit128k(9'd0), .vinit128k(9'd0), .hinitpen(9'd0), .vinitpen(9'd0),
		.ri(3'd7), .gi(3'd7), .bi(3'd7), .hcnt(hc), .vcnt(vc), .ro(ro), .go(go), .bo(bo), .hsync(hs), .vsync(vs),
		.csync(cs), .int_n(intn), .end_count_v(endv), .blank(blank));
	wire [7:0] r8, g8, b8; wire ohs, ovs, ode;
	zxuno_scandbl #(.CLKVIDEO(28030)) sd(.clk(clk), .clk14en(clk14en), .ri(ro), .gi(go), .bi(bo), .blank_i(blank),
		.hsync_ext_n(hs), .vsync_ext_n(vs), .ro(r8), .go(g8), .bo(b8), .hsync(ohs_p), .vsync(ovs_p), .de(ode));
	wire ohs_p, ovs_p; assign ohs = ~ohs_p; assign ovs = ~ovs_p;   // the checks below count active-low syncs
	integer t = 0, hs_t0 = 0, hs_lo = 0, line_clk = 0, de_cnt = 0, de_lines = 0, lines = 0, vs_lines = 0;
	integer in_hs_t = 0, in_hs_n = 0, ce14 = 0, hpos = 0, de_first = 0, cut = 0, de_l = 0, de_f = -1, vs_l = 0;
	reg ode_d = 0;
	reg ohs_d = 1, ovs_d = 1, hs_d = 1;
	always @(posedge clk) begin
		t = t + 1;
		if (clk14en) ce14 = ce14 + 1;
		if (hs_d && !hs) begin in_hs_n = in_hs_n + 1; if (in_hs_n == 50) $display("ULA line: %0d clk", t - in_hs_t); in_hs_t = t; end
		hs_d <= hs;
		hpos = t - hs_t0;
		if (ode && !ode_d) de_first = hpos;
		ode_d <= ode;
		if (ode) de_cnt = de_cnt + 1;
		if (!sd.dout[9] && !ode && sd.v_win === 1'b1) cut = cut + 1;
		if (!ohs) hs_lo = hs_lo + 1;
		if (ohs_d && !ohs) begin
			lines = lines + 1;
			if (lines == 100) $display("out line: %0d clk, hsync low %0d clk, de %0d clk from %0d", t - hs_t0, hs_lo, de_cnt, de_first);
			if (de_cnt) begin if (de_f < 0) de_f = lines; de_l = lines; de_lines = de_lines + 1; end
			if (!ovs) vs_l = lines;
			if (!ovs) vs_lines = vs_lines + 1;
			if (mode == 0 && lines > 2 && lines < 12) $display("  line %0d: %0d clk, de from %0d", lines, t - hs_t0, de_first);
			hs_t0 = t; hs_lo = 0; de_cnt = 0;
		end
		ohs_d <= ohs;
		if (ovs_d && !ovs) begin
			$display("mode %0d frame: %0d lines (%0d with DE, lines %0d..%0d, vsync %0d lines), %0d clk14en, visible points outside DE (in v window) %0d", mode, lines, de_lines, de_f, de_l, vs_lines, ce14, cut);
			de_f = -1; cut = 0;
			lines = 0; de_lines = 0; vs_lines = 0; ce14 = 0;
		end
		ovs_d <= ovs;
	end
	initial begin
		#(45_000_000); mode = 2'b01; #(45_000_000); mode = 2'b10; #(45_000_000); $finish;
	end
endmodule
