`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2021 03:28:24 PM
// Design Name: 
// Module Name: NTT_leading_stage
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: this module can function as the first stage of the NTT module, 
// 				it needs to process extrainformation, so it is different from other stages. 
// 				It can also	work as a normal NTT stage.
// 				This now incorporates a 9 stage pipeline.
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "common.vh"
module NTT_leading_stage #(
	parameter STAGE_NUM = 10,
	parameter NTT_STEP = 2**STAGE_NUM,
    parameter STEP = NTT_STEP/ `LINE_SIZE	//buffer line step
)(
    input clk, rstn,
	
	//to preceding FIFO
    myFIFO_NTT_sink_if.to_FIFO input_FIFO,
	//to next NTT stage
	myFIFO_NTT_sink_if.to_sink out_to_next_stage,

	config_if.to_top config_ports,
	
	input ROB_empty_NTT, 

	ROU_config_if.to_axil_bar1 rou_wr_port
);

typedef enum logic [3 : 0] {IDLE_RD1, COMPUTE, WR1, WR2, WAIT1_WR, WAIT2_WR, WAIT3_WR, WAIT4_WR, WAIT5_WR, WAIT6_WR, WAIT7_WR, WAIT8_WR, WAIT9_WR, WAIT10_WR, WAIT11_WR, WAIT_RD1} NTT_states;

logic is_leading_stage;	//this show whether this stage the actual leading stage, for example, if length is 2048, then stage 9 is not leading stage, but if length is 1024, the stage 9 is leading stage, this is to comply with variable sequence length
`ifndef FPGA_LESS_RST
	logic 	[`ADDR_WIDTH -1 : 0] 	rd_addrA;
	logic 	[`ADDR_WIDTH -1 : 0] 	rd_addrB;
	//logic 	[`RLWE_ID_WIDTH - 1 : 0] 	rlwe_id;
	//logic 	[`POLY_ID_WIDTH - 1 : 0] 	poly_id;
	//logic 	[`OPCODE_WIDTH - 1 : 0] 	opcode;
	logic 	[$clog2(`MAX_LEN / `LINE_SIZE) - 1 : 0]		step_counter;  

`else
	logic 	[`ADDR_WIDTH -1 : 0] 	rd_addrA = 0;
	logic 	[`ADDR_WIDTH -1 : 0] 	rd_addrB = STEP;
	//logic 	[`RLWE_ID_WIDTH - 1 : 0] 	rlwe_id, rlwe_id_next;
	//logic 	[`POLY_ID_WIDTH - 1 : 0] 	poly_id, poly_id_next;
	//logic 	[`OPCODE_WIDTH - 1 : 0] 	opcode,	opcode_next;
	logic 	[$clog2(`MAX_LEN / `LINE_SIZE) - 1 : 0]		step_counter = 0;  
`endif

logic 	[`ADDR_WIDTH -1 : 0] 	rd_addrA_next;
logic 	[`ADDR_WIDTH -1 : 0] 	rd_addrB_next;
logic 	[`ADDR_WIDTH -1 : 0] 	wr_addrA;//pipelined addr for synchronization
logic 	[`ADDR_WIDTH -1 : 0] 	wr_addrB;
logic 	[`ADDR_WIDTH -1 : 0] 	wr_addrA_q, wr_addrA_piped;//pipelined addr for synchronization
logic 	[`ADDR_WIDTH -1 : 0] 	wr_addrB_q, wr_addrB_piped;
//logic 	[`RLWE_ID_WIDTH - 1 : 0] 	rlwe_id, rlwe_id_next;
//logic 	[`POLY_ID_WIDTH - 1 : 0] 	poly_id, poly_id_next;
//logic 	[`OPCODE_WIDTH - 1 : 0] 	opcode,	opcode_next;
logic 	[$clog2(`MAX_LEN / `LINE_SIZE) - 1 : 0]		step_counter_next;  


assign is_leading_stage = config_ports.length[STAGE_NUM + 1];

