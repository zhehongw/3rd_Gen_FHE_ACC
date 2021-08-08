`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2021 03:28:24 PM
// Design Name: 
// Module Name: ROB
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: reorder buffer, to reorder the poly/RLWEs put into the iNTT module, since
//				multiple iNTT can work in parallel, need to maintain the order of the poly
//				and RLWE
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "common.vh"
module ROB #(
	parameter DEPTH = 8,
	parameter POINTER_WIDTH = $clog2(DEPTH)
)(
	input clk, rstn,
	//ROB write port to top controller
	input 							wr_en, 			//ROB write enable
	//input [`RLWE_ID_WIDTH - 1 : 0] 	rlwe_id_in,		//rlwe_id input
	input [2 : 0] 					gate_in,		//indicate which gate is evaluated for bootstrap init, used to select bound1 and bound2 for iNTT 
	input [`OPCODE_WIDTH  - 1 : 0] 	opcode_in,		//opcode input, no need to input poly_id, generate internally
	input [`INTT_ID_WIDTH - 1 : 0] 	iNTT_id_in,		//which iNTT module is used, currently only two
	input [`LWE_BIT_WIDTH - 1 : 0] 	init_value_in,	//used for bootstrap init 
	//input [`LWE_BIT_WIDTH - 1 : 0] 	bound1_in,		//used for bootstrap init
	//input [`LWE_BIT_WIDTH - 1 : 0] 	bound2_in,		//used for bootstrap init
	input [3 : 0]					subs_factor_in,	//used for subs module
	output ROB_full,
	output ROB_empty,
	
	//ROB read port to NTT module
	input rd_finish_NTT,
	//output [`RLWE_ID_WIDTH - 1 : 0] rlwe_id_out_NTT,
	output [`POLY_ID_WIDTH - 1 : 0] poly_id_out_NTT,
	output [`OPCODE_WIDTH  - 1 : 0]	opcode_out_NTT,
	output [`INTT_ID_WIDTH - 1 : 0]	iNTT_id_out_NTT,		//which iNTT module is used, currently only two
	output ROB_empty_NTT,
	
	//ROB read port to subs module
	input rd_finish_subs,
	output [`POLY_ID_WIDTH - 1 : 0] poly_id_out_subs,
	output [`INTT_ID_WIDTH - 1 : 0]	iNTT_id_out_subs,
	output [`OPCODE_WIDTH - 1 : 0] 	opcode_out_subs,
	output [3 : 0] 					subs_factor_out_subs,
	output ROB_empty_subs,
	
	//ROB read port to iNTT module
	input rd_finish_iNTT,
	output [`INTT_ID_WIDTH - 1 : 0] iNTT_id_out_iNTT,	//which iNTT module is used, currently only two
	//output [`RLWE_ID_WIDTH - 1 : 0] rlwe_id_out_iNTT,
	output [`OPCODE_WIDTH - 1 : 0]	opcode_out_iNTT,
	output [`LWE_BIT_WIDTH - 1 : 0] init_value_out_iNTT,
	output logic [`LWE_BIT_WIDTH - 1 : 0]	bound1_out_iNTT,
	output logic [`LWE_BIT_WIDTH - 1 : 0]	bound2_out_iNTT,
	output ROB_empty_iNTT,

	config_if.to_top config_ports
);

//FIFO data element
`ifndef FPGA_LESS_RST
	//FIFO data element
	//logic [`RLWE_ID_WIDTH - 1 : 0] 	rlwe_id_FIFO 		[DEPTH - 1 : 0];
	logic [2 : 0]					gate_FIFO			[DEPTH - 1 : 0];
	logic [`OPCODE_WIDTH  - 1 : 0] 	opcode_FIFO 		[DEPTH - 1 : 0];
	logic [`INTT_ID_WIDTH - 1 : 0] 	iNTT_id_FIFO 		[DEPTH - 1 : 0];
	logic [`LWE_BIT_WIDTH - 1 : 0] 	init_value_FIFO 	[DEPTH - 1 : 0];
	//logic [`LWE_BIT_WIDTH - 1 : 0] 	bound1_FIFO 		[DEPTH - 1 : 0];
	//logic [`LWE_BIT_WIDTH - 1 : 0] 	bound2_FIFO 		[DEPTH - 1 : 0];
	logic [3 : 0] 					subs_factor_FIFO 	[DEPTH - 1 : 0];
