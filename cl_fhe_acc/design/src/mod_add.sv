`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/24/2021 03:46:39 PM
// Design Name: 
// Module Name: CT_butterfly
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
//out = a+b mod q
module mod_add #(

) (
	input 	[`BIT_WIDTH - 1 : 0] a,
	input 	[`BIT_WIDTH - 1 : 0] b,
	input 	[`BIT_WIDTH - 1 : 0] q,
	output 	[`BIT_WIDTH - 1 : 0] out
);

logic [`BIT_WIDTH : 0] s;
logic [`BIT_WIDTH : 0] d;

assign s = a + b;
assign d = s - q;

assign out = s[`BIT_WIDTH] | (~d[`BIT_WIDTH]) ? d : s;

endmodule 
