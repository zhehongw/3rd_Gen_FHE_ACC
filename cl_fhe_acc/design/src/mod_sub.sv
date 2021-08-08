`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/24/2021 03:46:39 PM
// Design Name: 
// Module Name: mod_sub
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "common.vh"
//out = a-b mod q
module mod_sub #(
	
) (
	input 	[`BIT_WIDTH - 1 : 0] a,
	input 	[`BIT_WIDTH - 1 : 0] b,
	input 	[`BIT_WIDTH - 1 : 0] q,
	output 	[`BIT_WIDTH - 1 : 0] out
);

logic [`BIT_WIDTH : 0] s;
logic [`BIT_WIDTH : 0] d;

assign d = a - b;
assign s = d + q;

assign out = d[`BIT_WIDTH] ? s : d;

endmodule 
