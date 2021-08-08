`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/25/2021 10:25:14 AM
// Design Name: 
// Module Name: myFIFO_key_loading
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
module myFIFO_key_loading #(
	parameter POINTER_WIDTH = 5,
	parameter FIFO_DEPTH = 2**POINTER_WIDTH
)(
	input clk, rstn,
	//source ports
	input wr_enable,	//explicite wr_enable port, to disable write when input is not valid
    myFIFO_NTT_source_if.to_source source_ports,    //when reference interface, no need to elaborate parameter, only elaborate when instantiate interface
	myFIFO_NTT_sink_if.to_sink sink_ports

);
//generate full and empty
logic [POINTER_WIDTH : 0] wr_pointer, rd_pointer;
logic [POINTER_WIDTH : 0] wr_pointer_next, rd_pointer_next;

assign source_ports.full = (wr_pointer[POINTER_WIDTH - 1 : 0] == rd_pointer[POINTER_WIDTH - 1 : 0]) && (wr_pointer[POINTER_WIDTH] != rd_pointer[POINTER_WIDTH]) ? 1 : 0;

assign sink_ports.empty = (wr_pointer[POINTER_WIDTH - 1 : 0] == rd_pointer[POINTER_WIDTH - 1 : 0]) && (wr_pointer[POINTER_WIDTH] == rd_pointer[POINTER_WIDTH]) ? 1 : 0;

//state machine for FIFO update
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] doutA_mux [0 : FIFO_DEPTH - 1];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] doutB_mux [0 : FIFO_DEPTH - 1];

logic [FIFO_DEPTH - 1 : 0] we;
logic [FIFO_DEPTH - 1 : 0] en;

logic [`ADDR_WIDTH - 1 : 0] addrA [0 : FIFO_DEPTH - 1];
logic [`ADDR_WIDTH - 1 : 0] addrB [0 : FIFO_DEPTH - 1];

//logic [`RLWE_ID_WIDTH - 1 : 0] rlwe_id_fifo [0 : FIFO_DEPTH - 1];
//logic [`RLWE_ID_WIDTH - 1 : 0] rlwe_id_fifo_next [0 : FIFO_DEPTH - 1];
//
//logic [`POLY_ID_WIDTH - 1 : 0] poly_id_fifo [0 : FIFO_DEPTH - 1];
//logic [`POLY_ID_WIDTH - 1 : 0] poly_id_fifo_next [0 : FIFO_DEPTH - 1];
//
//logic [`OPCODE_WIDTH - 1 : 0] opcode_fifo [0 : FIFO_DEPTH - 1];
//logic [`OPCODE_WIDTH - 1 : 0] opcode_fifo_next [0 : FIFO_DEPTH - 1];

logic wr_state, rd_state;
logic wr_state_next, rd_state_next;

always_ff @(posedge clk) begin
	if(!rstn) begin
		wr_pointer <= `SD 0;
		rd_pointer <= `SD 0;
		wr_state <= `SD 0;
		rd_state <= `SD 0;
		//for(int i = 0; i < FIFO_DEPTH; i++) begin
		//	rlwe_id_fifo[i] <= `SD 0;
		//	poly_id_fifo[i] <= `SD 0;
		//	opcode_fifo[i] <= `SD 0;
		//end
	end else begin
		wr_pointer <= `SD wr_pointer_next;
		rd_pointer <= `SD rd_pointer_next;
		wr_state <=  `SD wr_state_next;
		rd_state <=  `SD rd_state_next;
		//for(int i = 0; i < FIFO_DEPTH; i++) begin
		//	rlwe_id_fifo[i] <= `SD rlwe_id_fifo_next[i];
		//	poly_id_fifo[i] <= `SD poly_id_fifo_next[i];
		//	opcode_fifo[i] <= `SD opcode_fifo_next[i];
		//end
	end
end

always_comb begin
	case(wr_state)
		0: begin
			if(!source_ports.wr_finish)begin
			 	wr_state_next = 1;
			end else begin
				wr_state_next = 0;
			end
			wr_pointer_next = wr_pointer;
		end
		1: begin
			if(source_ports.wr_finish)begin
				wr_state_next = 0;
				wr_pointer_next = wr_pointer + 1;
			end else begin
				wr_state_next = 1;
				wr_pointer_next = wr_pointer;
			end
		end
	endcase
	case(rd_state)
		0: begin
			if(!sink_ports.rd_finish)begin
			 	rd_state_next = 1;
			end else begin
				rd_state_next = 0;
			end
			rd_pointer_next = rd_pointer;
		end
		1: begin
			if(sink_ports.rd_finish)begin
				rd_state_next = 0;
				rd_pointer_next = rd_pointer + 1;
			end else begin
				rd_state_next = 1;
				rd_pointer_next = rd_pointer;
			end
		end
	endcase
