`timescale 1ns / 1ps
`include "common.vh" 
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/24/2021 03:46:39 PM
// Design Name: 
// Module Name: mod_mult
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: a 9-stage pipelined mod mult
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

//out = a*b mod q
//This one got more CLB but less DSP, and there are some more complication on the size of k
//module mod_mult #(
//	parameter MAX_BIT_WIDTH = 54
//) (
//	input 	[MAX_BIT_WIDTH - 1 : 0] a,		//input 1
//	input 	[MAX_BIT_WIDTH - 1 : 0] b,		//input 2
//	input 	[MAX_BIT_WIDTH - 1 : 0] q,		// modulo
//	input 	[MAX_BIT_WIDTH : 0] 	m,		// precomputed
//	input 	[5 : 0] 				k_p1,	// precomputed 1 + bit width of the modulo, supplied by shell 
//	input 	[5 : 0] 				k_m1,	// precomputed 1 + bit width of the modulo, supplied by shell
	
//	input 	[MAX_BIT_WIDTH: 0]	mod_mask, //precomputed, used to do mod 2^(k+1), it equals to 2^(k+1)-1, supplied by shell

//	output 	logic [MAX_BIT_WIDTH - 1 : 0] out
//);

//logic [2 * MAX_BIT_WIDTH - 1 : 0] 	prod;
//logic [2 * MAX_BIT_WIDTH - 1 : 0] 	q1;		//first quotient
//logic [2 * MAX_BIT_WIDTH + 1 : 0] 	q2;		//second quotient
//logic [2 * MAX_BIT_WIDTH + 1 : 0] 	q3;		//third quotient
//logic [2 * MAX_BIT_WIDTH : 0] 		partial;//partial product quotient * modulo

//logic [MAX_BIT_WIDTH : 0] r1, r2;
//logic [MAX_BIT_WIDTH + 1: 0] d;
//logic [MAX_BIT_WIDTH : 0] r;

//assign prod = a * b;	// get initial product

//shifter #(.BIT_WIDTH(2 * MAX_BIT_WIDTH)) bs1 (.k(k_m1), .in(prod), .out(q1));	//q1 = prod >> (k-1)

//assign q2 = q1[MAX_BIT_WIDTH : 0] * m; //q2 = q1 * m

//shifter #(.BIT_WIDTH(2 * MAX_BIT_WIDTH + 2)) bs2 (.k(k_p1), .in(q2), .out(q3)); //q3 = q2 >> (k+1)

//assign partial = q3[MAX_BIT_WIDTH : 0] * q;	//partial = q3 * q

////assign r1 = prod[MAX_BIT_WIDTH : 0] & mod_mask;	//r1 = prod mod 2^(k+1)
////assign r2 = partial[MAX_BIT_WIDTH : 0] & mod_mask; // r3 = partial mod 2(k+1)
//assign r1 = prod[MAX_BIT_WIDTH : 0];	//r1 = prod mod 2^(k+1)
//assign r2 = partial[MAX_BIT_WIDTH : 0]; // r3 = partial mod 2(k+1)

//assign d = r1 - r2;	// get the difference of the two 

////assign r = d[MAX_BIT_WIDTH + 1] ? d + mod_mask + 1 : d;	// if r < 0, r=r+2^(k+1)
//assign r = d[MAX_BIT_WIDTH : 0] & mod_mask;	// if r < 0, r=r+2^(k+1)

//assign out = r >= (q << 1) ? r - (q << 1) : r >= q ? r - q : r;	//continuouly subtract q

//always_comb
//assert(out < q) //$display("OK, output is less than Q.");
//    else $error("ERROR, output is greater than Q!!");

//endmodule 


