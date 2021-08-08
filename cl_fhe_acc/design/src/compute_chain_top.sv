`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2021 03:28:24 PM
// Design Name: 
// Module Name: compute_chain_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: wrapper for ROB, subs, iNTT, NTT, acc_top
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "common.vh"
module compute_chain_top #(
    parameter STAGES = $clog2(`MAX_LEN)
)(
	input clk, rstn,

	//to top control
	input ROB_wr_en,
//	input [`RLWE_ID_WIDTH - 1 : 0] 	rlwe_id_in,
	input [2 : 0]					gate_in,
	input [`OPCODE_WIDTH - 1 : 0] 	opcode_in,
	input [`INTT_ID_WIDTH - 1 : 0] 	iNTT_id_in,
	input [`LWE_BIT_WIDTH - 1 : 0] 	init_value_in,
//	input [`LWE_BIT_WIDTH - 1 : 0] 	bound1_in,
//	input [`LWE_BIT_WIDTH - 1 : 0] 	bound2_in,
	input [3 : 0] 					subs_factor_in,
	output ROB_full,
	output ROB_empty,

	//top global buffer read port
	myFIFO_NTT_sink_if.to_FIFO 				input_global_RLWE_buffer_if [1 : 0],
//	output [`RLWE_ID_WIDTH - 1 : 0] 		rlwe_id_out_global_buffer, 
	
	//top global buffer write port, write port needs also to include read
	//functionality 
	myFIFO_NTT_source_if.to_FIFO 			out_global_RLWE_buffer_if [1 : 0],
	output logic [1 : 0] 					global_RLWE_buffer_wr_enable,
	input [`BIT_WIDTH * `LINE_SIZE - 1 : 0] global_RLWE_buffer_doutA [1 : 0],
	input [`BIT_WIDTH * `LINE_SIZE - 1 : 0] global_RLWE_buffer_doutB [1 : 0],
	
	//port to key load module
	myFIFO_NTT_sink_if.to_FIFO key_FIFO[1 : 0],
	//axi irou write port	
	ROU_config_if.to_axil_bar1 irou_wr_port,

	//axi rou write port
	ROU_config_if.to_axil_bar1 rou_wr_port [0 : STAGES - 1],

	//config ports
	config_if.to_top config_ports
);



//ROB_iNTT
logic rd_finish_iNTT;
logic [`INTT_ID_WIDTH - 1 : 0] 	iNTT_id_out_iNTT;
//logic [`RLWE_ID_WIDTH - 1 : 0] 	rlwe_id_out_iNTT;
logic [`OPCODE_WIDTH - 1 : 0] 	opcode_out_iNTT;
logic [`LWE_BIT_WIDTH - 1 : 0] 	init_value_out_iNTT;
logic [`LWE_BIT_WIDTH - 1 : 0] 	bound1_out_iNTT;
logic [`LWE_BIT_WIDTH - 1 : 0] 	bound2_out_iNTT;
logic ROB_empty_iNTT;

