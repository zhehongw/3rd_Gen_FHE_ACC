`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2021 04:11:40 PM
// Design Name: 
// Module Name: interface_defines
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
interface myFIFO_NTT_source_if #(
)();
//FIFO interface between source and the FIFO
    logic 	[`ADDR_WIDTH - 1 : 0] 		addrA;
	logic 	[`ADDR_WIDTH - 1 : 0] 		addrB;
	logic 	[`BIT_WIDTH * `LINE_SIZE - 1 : 0] 	dA;
	logic 	[`BIT_WIDTH * `LINE_SIZE - 1 : 0] 	dB;
	logic 								wr_finish;   //used to indicate that the source finishes writing, low writing, high finishes
	logic						        full;
	logic 	[`RLWE_ID_WIDTH - 1 : 0]	rlwe_id;	
	logic 	[`POLY_ID_WIDTH - 1 : 0]	poly_id;
	logic 	[`OPCODE_WIDTH - 1 : 0]		opcode;

	modport to_source (input addrA, addrB, dA, dB, wr_finish, 
						output full, input rlwe_id, poly_id, opcode);
	modport to_FIFO (output addrA, addrB, dA, dB, wr_finish, 
						input full, output rlwe_id, poly_id, opcode);
endinterface

interface myFIFO_NTT_sink_if #(
)();
//FIFO interface between sink and the FIFO
    logic 	[`ADDR_WIDTH - 1 : 0] 		addrA;
	logic 	[`ADDR_WIDTH - 1 : 0] 		addrB;
	logic 	[`BIT_WIDTH * `LINE_SIZE - 1 : 0] 	dA;
	logic 	[`BIT_WIDTH * `LINE_SIZE - 1 : 0] 	dB;
	logic 								rd_finish;   //used to indicate that the source finishes writing, low writing, high finishes
	logic						        empty;
	logic 	[`RLWE_ID_WIDTH - 1 : 0]	rlwe_id;	
	logic 	[`POLY_ID_WIDTH - 1 : 0]	poly_id;
	logic 	[`OPCODE_WIDTH - 1 : 0]		opcode;
	modport to_sink (input addrA, addrB, output dA, dB, 
						input rd_finish, output empty, rlwe_id, poly_id, opcode);
	modport to_FIFO (output addrA, addrB, input dA, dB, 
						output rd_finish, input empty, rlwe_id, poly_id, opcode);
endinterface

//interface for config the logic
interface config_if #(
)();
//interface for the configuration parameters
	//RLWE related ports
	logic 	[`BIT_WIDTH - 1 : 0] 	q;			//RLWE modulo
	logic 	[`BIT_WIDTH : 0] 		m;			//barrett reduction precompute for q
	logic 	[6 : 0] 				k2; 		//barrett reduction precompute k * 2
	logic 	[11 : 0]				length; 	// length of RLWE sequence
	logic 	[`BIT_WIDTH - 1 : 0]	ilength; 	// multiplicative inverse of length over RLWE module
	logic 	[3 : 0]					log2_len; 	//log2(length)
	logic 	[`BIT_WIDTH - 1 : 0]	BG_mask;	//to mask the number for BG decompse
	logic 	[5 : 0]					digitG;		//logBG(Q), defines the number of decomposed polynomial
	logic 	[4 : 0]					BG_width; 	// width of BG mask, used to shift the mask 
	//LWE related ports
	logic 	[`LWE_BIT_WIDTH - 1 : 0]  	lwe_q_mask; 	// LWE modulo, in mask form. if q is 512, then lwe_q_mask = 511
	logic 	[3 : 0]					embed_factor; 	// this is embed_factor used in the acc init process, it only support 4 or 8, so at most 4 bits, embed_factor = 2 * N / lwe_q
	//input output RLWE FIFO mode selection
	logic 	top_fifo_mode;							//this is used to mux the top fifo input output interface

	//the following are the gate bound1 for the bootstrap init process, the
	//bound2 is calculated from them
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	or_bound1;		//OR gate
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	and_bound1;		//AND gate
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	nor_bound1;		//NOR gate
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	nand_bound1;	//NAND gate
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	xor_bound1;		//XOR gate
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	xnor_bound1;	//XNOR gate

	//the following are the gate bound2 for the bootstrap init process, the
	//bound2 is calculated from bound1 + lwe_q/2
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	or_bound2;		//OR gate
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	and_bound2;		//AND gate
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	nor_bound2;		//NOR gate
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	nand_bound2;	//NAND gate
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	xor_bound2;		//XOR gate
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	xnor_bound2;	//XNOR gate

	modport to_block (output q, m, k2, length, ilength, log2_len, BG_mask, 
					digitG, BG_width, lwe_q_mask, embed_factor, top_fifo_mode, 
					or_bound1, and_bound1, nor_bound1, nand_bound1, xor_bound1, 
					xnor_bound1, or_bound2, and_bound2, nor_bound2, nand_bound2, 
					xor_bound2, xnor_bound2);
	modport to_top (input q, m, k2, length, ilength, log2_len, BG_mask, 
					digitG, BG_width, lwe_q_mask, embed_factor, top_fifo_mode,
					or_bound1, and_bound1, nor_bound1, nand_bound1, xor_bound1, 
					xnor_bound1, or_bound2, and_bound2, nor_bound2, nand_bound2, 
					xor_bound2, xnor_bound2);
