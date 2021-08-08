`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2021 03:28:24 PM
// Design Name: 
// Module Name: iNTT_module
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: dual port RAM can only do two write or two read in on cycle, so need to
//				time interleave the iNTT module between two input FIFOs for better
//				butterfly utilization and performance
//				now incorporate output reg for the FIFO/ram, and also 5 stage
//				of pipeline
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "common.vh"

module iNTT_module #(
	parameter STAGES = $clog2(`MAX_LEN)
)(
    input clk, rstn,
	
	//to preceding FIFO
    myFIFO_NTT_sink_if.to_FIFO input_FIFO [1 : 0],	//0 is for poly a, 1 for poly b
	//to next NTT stage or subs module
	myFIFO_NTT_sink_if.to_sink out_to_next_stage [1 : 0],
	input [1 : 0] outer_rd_enable,	//explicit rd_en port for subs module

	config_if.to_top config_ports,

	ROU_config_if.to_axil_bar1 irou_wr_port,
	
	//ports for init module, these should be latched internally 
	input [`LWE_BIT_WIDTH - 1 : 0] init_value,  // this is the b in LWE ciphertext
	input [`LWE_BIT_WIDTH - 1 : 0] bound1,		// bootstrap bound1
	input [`LWE_BIT_WIDTH - 1 : 0] bound2,		// bootstrap bound2

	//port from ROB module to control the function, this also should be
	//latched internally 
	input [`OPCODE_WIDTH - 1 : 0] opcode_in,
    
    output rd_finish_ROB,   //rd_finish signal to the ROB, different from the one to the input FIFO
	input ROB_empty_iNTT
);

