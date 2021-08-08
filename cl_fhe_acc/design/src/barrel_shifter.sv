`timescale 1ns / 1ps
//module shifter #(
//	parameter BIT_WIDTH = 54 * 2
//) (
//	input 	[5 : 0] k,	// amount to be shifted
//	input 	[BIT_WIDTH - 1 : 0] in,
//	output 	[BIT_WIDTH - 1 : 0] out
//);

//logic [BIT_WIDTH - 1 : 0] s [0 : 6];

//assign s[0] = in;

//generate
//	genvar i;
//	for(i = 0; i < 6; i++)begin
//		assign s[i + 1] = k[i] ? s[i] >> (2**i) : s[i];
//	end
//endgenerate

//assign out = s[6];

//endmodule

`include "common.vh"
module shifter #(
	parameter BIT_WIDTH = 54 * 2
) (
	input 	[6 : 0] k, 	// amount to be shifted
	input 	[BIT_WIDTH - 1 : 0] in,
	output 	[BIT_WIDTH - 1 : 0] out
);
//this is synthesizable

assign out = in >> k;

endmodule