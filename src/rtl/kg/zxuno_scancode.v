// karabas: the ZX-Uno registers SCANCODE (04) and KBSTATUS (05) without a PS/2 port.
// The firmware sends the PS/2 set 2 bytes of each key (kg_mcu2 PS2_CODE / PS2_KIND / PS2_WR, the E0 / F0
// prefixes included); this keeps the last code and its flags as ps2_keyb.v of ZX-Uno did:
//   KBSTATUS = | BSY | 0 | 0 | 0 | ERR | RLS | EXT | PEN |  (PEN cleared after a read of KBSTATUS)
// Writes to SCANCODE (commands to the keyboard, LEDs) go nowhere: BSY and ERR stay 0.
module zxuno_scancode (
	input wire clk,
	input wire [7:0] ps2_code,
	input wire ps2_kind,          // 0 set 2, 1 XT: only set 2 is taken
	input wire ps2_wr,
	input wire [7:0] zxuno_addr,
	input wire zxuno_regrd,
	output wire oe_scancode,
	output wire [7:0] scancode_dout,
	output wire oe_kbstatus,
	output reg [7:0] kbstatus_dout = 8'h00
);

`include "../config/config.vh"   // resolved through the include dir rtl/zxuno/io, as the ZX-Uno files

	assign oe_scancode = (zxuno_addr == SCANCODE && zxuno_regrd == 1'b1);
	assign oe_kbstatus = (zxuno_addr == KBSTATUS && zxuno_regrd == 1'b1);

	reg [7:0] code = 8'h00;
	reg ext = 1'b0, rls = 1'b0;            // prefixes seen before the code byte
	reg reading_kbstatus = 1'b0;
	assign scancode_dout = code;

	always @(posedge clk) begin
		if (ps2_wr && !ps2_kind) begin
			if (ps2_code == 8'hE0 || ps2_code == 8'hE1)
				ext <= 1'b1;
			else if (ps2_code == 8'hF0)
				rls <= 1'b1;
			else begin
				code <= ps2_code;
				kbstatus_dout[2:0] <= { rls, ext, 1'b1 };
				ext <= 1'b0;
				rls <= 1'b0;
			end
		end
		else if (oe_kbstatus)
			reading_kbstatus <= 1'b1;
		else if (reading_kbstatus) begin
			kbstatus_dout[0] <= 1'b0;
			reading_kbstatus <= 1'b0;
		end
	end
endmodule
