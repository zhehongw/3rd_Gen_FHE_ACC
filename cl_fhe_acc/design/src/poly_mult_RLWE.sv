`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2021 03:28:24 PM
// Design Name: 
// Module Name: poly_mult_RLWE
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description:  this now includes a 3 stage pipeline
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "common.vh"

module poly_mult_RLWE #(

)(
    input clk, rstn,
	
	//to preceding NTT FIFO
    myFIFO_NTT_sink_if.to_FIFO NTT_FIFO,
	//to next accumulator stage
	myFIFO_NTT_sink_if.to_sink out_to_next_stage [1 : 0], //0 for poly a, 1 for poly b
	//to offchip loading key FIFO
    myFIFO_NTT_sink_if.to_FIFO key_FIFO [1 : 0],
	
	config_if.to_top config_ports

);
typedef enum logic [3 : 0] {IDLE_RD1, COMPUTE, W1, W2, WAIT1_WR, WAIT2_WR, WAIT3_WR, WAIT4_WR, WAIT5_WR, WAIT6_WR, WAIT7_WR, WAIT8_WR, WAIT9_WR, PASS, PASS_W1, PASS_W2} mult_states;

myFIFO_NTT_source_if mult_FIFO_if [1 : 0] ();

myFIFO_NTT mult_FIFOs [1 : 0] (
	.clk(clk),
	.rstn(rstn),
	.source_ports(mult_FIFO_if),
	.sink_ports(out_to_next_stage)
);

mult_states state, next;
`ifndef FPGA_LESS_RST 
	logic [`ADDR_WIDTH - 1 : 0] rd_addrA;
	logic [`ADDR_WIDTH - 1 : 0] rd_addrB;
`else
	logic [`ADDR_WIDTH - 1 : 0] rd_addrA = 0;
	logic [`ADDR_WIDTH - 1 : 0] rd_addrB = 1;
`endif

logic [`ADDR_WIDTH - 1 : 0] rd_addrA_next;
logic [`ADDR_WIDTH - 1 : 0] rd_addrB_next;
logic [`ADDR_WIDTH - 1 : 0] wr_addrA, wr_addrB;
logic [`ADDR_WIDTH - 1 : 0] wr_addrA_q, wr_addrB_q;
logic [`ADDR_WIDTH - 1 : 0] wr_addrA_piped, wr_addrB_piped;
logic wr_finish;
logic rd_finish_NTT, rd_finish_key;

logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] mult_out_A [1 : 0];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] mult_out_B [1 : 0];

//wr addr sync pipe line
pipeline #(.STAGE_NUM(9), .BIT_WIDTH(`ADDR_WIDTH * 2)) wr_addr_pipe(
	.clk(clk),
	.rstn(rstn),
	.pipe_in({wr_addrA_q, wr_addrB_q}),
	.pipe_out({wr_addrA_piped, wr_addrB_piped})
);
always_comb begin
    case(state)
        PASS, PASS_W1, PASS_W2: begin
        mult_FIFO_if[0].dA = 0;
        mult_FIFO_if[0].dB = 0;
        mult_FIFO_if[1].dA = NTT_FIFO.dA;
        mult_FIFO_if[1].dB = NTT_FIFO.dB;
        end
        default: begin
        mult_FIFO_if[0].dA = mult_out_A[0];
        mult_FIFO_if[0].dB = mult_out_B[0];
        mult_FIFO_if[1].dA = mult_out_A[1];
        mult_FIFO_if[1].dB = mult_out_B[1];
        end
    endcase
end



assign mult_FIFO_if[0].rlwe_id 	= NTT_FIFO.rlwe_id;
assign mult_FIFO_if[1].rlwe_id 	= NTT_FIFO.rlwe_id;
assign mult_FIFO_if[0].poly_id 	= NTT_FIFO.poly_id;
assign mult_FIFO_if[1].poly_id 	= NTT_FIFO.poly_id;
assign mult_FIFO_if[0].opcode 	= NTT_FIFO.opcode;
assign mult_FIFO_if[1].opcode 	= NTT_FIFO.opcode;


assign mult_FIFO_if[0].wr_finish 	= wr_finish;
assign mult_FIFO_if[1].wr_finish 	= wr_finish;
always_comb begin
    case(state)
        PASS, PASS_W1, PASS_W2: begin
            mult_FIFO_if[0].addrA 		= wr_addrA_q;
            mult_FIFO_if[0].addrB 		= wr_addrB_q;
            mult_FIFO_if[1].addrA 		= wr_addrA_q;
            mult_FIFO_if[1].addrB 		= wr_addrB_q;        
        end
        default: begin
            mult_FIFO_if[0].addrA 		= wr_addrA_piped;
            mult_FIFO_if[0].addrB 		= wr_addrB_piped;
            mult_FIFO_if[1].addrA 		= wr_addrA_piped;
            mult_FIFO_if[1].addrB 		= wr_addrB_piped;      
        end
    endcase
