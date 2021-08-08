`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/25/2021 10:25:14 AM
// Design Name: 
// Module Name: RLWE_input_FIFO
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: this is a wrapper module that contains the DMA AXI interface
// and two poly fifo for the input RLWE from sh 
// 
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "common.vh"
module RLWE_input_FIFO #(
	parameter POINTER_WIDTH = 2,
	parameter BUFFER_DEPTH = 2**POINTER_WIDTH
)(
	input clk, rstn,

	config_if.to_top config_ports,
	//axi port for DMA access
	axi_bus_if.to_master DMA_if,

	//read ports to iNTT module
	myFIFO_NTT_sink_if.to_sink iNTT_ports [1 : 0],
	
	//write ports acc module
	myFIFO_NTT_source_if.to_source acc_ports [1 : 0],
	//wr enable from acc module
	input logic [1 : 0] acc_wr_enable,
	//read out data to acc module
	output [`BIT_WIDTH * `LINE_SIZE - 1 : 0] acc_rd_doutA [1 : 0],
	output [`BIT_WIDTH * `LINE_SIZE - 1 : 0] acc_rd_doutB [1 : 0],

	//ports to the top ctrl
	output logic empty, 
	output logic full
);

myFIFO_NTT_source_if DMA_wr_0(), DMA_wr_1(); 
myFIFO_NTT_sink_if	DMA_rd_0(), DMA_rd_1();
logic DMA_wr_enable_0, DMA_wr_enable_1;

logic [1 : 0] fifo_empty;
logic [1 : 0] fifo_full;

assign empty = &fifo_empty;
assign full  = &fifo_full;

DMA_AXI_to_input_poly_FIFO #(.POINTER_WIDTH(POINTER_WIDTH)) DMA_AXI_CONVERSION(
	.clk(clk), 
	.rstn(rstn),

	.config_ports(config_ports),
	//axi port for DMA access
	.DMA_if(DMA_if),

	//write port to the FIFO
    .write_ports_0(DMA_wr_0),   	// for poly a 
    .write_ports_1(DMA_wr_1),   	// for poly b
	.write_enable_0(DMA_wr_enable_0),							//explicit write enable signal 
	.write_enable_1(DMA_wr_enable_1),							//explicit write enable signal 
	
	//read port to the FIFO
	.read_ports_0(DMA_rd_0),
	.read_ports_1(DMA_rd_1)
);

myFIFO_global_poly_input #(.POINTER_WIDTH(POINTER_WIDTH)) RLWE_POLY_A(
	.clk(clk), 
	.rstn(rstn),

	//ports to the top ctrl
	.empty(fifo_empty[0]),
	.full(fifo_full[0]),
	.mode_sel(config_ports.top_fifo_mode), 				//this is to determine the mode of the global input buffer,
									//0 means the bootstrap mode, in which this input global 
									//buffer is used as both source and sink for the internal 
									//computation, so both the AXI and internal logic can 
									//read this FIFO, and only the internal logic will write 
									//the buffer. 
									//1 means the RLWESUBS mode or RLWE mult RGSW mode, in which this input global 
									//buffer is only used as a source for the internal logic, 
									//so AXI write won't conflict with the internal write

	//write ports to the AXI interface
    .outer_wr_ports(DMA_wr_0),    //when reference interface, no need to elaborate parameter, only elaborate when instantiate interface
	.outer_wr_enable(DMA_wr_enable_0),	//explicit write enable port
	
	//read ports to the AXI interface 
	.outer_rd_ports(DMA_rd_0),
	
	//internal write ports
    .internal_wr_ports(acc_ports[0]),    //when reference interface, no need to elaborate parameter, only elaborate when instantiate interface
	.internal_wr_enable(acc_wr_enable[0]),	//explicit write enable port
	.doutA(acc_rd_doutA[0]),	//explicit doutA port for poly MAC loop access, because poly MAC module need to do both read and write 
	.doutB(acc_rd_doutB[0]),

	//internal read ports
	.internal_rd_ports(iNTT_ports[0])
);

myFIFO_global_poly_input #(.POINTER_WIDTH(POINTER_WIDTH)) RLWE_POLY_B(
	.clk(clk), 
	.rstn(rstn),

	//ports to the top ctrl
	.empty(fifo_empty[1]),
	.full(fifo_full[1]),
	.mode_sel(config_ports.top_fifo_mode), 				//this is to determine the mode of the global input buffer,
									//0 means the bootstrap mode, in which this input global 
									//buffer is used as both source and sink for the internal 
									//computation, so both the AXI and internal logic can 
									//read this FIFO, and only the internal logic will write 
									//the buffer. 
									//1 means the RLWESUBS mode or RLWE mult RGSW mode, in which this input global 
									//buffer is only used as a source for the internal logic, 
									//so AXI write won't conflict with the internal write

	//write ports to the AXI interface
    .outer_wr_ports(DMA_wr_1),    //when reference interface, no need to elaborate parameter, only elaborate when instantiate interface
	.outer_wr_enable(DMA_wr_enable_1),	//explicit write enable port
	
	//read ports to the AXI interface 
	.outer_rd_ports(DMA_rd_1),
	
	//internal write ports
    .internal_wr_ports(acc_ports[1]),    //when reference interface, no need to elaborate parameter, only elaborate when instantiate interface
	.internal_wr_enable(acc_wr_enable[1]),	//explicit write enable port
	.doutA(acc_rd_doutA[1]),	//explicit doutA port for poly MAC loop access, because poly MAC module need to do both read and write 
	.doutB(acc_rd_doutB[1]),

	//internal read ports
	.internal_rd_ports(iNTT_ports[1])
);

endmodule
