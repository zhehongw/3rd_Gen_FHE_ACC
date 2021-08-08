`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2021 03:28:24 PM
// Design Name: 
// Module Name: acc_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: wrapper for accumulator and poly_mult_RLWE
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "common.vh"
module acc_top #(

)(
	input clk, rstn,
	//to preceding NTT FIFO
	myFIFO_NTT_sink_if.to_FIFO NTT_FIFO,
	//to global RLWE buffer
	myFIFO_NTT_source_if.to_FIFO out_to_next_stage [1 : 0],
	
	//output_wr_enable to global RLWE buffer, 0 for poly a, 1 for poly b
	output logic [1 : 0] output_wr_enable,
	//data read from the global RLWE buffer
	input [`BIT_WIDTH * `LINE_SIZE - 1 : 0] outram_doutA [1 : 0],
	input [`BIT_WIDTH * `LINE_SIZE - 1 : 0] outram_doutB [1 : 0],

	//to offchip loading key FIFO
	myFIFO_NTT_sink_if.to_FIFO key_FIFO [1 : 0],
	//config ports
	config_if.to_top config_ports

);

myFIFO_NTT_sink_if mult_FIFO [1 : 0] ();

poly_mult_RLWE mult_module(
	.clk(clk),
	.rstn(rstn),
	.NTT_FIFO(NTT_FIFO),
	.out_to_next_stage(mult_FIFO),
	.key_FIFO(key_FIFO),
	.config_ports(config_ports)
);

accumulator acc(
	.clk(clk),
	.rstn(rstn),
	.mult_FIFO(mult_FIFO),
	.out_to_next_stage(out_to_next_stage),
	.output_wr_enable(output_wr_enable),
	.outram_doutA(outram_doutA),
	.outram_doutB(outram_doutB),
	.config_ports(config_ports)
);

endmodule