`else 
	//logic [`RLWE_ID_WIDTH - 1 : 0] 	rlwe_id_FIFO 		[DEPTH - 1 : 0] = '{DEPTH{0}};
	logic [2 : 0] 					gate_FIFO 			[DEPTH - 1 : 0] = '{DEPTH{0}};
	logic [`OPCODE_WIDTH  - 1 : 0] 	opcode_FIFO 		[DEPTH - 1 : 0] = '{DEPTH{`INVALIDOP}};
	logic [`INTT_ID_WIDTH - 1 : 0] 	iNTT_id_FIFO 		[DEPTH - 1 : 0] = '{DEPTH{0}};
	logic [`LWE_BIT_WIDTH - 1 : 0] 	init_value_FIFO 	[DEPTH - 1 : 0] = '{DEPTH{0}};
	//logic [`LWE_BIT_WIDTH - 1 : 0] 	bound1_FIFO 		[DEPTH - 1 : 0] = `{DEPTH{0}};
	//logic [`LWE_BIT_WIDTH - 1 : 0] 	bound2_FIFO 		[DEPTH - 1 : 0] = `{DEPTH{0}};
	logic [3 : 0] 					subs_factor_FIFO 	[DEPTH - 1 : 0] = '{DEPTH{0}};
`endif
//logic [`RLWE_ID_WIDTH - 1 : 0] 	rlwe_id_FIFO_next 		[DEPTH - 1 : 0];
logic [2 : 0] 					gate_FIFO_next 			[DEPTH - 1 : 0];
logic [`OPCODE_WIDTH  - 1 : 0] 	opcode_FIFO_next 		[DEPTH - 1 : 0];
logic [`INTT_ID_WIDTH - 1 : 0] 	iNTT_id_FIFO_next 		[DEPTH - 1 : 0];
logic [`LWE_BIT_WIDTH - 1 : 0] 	init_value_FIFO_next 	[DEPTH - 1 : 0];
//logic [`LWE_BIT_WIDTH - 1 : 0] 	bound1_FIFO_next 		[DEPTH - 1 : 0];
//logic [`LWE_BIT_WIDTH - 1 : 0] 	bound2_FIFO_next 		[DEPTH - 1 : 0];
logic [3 : 0] 					subs_factor_FIFO_next 	[DEPTH - 1 : 0];


//FIFO pointers 
logic [POINTER_WIDTH : 0] wr_pointer, wr_pointer_next;
logic [POINTER_WIDTH : 0] rd_pointer_NTT, rd_pointer_NTT_next;
logic [POINTER_WIDTH : 0] rd_pointer_subs, rd_pointer_subs_next;
logic [POINTER_WIDTH : 0] rd_pointer_iNTT, rd_pointer_iNTT_next;

assign ROB_full 		= wr_pointer[POINTER_WIDTH - 1 : 0] == rd_pointer_NTT[POINTER_WIDTH - 1 : 0] ? 
							wr_pointer[POINTER_WIDTH] ^ rd_pointer_NTT[POINTER_WIDTH] : 0;
assign ROB_empty_NTT 	= wr_pointer[POINTER_WIDTH - 1 : 0] == rd_pointer_NTT[POINTER_WIDTH - 1 : 0] ? 
							~(wr_pointer[POINTER_WIDTH] ^ rd_pointer_NTT[POINTER_WIDTH]) : 0;
assign ROB_empty_subs 	= wr_pointer[POINTER_WIDTH - 1 : 0] == rd_pointer_subs[POINTER_WIDTH - 1 : 0] ? 
							~(wr_pointer[POINTER_WIDTH] ^ rd_pointer_subs[POINTER_WIDTH]) : 0;
assign ROB_empty_iNTT 	= wr_pointer[POINTER_WIDTH - 1 : 0] == rd_pointer_iNTT[POINTER_WIDTH - 1 : 0] ? 
							~(wr_pointer[POINTER_WIDTH] ^ rd_pointer_iNTT[POINTER_WIDTH]) : 0;

assign ROB_empty 		= ROB_empty_NTT;	//NTT is the last stage, so ROB empty is the same as ROB_NTT empty

