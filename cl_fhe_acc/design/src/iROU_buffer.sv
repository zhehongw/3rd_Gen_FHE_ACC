`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/24/2021 08:50:59 PM
// Design Name: 
// Module Name: iROU_buffer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: with byte_enable and output reg
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "common.vh"
module iROU_buffer #(
	parameter STAGES = $clog2(`MAX_LEN),
	parameter COL_WIDTH = `BIT_WIDTH / 2
)( 
    input 	clk, 
    ROU_config_if.to_axil_bar1 wr_port,	//reuse the interface for ROU program
	input 	en,	
	input 	[`ADDR_WIDTH - 1 : 0]				addr_rd,
	output 	logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] 	iROU_line
);

logic 	[`BIT_WIDTH * `LINE_SIZE - 1 : 0] iROU_line_reg;
logic   [`BIT_WIDTH * `LINE_SIZE - 1 : 0] ram [0 : 2**(`ADDR_WIDTH) - 1];

integer i;
always_ff @(posedge clk) begin
	for(i = 0; i < `LINE_SIZE * 2; i++) begin
		if(wr_port.we[i])
			ram[wr_port.addr][i * COL_WIDTH +: COL_WIDTH] <= `SD wr_port.din;
	end
	iROU_line_reg <= `SD ram[addr_rd];
end
always_ff @(posedge clk) begin
	if(en) begin
		iROU_line <= `SD iROU_line_reg;	
	end
end
endmodule