//wr addr sync pipe line
pipeline #(.STAGE_NUM(11), .BIT_WIDTH(`ADDR_WIDTH * 2)) wr_addr_pipe(
	.clk(clk),
	.rstn(rstn),
	.pipe_in({wr_addrA_q, wr_addrB_q}),
	.pipe_out({wr_addrA_piped, wr_addrB_piped})
);

myFIFO_NTT_source_if output_FIFO();

assign input_FIFO.addrA 	= rd_addrA;
assign input_FIFO.addrB 	= rd_addrB;
assign output_FIFO.addrA 	= wr_addrA_piped;
assign output_FIFO.addrB 	= wr_addrB_piped;

assign output_FIFO.rlwe_id = input_FIFO.rlwe_id;
assign output_FIFO.poly_id = input_FIFO.poly_id;
assign output_FIFO.opcode = input_FIFO.opcode;

NTT_states state, next;

myFIFO_NTT out_buffer(
    .clk(clk),
    .rstn(rstn),
    .source_ports(output_FIFO),
    .sink_ports(out_to_next_stage)
);


ROU_table_if #(.STAGE_NUM(STAGE_NUM)) local_rou_table();

logic rou_rd_en;	// rou read enable

assign local_rou_table.en = rou_rd_en | (|rou_wr_port.we);

ROU_buffer #(.STAGE_NUM(STAGE_NUM)) local_rou( 
    .clk(clk), 
    .wr_port(rou_wr_port),
	.rd_port(local_rou_table)	//read interface for NTT_stage
); 

logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] shifted_dA;
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] shifted_dB;
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] masked_dA;
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] masked_dB;

logic [5 : 0] shift_step;	//to shift the input, equivalent to divide

logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] input_data_muxA;	//mask input when the stage is at the forefront
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] input_data_muxB;

assign input_data_muxA 	= is_leading_stage && !(input_FIFO.poly_id == `POLY_B && input_FIFO.opcode == `RLWESUBS) ? masked_dA : input_FIFO.dA;
assign input_data_muxB 	= is_leading_stage && !(input_FIFO.poly_id == `POLY_B && input_FIFO.opcode == `RLWESUBS) ? masked_dB : input_FIFO.dB;