//ROB_subs
logic rd_finish_subs;
logic [`POLY_ID_WIDTH - 1 : 0] 	poly_id_out_subs;
logic [`INTT_ID_WIDTH - 1 : 0]	iNTT_id_out_subs;
logic [`OPCODE_WIDTH - 1 : 0] 	opcode_out_subs;
logic [3 : 0] 					subs_factor_out_subs;
logic ROB_empty_subs;

//ROB_NTT
logic rd_finish_NTT;
//logic [`RLWE_ID_WIDTH - 1 : 0] 	rlwe_id_out_NTT;
logic [`POLY_ID_WIDTH - 1 : 0] 	poly_id_out_NTT;
logic [`OPCODE_WIDTH - 1 : 0] 	opcode_out_NTT;
logic [`INTT_ID_WIDTH - 1 : 0]	iNTT_id_out_NTT;	
logic ROB_empty_NTT;

assign ROB_empty = ROB_empty_NTT;

ROB #(.DEPTH(8)) reorder_buffer(
	.clk(clk), 
	.rstn(rstn),
	//ROB write port to top controller
	.wr_en(ROB_wr_en), 				//ROB write enable
//	.rlwe_id_in(rlwe_id_in),	//rlwe_id input
	.gate_in(gate_in),
	.opcode_in(opcode_in),		//opcode input, no need to input poly_id, generate internally
	.iNTT_id_in(iNTT_id_in),	//which iNTT module is used, currently only two
	.init_value_in(init_value_in),
//	.bound1_in(bound1_in),
//	.bound2_in(bound2_in),	
	.subs_factor_in(subs_factor_in),
	.ROB_full(ROB_full),
	
	//ROB read port to NTT module
	.rd_finish_NTT(rd_finish_NTT),
//	.rlwe_id_out_NTT(rlwe_id_out_NTT),
	.poly_id_out_NTT(poly_id_out_NTT),
	.opcode_out_NTT(opcode_out_NTT),
	.iNTT_id_out_NTT(iNTT_id_out_NTT),	//which iNTT module is used, currently only two
	.ROB_empty_NTT(ROB_empty_NTT),
	
	//ROB read port to subs module
	.rd_finish_subs(rd_finish_subs),
	.poly_id_out_subs(poly_id_out_subs),
	.iNTT_id_out_subs(iNTT_id_out_subs),
	.opcode_out_subs(opcode_out_subs),
	.subs_factor_out_subs(subs_factor_out_subs),
	.ROB_empty_subs(ROB_empty_subs),
	
	//ROB read port to iNTT module
	.rd_finish_iNTT(rd_finish_iNTT),
	.iNTT_id_out_iNTT(iNTT_id_out_iNTT),				//which iNTT module is used, currently only two
//	.rlwe_id_out_iNTT(rlwe_id_out_iNTT),
	.opcode_out_iNTT(opcode_out_iNTT),
	.init_value_out_iNTT(init_value_out_iNTT),
	.bound1_out_iNTT(bound1_out_iNTT),
	.bound2_out_iNTT(bound2_out_iNTT),
	.ROB_empty_iNTT(ROB_empty_iNTT),

	.config_ports(config_ports)
);

//iNTT ports

myFIFO_NTT_sink_if iNTT_input_FIFO_if0 [1 : 0]();
myFIFO_NTT_sink_if iNTT_output_FIFO_if0 [1 : 0]();
logic [1 : 0] iNTT_outer_rd_enable0;
logic rd_finish_ROB0;
logic ROB_empty_iNTT0;
iNTT_module iNTT0 (
    .clk(clk),
   	.rstn(rstn),
	
	//to preceding FIFO
    .input_FIFO(iNTT_input_FIFO_if0),	//0 is for poly a, 1 for poly b
	//to next NTT stage or subs module
	.out_to_next_stage(iNTT_output_FIFO_if0),
	.outer_rd_enable(iNTT_outer_rd_enable0),	//explicit rd_en port for subs module

	.config_ports(config_ports),

	.irou_wr_port(irou_wr_port),
	
	//ports for init module, these should be latched internally 
	.init_value(init_value_out_iNTT),  	// this is the b in LWE ciphertext
	.bound1(bound1_out_iNTT),			// bootstrap bound1
	.bound2(bound2_out_iNTT),			// bootstrap bound2

	//port from ROB module to control the function, this also should be
	//latched internally 
	.opcode_in(opcode_out_iNTT),
    .rd_finish_ROB(rd_finish_ROB0),
	.ROB_empty_iNTT(ROB_empty_iNTT0)
);

myFIFO_NTT_sink_if iNTT_input_FIFO_if1 [1 : 0]();
myFIFO_NTT_sink_if iNTT_output_FIFO_if1 [1 : 0]();
logic [1 : 0] iNTT_outer_rd_enable1;
logic rd_finish_ROB1;
logic ROB_empty_iNTT1;
iNTT_module iNTT1(
    .clk(clk),
   	.rstn(rstn),
	
	//to preceding FIFO
    .input_FIFO(iNTT_input_FIFO_if1),	//0 is for poly a, 1 for poly b
	//to next NTT stage or subs module
	.out_to_next_stage(iNTT_output_FIFO_if1),
	.outer_rd_enable(iNTT_outer_rd_enable1),	//explicit rd_en port for subs module

	.config_ports(config_ports),

	.irou_wr_port(irou_wr_port),
	
	//ports for init module, these should be latched internally 
	.init_value(init_value_out_iNTT),  	// this is the b in LWE ciphertext
	.bound1(bound1_out_iNTT),			// bootstrap bound1
	.bound2(bound2_out_iNTT),			// bootstrap bound2

	//port from ROB module to control the function, this also should be
	//latched internally 
	.opcode_in(opcode_out_iNTT),
    .rd_finish_ROB(rd_finish_ROB1),
	.ROB_empty_iNTT(ROB_empty_iNTT1)
);

myFIFO_NTT_sink_if iNTT_input_FIFO_if2 [1 : 0]();
myFIFO_NTT_sink_if iNTT_output_FIFO_if2 [1 : 0]();
logic [1 : 0] iNTT_outer_rd_enable2;
logic rd_finish_ROB2;
logic ROB_empty_iNTT2;
iNTT_module iNTT2(
    .clk(clk),
   	.rstn(rstn),
	
	//to preceding FIFO
    .input_FIFO(iNTT_input_FIFO_if2),	//0 is for poly a, 1 for poly b
	//to next NTT stage or subs module
	.out_to_next_stage(iNTT_output_FIFO_if2),
	.outer_rd_enable(iNTT_outer_rd_enable2),	//explicit rd_en port for subs module

	.config_ports(config_ports),

	.irou_wr_port(irou_wr_port),
	
	//ports for init module, these should be latched internally 
	.init_value(init_value_out_iNTT),  	// this is the b in LWE ciphertext
	.bound1(bound1_out_iNTT),			// bootstrap bound1
	.bound2(bound2_out_iNTT),			// bootstrap bound2

	//port from ROB module to control the function, this also should be
	//latched internally 
	.opcode_in(opcode_out_iNTT),
    .rd_finish_ROB(rd_finish_ROB2),
	.ROB_empty_iNTT(ROB_empty_iNTT2)
);

myFIFO_NTT_sink_if iNTT_input_FIFO_if3 [1 : 0]();
myFIFO_NTT_sink_if iNTT_output_FIFO_if3 [1 : 0]();
logic [1 : 0] iNTT_outer_rd_enable3;
logic rd_finish_ROB3;
logic ROB_empty_iNTT3;
iNTT_module iNTT3(
    .clk(clk),
   	.rstn(rstn),
	
	//to preceding FIFO
    .input_FIFO(iNTT_input_FIFO_if3),	//0 is for poly a, 1 for poly b
	//to next NTT stage or subs module
	.out_to_next_stage(iNTT_output_FIFO_if3),
	.outer_rd_enable(iNTT_outer_rd_enable3),	//explicit rd_en port for subs module

	.config_ports(config_ports),

	.irou_wr_port(irou_wr_port),
	
	//ports for init module, these should be latched internally 
	.init_value(init_value_out_iNTT),  	// this is the b in LWE ciphertext
	.bound1(bound1_out_iNTT),			// bootstrap bound1
	.bound2(bound2_out_iNTT),			// bootstrap bound2

	//port from ROB module to control the function, this also should be
	//latched internally 
	.opcode_in(opcode_out_iNTT),
    .rd_finish_ROB(rd_finish_ROB3),
	.ROB_empty_iNTT(ROB_empty_iNTT3)
);



//subs module interface and ports
myFIFO_NTT_sink_if subs_input_FIFO_if();
myFIFO_NTT_sink_if subs_output_FIFO_if();
logic subs_iNTT_rd_enable;
subs_module subs(
    .clk(clk),
   	.rstn(rstn),
	//to preceding FIFO
    .input_FIFO(subs_input_FIFO_if),
	//to next NTT stage
	.out_to_next_stage(subs_output_FIFO_if),

	.config_ports(config_ports),

	.rd_enable(subs_iNTT_rd_enable),			//rd_enable to iNTT stage FIFO
	.subs_factor(subs_factor_out_subs), 		//to calculate which power to subs
	.ROB_empty(ROB_empty_subs) 					//from reorder buffer to indicate ROB is empty
);

//NTT interface and ports
myFIFO_NTT_sink_if NTT_input_FIFO_if ();
myFIFO_NTT_sink_if NTT_output_FIFO_if ();

NTT_top NTT(
    .clk(clk),
   	.rstn(rstn),
   	.input_FIFO(NTT_input_FIFO_if),
    .out_to_next_stage(NTT_output_FIFO_if),
    .config_ports(config_ports),
	.ROB_empty_NTT(ROB_empty_NTT),
   	.rou_wr_port(rou_wr_port)   
);

acc_top poly_MAC(
    .clk(clk),
   	.rstn(rstn),
	//to preceding NTT FIFO
	.NTT_FIFO(NTT_output_FIFO_if),
	//to global RLWE buffer
	.out_to_next_stage(out_global_RLWE_buffer_if),
	
	//output_wr_enable to global RLWE buffer, 0 for poly a, 1 for poly b
	.output_wr_enable(global_RLWE_buffer_wr_enable),
	//data read from the global RLWE buffer
	.outram_doutA(global_RLWE_buffer_doutA),
	.outram_doutB(global_RLWE_buffer_doutB),

	//to offchip loading key FIFO
	.key_FIFO(key_FIFO),
	//config ports
	.config_ports(config_ports)
);


//iNTT to ROB
always_comb begin
	ROB_empty_iNTT0 = 1'b1;
	ROB_empty_iNTT1 = 1'b1;
	ROB_empty_iNTT2 = 1'b1;
	ROB_empty_iNTT3 = 1'b1;

	case(iNTT_id_out_iNTT)
		0: begin
			ROB_empty_iNTT0 = ROB_empty_iNTT;
		end
		1: begin
			ROB_empty_iNTT1 = ROB_empty_iNTT;
		end
		2: begin
			ROB_empty_iNTT2 = ROB_empty_iNTT;
		end
		3: begin
			ROB_empty_iNTT3 = ROB_empty_iNTT;
		end
	endcase
end


//iNTT_global mux
always_comb begin
	input_global_RLWE_buffer_if[0].addrA 		= 0;
	input_global_RLWE_buffer_if[0].addrB 		= 0;
	input_global_RLWE_buffer_if[0].rd_finish 	= 1;
	input_global_RLWE_buffer_if[1].addrA 		= 0;
	input_global_RLWE_buffer_if[1].addrB 		= 0;
	input_global_RLWE_buffer_if[1].rd_finish 	= 1;
    case(iNTT_id_out_iNTT) 
        0: begin
        	input_global_RLWE_buffer_if[0].addrA 		= iNTT_input_FIFO_if0[0].addrA;
			input_global_RLWE_buffer_if[0].addrB 		= iNTT_input_FIFO_if0[0].addrB;
			input_global_RLWE_buffer_if[0].rd_finish 	= iNTT_input_FIFO_if0[0].rd_finish;
			input_global_RLWE_buffer_if[1].addrA 		= iNTT_input_FIFO_if0[1].addrA;
			input_global_RLWE_buffer_if[1].addrB 		= iNTT_input_FIFO_if0[1].addrB;
			input_global_RLWE_buffer_if[1].rd_finish 	= iNTT_input_FIFO_if0[1].rd_finish;
        end
        1: begin
        	input_global_RLWE_buffer_if[0].addrA 		= iNTT_input_FIFO_if1[0].addrA;
			input_global_RLWE_buffer_if[0].addrB 		= iNTT_input_FIFO_if1[0].addrB;
			input_global_RLWE_buffer_if[0].rd_finish 	= iNTT_input_FIFO_if1[0].rd_finish;
			input_global_RLWE_buffer_if[1].addrA 		= iNTT_input_FIFO_if1[1].addrA;
			input_global_RLWE_buffer_if[1].addrB 		= iNTT_input_FIFO_if1[1].addrB;
			input_global_RLWE_buffer_if[1].rd_finish 	= iNTT_input_FIFO_if1[1].rd_finish;
        end
        2: begin
        	input_global_RLWE_buffer_if[0].addrA 		= iNTT_input_FIFO_if2[0].addrA;
			input_global_RLWE_buffer_if[0].addrB 		= iNTT_input_FIFO_if2[0].addrB;
			input_global_RLWE_buffer_if[0].rd_finish 	= iNTT_input_FIFO_if2[0].rd_finish;
			input_global_RLWE_buffer_if[1].addrA 		= iNTT_input_FIFO_if2[1].addrA;
			input_global_RLWE_buffer_if[1].addrB 		= iNTT_input_FIFO_if2[1].addrB;
			input_global_RLWE_buffer_if[1].rd_finish 	= iNTT_input_FIFO_if2[1].rd_finish;
        end
        3: begin
        	input_global_RLWE_buffer_if[0].addrA 		= iNTT_input_FIFO_if3[0].addrA;
			input_global_RLWE_buffer_if[0].addrB 		= iNTT_input_FIFO_if3[0].addrB;
			input_global_RLWE_buffer_if[0].rd_finish 	= iNTT_input_FIFO_if3[0].rd_finish;
			input_global_RLWE_buffer_if[1].addrA 		= iNTT_input_FIFO_if3[1].addrA;
			input_global_RLWE_buffer_if[1].addrB 		= iNTT_input_FIFO_if3[1].addrB;
			input_global_RLWE_buffer_if[1].rd_finish 	= iNTT_input_FIFO_if3[1].rd_finish;
        end
    endcase
end



//global_iNTT mux
always_comb begin
	//iNTT_input_FIFO_if0[0].dA 		= 0;
	//iNTT_input_FIFO_if0[0].dB 		= 0;
	iNTT_input_FIFO_if0[0].empty 	= 1;
	//iNTT_input_FIFO_if0[1].dA 		= 0;
	//iNTT_input_FIFO_if0[1].dB 		= 0;
	iNTT_input_FIFO_if0[1].empty 	= 1;
	
	//iNTT_input_FIFO_if1[0].dA 		= 0;
	//iNTT_input_FIFO_if1[0].dB 		= 0;
	iNTT_input_FIFO_if1[0].empty 	= 1;
	//iNTT_input_FIFO_if1[1].dA 		= 0;
	//iNTT_input_FIFO_if1[1].dB 		= 0;
	iNTT_input_FIFO_if1[1].empty 	= 1;

	//iNTT_input_FIFO_if2[0].dA 		= 0;
	//iNTT_input_FIFO_if2[0].dB 		= 0;
	iNTT_input_FIFO_if2[0].empty 	= 1;
	//iNTT_input_FIFO_if2[1].dA 		= 0;
	//iNTT_input_FIFO_if2[1].dB 		= 0;
	iNTT_input_FIFO_if2[1].empty 	= 1;

	//iNTT_input_FIFO_if3[0].dA 		= 0;
	//iNTT_input_FIFO_if3[0].dB 		= 0;
	iNTT_input_FIFO_if3[0].empty 	= 1;
	//iNTT_input_FIFO_if3[1].dA 		= 0;
	//iNTT_input_FIFO_if3[1].dB 		= 0;
	iNTT_input_FIFO_if3[1].empty 	= 1;

	iNTT_input_FIFO_if0[0].dA 		= input_global_RLWE_buffer_if[0].dA;
	iNTT_input_FIFO_if0[0].dB 		= input_global_RLWE_buffer_if[0].dB;
	//iNTT_input_FIFO_if0[0].empty 	= input_global_RLWE_buffer_if[0].empty;
	iNTT_input_FIFO_if0[1].dA 		= input_global_RLWE_buffer_if[1].dA;
	iNTT_input_FIFO_if0[1].dB 		= input_global_RLWE_buffer_if[1].dB;
	//iNTT_input_FIFO_if0[1].empty 	= input_global_RLWE_buffer_if[1].empty;
	iNTT_input_FIFO_if1[0].dA 		= input_global_RLWE_buffer_if[0].dA;
	iNTT_input_FIFO_if1[0].dB 		= input_global_RLWE_buffer_if[0].dB;
	//iNTT_input_FIFO_if1[0].empty 	= input_global_RLWE_buffer_if[0].empty;
	iNTT_input_FIFO_if1[1].dA 		= input_global_RLWE_buffer_if[1].dA;
	iNTT_input_FIFO_if1[1].dB 		= input_global_RLWE_buffer_if[1].dB;
	//iNTT_input_FIFO_if1[1].empty 	= input_global_RLWE_buffer_if[1].empty;
	iNTT_input_FIFO_if2[0].dA 		= input_global_RLWE_buffer_if[0].dA;
	iNTT_input_FIFO_if2[0].dB 		= input_global_RLWE_buffer_if[0].dB;
	//iNTT_input_FIFO_if2[0].empty 	= input_global_RLWE_buffer_if[0].empty;
	iNTT_input_FIFO_if2[1].dA 		= input_global_RLWE_buffer_if[1].dA;
	iNTT_input_FIFO_if2[1].dB 		= input_global_RLWE_buffer_if[1].dB;
	//iNTT_input_FIFO_if2[1].empty 	= input_global_RLWE_buffer_if[1].empty;
	iNTT_input_FIFO_if3[0].dA 		= input_global_RLWE_buffer_if[0].dA;
	iNTT_input_FIFO_if3[0].dB 		= input_global_RLWE_buffer_if[0].dB;
	//iNTT_input_FIFO_if3[0].empty 	= input_global_RLWE_buffer_if[0].empty;
	iNTT_input_FIFO_if3[1].dA 		= input_global_RLWE_buffer_if[1].dA;
	iNTT_input_FIFO_if3[1].dB 		= input_global_RLWE_buffer_if[1].dB;
	//iNTT_input_FIFO_if3[1].empty 	= input_global_RLWE_buffer_if[1].empty;
	case(iNTT_id_out_iNTT)
		0: begin
			//iNTT_input_FIFO_if0[0].dA 		= input_global_RLWE_buffer_if[0].dA;
			//iNTT_input_FIFO_if0[0].dB 		= input_global_RLWE_buffer_if[0].dB;
			iNTT_input_FIFO_if0[0].empty 	= input_global_RLWE_buffer_if[0].empty;
			//iNTT_input_FIFO_if0[1].dA 		= input_global_RLWE_buffer_if[1].dA;
			//iNTT_input_FIFO_if0[1].dB 		= input_global_RLWE_buffer_if[1].dB;
			iNTT_input_FIFO_if0[1].empty 	= input_global_RLWE_buffer_if[1].empty;
		end
		1: begin
			//iNTT_input_FIFO_if1[0].dA 		= input_global_RLWE_buffer_if[0].dA;
			//iNTT_input_FIFO_if1[0].dB 		= input_global_RLWE_buffer_if[0].dB;
			iNTT_input_FIFO_if1[0].empty 	= input_global_RLWE_buffer_if[0].empty;
			//iNTT_input_FIFO_if1[1].dA 		= input_global_RLWE_buffer_if[1].dA;
			//iNTT_input_FIFO_if1[1].dB 		= input_global_RLWE_buffer_if[1].dB;
			iNTT_input_FIFO_if1[1].empty 	= input_global_RLWE_buffer_if[1].empty;
		end
		2: begin
			//iNTT_input_FIFO_if2[0].dA 		= input_global_RLWE_buffer_if[0].dA;
			//iNTT_input_FIFO_if2[0].dB 		= input_global_RLWE_buffer_if[0].dB;
			iNTT_input_FIFO_if2[0].empty 	= input_global_RLWE_buffer_if[0].empty;
			//iNTT_input_FIFO_if2[1].dA 		= input_global_RLWE_buffer_if[1].dA;
			//iNTT_input_FIFO_if2[1].dB 		= input_global_RLWE_buffer_if[1].dB;
			iNTT_input_FIFO_if2[1].empty 	= input_global_RLWE_buffer_if[1].empty;
		end
		3: begin
			//iNTT_input_FIFO_if3[0].dA 		= input_global_RLWE_buffer_if[0].dA;
			//iNTT_input_FIFO_if3[0].dB 		= input_global_RLWE_buffer_if[0].dB;
			iNTT_input_FIFO_if3[0].empty 	= input_global_RLWE_buffer_if[0].empty;
			//iNTT_input_FIFO_if3[1].dA 		= input_global_RLWE_buffer_if[1].dA;
			//iNTT_input_FIFO_if3[1].dB 		= input_global_RLWE_buffer_if[1].dB;
			iNTT_input_FIFO_if3[1].empty 	= input_global_RLWE_buffer_if[1].empty;
		end
	endcase
end

logic [`INTT_NUM - 1 : 0] rd_finish_iNTT_and_vector;
assign rd_finish_iNTT_and_vector = {rd_finish_ROB3, rd_finish_ROB2, rd_finish_ROB1, rd_finish_ROB0};

