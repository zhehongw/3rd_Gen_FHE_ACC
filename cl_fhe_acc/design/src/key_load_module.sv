`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/25/2021 10:25:14 AM
// Design Name: 
// Module Name: key_load_module
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: the module that loads the keys from AXI bus to key FIFO, it
// has two queues, one for addr and opcode, the other for the loaded poly
// 				
// Currently, only LINE_SIZE = 4 and LINE_SIZE = 2 are supported  
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "common.vh"
module  key_load_module #(
	parameter INST_POINTER_WIDTH = 3,
	parameter INST_FIFO_DEPTH = 2**INST_POINTER_WIDTH,
	parameter POLY_POINTER_WIDTH = 3,
	parameter POLY_FIFO_DEPTH = 2**POLY_POINTER_WIDTH
)(
	input clk, rstn,

	//ports to the top control, for enqueue the addr and opcode 
	output logic inst_fifo_full,
	output logic inst_fifo_empty,
	input wr_enable, //to enqueue inst fifo
	input [`OPCODE_WIDTH - 1 : 0] opcode_in,
	input [`KEY_ADDR_WIDTH - `KEY_ADDR_WIDTH_LSB - 1 : 0] base_addr_in,	//key base addr in the CL DRAM. 
									//For RLWE key switch, this is the base
									//addr of the key switch key.
									//For bootstrap, this is the base addr of
									//a RGSW ciphertext 
									//the width is 30-bit, so only 1GB of addr
									//space

	//ports to DDR AXI, to load key from offchip
	axi_bus_if.to_slave DDR_axi_if,
		
	//ports to poly_mult_RLWE module, to read the poly FIFO
	myFIFO_NTT_sink_if.to_sink key_FIFO_if [1 : 0],
	
	//config ports
	config_if.to_top config_ports
);


logic [1 : 0] key_FIFO_wr_enable;	//to prevent extra writing when waiting for DDR
myFIFO_NTT_source_if key_FIFO_src_if [1 : 0]();

myFIFO_key_loading #(.POINTER_WIDTH(POLY_POINTER_WIDTH)) key_FIFO [1 : 0](
	.clk(clk),
	.rstn(rstn),
	.wr_enable(key_FIFO_wr_enable),
	.source_ports(key_FIFO_src_if),
	.sink_ports(key_FIFO_if)
);

//RLWE inst input FIFO, to cache the opcode and base addr
`ifndef FPGA_LESS_RST
	logic [`OPCODE_WIDTH - 1 : 0] opcode_fifo [INST_FIFO_DEPTH - 1 : 0];
	logic [`KEY_ADDR_WIDTH - `KEY_ADDR_WIDTH_LSB - 1 : 0] base_addr_fifo [INST_FIFO_DEPTH - 1 : 0];
	logic [INST_POINTER_WIDTH : 0] inst_wr_pointer;
	logic [INST_POINTER_WIDTH : 0] inst_rd_pointer;
`else
	logic [`OPCODE_WIDTH - 1 : 0] opcode_fifo [INST_FIFO_DEPTH - 1 : 0] 		                    = '{INST_FIFO_DEPTH{`INVALIDOP}};
	logic [`KEY_ADDR_WIDTH - `KEY_ADDR_WIDTH_LSB - 1 : 0] base_addr_fifo [INST_FIFO_DEPTH - 1 : 0] 	= '{INST_FIFO_DEPTH{0}};
	logic [INST_POINTER_WIDTH : 0] inst_wr_pointer = 0;
	logic [INST_POINTER_WIDTH : 0] inst_rd_pointer = 0;
`endif


logic [`OPCODE_WIDTH - 1 : 0] opcode_fifo_next [INST_FIFO_DEPTH - 1 : 0];
logic [`KEY_ADDR_WIDTH - `KEY_ADDR_WIDTH_LSB - 1 : 0] base_addr_fifo_next [INST_FIFO_DEPTH - 1 : 0];

logic [INST_POINTER_WIDTH : 0] inst_wr_pointer_next;
logic [INST_POINTER_WIDTH : 0] inst_rd_pointer_next;
logic inst_rd_enable;

assign inst_fifo_full = inst_rd_pointer[INST_POINTER_WIDTH - 1 : 0] == inst_wr_pointer[INST_POINTER_WIDTH - 1 : 0] ? inst_rd_pointer[INST_POINTER_WIDTH] ^ inst_wr_pointer[INST_POINTER_WIDTH] : 0;
assign inst_fifo_empty = inst_rd_pointer[INST_POINTER_WIDTH - 1 : 0] == inst_wr_pointer[INST_POINTER_WIDTH - 1 : 0] ? ~(inst_rd_pointer[INST_POINTER_WIDTH] ^ inst_wr_pointer[INST_POINTER_WIDTH]) : 0;

