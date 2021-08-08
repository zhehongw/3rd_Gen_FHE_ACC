`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/24/2021 03:46:39 PM
// Design Name: 
// Module Name: GS_butterfly
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: in total 11 stages pipelined, including the 9 stages in the
// mult
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

//a -> a + b -> ff ->              ff -> outa 
//b -> a - b -> ff -> (a-b)*ROU	-> ff -> outb
//      				^
//      				|
//ROU        ->	ff ->  ROU_q

`include "common.vh"
module GS_butterfly #(

)(
	input 	clk,
	input 	[`BIT_WIDTH - 1 : 0] 	a,
	input 	[`BIT_WIDTH - 1 : 0] 	b,
	input 	[`BIT_WIDTH - 1 : 0] 	ROU_entry,
	input 	[`BIT_WIDTH - 1 : 0] 	q,
	input 	[`BIT_WIDTH : 0] 		m,
	input 	[6 : 0] 				k2,
	
	output logic [`BIT_WIDTH - 1 : 0] outa,
	output logic [`BIT_WIDTH - 1 : 0] outb
    );

(*shreg_extract="no"*) logic 	[`BIT_WIDTH - 1 : 0] prod;
(*shreg_extract="no"*) logic 	[`BIT_WIDTH - 1 : 0] sum, sum_q1, sum_q2, sum_q3, sum_q4, sum_q5, sum_q6, sum_q7, sum_q8, sum_q9, sum_q10; 
(*shreg_extract="no"*) logic 	[`BIT_WIDTH - 1 : 0] diff, diff_q;
(*shreg_extract="no"*) logic 	[`BIT_WIDTH - 1 : 0] ROU_q;

always_ff @(posedge clk) begin
	ROU_q  	<= `SD ROU_entry;
    diff_q 	<= `SD diff;
	sum_q1 	<= `SD sum;
	sum_q2 	<= `SD sum_q1;
	sum_q3 	<= `SD sum_q2;
	sum_q4 	<= `SD sum_q3;
	sum_q5 	<= `SD sum_q4;
	sum_q6 	<= `SD sum_q5;
	sum_q7 	<= `SD sum_q6;
	sum_q8 	<= `SD sum_q7;
	sum_q9 	<= `SD sum_q8;
	sum_q10 <= `SD sum_q9;
	outa 	<= `SD sum_q10;
	outb 	<= `SD prod;
end

//get outb = V * ROU_entry, 3 stage pipelined 
mod_mult #(.MAX_BIT_WIDTH(`BIT_WIDTH)) mult(
	.clk(clk),
	.a(diff_q),
	.b(ROU_q),
	.q(q),
	.m(m),
	.k2(k2),
	.out(prod)
);

//outa = a + b
mod_add add(
	.a(a),
	.b(b),
	.q(q),
	.out(sum)
);
//V = a - b
mod_sub sub(
	.a(a),
	.b(b),
	.q(q),
	.out(diff)
);
    
endmodule
