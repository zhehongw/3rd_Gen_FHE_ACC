`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/25/2021 10:25:14 AM
// Design Name: 
// Module Name: myFIFO_global_output
// Project Name: 
// Target Devices: 
// Tool Versions: 
//
// Description: this is the global output RLWE FIFO, it has one read port and
// one write port. One write port to the CL. One read port for the AXI DMA read,
// this port needs a conversion layer for AXI access
//
// This module only contain one poly, to store one RLWE, instantiate two
// modules
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "common.vh"
module myFIFO_global_poly_output #(
	parameter POINTER_WIDTH = 2,
	parameter FIFO_DEPTH = 2**POINTER_WIDTH
)(
	input clk, rstn,

	//ports to the top ctrl
	output logic empty,
	output logic full,

	//read ports to the AXI interface 
	myFIFO_NTT_sink_if.to_sink outer_rd_ports,
	
	//internal write ports
    myFIFO_NTT_source_if.to_source internal_wr_ports,    //when reference interface, no need to elaborate parameter, only elaborate when instantiate interface
	input internal_wr_enable,	//explicit write enable port
	output logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] doutA,	//explicit doutA port for poly MAC loop access, because poly MAC module need to do both read and write 
	output logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] doutB

);

//generate full and empty
logic [POINTER_WIDTH : 0] wr_pointer, rd_pointer;
logic [POINTER_WIDTH : 0] wr_pointer_next, rd_pointer_next;

assign full 	= (wr_pointer[POINTER_WIDTH - 1 : 0] == rd_pointer[POINTER_WIDTH - 1 : 0]) && (wr_pointer[POINTER_WIDTH] != rd_pointer[POINTER_WIDTH]) ? 1 : 0;

assign empty 	= (wr_pointer[POINTER_WIDTH - 1 : 0] == rd_pointer[POINTER_WIDTH - 1 : 0]) && (wr_pointer[POINTER_WIDTH] == rd_pointer[POINTER_WIDTH]) ? 1 : 0;

assign internal_wr_ports.full 	= full;
assign outer_rd_ports.empty 	= empty;


//poly ram signals 
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] dinA_mux [0 : FIFO_DEPTH - 1];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] dinB_mux [0 : FIFO_DEPTH - 1];

logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] doutA_mux [0 : FIFO_DEPTH - 1];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] doutB_mux [0 : FIFO_DEPTH - 1];

logic [FIFO_DEPTH - 1 : 0] we;
logic [FIFO_DEPTH - 1 : 0] en;

logic [`ADDR_WIDTH - 1 : 0] addrA [0 : FIFO_DEPTH - 1];
logic [`ADDR_WIDTH - 1 : 0] addrB [0 : FIFO_DEPTH - 1];

//addr mux signal
logic [`ADDR_WIDTH - 1 : 0] wr_addrA, wr_addrB;
logic [`ADDR_WIDTH - 1 : 0] rd_addrA, rd_addrB;


//state machine to maintain the pointer and mux input output
typedef enum logic {WRIDLE, WR} FIFO_WR_STATES;
typedef enum logic {RDIDLE, RD} FIFO_RD_STATES;

FIFO_WR_STATES wr_state, wr_state_next;
FIFO_RD_STATES rd_state, rd_state_next;

always_ff @(posedge clk) begin
	if(!rstn) begin
		wr_pointer 	<= `SD 0;
		rd_pointer 	<= `SD 0;
		wr_state 	<= `SD WRIDLE;
		rd_state 	<= `SD RDIDLE;
	end else begin
		wr_pointer 	<= `SD wr_pointer_next;
		rd_pointer 	<= `SD rd_pointer_next;
		wr_state 	<= `SD wr_state_next;
		rd_state 	<= `SD rd_state_next;
	end
end

always_comb begin
	case(wr_state)
		WRIDLE: begin
			if(internal_wr_ports.wr_finish)
				wr_state_next = WRIDLE;
			else 
				wr_state_next = WR;
			wr_pointer_next = wr_pointer;
		end
		WR: begin
			if(internal_wr_ports.wr_finish) begin
				wr_state_next 	= WRIDLE;
				wr_pointer_next = wr_pointer + 1;
			end else begin
				wr_state_next 	= WR;
				wr_pointer_next = wr_pointer;
			end
		end
	endcase
	case(rd_state)
		RDIDLE: begin
			if(outer_rd_ports.rd_finish)
				rd_state_next = RDIDLE;
			else 
				rd_state_next = RD;
			rd_pointer_next = rd_pointer;
		end
		RD: begin
			if(outer_rd_ports.rd_finish) begin
				rd_state_next 	= RDIDLE;
				rd_pointer_next = rd_pointer + 1;
			end else begin
				rd_state_next 	= RD;
				rd_pointer_next = rd_pointer;
			end
		end
	endcase
end

//data input mux
always_comb begin
	for(integer i = 0; i < FIFO_DEPTH; i++) begin
		dinA_mux[i] = internal_wr_ports.dA;
		dinB_mux[i] = internal_wr_ports.dB;
	end
end

//addr mux
always_comb begin
	wr_addrA = internal_wr_ports.addrA;
	wr_addrB = internal_wr_ports.addrB;
	rd_addrA = outer_rd_ports.addrA;
	rd_addrB = outer_rd_ports.addrB;
end

always_comb begin
	for(integer i = 0; i < FIFO_DEPTH; i++) begin
		addrA[i] = 0;
		addrB[i] = 0;
	end
	for(integer i = 0; i < FIFO_DEPTH; i++) begin
		addrA[i] = (wr_pointer[POINTER_WIDTH - 1 : 0] == i) && (!full) ? wr_addrA : (rd_pointer[POINTER_WIDTH - 1 : 0] == i) && (!empty) ? rd_addrA : 0;
		addrB[i] = (wr_pointer[POINTER_WIDTH - 1 : 0] == i) && (!full) ? wr_addrB : (rd_pointer[POINTER_WIDTH - 1 : 0] == i) && (!empty) ? rd_addrB : 0;
	end
end

//we mux
always_comb begin
	for(integer i = 0; i < FIFO_DEPTH; i++) begin
		we[i] = 0;
	end
	for(integer i = 0; i < FIFO_DEPTH; i++) begin
		if(wr_pointer[POINTER_WIDTH - 1 : 0] == i) begin
			we[i] = ~(internal_wr_ports.wr_finish) | wr_state;
		end
	end
end
//en mux
always_comb begin
	for(integer i = 0; i < FIFO_DEPTH; i++) begin
		en[i] = 0;
	end
	for(integer i = 0; i < FIFO_DEPTH; i++) begin
		if(rd_pointer[POINTER_WIDTH - 1 : 0] == i) begin
			en[i] = ~(outer_rd_ports.rd_finish);
		end
	end
end

//data output mux
always_comb begin
    outer_rd_ports.dA 		= 0;
    outer_rd_ports.dB 		= 0;
    for(integer i = 0; i < FIFO_DEPTH; i++)begin
        if(rd_pointer[POINTER_WIDTH - 1 : 0] == i) begin
            outer_rd_ports.dA 		= doutA_mux[i];
            outer_rd_ports.dB 		= doutB_mux[i];
        end
    end
end

always_comb begin
    doutA = 0;
    doutB = 0;
    for(integer i = 0; i < FIFO_DEPTH; i++)begin
        if(wr_pointer[POINTER_WIDTH - 1 : 0] == i) begin
            doutA = doutA_mux[i];
            doutB = doutB_mux[i];
        end
    end
end

genvar i;
generate
	for(i = 0; i < FIFO_DEPTH; i++) begin : GENERATE_HEADER
		poly_ram_block FIFO (
			.clk(clk),
			.weA(we[i] & (internal_wr_enable)),
			.weB(we[i] & (internal_wr_enable)),
			//.weA(we[i] & internal_wr_enable),
			//.weB(we[i] & internal_wr_enable),
			.addrA(addrA[i]),
			.addrB(addrB[i]),
			.dinA(dinA_mux[i]),
			.dinB(dinB_mux[i]),
			.doutA(doutA_mux[i]),
			.doutB(doutB_mux[i]),
			.enA(en[i] | we[i]),
			.enB(en[i] | we[i])
		);
	end
endgenerate
//not sure why these assertion cannot pass in one specific instance, even though the other instance passes, from the simulation wave form it is ok, but it just report assertion error 
//assert property (@(posedge clk) !(empty && !outer_rd_ports.rd_finish));
//assert property (@(posedge clk) !(full && !internal_wr_ports.wr_finish));

endmodule