`ifndef FPGA_LESS_RST
	always_ff @(posedge clk) begin
		if(!rstn) begin
			inst_rd_pointer <= `SD 0;
			inst_wr_pointer <= `SD 0;
			for(integer i = 0; i < INST_FIFO_DEPTH; i++) begin
				opcode_fifo[i] 		<= `SD `INVALIDOP;
				base_addr_fifo[i] 	<= `SD 0;
			end
		end else begin
			inst_rd_pointer <= `SD inst_rd_pointer_next;
			inst_wr_pointer <= `SD inst_wr_pointer_next;
			for(integer i = 0; i < INST_FIFO_DEPTH; i++) begin
				opcode_fifo[i] 		<= `SD opcode_fifo_next[i];
				base_addr_fifo[i] 	<= `SD base_addr_fifo_next[i];
			end
		end
	end
`else
	always_ff @(posedge clk) begin
		inst_rd_pointer <= `SD inst_rd_pointer_next;
		inst_wr_pointer <= `SD inst_wr_pointer_next;
		for(integer i = 0; i < INST_FIFO_DEPTH; i++) begin
			opcode_fifo[i] 		<= `SD opcode_fifo_next[i];
			base_addr_fifo[i] 	<= `SD base_addr_fifo_next[i];
		end
	end
`endif	

always_comb begin
	for(integer i = 0; i < INST_FIFO_DEPTH; i++) begin
		opcode_fifo_next[i] 	= opcode_fifo[i];
		base_addr_fifo_next[i] 	= base_addr_fifo[i];
	end
	inst_wr_pointer_next = inst_wr_pointer;
	inst_rd_pointer_next = inst_rd_pointer;
	if(wr_enable) begin
		for(integer i = 0; i < INST_FIFO_DEPTH; i++) begin
			if(i == inst_wr_pointer[INST_POINTER_WIDTH - 1 : 0]) begin
				opcode_fifo_next[i] 	= opcode_in;
				base_addr_fifo_next[i] 	= base_addr_in;
			end
		end
		inst_wr_pointer_next = inst_wr_pointer + 1;
	end 
	if(inst_rd_enable) begin
		inst_rd_pointer_next = inst_rd_pointer + 1;
	end
end

assert property (@(posedge clk) ~(inst_fifo_full & wr_enable));
assert property (@(posedge clk) ~(inst_fifo_empty & inst_rd_enable));





`ifndef FPGA_LESS_RST
	logic [4 : 0] out_transaction_counter; 	//counter to keep track of the outstanding read requests, currently support 32 outstanding requests, not sure whether it is too large, need to verify
`else 
	logic [4 : 0] out_transaction_counter = 0; 
`endif
logic [4 : 0] out_transaction_counter_next; 

logic out_transaction_counter_incr; 
logic out_transaction_counter_decr; 

assign out_transaction_counter_incr = DDR_axi_if.arvalid & DDR_axi_if.arready;
assign out_transaction_counter_decr = DDR_axi_if.rvalid & DDR_axi_if.rready & DDR_axi_if.rlast;

`ifndef FPGA_LESS_RST
	always_ff @(posedge clk) begin
		if(!rstn) begin
			out_transaction_counter <= `SD 0; 
		end else begin
			out_transaction_counter <= `SD out_transaction_counter_next; 
		end
	end
`else 
	always_ff @(posedge clk) begin
		out_transaction_counter <= `SD out_transaction_counter_next; 
	end