end

//rlwe_id_fifo update state machine
//always_comb begin
//	case(wr_state)
//		0: begin
//			for(int i = 0; i < FIFO_DEPTH; i++)	begin
//				rlwe_id_fifo_next[i] = (i == wr_pointer[POINTER_WIDTH - 1 : 0]) && (!source_ports.wr_finish) ? source_ports.rlwe_id : rlwe_id_fifo[i];
//				poly_id_fifo_next[i] = (i == wr_pointer[POINTER_WIDTH - 1 : 0]) && (!source_ports.wr_finish) ? source_ports.poly_id : poly_id_fifo[i];
//				opcode_fifo_next[i] = (i == wr_pointer[POINTER_WIDTH - 1 : 0]) && (!source_ports.wr_finish) ? source_ports.opcode : opcode_fifo[i];
//			end
//		end
//		1: begin
//			for(int i = 0; i < FIFO_DEPTH; i++)	begin
//				rlwe_id_fifo_next[i] = rlwe_id_fifo[i];
//				poly_id_fifo_next[i] = poly_id_fifo[i];
//				opcode_fifo_next[i] = opcode_fifo[i];
//			end
//		end
//	endcase
//end
always_comb begin
    sink_ports.dA = 0;
    sink_ports.dB = 0;
    for(integer i = 0; i < FIFO_DEPTH; i++)begin
        if(rd_pointer[POINTER_WIDTH - 1 : 0] == i) begin
            sink_ports.dA = doutA_mux[i];
            sink_ports.dB = doutB_mux[i];
        end
    end
end
//assign sink_ports.dA = doutA_mux[rd_pointer[POINTER_WIDTH - 1 : 0]];
//assign sink_ports.dB = doutB_mux[rd_pointer[POINTER_WIDTH - 1 : 0]];

//assign sink_ports.rlwe_id = rlwe_id_fifo[rd_pointer[POINTER_WIDTH - 1 : 0]];
//assign sink_ports.poly_id = poly_id_fifo[rd_pointer[POINTER_WIDTH - 1 : 0]];
//assign sink_ports.opcode = opcode_fifo[rd_pointer[POINTER_WIDTH - 1 : 0]];

genvar i;
generate
	for(i = 0; i < FIFO_DEPTH; i++) begin : GENERATE_HEADER
		assign addrA[i] = ((wr_pointer[POINTER_WIDTH - 1 : 0] == i) && (!source_ports.full)) ? 
		                                                  source_ports.addrA : ((rd_pointer[POINTER_WIDTH - 1 : 0] == i) && (!sink_ports.empty)) ? 
		                                                  sink_ports.addrA : 0;
		assign addrB[i] = ((wr_pointer[POINTER_WIDTH - 1 : 0] == i) && (!source_ports.full)) ? 
		                                                  source_ports.addrB : ((rd_pointer[POINTER_WIDTH - 1 : 0] == i) && (!sink_ports.empty)) ? 
		                                                  sink_ports.addrB : 0;
		assign we[i] = (wr_pointer[POINTER_WIDTH - 1 : 0] == i) ? (~source_ports.wr_finish | wr_state) : 0;   // this makes it possible to raise finish with the last addr
		assign en[i] = (rd_pointer[POINTER_WIDTH - 1 : 0] == i) ? (~sink_ports.rd_finish) : 0;                // read needs to wait one cycle to finish, since read is different from write
		                                                                                                      // write can finish as soon as address reaches the end, but read need to wait 
		                                                                                                      // for the data to return   
		
		poly_ram_block FIFO (
			.clk(clk),
			.weA(we[i] & wr_enable),
			.weB(we[i] & wr_enable),
			.addrA(addrA[i]),
			.addrB(addrB[i]),
			.dinA(source_ports.dA),
			.dinB(source_ports.dB),
			.doutA(doutA_mux[i]),
			.doutB(doutB_mux[i]),
			.enA(en[i]),
			.enB(en[i])
		);
	end
endgenerate


assert property (@(posedge clk) !(sink_ports.empty && !sink_ports.rd_finish));
assert property (@(posedge clk) !(source_ports.full && !source_ports.wr_finish));


endmodule
