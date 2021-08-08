`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/24/2021 08:50:59 PM
// Design Name: 
// Module Name: ROU_buffer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description:  with output reg
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "common.vh"
module ROU_buffer #(
	parameter STAGE_NUM = 10,
	parameter NTT_STEP = 2**STAGE_NUM,
	parameter STEP = NTT_STEP / `LINE_SIZE,
	parameter COL_NUM = STEP > 0 ? 1 : `LINE_SIZE / NTT_STEP,
	parameter COL_WIDTH = `BIT_WIDTH / 2,
	parameter ADDR_WIDTH = $clog2(`MAX_LEN) - STAGE_NUM - $clog2(COL_NUM)
)( 
    input 	clk, 
    ROU_config_if.to_axil_bar1 wr_port,
	ROU_table_if.to_logic rd_port	//read interface for NTT_stage
);

logic   [`BIT_WIDTH * COL_NUM - 1 : 0] ram [0 : 2**(ADDR_WIDTH - 1) - 1];
logic   [`BIT_WIDTH * COL_NUM - 1 : 0] rd_out_reg;

logic 	[ADDR_WIDTH - 1 : 0]	addr_wr;
logic   [COL_NUM * 2 - 1 : 0]   we;

assign addr_wr = wr_port.addr[ADDR_WIDTH - 1 : 0];
assign we = wr_port.we[COL_NUM * 2 - 1 : 0];

integer i;
always_ff @(posedge clk) begin
	for(i = 0; i < COL_NUM * 2; i++) begin
		if(we[i])
			ram[addr_wr][i * COL_WIDTH +: COL_WIDTH] <= `SD wr_port.din;
	end
	rd_out_reg <= `SD ram[rd_port.addr];
end
//output reg
always_ff @(posedge clk) begin
	if(rd_port.en) begin
		rd_port.ROU_entry <= `SD rd_out_reg;
	end
end
endmodule