`endif

always_comb begin
	case({out_transaction_counter_incr, out_transaction_counter_decr})
		2'b00: begin
			out_transaction_counter_next = out_transaction_counter;
		end
		2'b01: begin
			out_transaction_counter_next = out_transaction_counter - 1;
		end
		2'b10: begin
			out_transaction_counter_next = out_transaction_counter + 1;
		end
		2'b11: begin
			out_transaction_counter_next = out_transaction_counter;
		end
	endcase	
end

assert property (@(posedge clk) !(out_transaction_counter_decr && (out_transaction_counter == 0)));
assert property (@(posedge clk) !(out_transaction_counter_incr && (out_transaction_counter == 31)));

//ar channel state machine, detached from read channel for higher bandwidth
typedef enum logic [2 : 0] {ARIDLE, ARVALID, ARCHECKSEG, ARCHECKRLWE} key_load_ar_states;
key_load_ar_states ar_state, ar_next;
logic [`KEY_ADDR_WIDTH - 1 : 0] base_addr_q, base_addr_q_next;
logic [`OPCODE_WIDTH - 1 : 0] opcode_q, opcode_q_next;
logic [6 : 0] RLWE_counter, RLWE_counter_next;		//count the number of RLWEs  

logic [2 : 0] ar_segment_counter, ar_segment_counter_next;//count the number of segments 
logic [2 : 0] ar_num_segment;	//number of segment of one RLWE, controlled by poly length

logic [5 : 0] digitG2; 		//digitG * 2

assign digitG2 		= config_ports.digitG << 1;

assign ar_num_segment 	= (config_ports.length >> 8) - 1; 	//num_segment = length * 2 * 8 / 4K, not need to differentiate the LINE_SIZE for this  

//set arlen, arsize
assign DDR_axi_if.arlen 	= 64 -1;
assign DDR_axi_if.arsize 	= 6;	

//assign the DDR if araddr
assign DDR_axi_if.araddr = {{(64 - `KEY_ADDR_WIDTH){1'b0}}, base_addr_q};

//state machine for ar channel
always_ff @(posedge clk) begin
	if(!rstn) begin
		ar_state 			<= `SD ARIDLE;
		opcode_q 			<= `SD `INVALIDOP;
		base_addr_q 		<= `SD 0;
		RLWE_counter 		<= `SD 0;
		ar_segment_counter 	<= `SD 0;
	end else begin
		ar_state 			<= `SD ar_next;
		opcode_q 			<= `SD opcode_q_next;
		base_addr_q 		<= `SD base_addr_q_next;
		RLWE_counter 		<= `SD RLWE_counter_next;
		ar_segment_counter 	<= `SD ar_segment_counter_next;
	end
end

always_comb begin
	case(ar_state) 
		ARIDLE: begin
			if(!inst_fifo_empty && out_transaction_counter != 31) begin
				ar_next 		= ARVALID;
				inst_rd_enable 	= 1;	
			end else begin
				ar_next 		= ARIDLE;
				inst_rd_enable 	= 0;	
			end
			opcode_q_next		        = opcode_fifo[inst_rd_pointer[INST_POINTER_WIDTH - 1 : 0]];
			base_addr_q_next	        = {base_addr_fifo[inst_rd_pointer[INST_POINTER_WIDTH - 1 : 0]], {`KEY_ADDR_WIDTH_LSB{1'b0}}};
			RLWE_counter_next 	        = 0;
			ar_segment_counter_next 	= 0;
			DDR_axi_if.arvalid 	        = 0;
		end
		ARVALID: begin
			if(DDR_axi_if.arready) begin
				ar_next 		= ARCHECKSEG;
			end else begin
				ar_next 		= ARVALID;
			end
			inst_rd_enable 				= 0;	
			opcode_q_next				= opcode_q;
			base_addr_q_next			= base_addr_q;
			RLWE_counter_next 			= RLWE_counter;
			ar_segment_counter_next 	= ar_segment_counter;
			DDR_axi_if.arvalid 			= 1;
		end
		ARCHECKSEG: begin
			if(out_transaction_counter != 31) begin
				if(ar_segment_counter == ar_num_segment) begin
					ar_next 			= ARCHECKRLWE;
				end else begin
					ar_next 			= ARVALID;
				end
				base_addr_q_next			= base_addr_q + 4096;
				ar_segment_counter_next 	= ar_segment_counter + 1;
			end else begin
				ar_next 					= ARCHECKSEG;
				base_addr_q_next			= base_addr_q;
				ar_segment_counter_next 	= ar_segment_counter;
			end
			inst_rd_enable 		= 0;	
			opcode_q_next		= opcode_q;
			RLWE_counter_next 	= RLWE_counter;
			DDR_axi_if.arvalid 	= 0;
		end
		ARCHECKRLWE: begin
			case(opcode_q) 
				`BOOTSTRAP, `BOOTSTRAP_INIT, `RLWE_MULT_RGSW: begin
					if(RLWE_counter == (digitG2 - 1)) begin
						ar_next = ARIDLE;
					end else begin
						ar_next = out_transaction_counter != 31 ? ARVALID : ARCHECKRLWE;
					end
				end
				`RLWESUBS: begin
					if(RLWE_counter == (config_ports.digitG - 1)) begin
						ar_next = ARIDLE;
					end else begin
						ar_next = out_transaction_counter != 31 ? ARVALID : ARCHECKRLWE;
					end
				end
				default: begin
					ar_next = ARIDLE;
				end
			endcase	

			inst_rd_enable 				= 0;	
			opcode_q_next				= opcode_q;
			base_addr_q_next			= base_addr_q;
			RLWE_counter_next 			= out_transaction_counter != 31 ? RLWE_counter + 1: RLWE_counter;
			ar_segment_counter_next 	= 0;
			DDR_axi_if.arvalid 			= 0;
		end
		default: begin
			ar_next 					= ARIDLE;
			inst_rd_enable 				= 0;	
			opcode_q_next				= 0;
			base_addr_q_next			= 0;
			RLWE_counter_next 			= 0;
			ar_segment_counter_next 	= 0;
			DDR_axi_if.arvalid 			= 0;
		end
	endcase
end


//to fully utilize the 512 bit data bus, when `LINE_SIZE = 2, the two polys of
//one RLWE are stored in an interleaved fashion. So, the the lower half stores
//poly a and higher half stores poly b. When `LINE_SIZE = 4, the polys are
//stored in succession 
typedef enum logic [2 : 0] {IDLE, WRITERDATA, CHECKSEG, CHECKPOLY} key_load_states;
key_load_states state, next;
logic [`ADDR_WIDTH - 1 : 0] fifo_wr_addrA, fifo_wr_addrA_next;	//write addr to key fifo
logic [`ADDR_WIDTH - 1 : 0] fifo_wr_addrB, fifo_wr_addrB_next;
logic poly_counter, poly_counter_next; 							//select between poly a and b, not used when LINE_SIZE == 2
logic fifo_wr_finish;
logic [2 : 0] segment_counter, segment_counter_next;//count the number of segments 
logic [2 : 0] num_segment;	//number of segment of one poly, controlled by poly length

generate 
	if(`LINE_SIZE == 4) begin
	//when `LINE_SIZE = 4
		assign num_segment 	= ((config_ports.length >> 9) - 1); 	//num_segment = length * 8 / 4K
	end else begin
	//when `LINE_SIZE = 2
		assign num_segment 	= ((config_ports.length >> 8) - 1); 	//num_segment = length * 2 * 8 / 4K, when LINE_SIZE == 2, two polys are read at the same time, so num_segment is doubled 
	end
endgenerate

//assign key fifo write signals 
assign key_FIFO_src_if[0].wr_finish = fifo_wr_finish;
assign key_FIFO_src_if[1].wr_finish = fifo_wr_finish;

assign key_FIFO_src_if[0].addrA = fifo_wr_addrA;
assign key_FIFO_src_if[0].addrB = fifo_wr_addrB;
assign key_FIFO_src_if[1].addrA = fifo_wr_addrA;
assign key_FIFO_src_if[1].addrB = fifo_wr_addrB;

//rdata to fifo data according to the `LINE_SIZE
genvar i;
generate 
	if(`LINE_SIZE == 4) begin
		for(i = 0; i < `LINE_SIZE; i++) begin
			assign key_FIFO_src_if[0].dA[i * `BIT_WIDTH +: `BIT_WIDTH] = DDR_axi_if.rdata[`LINE_SIZE * 64 * 0 + i * 64 +: `BIT_WIDTH];
			assign key_FIFO_src_if[0].dB[i * `BIT_WIDTH +: `BIT_WIDTH] = DDR_axi_if.rdata[`LINE_SIZE * 64 * 1 + i * 64 +: `BIT_WIDTH];
			assign key_FIFO_src_if[1].dA[i * `BIT_WIDTH +: `BIT_WIDTH] = DDR_axi_if.rdata[`LINE_SIZE * 64 * 0 + i * 64 +: `BIT_WIDTH];
			assign key_FIFO_src_if[1].dB[i * `BIT_WIDTH +: `BIT_WIDTH] = DDR_axi_if.rdata[`LINE_SIZE * 64 * 1 + i * 64 +: `BIT_WIDTH];
		end	
	end else if(`LINE_SIZE == 2) begin
		for(i = 0; i < `LINE_SIZE; i++) begin
			assign key_FIFO_src_if[0].dA[i * `BIT_WIDTH +: `BIT_WIDTH] = DDR_axi_if.rdata[`LINE_SIZE * 64 * 0 + i * 64 +: `BIT_WIDTH];
			assign key_FIFO_src_if[0].dB[i * `BIT_WIDTH +: `BIT_WIDTH] = DDR_axi_if.rdata[`LINE_SIZE * 64 * 1 + i * 64 +: `BIT_WIDTH];
			assign key_FIFO_src_if[1].dA[i * `BIT_WIDTH +: `BIT_WIDTH] = DDR_axi_if.rdata[`LINE_SIZE * 64 * 2 + i * 64 +: `BIT_WIDTH];
			assign key_FIFO_src_if[1].dB[i * `BIT_WIDTH +: `BIT_WIDTH] = DDR_axi_if.rdata[`LINE_SIZE * 64 * 3 + i * 64 +: `BIT_WIDTH];
		end	
	end else begin
		assign key_FIFO_src_if[0].dA = 0;
		assign key_FIFO_src_if[0].dB = 0;
		assign key_FIFO_src_if[1].dA = 0;
		assign key_FIFO_src_if[1].dB = 0;
	end
endgenerate


//start state machine
always_ff @(posedge clk) begin
	if(!rstn) begin
		state 			<= `SD IDLE;
		fifo_wr_addrA 	<= `SD 0;
		fifo_wr_addrB 	<= `SD 1;
		segment_counter <= `SD 0;
		poly_counter 	<= `SD 0;
	end else begin
		state 			<= `SD next;
		fifo_wr_addrA 	<= `SD fifo_wr_addrA_next;
		fifo_wr_addrB 	<= `SD fifo_wr_addrB_next;
		segment_counter <= `SD segment_counter_next;
		poly_counter 	<= `SD poly_counter_next;
	end
end

generate 
	if(`LINE_SIZE == 4) begin
	//when `LINE_SIZE = 4 
		always_comb begin
			case(state)
				IDLE: begin
					if((out_transaction_counter != 0) && !key_FIFO_src_if[0].full && !key_FIFO_src_if[1].full) begin
						next	= WRITERDATA;
					end else begin
						next	= IDLE;
					end
					fifo_wr_addrA_next		= 0;
					fifo_wr_addrB_next		= 1;
					segment_counter_next	= 0;
					poly_counter_next 		= 0;
					DDR_axi_if.rready 		= 0;
					fifo_wr_finish 			= 1;
					key_FIFO_wr_enable[0] 	= 0;
					key_FIFO_wr_enable[1] 	= 0;
				end
				WRITERDATA: begin
					if(DDR_axi_if.rvalid) begin
						if(DDR_axi_if.rlast) begin
							next 					= CHECKSEG;
						end else begin
							next 					= WRITERDATA;
						end	
						fifo_wr_addrA_next 		= fifo_wr_addrA + 2;
						fifo_wr_addrB_next 		= fifo_wr_addrB + 2;
						key_FIFO_wr_enable[0] 	= ~poly_counter;
						key_FIFO_wr_enable[1] 	= poly_counter;
					end else begin
						next 					= WRITERDATA;
						fifo_wr_addrA_next 		= fifo_wr_addrA;
						fifo_wr_addrB_next 		= fifo_wr_addrB;
						key_FIFO_wr_enable[0] 	= 0;
						key_FIFO_wr_enable[1] 	= 0;
					end
					segment_counter_next	= segment_counter;
					poly_counter_next 		= poly_counter;
					DDR_axi_if.rready 		= 1;
					fifo_wr_finish 			= 0;
				end
				CHECKSEG: begin
					if(segment_counter == num_segment) begin
						next 					= CHECKPOLY;
						fifo_wr_addrA_next 		= 0;
						fifo_wr_addrB_next 		= 1;
						segment_counter_next	= 0;
					end else begin
						next 					= WRITERDATA;
						fifo_wr_addrA_next 		= fifo_wr_addrA;
						fifo_wr_addrB_next 		= fifo_wr_addrB;
						segment_counter_next	= segment_counter + 1;
					end
					poly_counter_next 		= poly_counter;
					key_FIFO_wr_enable[0] 	= 0;
					key_FIFO_wr_enable[1] 	= 0;
					DDR_axi_if.rready 		= 0;
					fifo_wr_finish 			= 0;
				end
				CHECKPOLY: begin
					if(!poly_counter) begin
						next 			= WRITERDATA;
						fifo_wr_finish 	= 0;
					end else begin
						next			= IDLE;
						fifo_wr_finish 	= 1;
					end
					fifo_wr_addrA_next 		= fifo_wr_addrA;
					fifo_wr_addrB_next 		= fifo_wr_addrB;
					segment_counter_next	= segment_counter;
					poly_counter_next 		= poly_counter + 1;
					key_FIFO_wr_enable[0] 	= 0;
					key_FIFO_wr_enable[1] 	= 0;
					DDR_axi_if.rready 		= 0;
				end
				default: begin
					next 					= IDLE;
					fifo_wr_addrA_next 		= 0;
					fifo_wr_addrB_next 		= 1;
					segment_counter_next 	= 0;
					poly_counter_next 		= 0;
					key_FIFO_wr_enable[0] 	= 0;
					key_FIFO_wr_enable[1] 	= 0;
					DDR_axi_if.rready 		= 0;
					fifo_wr_finish 			= 1;
				end
			endcase
		end
	end else begin
	//when LINE_SIZE = 2
		always_comb begin
			case(state)
				IDLE: begin
					if((out_transaction_counter != 0) && !key_FIFO_src_if[0].full && !key_FIFO_src_if[1].full) begin
						next	= WRITERDATA;
					end else begin
						next	= IDLE;
					end
					fifo_wr_addrA_next		= 0;
					fifo_wr_addrB_next		= 1;
					segment_counter_next	= 0;
					DDR_axi_if.rready 		= 0;
					fifo_wr_finish 			= 1;
					key_FIFO_wr_enable[0] 	= 0;
					key_FIFO_wr_enable[1] 	= 0;
				end
				WRITERDATA: begin
					if(DDR_axi_if.rvalid) begin
						if(DDR_axi_if.rlast) begin
							next 					= CHECKSEG;
						end else begin
							next 					= WRITERDATA;
						end	
						fifo_wr_addrA_next 		= fifo_wr_addrA + 2;
						fifo_wr_addrB_next 		= fifo_wr_addrB + 2;
						key_FIFO_wr_enable[0] 	= 1;
						key_FIFO_wr_enable[1] 	= 1;
					end else begin
						next 					= WRITERDATA;
						fifo_wr_addrA_next 		= fifo_wr_addrA;
						fifo_wr_addrB_next 		= fifo_wr_addrB;
						key_FIFO_wr_enable[0] 	= 0;
						key_FIFO_wr_enable[1] 	= 0;
					end
					segment_counter_next	= segment_counter;
					DDR_axi_if.rready 		= 1;
					fifo_wr_finish 			= 0;
				end
				CHECKSEG: begin
					if(segment_counter == num_segment) begin
						next 					= IDLE;
						fifo_wr_addrA_next 		= 0;
						fifo_wr_addrB_next 		= 1;
						segment_counter_next	= 0;
						fifo_wr_finish 			= 1;
					end else begin
						next 					= WRITERDATA;
						fifo_wr_addrA_next 		= fifo_wr_addrA;
						fifo_wr_addrB_next 		= fifo_wr_addrB;
						segment_counter_next	= segment_counter + 1;
						fifo_wr_finish 			= 0;
					end
					key_FIFO_wr_enable[0] 	= 0;
					key_FIFO_wr_enable[1] 	= 0;
					DDR_axi_if.rready 		= 0;
				end
				//this state is not needed when `LINE_SIZE == 2
				//CHECKPOLY: begin
				//end
				default: begin
					next 					= IDLE;
					fifo_wr_addrA_next 		= 0;
					fifo_wr_addrB_next 		= 1;
					segment_counter_next 	= 0;
					key_FIFO_wr_enable[0] 	= 0;
					key_FIFO_wr_enable[1] 	= 0;
					DDR_axi_if.rready 		= 0;
					fifo_wr_finish 			= 1;
				end
			endcase
		end
	end

endgenerate

//tie unused axi ports
always_comb begin
	//read ports
	DDR_axi_if.arid = 0;	//for now disable out of order function, with the same arid
	//write ports
	DDR_axi_if.awid 	= 0;
	DDR_axi_if.awaddr 	= 0;
	DDR_axi_if.awlen 	= 0;
	DDR_axi_if.awsize 	= 0;
	DDR_axi_if.awvalid 	= 0;
	DDR_axi_if.wid 		= 0;
	DDR_axi_if.wdata	= 0;
	DDR_axi_if.wstrb	= 0;
	DDR_axi_if.wlast	= 0;
	DDR_axi_if.wvalid	= 0;
	DDR_axi_if.bready	= 0;
end

endmodule