//this one has more DSP but less CLB
`include "common.vh"
module mod_mult #(
	parameter MAX_BIT_WIDTH = 54
) (
	input clk,
	input 	[MAX_BIT_WIDTH - 1 : 0] a,		//input 1
	input 	[MAX_BIT_WIDTH - 1 : 0] b,		//input 2
	input 	[MAX_BIT_WIDTH - 1 : 0] q,		// modulo
	input 	[MAX_BIT_WIDTH : 0] 	m,		// precomputed
	//input 	[5 : 0] 				k_p1,	// precomputed 1 + bit width of the modulo, supplied by shell 
	//input 	[5 : 0] 				k_m1,	// precomputed 1 + bit width of the modulo, supplied by shell
	input   [6 : 0]                 k2,		//k*2
	//input 	[MAX_BIT_WIDTH: 0]	mod_mask, //precomputed, used to do mod 2^(k+1), it equals to 2^(k+1)-1, supplied by shell

	output 	logic [MAX_BIT_WIDTH - 1 : 0] out
);

//(* dont_touch = "yes" *) logic [2 * MAX_BIT_WIDTH - 1 : 0] 	prod, prod_q1, prod_q2, prod_q3, prod_q4, prod_q5, prod_q6;
//(* dont_touch = "yes" *) logic [MAX_BIT_WIDTH + MAX_BIT_WIDTH/2 + 1 - 1 : 0] 	    q1_hi_hi;		//first quotient
//(* dont_touch = "yes" *) logic [MAX_BIT_WIDTH + MAX_BIT_WIDTH/2 + 1 - 1 : 0] 	    q1_hi_lo;		//first quotient
//(* dont_touch = "yes" *) logic [2 * MAX_BIT_WIDTH + MAX_BIT_WIDTH/2 + 1 - 1: 0] 	    q1_hi;		//first quotient
//
//(* dont_touch = "yes" *) logic [MAX_BIT_WIDTH + MAX_BIT_WIDTH/2 - 1: 0] 	    q1_lo_hi;		//first quotient
//(* dont_touch = "yes" *) logic [MAX_BIT_WIDTH + MAX_BIT_WIDTH/2 - 1: 0] 	    q1_lo_lo;		//first quotient
//(* dont_touch = "yes" *) logic [2 * MAX_BIT_WIDTH + MAX_BIT_WIDTH/2 + 1 - 1 : 0] 	    q1_lo;		//first quotient
//
//(* dont_touch = "yes" *) logic [3 * MAX_BIT_WIDTH : 0] 	    q1;		//first quotient
//(* dont_touch = "yes" *) logic [MAX_BIT_WIDTH : 0] 	        q2;		//second quotient
//(* dont_touch = "yes" *) logic [2 * MAX_BIT_WIDTH : 0] 		partial;//partial product quotient * modulo
//(* dont_touch = "yes" *) logic [MAX_BIT_WIDTH + MAX_BIT_WIDTH/2 + 1 - 1: 0] 		partial_hi;//partial product quotient * modulo
//(* dont_touch = "yes" *) logic [MAX_BIT_WIDTH + MAX_BIT_WIDTH/2 + 1 - 1: 0] 		partial_lo;//partial product quotient * modulo
//
//(* dont_touch = "yes" *)logic [MAX_BIT_WIDTH + 1 : 0] d, d_q;

(* shreg_extract = "no" *) logic [2 * MAX_BIT_WIDTH - 1 : 0] 	prod, prod_q1, prod_q2, prod_q3, prod_q4, prod_q5, prod_q6;
(* shreg_extract = "no" *) logic [MAX_BIT_WIDTH + MAX_BIT_WIDTH/2 + 1 - 1 : 0] 	    q1_hi_hi;		//first quotient
(* shreg_extract = "no" *) logic [MAX_BIT_WIDTH + MAX_BIT_WIDTH/2 + 1 - 1 : 0] 	    q1_hi_lo;		//first quotient
(* shreg_extract = "no" *) logic [2 * MAX_BIT_WIDTH + MAX_BIT_WIDTH/2 + 1 - 1: 0] 	    q1_hi;		//first quotient

(* shreg_extract = "no" *) logic [MAX_BIT_WIDTH + MAX_BIT_WIDTH/2 - 1: 0] 	    q1_lo_hi;		//first quotient
(* shreg_extract = "no" *) logic [MAX_BIT_WIDTH + MAX_BIT_WIDTH/2 - 1: 0] 	    q1_lo_lo;		//first quotient
(* shreg_extract = "no" *) logic [2 * MAX_BIT_WIDTH + MAX_BIT_WIDTH/2 + 1 - 1 : 0] 	    q1_lo;		//first quotient

(* shreg_extract = "no" *) logic [3 * MAX_BIT_WIDTH : 0] 	    q1;		//first quotient
(* shreg_extract = "no" *) logic [MAX_BIT_WIDTH : 0] 	        q2;		//second quotient
(* shreg_extract = "no" *) logic [2 * MAX_BIT_WIDTH : 0] 		partial;//partial product quotient * modulo
(* shreg_extract = "no" *) logic [MAX_BIT_WIDTH + MAX_BIT_WIDTH/2 + 1 - 1: 0] 		partial_hi;//partial product quotient * modulo
(* shreg_extract = "no" *) logic [MAX_BIT_WIDTH + MAX_BIT_WIDTH/2 + 1 - 1: 0] 		partial_lo;//partial product quotient * modulo

(* shreg_extract = "no" *)logic [MAX_BIT_WIDTH + 1 : 0] d, d_q;

logic [MAX_BIT_WIDTH + 1 : 0] d_min_q; //d - q
logic d_ge_q;    // d >= q

always_ff @(posedge clk) begin
	prod 	<= `SD a * b;
	prod_q1 <= `SD prod;
	prod_q2 <= `SD prod_q1;
	prod_q3 <= `SD prod_q2;
	prod_q4 <= `SD prod_q3;
	prod_q5 <= `SD prod_q4;
	prod_q6 <= `SD prod_q5;
	