genvar i;
generate 
	for(i = 0; i < `LINE_SIZE; i++) begin
		shifter #(`BIT_WIDTH) shifterA (
			.k({1'b0, shift_step}),
			.in(input_FIFO.dA[i * `BIT_WIDTH +: `BIT_WIDTH]),
			.out(shifted_dA[i * `BIT_WIDTH +: `BIT_WIDTH])
		);
		shifter #(`BIT_WIDTH) shifterB (
			.k({1'b0, shift_step}),
			.in(input_FIFO.dB[i * `BIT_WIDTH +: `BIT_WIDTH]),
			.out(shifted_dB[i * `BIT_WIDTH +: `BIT_WIDTH])
		);
	end

	for(i = 0; i < `LINE_SIZE; i++) begin
		assign masked_dA[i * `BIT_WIDTH +: `BIT_WIDTH] = shifted_dA[i * `BIT_WIDTH +: `BIT_WIDTH] & config_ports.BG_mask;
		assign masked_dB[i * `BIT_WIDTH +: `BIT_WIDTH] = shifted_dB[i * `BIT_WIDTH +: `BIT_WIDTH] & config_ports.BG_mask;
	end

	for(i = 0; i < `LINE_SIZE; i++) begin
		CT_butterfly butterfly(
			.clk(clk),
			.a(input_data_muxA[i * `BIT_WIDTH +: `BIT_WIDTH]),
			.b(input_data_muxB[i * `BIT_WIDTH +: `BIT_WIDTH]),
			.ROU_entry(local_rou_table.ROU_entry),
			.q(config_ports.q),
			.m(config_ports.m),
			.k2(config_ports.k2),
			.outa(output_FIFO.dA[i * `BIT_WIDTH +: `BIT_WIDTH]),
			.outb(output_FIFO.dB[i * `BIT_WIDTH +: `BIT_WIDTH]));
	end
endgenerate 

logic 	[STAGE_NUM - $clog2(`LINE_SIZE) - 1 : 0] 	t;			//inner loop counter
logic 	[$clog2(`MAX_LEN) - STAGE_NUM - 1 : 0]		ROU_idx; 	//ROU table idx

`ifndef FPGA_LESS_RST
	logic 	[4 : 0]										poly_counter;	//used to count the number of poly decomposed
`else
	logic 	[4 : 0]										poly_counter = 0;	//used to count the number of poly decomposed
`endif

logic 	[4 : 0]										poly_counter_next;	//used to count the number of poly decomposed

logic 	[4 : 0]										poly_counter_q1, poly_counter_q2;	//used to count the number of poly decomposed

//logic 	[`BIT_WIDTH - 1 : 0]						data_mask, data_mask_next;

assign shift_step = poly_counter_q2 * config_ports.BG_width;

assign local_rou_table.addr = ROU_idx;
assign {ROU_idx, t} = step_counter;

`ifndef FPGA_LESS_RST 
	always_ff @(posedge clk) begin
		if(!rstn) begin
			state 			<= `SD IDLE_RD1;
			rd_addrA 		<= `SD 0;
			rd_addrB 		<= `SD STEP;
			//rlwe_id 		<= `SD 0;
			step_counter 	<= `SD 0;
			poly_counter 	<= `SD 0;
			//data_mask 	<= config_ports.BG_mask;
		end else begin
			state 			<= `SD next;
			rd_addrA 		<= `SD rd_addrA_next;
			rd_addrB 		<= `SD rd_addrB_next;
			//rlwe_id 		<= `SD rlwe_id_next;
			step_counter 	<= `SD step_counter_next;
			poly_counter 	<= `SD poly_counter_next;
			//data_mask 	<= data_mask_next;
		end
		wr_addrA 		<= `SD rd_addrA;
		wr_addrB 		<= `SD rd_addrB;
		wr_addrA_q 		<= `SD wr_addrA;
		wr_addrB_q 		<= `SD wr_addrB;
		poly_counter_q1	<= `SD poly_counter;
		poly_counter_q2	<= `SD poly_counter_q1;
	end
`else 
	always_ff @(posedge clk) begin
		if(!rstn) begin
			state 			<= `SD IDLE_RD1;
		end else begin
			state 			<= `SD next;
		end
		wr_addrA 		<= `SD rd_addrA;
		wr_addrB 		<= `SD rd_addrB;
		wr_addrA_q 		<= `SD wr_addrA;
		wr_addrB_q 		<= `SD wr_addrB;
		poly_counter_q1	<= `SD poly_counter;
		poly_counter_q2	<= `SD poly_counter_q1;
		rd_addrA 		<= `SD rd_addrA_next;
		rd_addrB 		<= `SD rd_addrB_next;
		step_counter 	<= `SD step_counter_next;
		poly_counter 	<= `SD poly_counter_next;
	end
`endif

always_comb begin
	case(state)
		IDLE_RD1: begin
			if(!input_FIFO.empty && !output_FIFO.full && !(ROB_empty_NTT && is_leading_stage)) begin
				next 					= COMPUTE;
				input_FIFO.rd_finish 	= 0;
				rd_addrA_next 			= rd_addrA + 1;
				rd_addrB_next 			= rd_addrB + 1;
				step_counter_next 		= step_counter + 1;
				//rlwe_id_next = input_FIFO.rlwe_id; 
				//poly_id_next = input_FIFO.poly_id; 
				//opcode_next = input_FIFO._id; 
				//data_mask_next = data_mask;
				rou_rd_en 				= 1;
			end else begin
				next 					= IDLE_RD1;
				input_FIFO.rd_finish 	= 1;
				rd_addrA_next 			= 0;
				rd_addrB_next 			= STEP;
				step_counter_next 		= 0;
				//rlwe_id_next = 0;
				//data_mask_next = config_ports.BG_mask;	
				rou_rd_en 				= 0;
			end
			output_FIFO.wr_finish 	= 1;
			poly_counter_next = 0;
		end
		COMPUTE: begin
			if(rd_addrB == ((config_ports.length >> $clog2(`LINE_SIZE)) - 1)) begin
				next 					= WR1;
				input_FIFO.rd_finish 	= 0;
				rd_addrA_next 			= 0;
				rd_addrB_next 			= STEP;
				output_FIFO.wr_finish 	= 0;
				step_counter_next 		= 0;
			end else begin
				if(t == STEP - 1) begin
					rd_addrA_next 	= rd_addrA + STEP + 1;
					rd_addrB_next 	= rd_addrB + STEP + 1;
				end else begin
					rd_addrA_next 	= rd_addrA + 1;
					rd_addrB_next 	= rd_addrB + 1;
				end 
				next 					= COMPUTE;
				input_FIFO.rd_finish 	= 0;
				step_counter_next 		= step_counter + 1;
				output_FIFO.wr_finish 	= 0;
			end
			poly_counter_next 		= poly_counter;
			rou_rd_en 				= 1;
		end	
		WR1: begin 
			next 					= WR2;
			input_FIFO.rd_finish 	= 0;
			rd_addrA_next 			= 0;
			rd_addrB_next 			= STEP;
			step_counter_next 		= 0;
			output_FIFO.wr_finish 	= 0;
			poly_counter_next 		= poly_counter;
			rou_rd_en 				= 1;
		end 
		WR2: begin 
			next 					= WAIT1_WR;
			input_FIFO.rd_finish 	= 0;
			rd_addrA_next 			= 0;
			rd_addrB_next 			= STEP;
			step_counter_next 		= 0;
			output_FIFO.wr_finish 	= 0;
			poly_counter_next 		= poly_counter;
			rou_rd_en 				= 1;
		end 
		WAIT1_WR: begin
			next 					= WAIT2_WR;
			input_FIFO.rd_finish 	= 0;
			rd_addrA_next 			= 0;
			rd_addrB_next 			= STEP;
			step_counter_next 		= 0;
			output_FIFO.wr_finish 	= 0;
			poly_counter_next 		= poly_counter;
			rou_rd_en 				= 0;
		end
		WAIT2_WR: begin
			next 					= WAIT3_WR;
			input_FIFO.rd_finish 	= 0;
			rd_addrA_next 			= 0;
			rd_addrB_next 			= STEP;
			step_counter_next 		= 0;
			output_FIFO.wr_finish 	= 0;
			poly_counter_next 		= poly_counter;
			rou_rd_en 				= 0;
		end
		WAIT3_WR: begin
			next 					= WAIT4_WR;
			input_FIFO.rd_finish 	= 0;
			rd_addrA_next 			= 0;
			rd_addrB_next 			= STEP;
			step_counter_next 		= 0;
			output_FIFO.wr_finish 	= 0;
			poly_counter_next 		= poly_counter;
			rou_rd_en 				= 0;
		end
		WAIT4_WR: begin
			next 					= WAIT5_WR;
			input_FIFO.rd_finish 	= 0;
			rd_addrA_next 			= 0;
			rd_addrB_next 			= STEP;
			step_counter_next 		= 0;
			output_FIFO.wr_finish 	= 0;
			poly_counter_next 		= poly_counter;
			rou_rd_en 				= 0;
		end
		WAIT5_WR: begin
			next 					= WAIT6_WR;
			input_FIFO.rd_finish 	= 0;
			rd_addrA_next 			= 0;
			rd_addrB_next 			= STEP;
			step_counter_next 		= 0;
			output_FIFO.wr_finish 	= 0;
			poly_counter_next 		= poly_counter;
			rou_rd_en 				= 0;
		end
		WAIT6_WR: begin
			next 					= WAIT7_WR;
			input_FIFO.rd_finish 	= 0;
			rd_addrA_next 			= 0;
			rd_addrB_next 			= STEP;
			step_counter_next 		= 0;
			output_FIFO.wr_finish 	= 0;
			poly_counter_next 		= poly_counter;
			rou_rd_en 				= 0;
		end
		WAIT7_WR: begin
			next 					= WAIT8_WR;
			input_FIFO.rd_finish 	= 0;
			rd_addrA_next 			= 0;
			rd_addrB_next 			= STEP;
			step_counter_next 		= 0;
			output_FIFO.wr_finish 	= 0;
			poly_counter_next 		= poly_counter;
			rou_rd_en 				= 0;
		end
		WAIT8_WR: begin
			next 					= WAIT9_WR;
			input_FIFO.rd_finish 	= 0;
			rd_addrA_next 			= 0;
			rd_addrB_next 			= STEP;
			step_counter_next 		= 0;
			output_FIFO.wr_finish 	= 0;
			poly_counter_next 		= poly_counter;
			rou_rd_en 				= 0;
		end
		WAIT9_WR: begin
			next 					= WAIT10_WR;
			input_FIFO.rd_finish 	= 0;
			rd_addrA_next 			= 0;
			rd_addrB_next 			= STEP;
			step_counter_next 		= 0;
			output_FIFO.wr_finish 	= 0;
			poly_counter_next 		= poly_counter;
			rou_rd_en 				= 0;
		end
		WAIT10_WR: begin
			next 					= WAIT11_WR;
			input_FIFO.rd_finish 	= 0;
			rd_addrA_next 			= 0;
			rd_addrB_next 			= STEP;
			step_counter_next 		= 0;
			output_FIFO.wr_finish 	= 0;
			poly_counter_next 		= poly_counter;
			rou_rd_en 				= 0;
		end
		WAIT11_WR: begin
			if((input_FIFO.poly_id == `POLY_B && input_FIFO.opcode == `RLWESUBS) || !is_leading_stage) begin
				next 					= IDLE_RD1;
				input_FIFO.rd_finish 	= 1;
				rd_addrA_next 			= 0;
				rd_addrB_next 			= STEP;
				step_counter_next 		= 0;
				output_FIFO.wr_finish 	= 1;
				poly_counter_next 		= 0;
				rou_rd_en 				= 0;
			end else begin
				next 					= WAIT_RD1;
				input_FIFO.rd_finish 	= 0;
				rd_addrA_next 			= 0;
				rd_addrB_next 			= STEP;
				step_counter_next 		= 0;
				output_FIFO.wr_finish 	= 1;
				poly_counter_next 		= poly_counter + 1;
				rou_rd_en 				= 0;
			end
		end
		WAIT_RD1:begin
			if(poly_counter == config_ports.digitG) begin
				next 					= IDLE_RD1;
				input_FIFO.rd_finish 	= 1;
				rd_addrA_next 			= 0;
				rd_addrB_next 			= STEP;
				//rlwe_id_next = rlwe_id;
				output_FIFO.wr_finish 	= 1;
				step_counter_next 		= 0;
				poly_counter_next 		= 0;
				//data_mask_next = config_ports.BG_mask;
				rou_rd_en 				= 0;
			end else begin
				if(!output_FIFO.full && !input_FIFO.empty) begin
					next 					= COMPUTE;
					input_FIFO.rd_finish 	= 0;
					rd_addrA_next 			= rd_addrA + 1;
					rd_addrB_next 			= rd_addrB + 1;
					output_FIFO.wr_finish 	= 1;
					step_counter_next 		= step_counter + 1;
					poly_counter_next 		= poly_counter;
					//data_mask_next = data_mask;
					rou_rd_en 				= 1;
				end else begin
					next 					= WAIT_RD1;
					input_FIFO.rd_finish 	= 0;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= STEP;
					output_FIFO.wr_finish 	= 1;
					step_counter_next 		= 0;
					poly_counter_next 		= poly_counter;
					//data_mask_next = data_mask;
					rou_rd_en 				= 0;
				end	
			end
		end
		default: begin
			next 					= IDLE_RD1;
			input_FIFO.rd_finish 	= 1;
			rd_addrA_next 			= 0;
			rd_addrB_next 			= STEP;
			step_counter_next 		= 0;
			output_FIFO.wr_finish 	= 1;
			poly_counter_next 		= 0;
			//data_mask_next = config_ports.BG_mask;
			rou_rd_en 				= 0;
		end
	endcase
end
endmodule