endinterface

//interface for config the ROU table from AXI-L BAR1 slave connected to SH
interface ROU_config_if #(
	parameter COL_WIDTH = `BIT_WIDTH / 2 
)();

	logic 	[`LINE_SIZE * 2 - 1 : 0]		we;	
	logic   [`ADDR_WIDTH - 1 : 0]    		addr;
    logic   [COL_WIDTH - 1 : 0] 		    din;	//the write port is from sh AXI-L BAR1 port, map to the 2MB register address space, so the bit width is always `LINE_SIZE/2=27 bits, needs to split a 54 bit number into two 27 bits in software when program the ROU table
    
    modport to_axil_bar1 (input we, addr, din);
    modport to_ROU_table (output we, addr, din);
endinterface

//interface for reading the ROU table from NTT stage
interface ROU_table_if #( 
	parameter STAGE_NUM = 10,
	parameter NTT_STEP = 2**STAGE_NUM,
    parameter STEP = NTT_STEP / `LINE_SIZE,
	parameter COL_NUM = STEP > 0 ? 1 : `LINE_SIZE / NTT_STEP, //defines how many ROU entry in each ROU buffer line, for STEP > 0, only one entry in each line, otherwise, multiple entry for each line
	parameter ADDR_WIDTH = $clog2(`MAX_LEN) - STAGE_NUM
)();
//interface between the NTT computation stage and ROU table of each stage

	logic 	[`BIT_WIDTH * COL_NUM - 1 : 0]	ROU_entry;

	logic 	[ADDR_WIDTH - 1 : 0]			addr;
	logic 									en;	//memory read en

	modport to_logic (output ROU_entry, input addr, en);
	modport to_ROU_table (input ROU_entry, output addr, en);
endinterface

interface axi_bus_if #(
)(
);
//axi interface
	logic[15:0] awid;
	logic[63:0] awaddr;
	logic[7:0] awlen;
	logic [2:0] awsize;
	logic awvalid;
	logic awready;
	
	logic[15:0] wid;
	logic[511:0] wdata;
	logic[63:0] wstrb;
	logic wlast;
	logic wvalid;
	logic wready;
	   
	logic[15:0] bid;
	logic[1:0] bresp;
	logic bvalid;
	logic bready;
	   
	logic[15:0] arid;
	logic[63:0] araddr;
	logic[7:0] arlen;
	logic [2:0] arsize;
	logic arvalid;
	logic arready;
	   
	logic[15:0] rid;
	logic[511:0] rdata;
	logic[1:0] rresp;
	logic rlast;
	logic rvalid;
	logic rready;
	
	modport to_master (input awid, awaddr, awlen, awsize, awvalid, output awready,
	                input wid, wdata, wstrb, wlast, wvalid, output wready,
	                output bid, bresp, bvalid, input bready,
	                input arid, araddr, arlen, arsize, arvalid, output arready,
	                output rid, rdata, rresp, rlast, rvalid, input rready);
	
	modport to_slave (output awid, awaddr, awlen, awsize, awvalid, input awready,
	               output wid, wdata, wstrb, wlast, wvalid, input wready,
	               input bid, bresp, bvalid, output bready,
	               output arid, araddr, arlen, arsize, arvalid, input arready,
	               input rid, rdata, rresp, rlast, rvalid, output rready);
endinterface

