`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2021 03:28:24 PM
// Design Name: 
// Module Name: NTT_stage
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

module NTT_stage #(
	parameter STAGE_NUM = 9,
	parameter NTT_STEP = 2**STAGE_NUM,
    parameter STEP = NTT_STEP/ `LINE_SIZE	//buffer line step
)(
    input clk, rstn,
	
	//to preceding FIFO
    myFIFO_NTT_sink_if.to_FIFO input_FIFO,
	//to next NTT stage
	myFIFO_NTT_sink_if.to_sink out_to_next_stage,

	config_if.to_top config_ports,

	ROU_config_if.to_axil_bar1 rou_wr_port
);
typedef enum logic [3 : 0] {IDLE_RD1, COMPUTE, WR1, WR2, WAIT1_WR, WAIT2_WR, WAIT3_WR, WAIT4_WR, WAIT5_WR, WAIT6_WR, WAIT7_WR, WAIT8_WR, WAIT9_WR, WAIT10_WR, WAIT11_WR} NTT_states;


logic 	[`ADDR_WIDTH -1 : 0] 		rd_addrA, rd_addrA_next;
logic 	[`ADDR_WIDTH -1 : 0] 		rd_addrB, rd_addrB_next;
logic 	[`ADDR_WIDTH -1 : 0] 		wr_addrA, wr_addrA_q, wr_addrA_piped;
logic 	[`ADDR_WIDTH -1 : 0] 		wr_addrB, wr_addrB_q, wr_addrB_piped;
//logic 	[`RLWE_ID_WIDTH - 1 : 0] 	rlwe_id, rlwe_id_next;
logic 	[$clog2(`MAX_LEN / `LINE_SIZE) - 1 : 0]		step_counter, step_counter_next;  

//wr addr sync pipe line
pipeline #(.STAGE_NUM(11), .BIT_WIDTH(`ADDR_WIDTH * 2)) wr_addr_pipe(
	.clk(clk),
	.rstn(rstn),
	.pipe_in({wr_addrA_q, wr_addrB_q}),
	.pipe_out({wr_addrA_piped, wr_addrB_piped})
);

myFIFO_NTT_source_if output_FIFO();

assign input_FIFO.addrA = rd_addrA;
assign input_FIFO.addrB = rd_addrB;
assign output_FIFO.addrA = wr_addrA_piped;
assign output_FIFO.addrB = wr_addrB_piped;


assign output_FIFO.rlwe_id = input_FIFO.rlwe_id;
assign output_FIFO.poly_id = input_FIFO.poly_id;
assign output_FIFO.opcode  = input_FIFO.opcode;

NTT_states state, next;

myFIFO_NTT out_buffer(
    .clk(clk),
    .rstn(rstn),
    .source_ports(output_FIFO),
    .sink_ports(out_to_next_stage)
);



ROU_table_if #(.STAGE_NUM(STAGE_NUM)) local_rou_table();
logic rou_rd_en;

assign local_rou_table.en = rou_rd_en | (|rou_wr_port.we);

ROU_buffer #(.STAGE_NUM(STAGE_NUM))local_rou( 
    .clk(clk), 
    .wr_port(rou_wr_port),
	.rd_port(local_rou_table)	//read interface for NTT_stage
); 

genvar i, j;
generate 
	if(STEP >= 1) begin
		for(i = 0; i < `LINE_SIZE; i++) begin
			CT_butterfly butterfly(
						.clk(clk),
						.a(input_FIFO.dA[i * `BIT_WIDTH +: `BIT_WIDTH]),
						.b(input_FIFO.dB[i * `BIT_WIDTH +: `BIT_WIDTH]),
						.ROU_entry(local_rou_table.ROU_entry),
						.q(config_ports.q),
						.m(config_ports.m),
						.k2(config_ports.k2),
						.outa(output_FIFO.dA[i * `BIT_WIDTH +: `BIT_WIDTH]),
						.outb(output_FIFO.dB[i * `BIT_WIDTH +: `BIT_WIDTH]));
		end
	end else begin
		for(i = 0; i < `LINE_SIZE / NTT_STEP / 2; i++) begin
			for(j = 0; j < NTT_STEP; j++) begin
				//for buffer line A
				CT_butterfly butterflyA(
							.clk(clk),
							.a(input_FIFO.dA[(i * NTT_STEP * 2 + j) * `BIT_WIDTH +: `BIT_WIDTH]),
							.b(input_FIFO.dA[(i * NTT_STEP * 2 + j + NTT_STEP) * `BIT_WIDTH +: `BIT_WIDTH]),
							.ROU_entry(local_rou_table.ROU_entry[i * `BIT_WIDTH +: `BIT_WIDTH]),
							.q(config_ports.q),
							.m(config_ports.m),
							.k2(config_ports.k2),
							.outa(output_FIFO.dA[(i * NTT_STEP * 2 + j) * `BIT_WIDTH +: `BIT_WIDTH]),
							.outb(output_FIFO.dA[(i * NTT_STEP * 2 + j + NTT_STEP) * `BIT_WIDTH +: `BIT_WIDTH]));
				//for buffer line B
				CT_butterfly butterflyB(
							.clk(clk),
							.a(input_FIFO.dB[(i * NTT_STEP * 2 + j) * `BIT_WIDTH +: `BIT_WIDTH]),
							.b(input_FIFO.dB[(i * NTT_STEP * 2 + j + NTT_STEP) * `BIT_WIDTH +: `BIT_WIDTH]),
							.ROU_entry(local_rou_table.ROU_entry[i * `BIT_WIDTH + `BIT_WIDTH * `LINE_SIZE / (2 ** STAGE_NUM) / 2 +: `BIT_WIDTH]),
							.q(config_ports.q),
							.m(config_ports.m),
							.k2(config_ports.k2),
							.outa(output_FIFO.dB[(i * NTT_STEP * 2 + j) * `BIT_WIDTH +: `BIT_WIDTH]),
							.outb(output_FIFO.dB[(i * NTT_STEP * 2 + j + NTT_STEP) * `BIT_WIDTH +: `BIT_WIDTH]));
			end
		end	
	end