//rd finish iNTT
assign rd_finish_iNTT = &rd_finish_iNTT_and_vector;



//subs to ROB
assign rd_finish_subs = subs_input_FIFO_if.rd_finish;

//NTT_subs_iNTT mux 
always_comb begin
	iNTT_output_FIFO_if0[0].addrA 		= 0;
	iNTT_output_FIFO_if0[0].addrB 		= 0;
	iNTT_output_FIFO_if0[0].rd_finish 	= 1;
	iNTT_outer_rd_enable0[0]			= 0;
	iNTT_output_FIFO_if0[1].addrA 		= 0;
	iNTT_output_FIFO_if0[1].addrB 		= 0;
	iNTT_output_FIFO_if0[1].rd_finish 	= 1;
	iNTT_outer_rd_enable0[1]			= 0;

	iNTT_output_FIFO_if1[0].addrA 		= 0;
	iNTT_output_FIFO_if1[0].addrB 		= 0;
	iNTT_output_FIFO_if1[0].rd_finish 	= 1;
	iNTT_outer_rd_enable1[0]			= 0;
	iNTT_output_FIFO_if1[1].addrA 		= 0;
	iNTT_output_FIFO_if1[1].addrB 		= 0;
	iNTT_output_FIFO_if1[1].rd_finish 	= 1;
	iNTT_outer_rd_enable1[1]			= 0;

	iNTT_output_FIFO_if2[0].addrA 		= 0;
	iNTT_output_FIFO_if2[0].addrB 		= 0;
	iNTT_output_FIFO_if2[0].rd_finish 	= 1;
	iNTT_outer_rd_enable2[0]			= 0;
	iNTT_output_FIFO_if2[1].addrA 		= 0;
	iNTT_output_FIFO_if2[1].addrB 		= 0;
	iNTT_output_FIFO_if2[1].rd_finish 	= 1;
	iNTT_outer_rd_enable2[1]			= 0;

	iNTT_output_FIFO_if3[0].addrA 		= 0;
	iNTT_output_FIFO_if3[0].addrB 		= 0;
	iNTT_output_FIFO_if3[0].rd_finish 	= 1;
	iNTT_outer_rd_enable3[0]			= 0;
	iNTT_output_FIFO_if3[1].addrA 		= 0;
	iNTT_output_FIFO_if3[1].addrB 		= 0;
	iNTT_output_FIFO_if3[1].rd_finish 	= 1;
	iNTT_outer_rd_enable3[1]			= 0;

	if((ROB_empty_subs || opcode_out_subs == `RLWESUBS) && opcode_out_NTT == `RLWESUBS) begin
		iNTT_output_FIFO_if0[0].addrA 		= subs_input_FIFO_if.addrA;
		iNTT_output_FIFO_if0[0].addrB 		= subs_input_FIFO_if.addrB;
		iNTT_output_FIFO_if0[1].addrA 		= subs_input_FIFO_if.addrA;
		iNTT_output_FIFO_if0[1].addrB 		= subs_input_FIFO_if.addrB;
		iNTT_output_FIFO_if1[0].addrA 		= subs_input_FIFO_if.addrA;
		iNTT_output_FIFO_if1[0].addrB 		= subs_input_FIFO_if.addrB;
		iNTT_output_FIFO_if1[1].addrA 		= subs_input_FIFO_if.addrA;
		iNTT_output_FIFO_if1[1].addrB 		= subs_input_FIFO_if.addrB;
		iNTT_output_FIFO_if2[0].addrA 		= subs_input_FIFO_if.addrA;
		iNTT_output_FIFO_if2[0].addrB 		= subs_input_FIFO_if.addrB;
		iNTT_output_FIFO_if2[1].addrA 		= subs_input_FIFO_if.addrA;
		iNTT_output_FIFO_if2[1].addrB 		= subs_input_FIFO_if.addrB;
		iNTT_output_FIFO_if3[0].addrA 		= subs_input_FIFO_if.addrA;
		iNTT_output_FIFO_if3[0].addrB 		= subs_input_FIFO_if.addrB;
		iNTT_output_FIFO_if3[1].addrA 		= subs_input_FIFO_if.addrA;
		iNTT_output_FIFO_if3[1].addrB 		= subs_input_FIFO_if.addrB;
		case({iNTT_id_out_subs, poly_id_out_subs})
			{2'd0, 1'b0}: begin
				//iNTT_output_FIFO_if0[0].addrA 		= subs_input_FIFO_if.addrA;
				//iNTT_output_FIFO_if0[0].addrB 		= subs_input_FIFO_if.addrB;
				iNTT_output_FIFO_if0[0].rd_finish 	= subs_input_FIFO_if.rd_finish;
				iNTT_outer_rd_enable0[0]			= subs_iNTT_rd_enable;	
			end
			{2'd0, 1'b1}: begin
				//iNTT_output_FIFO_if0[1].addrA 		= subs_input_FIFO_if.addrA;
				//iNTT_output_FIFO_if0[1].addrB 		= subs_input_FIFO_if.addrB;
				iNTT_output_FIFO_if0[1].rd_finish 	= subs_input_FIFO_if.rd_finish;
				iNTT_outer_rd_enable0[1]			= subs_iNTT_rd_enable;	
			end
			{2'd1, 1'b0}: begin
				//iNTT_output_FIFO_if1[0].addrA 		= subs_input_FIFO_if.addrA;
				//iNTT_output_FIFO_if1[0].addrB 		= subs_input_FIFO_if.addrB;
				iNTT_output_FIFO_if1[0].rd_finish 	= subs_input_FIFO_if.rd_finish;
				iNTT_outer_rd_enable1[0]			= subs_iNTT_rd_enable;	
			end
			{2'd1, 1'b1}: begin
				//iNTT_output_FIFO_if1[1].addrA 		= subs_input_FIFO_if.addrA;
				//iNTT_output_FIFO_if1[1].addrB 		= subs_input_FIFO_if.addrB;
				iNTT_output_FIFO_if1[1].rd_finish 	= subs_input_FIFO_if.rd_finish;
				iNTT_outer_rd_enable1[1]			= subs_iNTT_rd_enable;	
			end
			{2'd2, 1'b0}: begin
				//iNTT_output_FIFO_if2[0].addrA 		= subs_input_FIFO_if.addrA;
				//iNTT_output_FIFO_if2[0].addrB 		= subs_input_FIFO_if.addrB;
				iNTT_output_FIFO_if2[0].rd_finish 	= subs_input_FIFO_if.rd_finish;
				iNTT_outer_rd_enable2[0]			= subs_iNTT_rd_enable;	
			end
			{2'd2, 1'b1}: begin
				//iNTT_output_FIFO_if2[1].addrA 		= subs_input_FIFO_if.addrA;
				//iNTT_output_FIFO_if2[1].addrB 		= subs_input_FIFO_if.addrB;
				iNTT_output_FIFO_if2[1].rd_finish 	= subs_input_FIFO_if.rd_finish;
				iNTT_outer_rd_enable2[1]			= subs_iNTT_rd_enable;	
			end
			{2'd3, 1'b0}: begin
				//iNTT_output_FIFO_if3[0].addrA 		= subs_input_FIFO_if.addrA;
				//iNTT_output_FIFO_if3[0].addrB 		= subs_input_FIFO_if.addrB;
				iNTT_output_FIFO_if3[0].rd_finish 	= subs_input_FIFO_if.rd_finish;
				iNTT_outer_rd_enable3[0]			= subs_iNTT_rd_enable;	
			end
			{2'd3, 1'b1}: begin
				//iNTT_output_FIFO_if3[1].addrA 		= subs_input_FIFO_if.addrA;
				//iNTT_output_FIFO_if3[1].addrB 		= subs_input_FIFO_if.addrB;
				iNTT_output_FIFO_if3[1].rd_finish 	= subs_input_FIFO_if.rd_finish;
				iNTT_outer_rd_enable3[1]			= subs_iNTT_rd_enable;	
			end
		endcase	
	end else begin
		iNTT_output_FIFO_if0[0].addrA 		= NTT_input_FIFO_if.addrA;
		iNTT_output_FIFO_if0[0].addrB 		= NTT_input_FIFO_if.addrB;
		iNTT_output_FIFO_if0[1].addrA 		= NTT_input_FIFO_if.addrA;
		iNTT_output_FIFO_if0[1].addrB 		= NTT_input_FIFO_if.addrB;
		iNTT_output_FIFO_if1[0].addrA 		= NTT_input_FIFO_if.addrA;
		iNTT_output_FIFO_if1[0].addrB 		= NTT_input_FIFO_if.addrB;
		iNTT_output_FIFO_if1[1].addrA 		= NTT_input_FIFO_if.addrA;
		iNTT_output_FIFO_if1[1].addrB 		= NTT_input_FIFO_if.addrB;
		iNTT_output_FIFO_if2[0].addrA 		= NTT_input_FIFO_if.addrA;
		iNTT_output_FIFO_if2[0].addrB 		= NTT_input_FIFO_if.addrB;
		iNTT_output_FIFO_if2[1].addrA 		= NTT_input_FIFO_if.addrA;
		iNTT_output_FIFO_if2[1].addrB 		= NTT_input_FIFO_if.addrB;
		iNTT_output_FIFO_if3[0].addrA 		= NTT_input_FIFO_if.addrA;
		iNTT_output_FIFO_if3[0].addrB 		= NTT_input_FIFO_if.addrB;
		iNTT_output_FIFO_if3[1].addrA 		= NTT_input_FIFO_if.addrA;
		iNTT_output_FIFO_if3[1].addrB 		= NTT_input_FIFO_if.addrB;
		case({iNTT_id_out_NTT, poly_id_out_NTT})
			{2'd0, 1'b0}: begin
				//iNTT_output_FIFO_if0[0].addrA 		= NTT_input_FIFO_if.addrA;
				//iNTT_output_FIFO_if0[0].addrB 		= NTT_input_FIFO_if.addrB;
				iNTT_output_FIFO_if0[0].rd_finish 	= NTT_input_FIFO_if.rd_finish;
				iNTT_outer_rd_enable0[0]			= 1;	
			end
			{2'd0, 1'b1}: begin
				//iNTT_output_FIFO_if0[1].addrA 		= NTT_input_FIFO_if.addrA;
				//iNTT_output_FIFO_if0[1].addrB 		= NTT_input_FIFO_if.addrB;
				iNTT_output_FIFO_if0[1].rd_finish 	= NTT_input_FIFO_if.rd_finish;
				iNTT_outer_rd_enable0[1]			= 1;	
			end
			{2'd1, 1'b0}: begin
				//iNTT_output_FIFO_if1[0].addrA 		= NTT_input_FIFO_if.addrA;
				//iNTT_output_FIFO_if1[0].addrB 		= NTT_input_FIFO_if.addrB;
				iNTT_output_FIFO_if1[0].rd_finish 	= NTT_input_FIFO_if.rd_finish;
				iNTT_outer_rd_enable1[0]			= 1;	
			end
			{2'd1, 1'b1}: begin
				//iNTT_output_FIFO_if1[1].addrA 		= NTT_input_FIFO_if.addrA;
				//iNTT_output_FIFO_if1[1].addrB 		= NTT_input_FIFO_if.addrB;
				iNTT_output_FIFO_if1[1].rd_finish 	= NTT_input_FIFO_if.rd_finish;
				iNTT_outer_rd_enable1[1]			= 1;	
			end	
			{2'd2, 1'b0}: begin
				//iNTT_output_FIFO_if2[0].addrA 		= NTT_input_FIFO_if.addrA;
				//iNTT_output_FIFO_if2[0].addrB 		= NTT_input_FIFO_if.addrB;
				iNTT_output_FIFO_if2[0].rd_finish 	= NTT_input_FIFO_if.rd_finish;
				iNTT_outer_rd_enable2[0]			= 1;	
			end
			{2'd2, 1'b1}: begin
				//iNTT_output_FIFO_if2[1].addrA 		= NTT_input_FIFO_if.addrA;
				//iNTT_output_FIFO_if2[1].addrB 		= NTT_input_FIFO_if.addrB;
				iNTT_output_FIFO_if2[1].rd_finish 	= NTT_input_FIFO_if.rd_finish;
				iNTT_outer_rd_enable2[1]			= 1;	
			end	
			{2'd3, 1'b0}: begin
				//iNTT_output_FIFO_if3[0].addrA 		= NTT_input_FIFO_if.addrA;
				//iNTT_output_FIFO_if3[0].addrB 		= NTT_input_FIFO_if.addrB;
				iNTT_output_FIFO_if3[0].rd_finish 	= NTT_input_FIFO_if.rd_finish;
				iNTT_outer_rd_enable3[0]			= 1;	
			end
			{2'd3, 1'b1}: begin
				//iNTT_output_FIFO_if3[1].addrA 		= NTT_input_FIFO_if.addrA;
				//iNTT_output_FIFO_if3[1].addrB 		= NTT_input_FIFO_if.addrB;
				iNTT_output_FIFO_if3[1].rd_finish 	= NTT_input_FIFO_if.rd_finish;
				iNTT_outer_rd_enable3[1]			= 1;	
			end	
		endcase
	end

end

//iNTT_subs mux
always_comb begin
	subs_input_FIFO_if.dA 		= 0;
	subs_input_FIFO_if.dB 		= 0;
	subs_input_FIFO_if.empty 	= 1;
	
	if(opcode_out_subs == `RLWESUBS && opcode_out_NTT == `RLWESUBS) begin
		case({iNTT_id_out_subs, poly_id_out_subs})
			{2'd0, 1'b0}: begin
				subs_input_FIFO_if.dA 		= iNTT_output_FIFO_if0[0].dA;
				subs_input_FIFO_if.dB 		= iNTT_output_FIFO_if0[0].dB;
				subs_input_FIFO_if.empty 	= iNTT_output_FIFO_if0[0].empty;
			end
			{2'd0, 1'b1}: begin
				subs_input_FIFO_if.dA 		= iNTT_output_FIFO_if0[1].dA;
				subs_input_FIFO_if.dB 		= iNTT_output_FIFO_if0[1].dB;
				subs_input_FIFO_if.empty 	= iNTT_output_FIFO_if0[1].empty;
			end
			{2'd1, 1'b0}: begin
				subs_input_FIFO_if.dA 		= iNTT_output_FIFO_if1[0].dA;
				subs_input_FIFO_if.dB 		= iNTT_output_FIFO_if1[0].dB;
				subs_input_FIFO_if.empty 	= iNTT_output_FIFO_if1[0].empty;
			end
			{2'd1, 1'b1}: begin
				subs_input_FIFO_if.dA 		= iNTT_output_FIFO_if1[1].dA;
				subs_input_FIFO_if.dB 		= iNTT_output_FIFO_if1[1].dB;
				subs_input_FIFO_if.empty 	= iNTT_output_FIFO_if1[1].empty;
			end
			{2'd2, 1'b0}: begin
				subs_input_FIFO_if.dA 		= iNTT_output_FIFO_if2[0].dA;
				subs_input_FIFO_if.dB 		= iNTT_output_FIFO_if2[0].dB;
				subs_input_FIFO_if.empty 	= iNTT_output_FIFO_if2[0].empty;
			end
			{2'd2, 1'b1}: begin
				subs_input_FIFO_if.dA 		= iNTT_output_FIFO_if2[1].dA;
				subs_input_FIFO_if.dB 		= iNTT_output_FIFO_if2[1].dB;
				subs_input_FIFO_if.empty 	= iNTT_output_FIFO_if2[1].empty;
			end
			{2'd3, 1'b0}: begin
				subs_input_FIFO_if.dA 		= iNTT_output_FIFO_if3[0].dA;
				subs_input_FIFO_if.dB 		= iNTT_output_FIFO_if3[0].dB;
				subs_input_FIFO_if.empty 	= iNTT_output_FIFO_if3[0].empty;
			end
			{2'd3, 1'b1}: begin
				subs_input_FIFO_if.dA 		= iNTT_output_FIFO_if3[1].dA;
				subs_input_FIFO_if.dB 		= iNTT_output_FIFO_if3[1].dB;
				subs_input_FIFO_if.empty 	= iNTT_output_FIFO_if3[1].empty;
			end
		endcase
	end
end

//NTT_subs
always_comb begin
	subs_output_FIFO_if.addrA 		= 0;
	subs_output_FIFO_if.addrB 		= 0;
	subs_output_FIFO_if.rd_finish 	= 1;
	if(opcode_out_NTT == `RLWESUBS) begin
		subs_output_FIFO_if.addrA 		= NTT_input_FIFO_if.addrA;
		subs_output_FIFO_if.addrB 		= NTT_input_FIFO_if.addrB;
		subs_output_FIFO_if.rd_finish 	= NTT_input_FIFO_if.rd_finish;
	end
end

//iNTT_subs_NTT
always_comb begin
	NTT_input_FIFO_if.dA 	= 0;
	NTT_input_FIFO_if.dB 	= 0;
	NTT_input_FIFO_if.empty = 1;
	if(opcode_out_NTT == `RLWESUBS)begin
		NTT_input_FIFO_if.dA 	= subs_output_FIFO_if.dA;
		NTT_input_FIFO_if.dB 	= subs_output_FIFO_if.dB;
		NTT_input_FIFO_if.empty = subs_output_FIFO_if.empty;
	end else begin
		case({iNTT_id_out_NTT, poly_id_out_NTT})
			{2'd0, 1'b0}: begin
				NTT_input_FIFO_if.dA 	= iNTT_output_FIFO_if0[0].dA;
				NTT_input_FIFO_if.dB 	= iNTT_output_FIFO_if0[0].dB;
				NTT_input_FIFO_if.empty = iNTT_output_FIFO_if0[0].empty;
			end
			{2'd0, 1'b1}: begin
				NTT_input_FIFO_if.dA 	= iNTT_output_FIFO_if0[1].dA;
				NTT_input_FIFO_if.dB 	= iNTT_output_FIFO_if0[1].dB;
				NTT_input_FIFO_if.empty = iNTT_output_FIFO_if0[1].empty;
			end
			{2'd1, 1'b0}: begin
				NTT_input_FIFO_if.dA 	= iNTT_output_FIFO_if1[0].dA;
				NTT_input_FIFO_if.dB 	= iNTT_output_FIFO_if1[0].dB;
				NTT_input_FIFO_if.empty = iNTT_output_FIFO_if1[0].empty;
			end
			{2'd1, 1'b1}: begin
				NTT_input_FIFO_if.dA 	= iNTT_output_FIFO_if1[1].dA;
				NTT_input_FIFO_if.dB 	= iNTT_output_FIFO_if1[1].dB;
				NTT_input_FIFO_if.empty = iNTT_output_FIFO_if1[1].empty;
			end
			{2'd2, 1'b0}: begin
				NTT_input_FIFO_if.dA 	= iNTT_output_FIFO_if2[0].dA;
				NTT_input_FIFO_if.dB 	= iNTT_output_FIFO_if2[0].dB;
				NTT_input_FIFO_if.empty = iNTT_output_FIFO_if2[0].empty;
			end
			{2'd2, 1'b1}: begin
				NTT_input_FIFO_if.dA 	= iNTT_output_FIFO_if2[1].dA;
				NTT_input_FIFO_if.dB 	= iNTT_output_FIFO_if2[1].dB;
				NTT_input_FIFO_if.empty = iNTT_output_FIFO_if2[1].empty;
			end
			{2'd3, 1'b0}: begin
				NTT_input_FIFO_if.dA 	= iNTT_output_FIFO_if3[0].dA;
				NTT_input_FIFO_if.dB 	= iNTT_output_FIFO_if3[0].dB;
				NTT_input_FIFO_if.empty = iNTT_output_FIFO_if3[0].empty;
			end
			{2'd3, 1'b1}: begin
				NTT_input_FIFO_if.dA 	= iNTT_output_FIFO_if3[1].dA;
				NTT_input_FIFO_if.dB 	= iNTT_output_FIFO_if3[1].dB;
				NTT_input_FIFO_if.empty = iNTT_output_FIFO_if3[1].empty;
			end
		endcase
	end
end
//NTT to ROB
assign rd_finish_NTT             = NTT_input_FIFO_if.rd_finish;
//assign NTT_input_FIFO_if.rlwe_id = rlwe_id_out_NTT;
assign NTT_input_FIFO_if.poly_id = poly_id_out_NTT;
assign NTT_input_FIFO_if.opcode  = opcode_out_NTT;

endmodule