//state machine for write pointer
`ifndef FPGA_LESS_RST 
	always_ff @(posedge clk) begin
		if(!rstn) begin
			for(integer i = 0; i < DEPTH; i++) begin
				//rlwe_id_FIFO[i]		<= `SD 0;
				gate_FIFO[i]		<= `SD 0;
				opcode_FIFO[i] 		<= `SD `INVALIDOP;
				iNTT_id_FIFO[i] 	<= `SD 0;
				init_value_FIFO[i]	<= `SD 0;
				//bound1_FIFO[i] 		<= `SD 0;
				//bound2_FIFO[i]		<= `SD 0;
				subs_factor_FIFO[i] <= `SD 0;
			end	
		end else begin
			for(integer i = 0; i < DEPTH; i++) begin
				//rlwe_id_FIFO[i]		<= `SD rlwe_id_FIFO_next[i];
				gate_FIFO[i]		<= `SD gate_FIFO_next[i];
				opcode_FIFO[i] 		<= `SD opcode_FIFO_next[i];
				iNTT_id_FIFO[i] 	<= `SD iNTT_id_FIFO_next[i];
				init_value_FIFO[i]	<= `SD init_value_FIFO_next[i];
				//bound1_FIFO[i] 		<= `SD bound1_FIFO_next[i];
				//bound2_FIFO[i]		<= `SD bound2_FIFO_next[i];
				subs_factor_FIFO[i] <= `SD subs_factor_FIFO_next[i];
			end	
		end
	end
`else 
	always_ff @(posedge clk) begin
		for(integer i = 0; i < DEPTH; i++) begin
			//rlwe_id_FIFO[i]		<= `SD rlwe_id_FIFO_next[i];
			gate_FIFO[i]		<= `SD gate_FIFO_next[i];
			opcode_FIFO[i] 		<= `SD opcode_FIFO_next[i];
			iNTT_id_FIFO[i] 	<= `SD iNTT_id_FIFO_next[i];
			init_value_FIFO[i]	<= `SD init_value_FIFO_next[i];
			//bound1_FIFO[i] 		<= `SD bound1_FIFO_next[i];
			//bound2_FIFO[i]		<= `SD bound2_FIFO_next[i];
			subs_factor_FIFO[i] <= `SD subs_factor_FIFO_next[i];
		end	
	end
`endif

always_ff @(posedge clk) begin
	if(!rstn) begin
		wr_pointer <= `SD 0;
	end else begin
		wr_pointer <= `SD wr_pointer_next;
	end
end

always_comb begin
	wr_pointer_next = wr_pointer;
	for(integer i = 0; i < DEPTH; i++) begin
		//rlwe_id_FIFO_next[i] 		= rlwe_id_FIFO[i]; 
		gate_FIFO_next[i] 			= gate_FIFO[i]; 
		opcode_FIFO_next[i] 		= opcode_FIFO[i]; 
		iNTT_id_FIFO_next[i] 		= iNTT_id_FIFO[i]; 
		init_value_FIFO_next[i]		= init_value_FIFO[i];
		//bound1_FIFO_next[i] 		= bound1_FIFO[i];
		//bound2_FIFO_next[i]		= bound2_FIFO[i];
		subs_factor_FIFO_next[i] 	= subs_factor_FIFO[i]; 
	end	
	if(wr_en) begin
		wr_pointer_next = wr_pointer + 1;
		for(integer i = 0; i < DEPTH; i++) begin
			if(i == wr_pointer[POINTER_WIDTH - 1 :0]) begin
				//rlwe_id_FIFO_next[i] 		= rlwe_id_in; 
				gate_FIFO_next[i] 			= gate_in; 
				opcode_FIFO_next[i] 		= opcode_in; 
				iNTT_id_FIFO_next[i] 		= iNTT_id_in; 
				init_value_FIFO_next[i]		= init_value_in;
				//bound1_FIFO_next[i] 		= bound1_in;
				//bound2_FIFO_next[i]		= bound2_in;
				subs_factor_FIFO_next[i] 	= subs_factor_in; 
			end
		end	
	end
end
assert property (@(posedge clk) !(wr_en && ROB_full));


//state machine for iNTT read pointer 
typedef enum logic {INTT_IDLE, READ} iNTT_rd_states;
iNTT_rd_states iNTT_state, iNTT_next;

always_ff @(posedge clk) begin
	if(!rstn) begin
		rd_pointer_iNTT <= `SD 0;
		iNTT_state 		<= `SD INTT_IDLE;
	end else begin
		rd_pointer_iNTT <= `SD rd_pointer_iNTT_next;
		iNTT_state 		<= `SD iNTT_next;
	end