endgenerate 


generate 
	if(STEP > 1) begin // for stage number greater than LINE_SIZE/2, step size greater than one
		logic 	[STAGE_NUM - $clog2(`LINE_SIZE) - 1 : 0] 	t;	//inner loop counter
		logic 	[$clog2(`MAX_LEN) - STAGE_NUM - 1 : 0]		ROU_idx; //ROU table idx

		assign local_rou_table.addr = ROU_idx;
		assign {ROU_idx, t} = step_counter;

		always_ff @(posedge clk) begin
			if(!rstn) begin
				state 			<= `SD IDLE_RD1;
				rd_addrA 		<= `SD 0;
				rd_addrB 		<= `SD STEP;
				//rlwe_id 		<= `SD 0;
				step_counter 	<= `SD 0;
			end else begin
				state 			<= `SD next;
				rd_addrA 		<= `SD rd_addrA_next;
				rd_addrB 		<= `SD rd_addrB_next;
				//rlwe_id 		<= `SD rlwe_id_next;
				step_counter 	<= `SD step_counter_next;
			end
			wr_addrA 		<= `SD rd_addrA;
			wr_addrB 		<= `SD rd_addrB;
			wr_addrA_q 		<= `SD wr_addrA;
			wr_addrB_q 		<= `SD wr_addrB;
		end

		always_comb begin
			case(state)
				IDLE_RD1: begin
					if(!input_FIFO.empty && !output_FIFO.full) begin
						next 					= COMPUTE;
						input_FIFO.rd_finish 	= 0;
						rd_addrA_next 			= rd_addrA + 1;
						rd_addrB_next 			= rd_addrB + 1;
						step_counter_next 		= step_counter + 1;
						//rlwe_id_next = input_FIFO.rlwe_id; 
						output_FIFO.wr_finish 	= 1;
						rou_rd_en 				= 1;
					end else begin
						next 					= IDLE_RD1;
						input_FIFO.rd_finish 	= 1;
						rd_addrA_next 			= 0;
						rd_addrB_next 			= STEP;
						step_counter_next 		= 0;
						//rlwe_id_next = 0;
						output_FIFO.wr_finish 	= 1;
						rou_rd_en 				= 0;
					end
				end
				COMPUTE: begin
					if(rd_addrB == ((config_ports.length >> $clog2(`LINE_SIZE)) - 1)) begin
						next 					= WR1;
						input_FIFO.rd_finish 	= 0;
						rd_addrA_next 			= 0;
						rd_addrB_next 			= STEP;
						//rlwe_id_next 			= rlwe_id;
						output_FIFO.wr_finish 	= 0;
						step_counter_next 		= 0;
						rou_rd_en 				= 1;
					end else begin
						if(t == STEP - 1) begin
							rd_addrA_next 		= rd_addrA + STEP + 1;
							rd_addrB_next 		= rd_addrB + STEP + 1;
						end else begin
							rd_addrA_next 		= rd_addrA + 1;
							rd_addrB_next 		= rd_addrB + 1;
						end
						next 					= COMPUTE;
						input_FIFO.rd_finish 	= 0;
						step_counter_next 		= step_counter + 1;
						//rlwe_id_next 			= rlwe_id;
						output_FIFO.wr_finish 	= 0;
						rou_rd_en 				= 1;
					end
				end
				WR1: begin
					next 					= WR2;
					input_FIFO.rd_finish 	= 0;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= STEP;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 1;
				end
				WR2: begin
					next 					= WAIT1_WR;
					input_FIFO.rd_finish 	= 0;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= STEP;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 1;
				end
				WAIT1_WR: begin
					next 					= WAIT2_WR;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= STEP;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
				WAIT2_WR: begin
					next 					= WAIT3_WR;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= STEP;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
				WAIT3_WR: begin
					next 					= WAIT4_WR;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= STEP;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
				WAIT4_WR: begin
					next 					= WAIT5_WR;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= STEP;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
				WAIT5_WR: begin
					next 					= WAIT6_WR;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= STEP;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
				WAIT6_WR: begin
					next 					= WAIT7_WR;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= STEP;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
				WAIT7_WR: begin
					next 					= WAIT8_WR;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= STEP;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
				WAIT8_WR: begin
					next 					= WAIT9_WR;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= STEP;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
				WAIT9_WR: begin
					next 					= WAIT10_WR;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= STEP;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
				WAIT10_WR: begin
					next 					= WAIT11_WR;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= STEP;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
				WAIT11_WR: begin
					next 					= IDLE_RD1;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= STEP;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 1;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
				default: begin
					next 					= IDLE_RD1;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= STEP;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 1;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
			endcase
		end

	end else begin// for stage number less or equal to LINE_SIZE/2, step size less or equal to one

		assign local_rou_table.addr = step_counter;
		always_ff @(posedge clk) begin
			if(!rstn) begin
				state 			<= `SD IDLE_RD1;
				rd_addrA 		<= `SD 0;
				rd_addrB 		<= `SD 1;
				//rlwe_id 		<= `SD 0;
				step_counter 	<= `SD 0;
			end else begin
				state 			<= `SD next;
				rd_addrA 		<= `SD rd_addrA_next;
				rd_addrB 		<= `SD rd_addrB_next;
				//rlwe_id 		<= `SD rlwe_id_next;
				step_counter 	<= `SD step_counter_next;
			end
			wr_addrA 		<= `SD rd_addrA;
			wr_addrB 		<= `SD rd_addrB;
			wr_addrA_q 		<= `SD wr_addrA;
			wr_addrB_q 		<= `SD wr_addrB;
		end
		always_comb begin
			case(state)
				IDLE_RD1: begin
					if(!input_FIFO.empty && !output_FIFO.full) begin
						next 					= COMPUTE;
						input_FIFO.rd_finish 	= 0;
						rd_addrA_next 			= rd_addrA + 2;
						rd_addrB_next 			= rd_addrB + 2;
						step_counter_next 		= step_counter + 1;
						//rlwe_id_next = input_FIFO.rlwe_id; 
						output_FIFO.wr_finish 	= 1;
						rou_rd_en 				= 1;
					end else begin
						next 					= IDLE_RD1;
						input_FIFO.rd_finish 	= 1;
						rd_addrA_next 			= 0;
						rd_addrB_next 			= 1;
						step_counter_next 		= 0;
						//rlwe_id_next = 0;
						output_FIFO.wr_finish 	= 1;
						rou_rd_en 				= 0;
					end
				end
				COMPUTE: begin
					//if(step_counter == (config_ports.length >> ($clog2(`LINE_SIZE) + 1))) begin
					if(rd_addrB == ((config_ports.length >> $clog2(`LINE_SIZE)) - 1)) begin
						next 					= WR1;
						input_FIFO.rd_finish 	= 0;
						rd_addrA_next 			= 0;
						rd_addrB_next 			= 1;
						//rlwe_id_next = rlwe_id;
						output_FIFO.wr_finish 	= 0;
						step_counter_next 		= 0;
						rou_rd_en 				= 1;
					end else begin 
						rd_addrA_next 			= rd_addrA + 2;
						rd_addrB_next 			= rd_addrB + 2;
						next 					= COMPUTE;
						input_FIFO.rd_finish 	= 0;
						step_counter_next 		= step_counter + 1;
						//rlwe_id_next = rlwe_id;
						output_FIFO.wr_finish 	= 0;
						rou_rd_en 				= 1;
					end
				end
				WR1: begin
					next 					= WR2;
					input_FIFO.rd_finish 	= 0;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= 1;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 1;
				end
				WR2: begin
					next 					= WAIT1_WR;
					input_FIFO.rd_finish 	= 0;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= 1;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 1;
				end
				WAIT1_WR: begin
					next 					= WAIT2_WR;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= 1;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
				WAIT2_WR: begin
					next 					= WAIT3_WR;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= 1;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
				WAIT3_WR: begin
					next 					= WAIT4_WR;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= 1;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
				WAIT4_WR: begin
					next 					= WAIT5_WR;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= 1;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
				WAIT5_WR: begin
					next 					= WAIT6_WR;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= 1;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
				WAIT6_WR: begin
					next 					= WAIT7_WR;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= 1;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
				WAIT7_WR: begin
					next 					= WAIT8_WR;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= 1;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
				WAIT8_WR: begin
					next 					= WAIT9_WR;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= 1;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
				WAIT9_WR: begin
					next 					= WAIT10_WR;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= 1;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
				WAIT10_WR: begin
					next 					= WAIT11_WR;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= 1;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 0;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
				WAIT11_WR: begin
					next 					= IDLE_RD1;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= 1;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 1;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
				default: begin
					next 					= IDLE_RD1;
					input_FIFO.rd_finish 	= 1;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= 1;
					//rlwe_id_next = rlwe_id;
					output_FIFO.wr_finish 	= 1;
					step_counter_next 		= 0;
					rou_rd_en 				= 0;
				end
			endcase
		end
	end 
endgenerate

endmodule

