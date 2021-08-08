`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/24/2021 08:50:59 PM
// Design Name: 
// Module Name: poly_ram_block
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: with output reg
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "common.vh"
module poly_ram_block#(

)( 
    input 									clk, 
	input 									weA,
	input 									weB,
    input   [`ADDR_WIDTH - 1 : 0]    		addrA,
    input   [`ADDR_WIDTH - 1 : 0]    		addrB,
    input   [`BIT_WIDTH * `LINE_SIZE - 1 : 0] dinA,
    input   [`BIT_WIDTH * `LINE_SIZE - 1 : 0] dinB,
	input 									enA,
	input 									enB,

    output logic 	[`BIT_WIDTH * `LINE_SIZE - 1 : 0] doutA,
    output logic   	[`BIT_WIDTH * `LINE_SIZE - 1 : 0] doutB
    );
    
logic 	[`BIT_WIDTH * `LINE_SIZE - 1 : 0] dout_regA;
logic  	[`BIT_WIDTH * `LINE_SIZE - 1 : 0] dout_regB;
logic   [`BIT_WIDTH * `LINE_SIZE - 1 : 0] ram [0 : 2**`ADDR_WIDTH - 1];

always_ff @(posedge clk) begin
	if(weA)
	   ram[addrA] <= `SD dinA;
	dout_regA <= `SD ram[addrA];
end

//output reg
always_ff @(posedge clk) begin
	if(enA) begin
		doutA <= `SD dout_regA;
	end
end

always_ff @(posedge clk) begin
	   if(weB)
		  ram[addrB] <= `SD dinB;
	   dout_regB <= `SD ram[addrB];
end
//output reg
always_ff @(posedge clk) begin
	if(enB) begin
		doutB <= `SD dout_regB;
	end
end

endmodule