//	q1 		<= `SD prod * m;
//	q2      <= `SD q1_shifted[MAX_BIT_WIDTH : 0];
	q1_hi_hi <= `SD prod[MAX_BIT_WIDTH +: MAX_BIT_WIDTH] * m[MAX_BIT_WIDTH : MAX_BIT_WIDTH/2];
	q1_hi_lo <= `SD prod[0 +: MAX_BIT_WIDTH] * m[MAX_BIT_WIDTH : MAX_BIT_WIDTH/2];
	q1_lo_hi <= `SD prod[MAX_BIT_WIDTH +: MAX_BIT_WIDTH] * m[MAX_BIT_WIDTH/2 - 1 : 0];
	q1_lo_lo <= `SD prod[0 +: MAX_BIT_WIDTH] * m[MAX_BIT_WIDTH/2 - 1 : 0];
	
	
	q1_hi 	<= `SD {q1_hi_hi + {{MAX_BIT_WIDTH{1'b0}}, q1_hi_lo[MAX_BIT_WIDTH +: (MAX_BIT_WIDTH/2 + 1)]}, q1_hi_lo[MAX_BIT_WIDTH - 1 : 0]};
	q1_lo 	<= `SD {{1'b0, q1_lo_hi} + {{(MAX_BIT_WIDTH/2 + 1){1'b0}}, q1_lo_lo[MAX_BIT_WIDTH +: MAX_BIT_WIDTH/2]}, q1_lo_lo[MAX_BIT_WIDTH - 1 : 0]};
	
	q1 		<= `SD {q1_hi + q1_lo[MAX_BIT_WIDTH/2 +: (2 * MAX_BIT_WIDTH + 1)], q1_lo[MAX_BIT_WIDTH/2 - 1 : 0]};
	
	case(k2)
		108: 	q2 	<= `SD {{(MAX_BIT_WIDTH + 1 - 55){1'b0}}, q1[108 +: 55]};
		54:		q2 	<= `SD {{(MAX_BIT_WIDTH + 1 - 28){1'b0}}, q1[54 +: 28]};
		58:		q2 	<= `SD {{(MAX_BIT_WIDTH + 1 - 28){1'b0}}, q1[58 +: 30]};
		70:		q2 	<= `SD {{(MAX_BIT_WIDTH + 1 - 28){1'b0}}, q1[70 +: 36]};
		74:		q2 	<= `SD {{(MAX_BIT_WIDTH + 1 - 28){1'b0}}, q1[74 +: 38]};
		100:	q2 	<= `SD {{(MAX_BIT_WIDTH + 1 - 28){1'b0}}, q1[100 +: 51]};
		default: q2 <= `SD 0;
	endcase

	partial_hi <= `SD q2 * q[MAX_BIT_WIDTH/2 +: MAX_BIT_WIDTH/2];
	partial_lo <= `SD q2 * q[0 +: MAX_BIT_WIDTH/2];

	partial <= `SD {partial_hi + partial_lo[MAX_BIT_WIDTH/2 +: (MAX_BIT_WIDTH + 1)], partial_lo[MAX_BIT_WIDTH/2 - 1 : 0]};

	d		<= `SD {1'b0, prod_q6} - partial;
	d_min_q <= `SD d - q;
	d_ge_q  <= `SD (d >= q);
	d_q     <= `SD d;
end


//assign prod = a * b;	// get initial product

//assign q1 = prod * m;

//shifter #(.BIT_WIDTH(3 * MAX_BIT_WIDTH + 1)) bs1 (.k(k2), .in(q1), .out(q1_shifted));	//q2 = q1 >> (k*2)

//assign partial = q2[MAX_BIT_WIDTH : 0] * q; //partial = q2 * q

//assign d = {1'b0, prod_q3} - partial; // prod - q2 * q, this must be positive, since q2 * q < prod

//assign out = d >= q ? d - q : d;	//continuouly subtract q

assign out = d_ge_q ? d_min_q : d_q;	//continuouly subtract q
//always_comb
//assert(out < q) //$display("OK, output is less than Q.");
//    else $error("ERROR, output is greater than Q!! out = %h, q = %h", out, q);

endmodule 
