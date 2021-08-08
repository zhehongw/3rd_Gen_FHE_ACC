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
// Description:  in total 11 stage pipelined, including the 9 stages in the
// mult
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

//a -> ff		   -> ff -> a + b*ROU -> outa
//b -> ff -> b*ROU -> ff -> a - b*ROU -> outb
//      		^
//      		|
//ROU -> ff	-> ROU

`include "common.vh"
module CT_butterfly #(

)(
    input   clk,
	input 	[`BIT_WIDTH - 1 : 0] a,
	input 	[`BIT_WIDTH - 1 : 0] b,
	input 	[`BIT_WIDTH - 1 : 0] ROU_entry,
	input 	[`BIT_WIDTH - 1 : 0] q,
	input 	[`BIT_WIDTH : 0] 	m,
	input 	[6 : 0] 			k2,
	
	output logic 	[`BIT_WIDTH - 1 : 0] outa,
	output logic 	[`BIT_WIDTH - 1 : 0] outb
    );

(* shreg_extract = "no" *) logic 	[`BIT_WIDTH - 1 : 0] prod, prod_q;
(* shreg_extract = "no" *) logic 	[`BIT_WIDTH - 1 : 0] a_q1, a_q2, a_q3, a_q4, a_q5, a_q6, a_q7, a_q8, a_q9, a_q10, a_q11;
(* shreg_extract = "no" *) logic 	[`BIT_WIDTH - 1 : 0] b_q1;
(* shreg_extract = "no" *) logic 	[`BIT_WIDTH - 1 : 0] ROU_q1;

always_ff @(posedge clk) begin
	a_q1 	<= `SD a;
	b_q1 	<= `SD b;
	ROU_q1 	<= `SD ROU_entry;

	a_q2 	<= `SD a_q1;
	a_q3 	<= `SD a_q2;
	a_q4 	<= `SD a_q3;
	a_q5 	<= `SD a_q4;
	a_q6 	<= `SD a_q5;
	a_q7 	<= `SD a_q6;
	a_q8 	<= `SD a_q7;
	a_q9 	<= `SD a_q8;
	a_q10 	<= `SD a_q9;
	a_q11 	<= `SD a_q10;
	prod_q 	<= `SD prod;
end

//get V = b * ROU_entry
mod_mult #(.MAX_BIT_WIDTH(`BIT_WIDTH)) mult(
	.clk(clk),
	.a(b_q1),
	.b(ROU_q1),
	.q(q),
	.m(m),
	.k2(k2),
	.out(prod)
);

//outa = a + V 
mod_add add(
	.a(a_q11),
	.b(prod_q),
	.q(q),
	.out(outa)
);
//outb = a - V
mod_sub sub(
	.a(a_q11),
	.b(prod_q),
	.q(q),
	.out(outb)
);

endmodule
