// karabas: the Kempston mouse of ZX-Uno (ports FBDF / FFDF / FADF) fed by kg_cursor of the USB mouse, in place
// of ps2_mouse_kempston.v (PS/2 port + ps2mouse_to_kmouse). Same port decode and button layout as the
// original: buttons = { 5'b11111, ~middle, ~left, ~right }.
// MOUSEDATA / MOUSESTATUS (09 / 0A, the raw PS/2 bytes of the mouse) are not there (oe 0).
module zxuno_kmouse (
	input wire [15:0] a,
	input wire iorq_n,
	input wire rd_n,
	input wire [7:0] x,              // kg_cursor x / y
	input wire [7:0] y,
	input wire [2:0] b,              // USB buttons: 0 left, 1 right, 2 middle
	output reg [7:0] kmouse_dout,
	output reg oe_kmouse
);
	wire kmouse_x_req    = (!iorq_n && !rd_n && a[7:0]==8'hDF && a[8]==1'b1 && a[9]==1'b1 && a[10]==1'b0 && a[11]==1'b1);
	wire kmouse_y_req    = (!iorq_n && !rd_n && a[7:0]==8'hDF && a[8]==1'b1 && a[9]==1'b1 && a[10]==1'b1 && a[11]==1'b1);
	wire kmouse_butt_req = (!iorq_n && !rd_n && a[7:0]==8'hDF && a[8]==1'b0 && a[9]==1'b1 && a[10]==1'b0 && a[11]==1'b1);

	always @* begin
		oe_kmouse = (kmouse_x_req | kmouse_y_req | kmouse_butt_req);
		case (1'b1)
			kmouse_x_req    : kmouse_dout = x;
			kmouse_y_req    : kmouse_dout = y;
			kmouse_butt_req : kmouse_dout = { 5'b11111, ~b[2], ~b[0], ~b[1] };
			default         : kmouse_dout = 8'hFF;
		endcase
	end
endmodule