end

always_comb begin
	case(iNTT_state) 
		INTT_IDLE: begin
			if(!rd_finish_iNTT) begin
				iNTT_next = READ;
			end	else begin
				iNTT_next = INTT_IDLE;
			end
			rd_pointer_iNTT_next = rd_pointer_iNTT;
		end
		READ: begin
			if(rd_finish_iNTT) begin
				rd_pointer_iNTT_next = rd_pointer_iNTT + 1;
				iNTT_next = INTT_IDLE;
			end else begin
				rd_pointer_iNTT_next = rd_pointer_iNTT;
				iNTT_next = READ;
			end
		end
	endcase
end

assign iNTT_id_out_iNTT 	= iNTT_id_FIFO[rd_pointer_iNTT[POINTER_WIDTH - 1 : 0]];
//assign rlwe_id_out_iNTT 	= rlwe_id_FIFO[rd_pointer_iNTT[POINTER_WIDTH - 1 : 0]];
assign opcode_out_iNTT      = opcode_FIFO[rd_pointer_iNTT[POINTER_WIDTH - 1 : 0]];
assign init_value_out_iNTT 	= init_value_FIFO[rd_pointer_iNTT[POINTER_WIDTH - 1 : 0]];

//bound output mux 
always_comb begin
	bound1_out_iNTT 	= 0;
	bound2_out_iNTT 	= 0;
	for(integer i = 0; i < DEPTH; i++) begin
		if(i == rd_pointer_iNTT[POINTER_WIDTH - 1 : 0]) begin
			case(gate_FIFO[i])
				`OR: begin
					bound1_out_iNTT 	= config_ports.or_bound1;
					bound2_out_iNTT 	= config_ports.or_bound2;
				end
				`AND: begin
					bound1_out_iNTT 	= config_ports.and_bound1;
					bound2_out_iNTT 	= config_ports.and_bound2;
				end
				`NOR: begin
					bound1_out_iNTT 	= config_ports.nor_bound1;
					bound2_out_iNTT 	= config_ports.nor_bound2;
				end
				`NAND: begin
					bound1_out_iNTT 	= config_ports.nand_bound1;
					bound2_out_iNTT 	= config_ports.nand_bound2;
				end
				`XOR: begin
					bound1_out_iNTT 	= config_ports.xor_bound1;
					bound2_out_iNTT 	= config_ports.xor_bound2;
				end
				`XNOR: begin
					bound1_out_iNTT 	= config_ports.xnor_bound1;
					bound2_out_iNTT 	= config_ports.xnor_bound2;
				end
			endcase
		end
	end
end

assert property (@(posedge clk) !(ROB_empty_iNTT && !rd_finish_iNTT));