end


assign NTT_FIFO.rd_finish 			= rd_finish_NTT;
assign key_FIFO[1].rd_finish 		= rd_finish_key;
assign key_FIFO[0].rd_finish 		= rd_finish_key;

assign NTT_FIFO.addrA 				= rd_addrA;
assign NTT_FIFO.addrB				= rd_addrB;
assign key_FIFO[0].addrA 			= rd_addrA;
assign key_FIFO[0].addrB			= rd_addrB;
assign key_FIFO[1].addrA 			= rd_addrA;
assign key_FIFO[1].addrB			= rd_addrB;

genvar i, j;
generate
	for(j = 0; j < 2; j++) begin 
		for(i = 0; i < `LINE_SIZE; i++) begin
			mod_mult #(.MAX_BIT_WIDTH(`BIT_WIDTH)) mult_A (
				.clk(clk),
				.a(NTT_FIFO.dA[i * `BIT_WIDTH +: `BIT_WIDTH]),
				.b(key_FIFO[j].dA[i * `BIT_WIDTH +: `BIT_WIDTH]),
				.q(config_ports.q),
				.m(config_ports.m),
				.k2(config_ports.k2),
				.out(mult_out_A[j][i * `BIT_WIDTH +: `BIT_WIDTH])
			);
			mod_mult #(.MAX_BIT_WIDTH(`BIT_WIDTH)) mult_B (
				.clk(clk),
				.a(NTT_FIFO.dB[i * `BIT_WIDTH +: `BIT_WIDTH]),
				.b(key_FIFO[j].dB[i * `BIT_WIDTH +: `BIT_WIDTH]),
				.q(config_ports.q),
				.m(config_ports.m),
				.k2(config_ports.k2),
				.out(mult_out_B[j][i * `BIT_WIDTH +: `BIT_WIDTH])
			);
		end
	end
endgenerate 

`ifndef FPGA_LESS_RST
	always_ff @(posedge clk) begin
		if(!rstn) begin
			state 		<= IDLE_RD1;
			rd_addrA 	<= 0;
			rd_addrB 	<= 1;
		end else begin
			state 		<= next;
			rd_addrA 	<= rd_addrA_next;
			rd_addrB 	<= rd_addrB_next;
		end
		wr_addrA 	<= rd_addrA;
		wr_addrB 	<= rd_addrB;
		wr_addrA_q 	<= wr_addrA;
		wr_addrB_q 	<= wr_addrB;
	end
`else 
	always_ff @(posedge clk) begin
		if(!rstn) begin
			state 		<= IDLE_RD1;
		end else begin
			state 		<= next;
		end
		rd_addrA 	<= rd_addrA_next;
		rd_addrB 	<= rd_addrB_next;
		wr_addrA 	<= rd_addrA;
		wr_addrB 	<= rd_addrB;
		wr_addrA_q 	<= wr_addrA;
		wr_addrB_q 	<= wr_addrB;
	end
