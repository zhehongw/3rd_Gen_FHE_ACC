`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2021 03:28:24 PM
// Design Name: 
// Module Name: subs_module
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

module subs_module #(

)(
    input clk, rstn,
	
	//to preceding FIFO
    myFIFO_NTT_sink_if.to_FIFO input_FIFO,
	//to next NTT stage
	myFIFO_NTT_sink_if.to_sink out_to_next_stage,

	config_if.to_top config_ports,

	output logic rd_enable,				//rd_enable to iNTT stage FIFO
	input [3 : 0] subs_factor, 			// to calculate which power to subs
	input ROB_empty 					//from reorder buffer to indicate ROB is empty

);
typedef enum logic [2 : 0] {IDLE, RD1, WR_WORD0, WR_WORD1, WR_WORD2, WR_WORD3} subs_states;

logic [`LINE_SIZE - 1 : 0 ] wr_word_selA, wr_word_selB;

myFIFO_NTT_source_if subs_FIFO_if();

myFIFO_subs subs_FIFO (
	.clk(clk),
	.rstn(rstn),
	.source_ports(subs_FIFO_if),
	.word_selA(wr_word_selA),
	.word_selB(wr_word_selB),
	.sink_ports(out_to_next_stage)
);

subs_states state, next;
logic [$clog2(`MAX_LEN) - 1 : 0] 	rd_addrA, rd_addrA_next;
logic [$clog2(`MAX_LEN) - 1 : 0] 	rd_addrB, rd_addrB_next;
logic [$clog2(`MAX_LEN) - 1 : 0] 	rd_addrA_prev, rd_addrA_prev_q;
logic [$clog2(`MAX_LEN) - 1 : 0] 	rd_addrB_prev, rd_addrB_prev_q;
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] 	data_latchA, data_latchA_next;//input data latch, to reduce read freq
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] 	data_latchB, data_latchB_next;
logic [$clog2(`MAX_LEN) - 1 : 0] 		wr_addrA;
logic [$clog2(`MAX_LEN) - 1 : 0] 		wr_addrB;
logic [$clog2(`MAX_LEN) * 2 - 1 : 0] 	addrA_prod;	// equals to i * power in the c code
logic [$clog2(`MAX_LEN) * 2 - 1 : 0] 	addrB_prod;	// equals to i * power inaddrB_prod;
logic [3 : 0]						shift_step;
logic [$clog2(`MAX_LEN) - 1 : 0]	len_m1;	//length minus one

logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] data_inA;
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] data_inB;
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] data_inA_invert;	//get data * (-1), modulo - data
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] data_inB_invert;
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] data_outA;
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] data_outB;

logic [`LINE_SIZE - 1 : 0] wr_data_selA;	//used as a prestep to generate write word selection
logic [`LINE_SIZE - 1 : 0] wr_data_selB;

logic [`BIT_WIDTH - 1 : 0] internal_q;

assign internal_q = config_ports.q;

generate
    genvar i;
	for(i = 0; i < `LINE_SIZE; i++) begin
		assign wr_data_selA[i] = wr_addrA[$clog2(`LINE_SIZE) - 1 : 0] == i ? 1 : 0;
		assign wr_data_selB[i] = wr_addrB[$clog2(`LINE_SIZE) - 1 : 0] == i ? 1 : 0;
	end
	for(i = 0; i < `LINE_SIZE; i++) begin
		assign data_inA_invert[i * `BIT_WIDTH +: `BIT_WIDTH] = data_inA[i * `BIT_WIDTH +: `BIT_WIDTH] == 0 ? {`BIT_WIDTH{1'b0}} : internal_q - data_inA[i * `BIT_WIDTH +: `BIT_WIDTH];
		assign data_inB_invert[i * `BIT_WIDTH +: `BIT_WIDTH] = data_inB[i * `BIT_WIDTH +: `BIT_WIDTH] == 0 ? {`BIT_WIDTH{1'b0}} : internal_q - data_inB[i * `BIT_WIDTH +: `BIT_WIDTH];
	end
endgenerate 

always_comb begin
	for(integer i = 0; i < `LINE_SIZE; i++) begin
		if(wr_addrA[$clog2(`LINE_SIZE) - 1 : 0] == i) begin
			if(`LINE_SIZE == 4 )begin
				case(rd_addrA_prev_q[$clog2(`LINE_SIZE) - 1 : 0])
					0: begin 
						data_outA[i * `BIT_WIDTH +: `BIT_WIDTH] = addrA_prod[config_ports.log2_len] ? data_inA_invert[0 * `BIT_WIDTH +: `BIT_WIDTH] : data_inA[0 * `BIT_WIDTH +: `BIT_WIDTH];
					end
					1: begin
						data_outA[i * `BIT_WIDTH +: `BIT_WIDTH] = addrA_prod[config_ports.log2_len] ? data_inA_invert[1 * `BIT_WIDTH +: `BIT_WIDTH] : data_inA[1 * `BIT_WIDTH +: `BIT_WIDTH];
					end
					2: begin
						data_outA[i * `BIT_WIDTH +: `BIT_WIDTH] = addrA_prod[config_ports.log2_len] ? data_inA_invert[2 * `BIT_WIDTH +: `BIT_WIDTH] : data_inA[2 * `BIT_WIDTH +: `BIT_WIDTH];
					end
					3: begin
						data_outA[i * `BIT_WIDTH +: `BIT_WIDTH] = addrA_prod[config_ports.log2_len] ? data_inA_invert[3 * `BIT_WIDTH +: `BIT_WIDTH] : data_inA[3 * `BIT_WIDTH +: `BIT_WIDTH];
					end
				endcase
			end else if(`LINE_SIZE == 2) begin
				case(rd_addrA_prev_q[$clog2(`LINE_SIZE) - 1 : 0])
					0: begin 
						data_outA[i * `BIT_WIDTH +: `BIT_WIDTH] = addrA_prod[config_ports.log2_len] ? data_inA_invert[0 * `BIT_WIDTH +: `BIT_WIDTH] : data_inA[0 * `BIT_WIDTH +: `BIT_WIDTH];
					end
					1: begin
						data_outA[i * `BIT_WIDTH +: `BIT_WIDTH] = addrA_prod[config_ports.log2_len] ? data_inA_invert[1 * `BIT_WIDTH +: `BIT_WIDTH] : data_inA[1 * `BIT_WIDTH +: `BIT_WIDTH];
					end
				endcase
			end
		end else begin
			data_outA[i * `BIT_WIDTH +: `BIT_WIDTH] = 0;
		end

		if(wr_addrB[$clog2(`LINE_SIZE) - 1 : 0] == i) begin
			if(`LINE_SIZE == 4 )begin
				case(rd_addrB_prev_q[$clog2(`LINE_SIZE) - 1 :0])
					0: begin 
						data_outB[i * `BIT_WIDTH +: `BIT_WIDTH] = addrB_prod[config_ports.log2_len] ? data_inB_invert[0 * `BIT_WIDTH +: `BIT_WIDTH] : data_inB[0 * `BIT_WIDTH +: `BIT_WIDTH];
					end
					1: begin
						data_outB[i * `BIT_WIDTH +: `BIT_WIDTH] = addrB_prod[config_ports.log2_len] ? data_inB_invert[1 * `BIT_WIDTH +: `BIT_WIDTH] : data_inB[1 * `BIT_WIDTH +: `BIT_WIDTH];
					end
					2: begin
						data_outB[i * `BIT_WIDTH +: `BIT_WIDTH] = addrB_prod[config_ports.log2_len] ? data_inB_invert[2 * `BIT_WIDTH +: `BIT_WIDTH] : data_inB[2 * `BIT_WIDTH +: `BIT_WIDTH];
					end
					3: begin
						data_outB[i * `BIT_WIDTH +: `BIT_WIDTH] = addrB_prod[config_ports.log2_len] ? data_inB_invert[3 * `BIT_WIDTH +: `BIT_WIDTH] : data_inB[3 * `BIT_WIDTH +: `BIT_WIDTH];
					end
				endcase
			end else if(`LINE_SIZE == 2) begin
				case(rd_addrB_prev_q[$clog2(`LINE_SIZE) - 1 :0])
					0: begin 
						data_outB[i * `BIT_WIDTH +: `BIT_WIDTH] = addrB_prod[config_ports.log2_len] ? data_inB_invert[0 * `BIT_WIDTH +: `BIT_WIDTH] : data_inB[0 * `BIT_WIDTH +: `BIT_WIDTH];
					end
					1: begin
						data_outB[i * `BIT_WIDTH +: `BIT_WIDTH] = addrB_prod[config_ports.log2_len] ? data_inB_invert[1 * `BIT_WIDTH +: `BIT_WIDTH] : data_inB[1 * `BIT_WIDTH +: `BIT_WIDTH];
					end
				endcase
			end
		end else begin
			data_outB[i * `BIT_WIDTH +: `BIT_WIDTH] = 0;
		end
	end
end

//add write addr collision resolution to write enable
assign subs_FIFO_if.dA = wr_addrA[$clog2(`LINE_SIZE) +: `ADDR_WIDTH] == wr_addrB[$clog2(`LINE_SIZE) +: `ADDR_WIDTH] ? data_outA | data_outB : data_outA;
assign subs_FIFO_if.dB = wr_addrA[$clog2(`LINE_SIZE) +: `ADDR_WIDTH] == wr_addrB[$clog2(`LINE_SIZE) +: `ADDR_WIDTH] ? 0 : data_outB;

assign wr_word_selA = wr_addrA[$clog2(`LINE_SIZE) +: `ADDR_WIDTH] == wr_addrB[$clog2(`LINE_SIZE) +: `ADDR_WIDTH] ? wr_data_selA | wr_data_selB : wr_data_selA;
assign wr_word_selB = wr_addrA[$clog2(`LINE_SIZE) +: `ADDR_WIDTH] == wr_addrB[$clog2(`LINE_SIZE) +: `ADDR_WIDTH] ? 0 : wr_data_selB;


assign shift_step = config_ports.log2_len - subs_factor;
assign len_m1 = config_ports.length - 1;


assign subs_FIFO_if.addrA 	= wr_addrA[$clog2(`LINE_SIZE) +: `ADDR_WIDTH];
assign subs_FIFO_if.addrB 	= wr_addrB[$clog2(`LINE_SIZE) +: `ADDR_WIDTH];
assign input_FIFO.addrA 	= rd_addrA[$clog2(`LINE_SIZE) +: `ADDR_WIDTH];
assign input_FIFO.addrB 	= rd_addrB[$clog2(`LINE_SIZE) +: `ADDR_WIDTH];



assign addrA_prod = (rd_addrA_prev_q << shift_step) + rd_addrA_prev_q;
assign addrB_prod = (rd_addrB_prev_q << shift_step) + rd_addrB_prev_q;
assign wr_addrA = addrA_prod[$clog2(`MAX_LEN) - 1 : 0] & len_m1;
assign wr_addrB = addrB_prod[$clog2(`MAX_LEN) - 1 : 0] & len_m1;

always_ff @(posedge clk) begin
	if(!rstn) begin
		state 			<= `SD IDLE;
		rd_addrA 		<= `SD 0;							//rd_addrA starts from 0
		rd_addrB 		<= `SD config_ports.length >> 1;	//rd_addrB starts from halfway
		rd_addrA_prev 	<= `SD 0;
		rd_addrB_prev 	<= `SD config_ports.length >> 1;
		rd_addrA_prev_q <= `SD 0;
		rd_addrB_prev_q <= `SD config_ports.length >> 1;
		data_latchA 	<= `SD 0;
		data_latchB 	<= `SD 0;
//		wr_addrA 		<= `SD 0;
//		wr_addrB 		<= `SD 0;
	end else begin
		state 			<= `SD next;
		rd_addrA 		<= `SD rd_addrA_next;
		rd_addrB 		<= `SD rd_addrB_next;
		data_latchA 	<= `SD data_latchA_next;
		data_latchB 	<= `SD data_latchB_next;
//		wr_addrA 		<= `SD wr_addrA_next[$clog2(`MAX_LEN) - 1 : 0] & len_m1;
//		wr_addrB 		<= `SD wr_addrB_next[$clog2(`MAX_LEN) - 1 : 0] & len_m1;
		rd_addrA_prev 	<= `SD rd_addrA;
		rd_addrB_prev 	<= `SD rd_addrB;
		rd_addrA_prev_q <= `SD rd_addrA_prev;
		rd_addrB_prev_q <= `SD rd_addrB_prev;
	end
end


generate 
if(`LINE_SIZE == 4) begin
	//if `LINE_SIZE is 4 use this combinational part
	always_comb begin
		case(state)
			IDLE: begin
				if(!input_FIFO.empty && !ROB_empty && !subs_FIFO_if.full) begin
					next 					= RD1;
					input_FIFO.rd_finish 	= 0;
					rd_enable 				= 1;
					rd_addrA_next 			= rd_addrA + 1;
					rd_addrB_next 			= rd_addrB + 1;
				end else begin
					next 					= IDLE;
					input_FIFO.rd_finish 	= 1;
					rd_enable 				= 0;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= config_ports.length >> 1;
				end
				subs_FIFO_if.wr_finish 	= 1;
				//wr_addrA_next 			= (rd_addrA << shift_step) + rd_addrA;
				//wr_addrB_next 			= (rd_addrB << shift_step) + rd_addrB;
				data_latchA_next 		= 0;
				data_latchB_next 		= 0;
				data_inA 				= 0;
				data_inB 				= 0;
			end
			RD1: begin
				next 					= WR_WORD0;
			   	input_FIFO.rd_finish 	= 0;
				rd_enable 				= 1;
				rd_addrA_next 			= rd_addrA + 1;
				rd_addrB_next 			= rd_addrB + 1;
				subs_FIFO_if.wr_finish 	= 0;
				//wr_addrA_next 			= (rd_addrA << shift_step) + rd_addrA;
				//wr_addrB_next 			= (rd_addrB << shift_step) + rd_addrB;
				data_latchA_next 		= 0;
				data_latchB_next 		= 0;
				data_inA 				= 0;
				data_inB 				= 0;
			end
			WR_WORD0: begin
				next 					= WR_WORD1;
			   	input_FIFO.rd_finish 	= 0;
				rd_enable 				= 0;
				rd_addrA_next 			= rd_addrA + 1;
				rd_addrB_next 			= rd_addrB + 1;
				subs_FIFO_if.wr_finish 	= 0;
				//wr_addrA_next 			= (rd_addrA << shift_step) + rd_addrA;
				//wr_addrB_next 			= (rd_addrB << shift_step) + rd_addrB;
				data_latchA_next 		= input_FIFO.dA;
				data_latchB_next 		= input_FIFO.dB;
				data_inA 				= input_FIFO.dA;
				data_inB 				= input_FIFO.dB;
			end
			WR_WORD1: begin
				next 					= WR_WORD2;
			   	input_FIFO.rd_finish 	= 0;
				rd_enable 				= 0;
				rd_addrA_next 			= rd_addrA + 1;
				rd_addrB_next 			= rd_addrB + 1;
				subs_FIFO_if.wr_finish 	= 0;
				//wr_addrA_next 			= (rd_addrA << shift_step) + rd_addrA;
				//wr_addrB_next 			= (rd_addrB << shift_step) + rd_addrB;
				data_latchA_next 		= data_latchA;
				data_latchB_next 		= data_latchB;
				data_inA 				= data_latchA;
				data_inB 				= data_latchB;
			end
			WR_WORD2: begin
				next 					= WR_WORD3;
			   	input_FIFO.rd_finish 	= 0;
				rd_enable 				= 1;
				rd_addrA_next 			= rd_addrA + 1;
				rd_addrB_next 			= rd_addrB + 1;
				subs_FIFO_if.wr_finish 	= 0;
				//wr_addrA_next 			= (rd_addrA << shift_step) + rd_addrA;
				//wr_addrB_next 			= (rd_addrB << shift_step) + rd_addrB;
				data_latchA_next 		= data_latchA;
				data_latchB_next 		= data_latchB;
				data_inA 				= data_latchA;
				data_inB 				= data_latchB;
			end
			WR_WORD3: begin
				if(rd_addrB_prev_q == (config_ports.length - 1)) begin
					next 					= IDLE;
			   		input_FIFO.rd_finish 	= 1;
					rd_enable 				= 0;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= config_ports.length >> 1;
					subs_FIFO_if.wr_finish 	= 1;
					//wr_addrA_next 			= (rd_addrA << shift_step) + rd_addrA;
					//wr_addrB_next 			= (rd_addrB << shift_step) + rd_addrB;
					data_latchA_next 		= 0;
					data_latchB_next 		= 0;
					data_inA 				= data_latchA;
					data_inB 				= data_latchB;
				end else begin
					next 					= WR_WORD0;
			   		input_FIFO.rd_finish 	= 0;
					rd_enable 				= 1;
					rd_addrA_next 			= rd_addrA + 1;
					rd_addrB_next 			= rd_addrB + 1;
					subs_FIFO_if.wr_finish 	= 0;
					//wr_addrA_next 			= (rd_addrA << shift_step) + rd_addrA;
					//wr_addrB_next 			= (rd_addrB << shift_step) + rd_addrB;
					data_latchA_next 		= data_latchA;
					data_latchB_next 		= data_latchB;
					data_inA 				= data_latchA;
					data_inB 				= data_latchB;
				end
			end
			default: begin
				next 					= IDLE;
				input_FIFO.rd_finish 	= 1;
				rd_enable 				= 0;
				rd_addrA_next 			= 0;
				rd_addrB_next 			= config_ports.length >> 1;
				subs_FIFO_if.wr_finish 	= 1;
				//wr_addrA_next 			= (rd_addrA << shift_step) + rd_addrA;
				//wr_addrB_next 			= (rd_addrB << shift_step) + rd_addrB;
				data_latchA_next 		= 0;
				data_latchB_next 		= 0;
				data_inA 				= 0;
				data_inB 				= 0;
			end
		endcase
	end
end else if(`LINE_SIZE == 2) begin
	//if `LINE_SIZE is 2 use this combinational part
	always_comb begin
		case(state)
			IDLE: begin
				if(!input_FIFO.empty && !ROB_empty && !subs_FIFO_if.full) begin
					next 					= RD1;
					input_FIFO.rd_finish 	= 0;
					rd_enable 				= 1;
					rd_addrA_next 			= rd_addrA + 1;
					rd_addrB_next 			= rd_addrB + 1;
				end else begin
					next 					= IDLE;
					input_FIFO.rd_finish 	= 1;
					rd_enable 				= 0;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= config_ports.length >> 1;
				end
				subs_FIFO_if.wr_finish 	= 1;
				//wr_addrA_next 			= (rd_addrA << shift_step) + rd_addrA;
				//wr_addrB_next 			= (rd_addrB << shift_step) + rd_addrB;
				data_latchA_next 		= 0;
				data_latchB_next 		= 0;
				data_inA 				= 0;
				data_inB 				= 0;
			end
			RD1: begin
				next 					= WR_WORD0;
			   	input_FIFO.rd_finish 	= 0;
				rd_enable 				= 1;
				rd_addrA_next 			= rd_addrA + 1;
				rd_addrB_next 			= rd_addrB + 1;
				subs_FIFO_if.wr_finish 	= 0;
				//wr_addrA_next 			= (rd_addrA << shift_step) + rd_addrA;
				//wr_addrB_next 			= (rd_addrB << shift_step) + rd_addrB;
				data_latchA_next 		= 0;
				data_latchB_next 		= 0;
				data_inA 				= 0;
				data_inB 				= 0;

			end
			WR_WORD0: begin
				next 					= WR_WORD1;
			   	input_FIFO.rd_finish 	= 0;
				rd_enable 				= 1;
				rd_addrA_next 			= rd_addrA + 1;
				rd_addrB_next 			= rd_addrB + 1;
				subs_FIFO_if.wr_finish 	= 0;
				//wr_addrA_next 			= (rd_addrA << shift_step) + rd_addrA;
				//wr_addrB_next 			= (rd_addrB << shift_step) + rd_addrB;
				data_latchA_next 		= input_FIFO.dA;
				data_latchB_next 		= input_FIFO.dB;
				data_inA 				= input_FIFO.dA;
				data_inB 				= input_FIFO.dB;
			end
			WR_WORD1: begin
				if(rd_addrB_prev_q == (config_ports.length - 1)) begin
					next 					= IDLE;
			   		input_FIFO.rd_finish 	= 1;
					rd_enable 				= 0;
					rd_addrA_next 			= 0;
					rd_addrB_next 			= config_ports.length >> 1;
					subs_FIFO_if.wr_finish 	= 1;
					//wr_addrA_next 			= (rd_addrA << shift_step) + rd_addrA;
					//wr_addrB_next 			= (rd_addrB << shift_step) + rd_addrB;
					data_latchA_next 		= 0;
					data_latchB_next 		= 0;
					data_inA 				= data_latchA;
					data_inB 				= data_latchB;
				end else begin
					next 					= WR_WORD0;
			   		input_FIFO.rd_finish 	= 0;
					rd_enable 				= 1;
					rd_addrA_next 			= rd_addrA + 1;
					rd_addrB_next 			= rd_addrB + 1;
					subs_FIFO_if.wr_finish 	= 0;
					//wr_addrA_next 			= (rd_addrA << shift_step) + rd_addrA;
					//wr_addrB_next 			= (rd_addrB << shift_step) + rd_addrB;
					data_latchA_next 		= data_latchA;
					data_latchB_next 		= data_latchB;
					data_inA 				= data_latchA;
					data_inB 				= data_latchB;
				end
			end
			default: begin
				next 					= IDLE;
				input_FIFO.rd_finish 	= 1;
				rd_enable 				= 0;
				rd_addrA_next 			= 0;
				rd_addrB_next 			= config_ports.length >> 1;
				subs_FIFO_if.wr_finish 	= 1;
				//wr_addrA_next 			= (rd_addrA << shift_step) + rd_addrA;
				//wr_addrB_next 			= (rd_addrB << shift_step) + rd_addrB;
				data_latchA_next 		= 0;
				data_latchB_next 		= 0;
				data_inA 				= 0;
				data_inB 				= 0;
			end
		endcase
	end

end
endgenerate

endmodule