//state machine for subs pointer 
typedef enum logic [1 : 0] {SUBS_IDLE, SUBS_READA, SUBS_WAITB, SUBS_READB} subs_rd_states;
subs_rd_states subs_state, subs_next;
logic [`POLY_ID_WIDTH - 1 : 0] poly_id_subs, poly_id_subs_next;


always_ff @(posedge clk) begin
	if(!rstn) begin
		subs_state 		<= `SD SUBS_IDLE;
		poly_id_subs 	<= `SD `POLY_A;
		rd_pointer_subs <= `SD 0;
	end else begin
		subs_state 		<= `SD subs_next;
		poly_id_subs 	<= `SD poly_id_subs_next;
		rd_pointer_subs <= `SD rd_pointer_subs_next;
	end
end

always_comb begin
	case(subs_state) 
		SUBS_IDLE: begin
			if(opcode_FIFO[rd_pointer_subs] == `RLWESUBS) begin
				if(!rd_finish_subs) begin
					subs_next 	= SUBS_READA;
				end else begin
					subs_next 	= SUBS_IDLE;
				end
				rd_pointer_subs_next	= rd_pointer_subs;
			end else begin
				subs_next 				= SUBS_IDLE;
				rd_pointer_subs_next 	= rd_pointer_subs == rd_pointer_iNTT ? rd_pointer_subs : rd_pointer_subs + 1;
			end
			poly_id_subs_next 		= `POLY_A;
		end
		SUBS_READA: begin
			if(rd_finish_subs) begin
				subs_next 			= SUBS_WAITB;
				poly_id_subs_next 	= `POLY_B;
			end else begin
				subs_next 			= SUBS_READA;
				poly_id_subs_next 	= `POLY_A;
			end
			rd_pointer_subs_next = rd_pointer_subs;
		end
		SUBS_WAITB: begin
			if(!rd_finish_subs) begin
				subs_next 	= SUBS_READB;
			end else begin
				subs_next 	= SUBS_WAITB;
			end
			poly_id_subs_next 		= `POLY_B;
			rd_pointer_subs_next 	= rd_pointer_subs;
		end
		SUBS_READB: begin
			if(rd_finish_subs) begin
				subs_next 				= SUBS_IDLE;
				rd_pointer_subs_next 	= rd_pointer_subs + 1;
				poly_id_subs_next 		= `POLY_A;
			end else begin
				subs_next 				= SUBS_READB;
				rd_pointer_subs_next 	= rd_pointer_subs;
				poly_id_subs_next 		= `POLY_B;
			end
		end
	endcase
end
assign poly_id_out_subs 	= poly_id_subs;
assign iNTT_id_out_subs 	= iNTT_id_FIFO[rd_pointer_subs[POINTER_WIDTH - 1 : 0]];
assign opcode_out_subs 		= opcode_FIFO[rd_pointer_subs[POINTER_WIDTH - 1 : 0]];
assign subs_factor_out_subs = subs_factor_FIFO[rd_pointer_subs[POINTER_WIDTH -1 : 0]];

assert property (@(posedge clk) !(ROB_empty_subs && !rd_finish_subs));


//state machine for NTT pointer
typedef enum logic [1 : 0] {NTT_IDLE, NTT_READA, NTT_WAITB, NTT_READB} NTT_rd_states;
NTT_rd_states NTT_state, NTT_next;
logic [`POLY_ID_WIDTH - 1 : 0] poly_id_NTT, poly_id_NTT_next;

always_ff @(posedge clk) begin
	if(!rstn) begin
		rd_pointer_NTT 	<= `SD 0;
		NTT_state 		<= `SD NTT_IDLE;
		poly_id_NTT 	<= `SD `POLY_A;
	end else begin
		rd_pointer_NTT 	<= `SD rd_pointer_NTT_next;
		NTT_state 		<= `SD NTT_next;
		poly_id_NTT 	<= `SD poly_id_NTT_next;
	end
end

always_comb begin
	case(NTT_state) 
		NTT_IDLE: begin
			if(!rd_finish_NTT) begin
				NTT_next = NTT_READA;
			end	else begin
				NTT_next = NTT_IDLE;
			end
			rd_pointer_NTT_next 	= rd_pointer_NTT;
			poly_id_NTT_next		= `POLY_A;
		end
		NTT_READA: begin
			if(rd_finish_NTT) begin
				NTT_next 			= NTT_WAITB;
				poly_id_NTT_next 	= `POLY_B;
			end else begin
				NTT_next 			= NTT_READA;
				poly_id_NTT_next 	= `POLY_A;
			end
			rd_pointer_NTT_next = rd_pointer_NTT;
		end
		NTT_WAITB: begin
			if(!rd_finish_NTT) begin
				NTT_next 			= NTT_READB;
			end else begin
				NTT_next 			= NTT_WAITB;
			end
			poly_id_NTT_next 	= `POLY_B;
			rd_pointer_NTT_next = rd_pointer_NTT;
		end
		NTT_READB: begin
			if(rd_finish_NTT) begin
				NTT_next 			= NTT_IDLE;
				poly_id_NTT_next 	= `POLY_A;
				rd_pointer_NTT_next = rd_pointer_NTT + 1;
			end else begin
				NTT_next 			= NTT_READB;
				poly_id_NTT_next 	= `POLY_B;
				rd_pointer_NTT_next = rd_pointer_NTT;
			end
		end
	endcase
end

assign iNTT_id_out_NTT 	= iNTT_id_FIFO[rd_pointer_NTT[POINTER_WIDTH - 1 : 0]];
//assign rlwe_id_out_NTT 	= rlwe_id_FIFO[rd_pointer_NTT[POINTER_WIDTH - 1 : 0]];
assign opcode_out_NTT 	= opcode_FIFO[rd_pointer_NTT[POINTER_WIDTH - 1 : 0]];
assign poly_id_out_NTT  = poly_id_NTT;

assert property (@(posedge clk) !(ROB_empty_NTT && !rd_finish_NTT));


endmodule