`endif

always_comb begin
	case(state)
		IDLE_RD1: begin
			if(!NTT_FIFO.empty && !mult_FIFO_if[1].full && !mult_FIFO_if[0].full) begin
				if(NTT_FIFO.opcode == `RLWESUBS && NTT_FIFO.poly_id == `POLY_B) begin
					next 			= PASS;
					rd_addrA_next 	= rd_addrA + 2;
					rd_addrB_next 	= rd_addrB + 2;
					rd_finish_NTT	= 0;
					rd_finish_key 	= 1;
					wr_finish 		= 1;
				end else if(!key_FIFO[1].empty && !key_FIFO[0].empty) begin
					next 			= COMPUTE;
					rd_addrA_next 	= rd_addrA + 2;
					rd_addrB_next 	= rd_addrB + 2;
					rd_finish_NTT	= 0;
					rd_finish_key 	= 0;
					wr_finish 		= 1;
				end else begin
					next 			= IDLE_RD1;
					rd_addrA_next 	= 0;
					rd_addrB_next 	= 1;
					rd_finish_NTT	= 1;
					rd_finish_key	= 1;
					wr_finish 		= 1;
				end
			end else begin
				next 			= IDLE_RD1;
				rd_addrA_next 	= 0;
				rd_addrB_next 	= 1;
				rd_finish_NTT	= 1;
				rd_finish_key	= 1;
				wr_finish 		= 1;
			end
		end
		COMPUTE: begin
			if(rd_addrB == ((config_ports.length >> $clog2(`LINE_SIZE)) - 1)) begin
				next 			= W1;
				rd_addrA_next 	= 0;
			   	rd_addrB_next 	= 1;
				rd_finish_NTT	= 0;
				rd_finish_key	= 0;
				wr_finish 		= 0;
			end else begin
				next 			= COMPUTE;
				rd_addrA_next 	= rd_addrA + 2;
				rd_addrB_next 	= rd_addrB + 2;
				rd_finish_NTT	= 0;
				rd_finish_key	= 0;
				wr_finish 		= 0;
			end
		end
		W1: begin
			next 			= W2;
			rd_addrA_next 	= 0;
			rd_addrB_next 	= 1;
			rd_finish_NTT	= 0;
			rd_finish_key	= 0;
			wr_finish 		= 0;
		end
		W2: begin
			next 			= WAIT1_WR;
			rd_addrA_next 	= 0;
			rd_addrB_next 	= 1;
			rd_finish_NTT	= 0;
			rd_finish_key	= 0;
			wr_finish 		= 0;
		end
		WAIT1_WR: begin
			next 			= WAIT2_WR;
			rd_addrA_next 	= 0;
			rd_addrB_next 	= 1;
			rd_finish_NTT	= 1;
			rd_finish_key	= 1;
			wr_finish 		= 0;
		end
		WAIT2_WR: begin
			next 			= WAIT3_WR;
			rd_addrA_next 	= 0;
			rd_addrB_next 	= 1;
			rd_finish_NTT	= 1;
			rd_finish_key	= 1;
			wr_finish 		= 0;
		end
		WAIT3_WR: begin
			next 			= WAIT4_WR;
			rd_addrA_next 	= 0;
			rd_addrB_next 	= 1;
			rd_finish_NTT	= 1;
			rd_finish_key	= 1;
			wr_finish 		= 0;
		end
		WAIT4_WR: begin
			next 			= WAIT5_WR;
			rd_addrA_next 	= 0;
			rd_addrB_next 	= 1;
			rd_finish_NTT	= 1;
			rd_finish_key	= 1;
			wr_finish 		= 0;
		end
		WAIT5_WR: begin
			next 			= WAIT6_WR;
			rd_addrA_next 	= 0;
			rd_addrB_next 	= 1;
			rd_finish_NTT	= 1;
			rd_finish_key	= 1;
			wr_finish 		= 0;
		end
		WAIT6_WR: begin
			next 			= WAIT7_WR;
			rd_addrA_next 	= 0;
			rd_addrB_next 	= 1;
			rd_finish_NTT	= 1;
			rd_finish_key	= 1;
			wr_finish 		= 0;
		end
		WAIT7_WR: begin
			next 			= WAIT8_WR;
			rd_addrA_next 	= 0;
			rd_addrB_next 	= 1;
			rd_finish_NTT	= 1;
			rd_finish_key	= 1;
			wr_finish 		= 0;
		end
		WAIT8_WR: begin
			next 			= WAIT9_WR;
			rd_addrA_next 	= 0;
			rd_addrB_next 	= 1;
			rd_finish_NTT	= 1;
			rd_finish_key	= 1;
			wr_finish 		= 0;
		end
		WAIT9_WR: begin
			next 			= IDLE_RD1;
			rd_addrA_next 	= 0;
			rd_addrB_next 	= 1;
			rd_finish_NTT	= 1;
			rd_finish_key	= 1;
			wr_finish 		= 1;
		end
		PASS: begin
			if(rd_addrB == ((config_ports.length >> $clog2(`LINE_SIZE)) - 1)) begin
				next 			= PASS_W1;
				rd_addrA_next 	= 0;
			   	rd_addrB_next 	= 1;
				rd_finish_NTT	= 0;
				rd_finish_key	= 1;
				wr_finish 		= 0;
			end else begin
				next 			= PASS;
				rd_addrA_next 	= rd_addrA + 2;
				rd_addrB_next 	= rd_addrB + 2;
				rd_finish_NTT	= 0;
				rd_finish_key	= 1;
				wr_finish 		= 0;
			end
		end
		PASS_W1: begin
		    next 			= PASS_W2;
		    rd_addrA_next 	= 0;
		    rd_addrB_next 	= 1;
		    rd_finish_NTT	= 0;
		    rd_finish_key	= 1;
		    wr_finish 		= 0;
		end
		PASS_W2: begin
			next 			= IDLE_RD1;
		    rd_addrA_next 	= 0;
		    rd_addrB_next 	= 1;
		    rd_finish_NTT	= 1;
		    rd_finish_key	= 1;
		    wr_finish 		= 1;
		end
		default: begin
			next 			= IDLE_RD1;
			rd_addrA_next 	= 0;
			rd_addrB_next 	= 1;
			rd_finish_NTT	= 1;
			rd_finish_key	= 1;
			wr_finish 		= 1;
		end
	endcase
end

endmodule

