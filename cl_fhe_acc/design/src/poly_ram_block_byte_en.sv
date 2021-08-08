`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/24/2021 08:50:59 PM
// Design Name: 
// Module Name: poly_ram_block_byte_en
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: this ram block has byte enable feature, and optional output
// 				reg for better timing 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "common.vh"
module poly_ram_block_byte_en #(

)( 
    input 									clk, 
	input 	[`LINE_SIZE - 1 : 0]			weA,
	input 	[`LINE_SIZE - 1 : 0]			weB,
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

//integer i;

always_ff @(posedge clk) begin
	for(integer i = 0; i < `LINE_SIZE; i++) begin
   		if(weA[i])
	  		ram[addrA][i * `BIT_WIDTH +: `BIT_WIDTH] <= `SD dinA[i * `BIT_WIDTH +: `BIT_WIDTH];
	end
	dout_regA <= `SD ram[addrA];
end
//output reg for better timing 
always_ff @(posedge clk) begin
	if(enA) begin
		doutA <= `SD dout_regA;
	end
end

always_ff @(posedge clk) begin
	for(integer i = 0; i < `LINE_SIZE; i++) begin
		if(weB[i])
	  		ram[addrB][i * `BIT_WIDTH +: `BIT_WIDTH] <= `SD dinB[i * `BIT_WIDTH +: `BIT_WIDTH];
	end
	dout_regB <= `SD ram[addrB];
end
//output reg for better timing 
always_ff @(posedge clk) begin
	if(enB) begin
		doutB <= `SD dout_regB;
	end
end

endmodule