logic [$clog2(`MAX_LEN) - 1 : 0] irou_addr;
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] irou_line;
//logic irou_en;
logic irou_rd_en;	//irou table read enable

//assign irou_en = irou_rd_en | (|irou_wr_port.we);
iROU_buffer irou_table(
		.clk(clk),
		.wr_port(irou_wr_port),
		.en(irou_rd_en),
		.addr_rd(irou_addr[$clog2(`MAX_LEN) - 1 : $clog2(`LINE_SIZE)]),
		.iROU_line(irou_line)	
);


myFIFO_NTT_source_if output_FIFO_mux [1 : 0] ();
logic [`LINE_SIZE - 1 : 0] word_selA_mux [1 : 0];
logic [`LINE_SIZE - 1 : 0] word_selB_mux [1 : 0];
logic [1 : 0] inner_rd_enable;
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] out_buffer_doutA [1 : 0];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] out_buffer_doutB [1 : 0];
myFIFO_iNTT out_buffer [1 : 0] (	
		.clk(clk),
		.rstn(rstn),
		//.wr_enable(wr_enable),
		.word_selA(word_selA_mux),
		.word_selB(word_selB_mux),
		.inner_rd_enable(inner_rd_enable),
		.outer_rd_enable(outer_rd_enable),
		.doutA(out_buffer_doutA),
		.doutB(out_buffer_doutB),
		.source_ports(output_FIFO_mux),
		.sink_ports(out_to_next_stage)
); 

//opcode latch
logic wr_finish_iNTT;
logic wr_finish_init;
logic rd_finish_iNTT;
logic rd_finish_init;   //though init does not read previous stage, this is used to synchoronize with ROB

logic [`OPCODE_WIDTH - 1 : 0] opcode;
always_ff @(posedge clk) begin
	if(wr_finish_iNTT && wr_finish_init)
		opcode <= `SD opcode_in;
	else 
		opcode <= `SD opcode;
end
//output FIFO addr/data/wr_finish mux 
//word sel for init module
logic [`LINE_SIZE - 1 : 0]	word_selA_init [1 : 0];
logic [`LINE_SIZE - 1 : 0]	word_selB_init [1 : 0];
//word sel for iNTT module
logic [1 : 0] wr_enable;

always_comb begin
	if(opcode == `BOOTSTRAP_INIT) begin
		word_selA_mux[0] 				= word_selA_init[0];	 
		word_selB_mux[0] 				= word_selB_init[0];
		word_selA_mux[1] 				= word_selA_init[1];
		word_selB_mux[1] 				= word_selB_init[1];
		output_FIFO_mux[0].addrA 		= wr_addrA_init;
		output_FIFO_mux[0].addrB 		= wr_addrB_init;
		output_FIFO_mux[1].addrA 		= wr_addrA_init;
		output_FIFO_mux[1].addrB 		= wr_addrB_init;
		output_FIFO_mux[0].dA 			= dA_init;
		output_FIFO_mux[0].dB 			= dB_init;
		output_FIFO_mux[1].dA 			= dA_init;
		output_FIFO_mux[1].dB 			= dB_init;
		output_FIFO_mux[0].wr_finish 	= wr_finish_init;
		output_FIFO_mux[1].wr_finish 	= wr_finish_init;
	end else begin
		word_selA_mux[0] 				= {`LINE_SIZE{wr_enable[0]}};	 
		word_selB_mux[0] 				= {`LINE_SIZE{wr_enable[0]}};
		word_selA_mux[1] 				= {`LINE_SIZE{wr_enable[1]}};
		word_selB_mux[1] 				= {`LINE_SIZE{wr_enable[1]}};
		output_FIFO_mux[0].addrA 		= output_FIFO_iNTT[0].addrA;
		output_FIFO_mux[0].addrB 		= output_FIFO_iNTT[0].addrB;
		output_FIFO_mux[1].addrA 		= output_FIFO_iNTT[1].addrA;
		output_FIFO_mux[1].addrB 		= output_FIFO_iNTT[1].addrB;
		output_FIFO_mux[0].dA 			= output_FIFO_iNTT[0].dA;
		output_FIFO_mux[0].dB 			= output_FIFO_iNTT[0].dB;
		output_FIFO_mux[1].dA 			= output_FIFO_iNTT[1].dA;
		output_FIFO_mux[1].dB 			= output_FIFO_iNTT[1].dB;
		output_FIFO_mux[0].wr_finish 	= output_FIFO_iNTT[0].wr_finish;
		output_FIFO_mux[1].wr_finish 	= output_FIFO_iNTT[1].wr_finish;
	end
end


//input/output for the butterfly units
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] input_data_muxA;
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] input_data_muxB;
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] output_data_muxA;
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] output_data_muxB;

logic [`BIT_WIDTH - 1 : 0] iROU_entry_mux [0 : `LINE_SIZE - 1];

logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] mult_inputA, mult_inputA_q1;	//mult only contains 9 stage pipeline it, need to add two more to synchronize, one to the input of the mult, another to the output of the mult
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] mult_inputB, mult_inputB_q1;
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] mult_outputA_q1, mult_outputA;
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] mult_outputB_q1, mult_outputB;

pipeline #(.STAGE_NUM(1), .BIT_WIDTH(`BIT_WIDTH * `LINE_SIZE * 2)) mult_input_pipe(
	.clk(clk),
	.rstn(rstn),
	.pipe_in({mult_inputA, mult_inputB}),
	.pipe_out({mult_inputA_q1, mult_inputB_q1})
);

pipeline #(.STAGE_NUM(1), .BIT_WIDTH(`BIT_WIDTH * `LINE_SIZE * 2)) mult_output_pipe(
	.clk(clk),
	.rstn(rstn),
	.pipe_in({mult_outputA_q1, mult_outputB_q1}),
	.pipe_out({mult_outputA, mult_outputB})
);

genvar i;
generate 
	for(i = 0; i < `LINE_SIZE; i++) begin
		GS_butterfly butterfly(
					.clk(clk),
					.a(input_data_muxA[i * `BIT_WIDTH +: `BIT_WIDTH]),
					.b(input_data_muxB[i * `BIT_WIDTH +: `BIT_WIDTH]),
					.ROU_entry(iROU_entry_mux[i]),
					.q(config_ports.q),
					.m(config_ports.m),
					.k2(config_ports.k2),
					.outa(output_data_muxA[i * `BIT_WIDTH +: `BIT_WIDTH]),
					.outb(output_data_muxB[i * `BIT_WIDTH +: `BIT_WIDTH])
		);
	end
	for(i = 0; i < `LINE_SIZE; i++)begin
		mod_mult multiplierA(
			.clk(clk),
			.a(mult_inputA_q1[i * `BIT_WIDTH +: `BIT_WIDTH]),
			.b(config_ports.ilength),
			.q(config_ports.q),
			.m(config_ports.m),
			.k2(config_ports.k2),
			.out(mult_outputA_q1[i * `BIT_WIDTH +: `BIT_WIDTH])
		);
		mod_mult multiplierB(
			.clk(clk),
			.a(mult_inputB_q1[i * `BIT_WIDTH +: `BIT_WIDTH]),
			.b(config_ports.ilength),
			.q(config_ports.q),
			.m(config_ports.m),
			.k2(config_ports.k2),
			.out(mult_outputB_q1[i * `BIT_WIDTH +: `BIT_WIDTH])
		);
	end
endgenerate

//state machine related variables
typedef enum logic [5 : 0] {IDLE, RD0, RD1, RD0WR0, RD1WR1, WAIT1_RD0WR0, WAIT2_RD1WR1, WAIT3_RD0WR0, WAIT4_RD1WR1, WAIT5_RD0WR0, WAIT6_RD1WR1, WAIT7_RD0WR0, WAIT8_RD1WR1, WAIT9_RD0WR0, WAIT10_RD1WR1, WAIT11_RD0WR0, WAIT12_RD1WR1, WAIT13_RD0WR0, MULT_RD1WR1, MULT_RD0WR0, WAIT1_WR1, WAIT2_WR0, WAIT3_WR1, WAIT4_WR0, WAIT5_WR1, WAIT6_WR0, WAIT7_WR1, WAIT8_WR0, WAIT9_WR1, WAIT10_WR0, WAIT11_WR1, WAIT12_WR0, WAIT13_WR1} iNTT_states;
//states without any prefix are iNTT stages,
//states with WAIT prefix and both RD, WR, are transition states to wait for
//the iNTT pipeline to finish, 2 + 11, 2 for the read data pipeline, 11 for
//write data pipeline
//states with MULT prfix are mult states
//states with WAIT prefix and WR alone, are finishing states to wait for the
//mult pipeline to finish

iNTT_states state, next;
`ifndef FPGA_LESS_RST 
	logic [$clog2(`MAX_LEN) - 1 : 0]	rd_step;			//t
	logic [`ADDR_WIDTH - 1 : 0]			rd_addrA;
	logic [`ADDR_WIDTH - 1 : 0]			rd_addrB;
	logic [$clog2(`MAX_LEN) - 2 : 0] 	step_counter;//i, used to index rou table
	logic 								wr_addr_sel;
	logic [$clog2(`MAX_LEN) - 2 : 0] 	inner_counter;//inner loop counter j
`else
	logic [$clog2(`MAX_LEN) - 1 : 0]	rd_step 	= 1;			//t
	logic [`ADDR_WIDTH - 1 : 0]			rd_addrA	= 0;
	logic [`ADDR_WIDTH - 1 : 0]			rd_addrB	= 1;
	logic [$clog2(`MAX_LEN) - 2 : 0] 	step_counter = 0; //i, used to index rou table
	logic 								wr_addr_sel = 0;
	logic [$clog2(`MAX_LEN) - 2 : 0] 	inner_counter = 0;//inner loop counter j
`endif


logic [$clog2(`MAX_LEN) - 1 : 0] 	rou_base_addr, rou_base_addr_next;	//m
logic [$clog2(`MAX_LEN) - 1 : 0]	rd_step_next;			//t
logic [$clog2(`MAX_LEN) - 1 : 0]	wr_step, wr_step_q, wr_step_piped;			//delayed version of rd_step for write data mux
logic [$clog2(`MAX_LEN) - 1 : 0]	stepx2;						//t*2, used for read addr
logic [`ADDR_WIDTH - 1 : 0]			rd_addrA_next, rd_addrB_next;

logic [`ADDR_WIDTH - 1 : 0]			wr_addrA, wr_addrB;
logic [`ADDR_WIDTH - 1 : 0]			wr_addrA_q, wr_addrB_q;	//wr_addr needs to latch twice to accomdate the output reg of the FIFO
logic [`ADDR_WIDTH - 1 : 0]			wr_addrA_piped, wr_addrB_piped;	//pipelined signal, 7 stages

//logic rd_addr_sel, rd_addr_sel_next;	//this is actually not addr sel, but data sel
logic wr_addr_sel_next;
//logic rd_addr_sel_pipe;	//pipelined signal, 9 stages
logic wr_addr_sel_piped;	//pipelined signal, 9 stages
logic [$clog2(`MAX_LEN) - 2 : 0] step_counter_next;//i, used to index rou table
logic [$clog2(`MAX_LEN) - 2 : 0] inner_counter_next;//inner loop counter j

myFIFO_NTT_source_if output_FIFO_iNTT [1 : 0] ();

//to sync with the butterfly pipeline
pipeline #(.STAGE_NUM(11), .BIT_WIDTH(`ADDR_WIDTH * 2)) wr_addr_iNTT_pipe (
	.clk(clk),
	.rstn(rstn),
	.pipe_in({wr_addrA_q, wr_addrB_q}),
	.pipe_out({wr_addrA_piped, wr_addrB_piped})
);

pipeline #(.STAGE_NUM(11), .BIT_WIDTH(1)) wr_addr_sel_iNTT_pipe (
	.clk(clk),
	.rstn(rstn),
	.pipe_in(wr_addr_sel),
	.pipe_out(wr_addr_sel_piped)
);

pipeline #(.STAGE_NUM(11), .BIT_WIDTH($clog2(`MAX_LEN))) wr_step_pipe (
	.clk(clk),
	.rstn(rstn),
	.pipe_in(wr_step_q),
	.pipe_out(wr_step_piped)
);

assign stepx2 = rd_step << 1;

//output FIFO write enable signal
assign wr_enable[0] = ~wr_addr_sel_piped;
assign wr_enable[1] = wr_addr_sel_piped;
assign inner_rd_enable[0] = ~wr_addr_sel_piped; //en is applied to the output reg, so need to be delayed by one cycle, which makes it the same as wr_addr_sel
assign inner_rd_enable[1] = wr_addr_sel_piped;

//input FIFO addr assignment
assign input_FIFO[0].addrA = rd_addrA;
assign input_FIFO[0].addrB = rd_addrB;
assign input_FIFO[1].addrA = rd_addrA;
assign input_FIFO[1].addrB = rd_addrB;

//output FIFO addr assignment 
assign output_FIFO_iNTT[0].addrA = wr_addr_sel_piped ? rd_addrA : wr_addrA_piped;
assign output_FIFO_iNTT[0].addrB = wr_addr_sel_piped ? rd_addrB : wr_addrB_piped;
assign output_FIFO_iNTT[1].addrA = wr_addr_sel_piped ? wr_addrA_piped : rd_addrA;
assign output_FIFO_iNTT[1].addrB = wr_addr_sel_piped ? wr_addrB_piped : rd_addrB;

//output FIFO write finish
assign output_FIFO_iNTT[0].wr_finish = wr_finish_iNTT;
assign output_FIFO_iNTT[1].wr_finish = wr_finish_iNTT;

//input FIFO read finish
assign input_FIFO[0].rd_finish  = rd_finish_iNTT;   //no need to output rd_finish to the input FIFO when doing the init process, since init does not read in poly
assign input_FIFO[1].rd_finish  = rd_finish_iNTT;
assign rd_finish_ROB            = rd_finish_iNTT & rd_finish_init; //the rd_finish_ROB is the and of rd_finish_iNTT and rd_finish_init

//write input data and output data mux for butterfly 
always_comb begin
	case(wr_step_q)
		1: begin
			//input mux
			if(wr_addr_sel) begin
				for(integer i = 0; i < `LINE_SIZE; i++) begin
					if(i < `LINE_SIZE / 2) begin
						input_data_muxA[i * `BIT_WIDTH +: `BIT_WIDTH] = input_FIFO[1].dA[2 * i * `BIT_WIDTH +: `BIT_WIDTH];
						input_data_muxB[i * `BIT_WIDTH +: `BIT_WIDTH] = input_FIFO[1].dA[(2 * i + 1) * `BIT_WIDTH +: `BIT_WIDTH];
					end else begin
						input_data_muxA[i * `BIT_WIDTH +: `BIT_WIDTH] = input_FIFO[1].dB[2 * (i - `LINE_SIZE / 2) * `BIT_WIDTH +: `BIT_WIDTH];
						input_data_muxB[i * `BIT_WIDTH +: `BIT_WIDTH] = input_FIFO[1].dB[(2 * (i - `LINE_SIZE / 2) + 1)* `BIT_WIDTH +: `BIT_WIDTH];
					end
				end
			end else begin 
				for(integer i = 0; i < `LINE_SIZE; i++) begin
					if(i < `LINE_SIZE / 2) begin
						input_data_muxA[i * `BIT_WIDTH +: `BIT_WIDTH] = input_FIFO[0].dA[2 * i * `BIT_WIDTH +: `BIT_WIDTH];
						input_data_muxB[i * `BIT_WIDTH +: `BIT_WIDTH] = input_FIFO[0].dA[(2 * i + 1) * `BIT_WIDTH +: `BIT_WIDTH];
					end else begin
						input_data_muxA[i * `BIT_WIDTH +: `BIT_WIDTH] = input_FIFO[0].dB[2 * (i - `LINE_SIZE / 2) * `BIT_WIDTH +: `BIT_WIDTH];
						input_data_muxB[i * `BIT_WIDTH +: `BIT_WIDTH] = input_FIFO[0].dB[(2 * (i - `LINE_SIZE / 2) + 1)* `BIT_WIDTH +: `BIT_WIDTH];
					end
				end
			end
		end
		2: begin
			//input mux
			if(wr_addr_sel) begin
				for(integer i = 0; i < `LINE_SIZE; i++) begin
					if(`LINE_SIZE == 4) begin
						if(i < `LINE_SIZE / 2) begin
							input_data_muxA[i * `BIT_WIDTH +: `BIT_WIDTH] = out_buffer_doutA[1][i * `BIT_WIDTH +: `BIT_WIDTH];
							input_data_muxB[i * `BIT_WIDTH +: `BIT_WIDTH] = out_buffer_doutA[1][(i + 2) * `BIT_WIDTH +: `BIT_WIDTH];
                        end else begin
							input_data_muxA[i * `BIT_WIDTH +: `BIT_WIDTH] = out_buffer_doutB[1][(i - `LINE_SIZE / 2) * `BIT_WIDTH +: `BIT_WIDTH];
							input_data_muxB[i * `BIT_WIDTH +: `BIT_WIDTH] = out_buffer_doutB[1][((i - `LINE_SIZE / 2) + 2) * `BIT_WIDTH +: `BIT_WIDTH];
                        end
					end else begin
						input_data_muxA[i * `BIT_WIDTH +: `BIT_WIDTH] = out_buffer_doutA[1][i * `BIT_WIDTH +: `BIT_WIDTH];
						input_data_muxB[i * `BIT_WIDTH +: `BIT_WIDTH] = out_buffer_doutB[1][i * `BIT_WIDTH +: `BIT_WIDTH];
					end
				end
			end else begin 
				for(integer i = 0; i < `LINE_SIZE; i++) begin
					if(`LINE_SIZE == 4) begin
						if(i < `LINE_SIZE / 2) begin
							input_data_muxA[i * `BIT_WIDTH +: `BIT_WIDTH] = out_buffer_doutA[0][i * `BIT_WIDTH +: `BIT_WIDTH];
							input_data_muxB[i * `BIT_WIDTH +: `BIT_WIDTH] = out_buffer_doutA[0][(i + 2) * `BIT_WIDTH +: `BIT_WIDTH];
						end else begin
							input_data_muxA[i * `BIT_WIDTH +: `BIT_WIDTH] = out_buffer_doutB[0][(i - `LINE_SIZE / 2) * `BIT_WIDTH +: `BIT_WIDTH];
							input_data_muxB[i * `BIT_WIDTH +: `BIT_WIDTH] = out_buffer_doutB[0][((i - `LINE_SIZE / 2) + 2) * `BIT_WIDTH +: `BIT_WIDTH];
						end
					end else begin
						input_data_muxA[i * `BIT_WIDTH +: `BIT_WIDTH] = out_buffer_doutA[0][i * `BIT_WIDTH +: `BIT_WIDTH];
						input_data_muxB[i * `BIT_WIDTH +: `BIT_WIDTH] = out_buffer_doutB[0][i * `BIT_WIDTH +: `BIT_WIDTH];
					end
				end
			end
		end
		
		default: begin
			//input mux
			if(wr_addr_sel) begin
				input_data_muxA = out_buffer_doutA[1];
				input_data_muxB = out_buffer_doutB[1];
			end else begin
				input_data_muxA = out_buffer_doutA[0];
				input_data_muxB = out_buffer_doutB[0];
			end
		end
	endcase
end

always_comb begin
    case(wr_step_piped)
        1: begin
        	for(integer i = 0; i < `LINE_SIZE; i++) begin
				if(i < `LINE_SIZE / 2) begin
					output_FIFO_iNTT[1].dA[2 * i * `BIT_WIDTH +: `BIT_WIDTH]		= output_data_muxA[i * `BIT_WIDTH +: `BIT_WIDTH] ;
					output_FIFO_iNTT[1].dA[(2 * i + 1) * `BIT_WIDTH +: `BIT_WIDTH]	= output_data_muxB[i * `BIT_WIDTH +: `BIT_WIDTH] ;
				end else begin
					output_FIFO_iNTT[1].dB[2 * (i - `LINE_SIZE / 2) * `BIT_WIDTH +: `BIT_WIDTH]		    = output_data_muxA[i * `BIT_WIDTH +: `BIT_WIDTH];
					output_FIFO_iNTT[1].dB[(2 * (i - `LINE_SIZE / 2) + 1)* `BIT_WIDTH +: `BIT_WIDTH]	= output_data_muxB[i * `BIT_WIDTH +: `BIT_WIDTH];
				end
			end

			for(integer i = 0; i < `LINE_SIZE; i++) begin
				if(i < `LINE_SIZE / 2) begin
					 output_FIFO_iNTT[0].dA[2 * i * `BIT_WIDTH +: `BIT_WIDTH]			= output_data_muxA[i * `BIT_WIDTH +: `BIT_WIDTH];
					 output_FIFO_iNTT[0].dA[(2 * i + 1) * `BIT_WIDTH +: `BIT_WIDTH]	 	= output_data_muxB[i * `BIT_WIDTH +: `BIT_WIDTH];
				end else begin
					 output_FIFO_iNTT[0].dB[2 * (i - `LINE_SIZE / 2) * `BIT_WIDTH +: `BIT_WIDTH]	    = output_data_muxA[i * `BIT_WIDTH +: `BIT_WIDTH];
					 output_FIFO_iNTT[0].dB[(2 * (i - `LINE_SIZE / 2) + 1)* `BIT_WIDTH +: `BIT_WIDTH]	= output_data_muxB[i * `BIT_WIDTH +: `BIT_WIDTH];
				end
			end
        end
        2: begin
        	for(integer i = 0; i < `LINE_SIZE; i++) begin
				if(`LINE_SIZE == 4) begin
					if(i < `LINE_SIZE / 2) begin
						output_FIFO_iNTT[1].dA[i * `BIT_WIDTH +: `BIT_WIDTH]		= output_data_muxA[i * `BIT_WIDTH +: `BIT_WIDTH];
						output_FIFO_iNTT[1].dA[(i + 2) * `BIT_WIDTH +: `BIT_WIDTH]	= output_data_muxB[i * `BIT_WIDTH +: `BIT_WIDTH];
					end else begin
						output_FIFO_iNTT[1].dB[(i - `LINE_SIZE / 2) * `BIT_WIDTH +: `BIT_WIDTH]			= output_data_muxA[i * `BIT_WIDTH +: `BIT_WIDTH];
						output_FIFO_iNTT[1].dB[((i - `LINE_SIZE / 2) + 2) * `BIT_WIDTH +: `BIT_WIDTH]	= output_data_muxB[i * `BIT_WIDTH +: `BIT_WIDTH];
					end
				end else begin
					output_FIFO_iNTT[1].dA[i * `BIT_WIDTH +: `BIT_WIDTH] = output_data_muxA[i * `BIT_WIDTH +: `BIT_WIDTH];
					output_FIFO_iNTT[1].dB[i * `BIT_WIDTH +: `BIT_WIDTH] = output_data_muxB[i * `BIT_WIDTH +: `BIT_WIDTH];
				end
			end

			for(integer i = 0; i < `LINE_SIZE; i++) begin
				if(`LINE_SIZE == 4) begin
					if(i < `LINE_SIZE / 2) begin
						output_FIFO_iNTT[0].dA[i * `BIT_WIDTH +: `BIT_WIDTH]		= output_data_muxA[i * `BIT_WIDTH +: `BIT_WIDTH];
						output_FIFO_iNTT[0].dA[(i + 2) * `BIT_WIDTH +: `BIT_WIDTH] 	= output_data_muxB[i * `BIT_WIDTH +: `BIT_WIDTH];
					end else begin
						output_FIFO_iNTT[0].dB[(i - `LINE_SIZE / 2) * `BIT_WIDTH +: `BIT_WIDTH]		  = output_data_muxA[i * `BIT_WIDTH +: `BIT_WIDTH];
						output_FIFO_iNTT[0].dB[((i - `LINE_SIZE / 2) + 2) * `BIT_WIDTH +: `BIT_WIDTH] = output_data_muxB[i * `BIT_WIDTH +: `BIT_WIDTH];
					end
				end else begin
					output_FIFO_iNTT[0].dA[i * `BIT_WIDTH +: `BIT_WIDTH] = output_data_muxA[i * `BIT_WIDTH +: `BIT_WIDTH];
					output_FIFO_iNTT[0].dB[i * `BIT_WIDTH +: `BIT_WIDTH] = output_data_muxB[i * `BIT_WIDTH +: `BIT_WIDTH];
				end
			end
        end
        default: begin
        	case(state)
				MULT_RD0WR0, MULT_RD1WR1, WAIT1_WR1, WAIT2_WR0, WAIT3_WR1, WAIT4_WR0, WAIT5_WR1, WAIT6_WR0, WAIT7_WR1, WAIT8_WR0, WAIT9_WR1, WAIT10_WR0, WAIT11_WR1, WAIT12_WR0, WAIT13_WR1: begin
					output_FIFO_iNTT[1].dA = mult_outputA;
					output_FIFO_iNTT[1].dB = mult_outputB;
				end
				default: begin
					output_FIFO_iNTT[1].dA = output_data_muxA;
					output_FIFO_iNTT[1].dB = output_data_muxB;
				end
			endcase

			case(state)
				MULT_RD0WR0, MULT_RD1WR1, WAIT1_WR1, WAIT2_WR0, WAIT3_WR1, WAIT4_WR0, WAIT5_WR1, WAIT6_WR0, WAIT7_WR1, WAIT8_WR0, WAIT9_WR1, WAIT10_WR0, WAIT11_WR1, WAIT12_WR0, WAIT13_WR1: begin
					output_FIFO_iNTT[0].dA = mult_outputA;
					output_FIFO_iNTT[0].dB = mult_outputB;
				end
				default: begin
					output_FIFO_iNTT[0].dA = output_data_muxA;
					output_FIFO_iNTT[0].dB = output_data_muxB;
				end
			endcase
        end
    endcase
end

//multiplier input mux 
always_comb begin
	case(state)
		WAIT3_RD0WR0, WAIT4_RD1WR1, WAIT5_RD0WR0, WAIT6_RD1WR1, WAIT7_RD0WR0, WAIT8_RD1WR1, WAIT9_RD0WR0, WAIT10_RD1WR1, WAIT11_RD0WR0, WAIT12_RD1WR1, WAIT13_RD0WR0, MULT_RD0WR0, MULT_RD1WR1, WAIT1_WR1, WAIT2_WR0: begin
			if(wr_addr_sel) begin
				mult_inputA = out_buffer_doutA[1];	
				mult_inputB = out_buffer_doutB[1];	
			end else begin
				mult_inputA = out_buffer_doutA[0];	
				mult_inputB = out_buffer_doutB[0];	
			end
		end
		default: begin
			mult_inputA = 0;	
			mult_inputB = 0;	
		end
	endcase
end


logic [$clog2(`LINE_SIZE) - 1 : 0] irou_column_sel, irou_column_sel_q;	//used to latch the LSB of ROU addr for column decoder

//rou table decoder
always_ff @(posedge clk) begin
	if(!rstn) begin
		irou_column_sel   <= `SD 0;
		irou_column_sel_q <= `SD 0;
	end else begin
		irou_column_sel   <= `SD irou_addr[$clog2(`LINE_SIZE) - 1 : 0];	//latch the LSBs of irou addr
        irou_column_sel_q <= `SD irou_column_sel;
	end
end

always_comb begin
    for(integer i = 0; i < `LINE_SIZE; i++) begin
        iROU_entry_mux[i] = 0;
    end
	irou_addr = rou_base_addr + step_counter;
	case(wr_step_q)
		1: begin
			for(integer i = 0; i < `LINE_SIZE; i++) begin
				iROU_entry_mux[i] = irou_line[i * `BIT_WIDTH +: `BIT_WIDTH];
			end
		end
		2: begin
			for(integer i = 0; i < `LINE_SIZE / 2; i++) begin
	 			iROU_entry_mux[2*i] 	= irou_column_sel_q[$clog2(`LINE_SIZE) - 1] ? 
										irou_line[(`BIT_WIDTH * `LINE_SIZE / 2 + i *`BIT_WIDTH) +: `BIT_WIDTH] : irou_line[i * `BIT_WIDTH +: `BIT_WIDTH];
				iROU_entry_mux[2*i+1] 	= irou_column_sel_q[$clog2(`LINE_SIZE) - 1] ? 
										irou_line[(`BIT_WIDTH * `LINE_SIZE / 2 + i * `BIT_WIDTH) +: `BIT_WIDTH] : irou_line[i * `BIT_WIDTH +: `BIT_WIDTH];
			end
		end
		default: begin
			for(integer i = 0; i < `LINE_SIZE; i++) begin
				for(integer j = 0; j < `LINE_SIZE; j++) begin
					if(irou_column_sel_q == j)
						iROU_entry_mux[i] = irou_line[j * `BIT_WIDTH +: `BIT_WIDTH];
				end
			end
		end		
	endcase	

end

//main state machine
`ifndef FPGA_LESS_RST
	always_ff @(posedge clk) begin
		if(!rstn) begin
			state 			<= `SD IDLE;
			rou_base_addr	<= `SD config_ports.length >> 1;
			rd_step 		<= `SD 1;
			step_counter 	<= `SD 0;
			rd_addrA 		<= `SD 0;
			rd_addrB 		<= `SD 1;
			//rd_addr_sel 	<= `SD 0;	//this init value should be correct
			wr_addr_sel 	<= `SD 0;	//this init value should be correct
			inner_counter 	<= `SD 0;
		end else begin
			state 			<= `SD next;
			rou_base_addr	<= `SD rou_base_addr_next;
			rd_step	 		<= `SD rd_step_next;
			step_counter 	<= `SD step_counter_next;
			rd_addrA 		<= `SD rd_addrA_next;
			rd_addrB 		<= `SD rd_addrB_next;
			//rd_addr_sel 	<= `SD rd_addr_sel_next;
			wr_addr_sel 	<= `SD wr_addr_sel_next;
			inner_counter 	<= `SD inner_counter_next;
		end
		wr_step 		<= `SD rd_step;
		wr_step_q 		<= `SD wr_step;
		wr_addrA 		<= `SD rd_addrA;
		wr_addrB 		<= `SD rd_addrB;
		wr_addrA_q		<= `SD wr_addrA;
		wr_addrB_q 		<= `SD wr_addrB;
	end
`else
	always_ff @(posedge clk) begin
		if(!rstn) begin
			state 			<= `SD IDLE;
			rou_base_addr	<= `SD config_ports.length >> 1;
			//rd_addr_sel 	<= `SD 0;	//this init value should be correct
		end else begin
			state 			<= `SD next;
			rou_base_addr	<= `SD rou_base_addr_next;

		end
		rd_step	 		<= `SD rd_step_next;
		step_counter 	<= `SD step_counter_next;
		rd_addrA 		<= `SD rd_addrA_next;
		rd_addrB 		<= `SD rd_addrB_next;
		//rd_addr_sel 	<= `SD rd_addr_sel_next;
		wr_addr_sel 	<= `SD wr_addr_sel_next;
		inner_counter 	<= `SD inner_counter_next;
		wr_step 		<= `SD rd_step;
		wr_step_q 		<= `SD wr_step;
		wr_addrA 		<= `SD rd_addrA;
		wr_addrB 		<= `SD rd_addrB;
		wr_addrA_q		<= `SD wr_addrA;
		wr_addrB_q 		<= `SD wr_addrB;
	end
`endif

//state machine combinational logic
always_comb begin
	case(state)
		IDLE: begin
		//idle state, can also be viewed as first RD0 state
			if(!input_FIFO[0].empty && !input_FIFO[1].empty 
			&& !output_FIFO_mux[0].full && !output_FIFO_mux[1].full 
			&& (opcode_in != `BOOTSTRAP_INIT) && !ROB_empty_iNTT) begin
				next 				= RD1;
			end else begin
				next 				= IDLE;
			end
			rou_base_addr_next	= config_ports.length >> 1;
			rd_step_next   		= 1;
			step_counter_next 	= 0;
			rd_addrA_next 		= 0;
			rd_addrB_next       = 1;
			wr_addr_sel_next 	= 0;
			inner_counter_next 	= 0;
			rd_finish_iNTT 		= 1;
			irou_rd_en 			= 0;
			wr_finish_iNTT 		= 1;
		end
		RD0: begin
			next 				= RD1;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA;
			rd_addrB_next 		= rd_addrB;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= 0;
			rd_finish_iNTT 		= 0;
			irou_rd_en 			= 1;
			wr_finish_iNTT 		= 1;
		end
		RD1: begin
			//send the first rd addr for input FIFO1
			next 				= RD0WR0;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter + `LINE_SIZE;
			rd_addrA_next 		= rd_addrA + 2;
			rd_addrB_next 		= rd_addrB + 2;
			//rd_addr_sel_next 	= ~rd_addr_sel;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= 0;		
			rd_finish_iNTT 		= 0;
			irou_rd_en 			= 1;
			wr_finish_iNTT 		= 1;	//wr_finish_iNTT can be low or high, not matter
		end
		RD0WR0: begin
		//this state prepare the rdaddr for input 0, and write the result to output 0
			next 				= RD1WR1;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA;
			rd_addrB_next 		= rd_addrB;
			//rd_addr_sel_next 	= ~rd_addr_sel;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= wr_step_q[0] != 1'b1 ? 1 : 0;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 1;
            rd_step_next 		= rd_step;
		end
		RD1WR1: begin
		//this state prepare the rdaddr for input 1, and write the result to output 1
			if(rd_addrB == ((config_ports.length >> $clog2(`LINE_SIZE)) - 1)) begin
				if(rou_base_addr == 1) begin
					next 				= WAIT1_RD0WR0;
					rou_base_addr_next 	= rou_base_addr;
					step_counter_next 	= step_counter;
					rd_addrA_next 		= 0;
					rd_addrB_next 		= 1;
					rd_step_next 		= rd_step;
				end else begin
					next 				= RD0WR0;
					rou_base_addr_next 	= rou_base_addr >> 1;
					step_counter_next 	= 0;
					rd_addrA_next 		= 0;
					rd_addrB_next 		= |stepx2[$clog2(`MAX_LEN) - 1 : $clog2(`LINE_SIZE)] ? stepx2[$clog2(`MAX_LEN) - 1 : $clog2(`LINE_SIZE)] : 1;
					rd_step_next 		= rd_step << 1;
				end
				inner_counter_next 	= 0;
			end else begin
				next 				= RD0WR0;
				rou_base_addr_next 	= rou_base_addr;
				// this part only support `LINE_SIZE = 2 or 4	
				case(rd_step) 
					1: 			step_counter_next = step_counter + `LINE_SIZE;
					2: 			step_counter_next = step_counter + `LINE_SIZE/2;
					default: 	step_counter_next = inner_counter == rd_step - `LINE_SIZE ? step_counter + 1 : step_counter;
				endcase
				rd_addrA_next 		= rd_step <= `LINE_SIZE ? rd_addrA + 2 : 
										inner_counter == rd_step - `LINE_SIZE ? rd_addrA + rd_step[$clog2(`MAX_LEN) - 1: $clog2(`LINE_SIZE)] + 1 : rd_addrA + 1;	
				rd_addrB_next 		= rd_step <= `LINE_SIZE ? rd_addrB + 2 : 
										inner_counter == rd_step - `LINE_SIZE ? rd_addrB + rd_step[$clog2(`MAX_LEN) - 1: $clog2(`LINE_SIZE)] + 1 : rd_addrB + 1;	
				inner_counter_next 	= rd_step <= `LINE_SIZE ? 0 : 
									    inner_counter == rd_step - `LINE_SIZE ? 0 : inner_counter + `LINE_SIZE;  
				rd_step_next 		= rd_step;
			end
			//rd_addr_sel_next 	= ~rd_addr_sel;
			wr_addr_sel_next 	= ~wr_addr_sel;
			rd_finish_iNTT 		= wr_step_q[0] != 1'b1 ? 1 : 0;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 1;
		end
		WAIT1_RD0WR0: begin
		//intermediate state to clean up the Butterfly pipeline, and put data
		//into the mult pipeline, this state write the last addr of iNTT a into
		//the pipeline
			next 				= WAIT2_RD1WR1;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA;
			rd_addrB_next 		= rd_addrB;
			//rd_addr_sel_next 	= ~rd_addr_sel;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 1;
		end
		WAIT2_RD1WR1: begin
		//intermediate state to clean up the Butterfly pipeline, and put data
		//into the mult pipeline, this state write the last addr of iNTT
		//b into the pipeline
			next 				= WAIT3_RD0WR0;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA + 2;
			rd_addrB_next 		= rd_addrB + 2;
			//rd_addr_sel_next 	= ~rd_addr_sel;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 1;
		end
		WAIT3_RD0WR0: begin
		//intermediate state to clean up the Butterfly pipeline, and put data
		//into the mult pipeline
			next 				= WAIT4_RD1WR1;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA;
			rd_addrB_next 		= rd_addrB;
			//rd_addr_sel_next 	= ~rd_addr_sel;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		WAIT4_RD1WR1: begin
		//intermediate state to clean up the Butterfly pipeline, and put data
		//into the mult pipeline
			next 				= WAIT5_RD0WR0;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA + 2;
			rd_addrB_next 		= rd_addrB + 2;
			//rd_addr_sel_next 	= ~rd_addr_sel;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		WAIT5_RD0WR0: begin
		//intermediate state to clean up the Butterfly pipeline, and put data
		//into the mult pipeline
			next 				= WAIT6_RD1WR1;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA;
			rd_addrB_next 		= rd_addrB;
			//rd_addr_sel_next 	= ~rd_addr_sel;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		WAIT6_RD1WR1: begin
		//intermediate state to clean up the Butterfly pipeline, and put data
		//into the mult pipeline
			next 				= WAIT7_RD0WR0;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA + 2;
			rd_addrB_next 		= rd_addrB + 2;
			//rd_addr_sel_next 	= ~rd_addr_sel;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		WAIT7_RD0WR0: begin
		//intermediate state to clean up the Butterfly pipeline, and put data
		//into the mult pipeline
			next 				= WAIT8_RD1WR1;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA;
			rd_addrB_next 		= rd_addrB;
			//rd_addr_sel_next 	= ~rd_addr_sel;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		WAIT8_RD1WR1: begin
		//intermediate state to clean up the Butterfly pipeline, and put data
		//into the mult pipeline
			next 				= WAIT9_RD0WR0;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA + 2;
			rd_addrB_next 		= rd_addrB + 2;
			//rd_addr_sel_next 	= ~rd_addr_sel;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		WAIT9_RD0WR0: begin
		//intermediate state to clean up the Butterfly pipeline, and put data
		//into the mult pipeline
			next 				= WAIT10_RD1WR1;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA;
			rd_addrB_next 		= rd_addrB;
			//rd_addr_sel_next 	= ~rd_addr_sel;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		WAIT10_RD1WR1: begin
		//intermediate state to clean up the Butterfly pipeline, and put data
		//into the mult pipeline
			next 				= WAIT11_RD0WR0;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA + 2;
			rd_addrB_next 		= rd_addrB + 2;
			//rd_addr_sel_next 	= ~rd_addr_sel;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		WAIT11_RD0WR0: begin
		//intermediate state to clean up the Butterfly pipeline, and put data
		//into the mult pipeline
			next 				= WAIT12_RD1WR1;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA;
			rd_addrB_next 		= rd_addrB;
			//rd_addr_sel_next 	= ~rd_addr_sel;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		WAIT12_RD1WR1: begin
		//intermediate state to clean up the Butterfly pipeline, and put data
		//into the mult pipeline
			next 				= WAIT13_RD0WR0;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA + 2;
			rd_addrB_next 		= rd_addrB + 2;
			//rd_addr_sel_next 	= ~rd_addr_sel;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		WAIT13_RD0WR0: begin
		//intermediate state to clean up the Butterfly pipeline, and put data
		//into the mult pipeline
			next 				= MULT_RD1WR1;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA;
			rd_addrB_next 		= rd_addrB;
			//rd_addr_sel_next 	= ~rd_addr_sel;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		MULT_RD1WR1: begin
		//this state prepare the rdaddr for input 1, and write the result to output 1
			if(rd_addrB == ((config_ports.length >> $clog2(`LINE_SIZE)) - 1)) begin
				next 				= WAIT1_WR1;
				rd_addrA_next 		= rd_addrA;
				rd_addrB_next 		= rd_addrB;
			end else begin
				next 				= MULT_RD0WR0;
				rd_addrA_next 		= rd_addrA + 2;
				rd_addrB_next 		= rd_addrB + 2;
			end
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			//rd_addr_sel_next 	= ~rd_addr_sel;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		MULT_RD0WR0: begin
		//this state prepare the rdaddr for input 0, and write the result to output 1
			next 				= MULT_RD1WR1;
			rd_addrA_next 		= rd_addrA;
			rd_addrB_next 		= rd_addrB;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			//rd_addr_sel_next 	= ~rd_addr_sel;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		WAIT1_WR1: begin
		//this state write the last result to output 1
			next 				= WAIT2_WR0;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA;
			rd_addrB_next 		= rd_addrB;
			//rd_addr_sel_next	= 1;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		WAIT2_WR0: begin
		//this state write the last result to output 1
			next 				= WAIT3_WR1;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA;
			rd_addrB_next 		= rd_addrB;
			//rd_addr_sel_next	= 1;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		WAIT3_WR1: begin
		//this state write the last result to output 1
			next 				= WAIT4_WR0;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA;
			rd_addrB_next 		= rd_addrB;
			//rd_addr_sel_next	= 1;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		WAIT4_WR0: begin
		//this state write the last result to output 1
			next 				= WAIT5_WR1;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA;
			rd_addrB_next 		= rd_addrB;
			//rd_addr_sel_next	= 1;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		WAIT5_WR1: begin
		//this state write the last result to output 1
			next 				= WAIT6_WR0;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA;
			rd_addrB_next 		= rd_addrB;
			//rd_addr_sel_next	= 1;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		WAIT6_WR0: begin
		//this state write the last result to output 1
			next 				= WAIT7_WR1;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA;
			rd_addrB_next 		= rd_addrB;
			//rd_addr_sel_next	= 1;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		WAIT7_WR1: begin
		//this state write the last result to output 1
			next 				= WAIT8_WR0;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA;
			rd_addrB_next 		= rd_addrB;
			//rd_addr_sel_next	= 1;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		WAIT8_WR0: begin
		//this state write the last result to output 1
			next 				= WAIT9_WR1;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA;
			rd_addrB_next 		= rd_addrB;
			//rd_addr_sel_next	= 1;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		WAIT9_WR1: begin
		//this state write the last result to output 1
			next 				= WAIT10_WR0;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA;
			rd_addrB_next 		= rd_addrB;
			//rd_addr_sel_next	= 1;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		WAIT10_WR0: begin
		//this state write the last result to output 1
			next 				= WAIT11_WR1;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA;
			rd_addrB_next 		= rd_addrB;
			//rd_addr_sel_next	= 1;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		WAIT11_WR1: begin
		//this state write the last result to output 1
			next 				= WAIT12_WR0;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA;
			rd_addrB_next 		= rd_addrB;
			//rd_addr_sel_next	= 1;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		WAIT12_WR0: begin
		//this state write the last result to output 1
			next 				= WAIT13_WR1;
			rou_base_addr_next 	= rou_base_addr;
			rd_step_next 		= rd_step;
			step_counter_next 	= step_counter;
			rd_addrA_next 		= rd_addrA;
			rd_addrB_next 		= rd_addrB;
			//rd_addr_sel_next	= 1;
			wr_addr_sel_next 	= ~wr_addr_sel;
			inner_counter_next 	= inner_counter;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 0;
			irou_rd_en 			= 0;
		end
		WAIT13_WR1: begin
		//this state write the last result to output 1
			next 				= IDLE;
			rou_base_addr_next 	= config_ports.length >> 1;
			rd_step_next 		= 1;
			step_counter_next 	= 0;
			rd_addrA_next 		= 0;
			rd_addrB_next 		= 1;
			//rd_addr_sel_next	= 1;
			wr_addr_sel_next 	= 0;
			inner_counter_next 	= 0;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 1;
			irou_rd_en 			= 0;
		end
		default: begin
			next 				= IDLE;
			rou_base_addr_next	= config_ports.length >> 1;
			rd_step_next      		= 1;
			step_counter_next 	= 0;
			rd_addrA_next 		= 0;
			rd_addrB_next       = 1;
			//rd_addr_sel_next 	= 1;
			wr_addr_sel_next 	= 0;
			inner_counter_next 	= 0;
			rd_finish_iNTT 		= 1;
			wr_finish_iNTT 		= 1;
			irou_rd_en 			= 0;
		end
	endcase
end



//the init module of the bootstrap process
typedef enum logic [1 : 0] {INIT_IDLE, ZEROFILL, INIT} init_states;

init_states init_state, init_next;
logic [`ADDR_WIDTH - 1 : 0] wr_addrA_init;
logic [`ADDR_WIDTH - 1 : 0] wr_addrB_init; 
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] dA_init;
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] dB_init;

logic [$clog2(`MAX_LEN) - 1 : 0] index, index_next;	//this is the loop counter for the init process
logic [`LWE_BIT_WIDTH + 4 - 1 : 0] i_mult_embed;	// index * embed_factor
logic [`LWE_BIT_WIDTH - 1 : 0] init_coefficient;

			
logic [`BIT_WIDTH - 1 : 0] q8;	//q/8
logic [`BIT_WIDTH - 1 : 0] negq8;	//q-q/8

logic [`LWE_BIT_WIDTH - 1 : 0] value_q, value_q_next;
logic [`LWE_BIT_WIDTH - 1 : 0] bound1_q, bound1_q_next;
logic [`LWE_BIT_WIDTH - 1 : 0] bound2_q, bound2_q_next;

assign q8 = (config_ports.q >> 3) + 1;
assign negq8 = config_ports.q - q8;

//assign i_mult_embed 		= index * config_ports.embed_factor;
always_comb begin
    case(config_ports.embed_factor)
        2: i_mult_embed = index << 1;
        4: i_mult_embed = index << 2;
        8: i_mult_embed = index << 3;
        default: i_mult_embed = 0;
    endcase
end
assign init_coefficient 	= (value_q - index) & config_ports.lwe_q_mask;//this the tmp in software


always_ff @(posedge clk) begin
	if(!rstn) begin
		init_state 		<= `SD INIT_IDLE;
		index 			<= `SD 0;
		value_q 		<= `SD 0;
		bound1_q 		<= `SD 0;
		bound2_q 		<= `SD 0;
	end else begin
		init_state 		<= `SD init_next;
		index 			<= `SD index_next;
		value_q 		<= `SD value_q_next;
		bound1_q 		<= `SD bound1_q_next;
		bound2_q 		<= `SD bound2_q_next;
	end
end


always_comb begin
	case(init_state)
		INIT_IDLE: begin
			if((opcode_in == `BOOTSTRAP_INIT) && !output_FIFO_mux[0].full && !output_FIFO_mux[1].full && !ROB_empty_iNTT) begin
				init_next 			= ZEROFILL;
				//index_next 			= index + `LINE_SIZE * 2; 

//				word_selA_init[0] 	= {`LINE_SIZE{1'b1}};
//				word_selB_init[0] 	= {`LINE_SIZE{1'b1}};
//				word_selA_init[1] 	= {`LINE_SIZE{1'b1}};
//				word_selB_init[1] 	= {`LINE_SIZE{1'b1}};
				//wr_finish_init 		= 0;
				rd_finish_init 		= 0;
			end else begin
				init_next 			= INIT_IDLE;
				rd_finish_init 		= 1;
			end
			index_next 			= 0;
			word_selA_init[0] 	= {`LINE_SIZE{1'b0}};
			word_selB_init[0] 	= {`LINE_SIZE{1'b0}};
			word_selA_init[1] 	= {`LINE_SIZE{1'b0}};
			word_selB_init[1] 	= {`LINE_SIZE{1'b0}};			
			wr_finish_init 		= 1;
			wr_addrA_init		= index[$clog2(`LINE_SIZE) +: `ADDR_WIDTH];
			wr_addrB_init		= index[$clog2(`LINE_SIZE) +: `ADDR_WIDTH] + 1;
			dA_init 			= 0;
			dB_init 			= 0;
			value_q_next 		= init_value;
			bound1_q_next 		= bound1;
			bound2_q_next 		= bound2;
		end
		ZEROFILL: begin
			if(index == (config_ports.length - `LINE_SIZE * 2)) begin
				init_next 			= INIT;
				index_next 			= 0;
			end else begin
				init_next 			= ZEROFILL;
				index_next 			= index + `LINE_SIZE * 2;	
			end
			wr_addrA_init		= index[$clog2(`LINE_SIZE) +: `ADDR_WIDTH];
			wr_addrB_init		= index[$clog2(`LINE_SIZE) +: `ADDR_WIDTH] + 1;
			dA_init 			= 0;
			dB_init 			= 0;
			word_selA_init[0] 	= {`LINE_SIZE{1'b1}};
			word_selB_init[0] 	= {`LINE_SIZE{1'b1}};
			word_selA_init[1] 	= {`LINE_SIZE{1'b1}};
			word_selB_init[1] 	= {`LINE_SIZE{1'b1}};
			wr_finish_init 		= 0;
			rd_finish_init 		= 1;
			value_q_next 		= value_q;
			bound1_q_next 		= bound1_q;
			bound2_q_next 		= bound2_q;
		end 
		INIT: begin
			if(index == (config_ports.lwe_q_mask >> 1)) begin	//check index == q/2 - 1 = (q - 1 ) / 2
				init_next 			= INIT_IDLE;
				index_next 			= 0;
			    wr_finish_init      = 1;
			end else begin
				init_next 			= INIT;
				index_next 			= index + 1;
			    wr_finish_init      = 0;
			end
			rd_finish_init 		= 1;
			wr_addrA_init		= i_mult_embed[$clog2(`LINE_SIZE) +: `ADDR_WIDTH];	//only write on port A of poly b
			wr_addrB_init		= 0;

			for(integer i = 0; i < `LINE_SIZE; i++)begin
				if(i_mult_embed[$clog2(`LINE_SIZE) - 1 : 0] == i) begin
					if(bound1_q < bound2_q)
						dA_init[i*`BIT_WIDTH +: `BIT_WIDTH] = init_coefficient >= bound1_q && init_coefficient < bound2_q ? negq8 : q8;
					else 
						dA_init[i*`BIT_WIDTH +: `BIT_WIDTH] = init_coefficient >= bound2_q && init_coefficient < bound1_q ? q8 : negq8;
					word_selA_init[1][i] = 1;
				end else begin
					dA_init[i*`BIT_WIDTH +: `BIT_WIDTH] = 0;
					word_selA_init[1][i] = 0;
				end
			end

			dB_init = 0;
			word_selA_init[0] 	= {`LINE_SIZE{1'b0}};
			word_selB_init[0] 	= {`LINE_SIZE{1'b0}};
			word_selB_init[1] 	= {`LINE_SIZE{1'b0}};
			
			value_q_next 		= value_q;
			bound1_q_next 		= bound1_q;
			bound2_q_next 		= bound2_q;
		end
		default: begin
			init_next 			= INIT_IDLE;
			index_next 			= 0;

			word_selA_init[0] 	= {`LINE_SIZE{1'b0}};
			word_selB_init[0] 	= {`LINE_SIZE{1'b0}};
			word_selA_init[1] 	= {`LINE_SIZE{1'b0}};
			word_selB_init[1] 	= {`LINE_SIZE{1'b0}};
			wr_finish_init 		= 1;
			rd_finish_init 		= 1;

			wr_addrA_init		= index[$clog2(`LINE_SIZE) +: `ADDR_WIDTH];
			wr_addrB_init		= index[$clog2(`LINE_SIZE) +: `ADDR_WIDTH] + 1;
			dA_init 			= 0;
			dB_init 			= 0;
			value_q_next 		= init_value;
			bound1_q_next 		= bound1;
			bound2_q_next 		= bound2;
		end
	endcase
end

assert property (@(posedge clk) !(!rstn && state != IDLE && init_state != INIT_IDLE));

endmodule
