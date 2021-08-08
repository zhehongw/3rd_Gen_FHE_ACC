`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/25/2021 10:25:14 AM
// Design Name: 
// Module Name: DMA_AXI_to_output_poly_FIFO
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// This a interface conversion module for the DMA communication between SH and
// onchip output RLWE/poly FIFO, it connects two poly fifos, one for poly a, one for
// poly b. It is a read only module, all the write channels are tied. 
//
// This module currenly ignores the full and empty signal of the
// FIFOs, it should be taken care of in the application code
//
// Current address space is the max poly length * 2, which is 2K * 8B * 2 = 32KB. so
// addr width is 15 bits. The two polys in one RLWE has adjecent addr, for example, 
// addr of poly a is 0 to 16K - 1, and addr for poly b is 16K to 32K - 1
// 
// Currently, this module will ignore the input axi addr, the addr mapping in
// the top addr space is taken care of by the axi interconnect. This module
// assumes that the SH always writes from addr 0x4_0000_0000 to 0x4_0000_0000
// + 16K for 1k length poly or 0x4_0000_0000 + 32K for 2k length poly. 
// 
// So this module will only use the wvalid in the wr channel and rready in the
// rd channel to synchoronize the transaction. This means the SH must always
// write the full addr space of this module according to the length setting.
// No random address read/write allowed.
//
// The wstrb and wrsize are always taken as full, ie, wstrb = 3F, and
// wrsize = 63, all 512 bits of the input data are used. wrlen is also always 
// taken as full, which is 4K/64 = 64. As long as the SH 
// write/read addr to is aligned to 4K boundary, this is always satisfied.
//
// Currently I am not going to support full AXI features in this module,
// mainly multithreading read/write, but I don't know whether it works with
// the DMA interface, I will have to simulate and do a actual test. This will
// be the main work in the coming week. 
//
// AXI signals ignored for now: wstrb, and any id information will just be
// latched and sent back. AWS fixed awsize/rsize to 64, so this input is also ignored.
// Assume that the DMA does not change id when writing/reading the whole FIFO addr space.
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "common.vh"
module DMA_AXI_to_output_poly_FIFO #(
	parameter POINTER_WIDTH = 2,
	parameter BUFFER_DEPTH = 2**POINTER_WIDTH
)(
	input clk, rstn,

	config_if.to_top config_ports,
	//axi port for DMA access
	axi_bus_if.to_master DMA_if,

	//read port to the FIFO
	myFIFO_NTT_sink_if.to_FIFO read_ports_0,
	myFIFO_NTT_sink_if.to_FIFO read_ports_1
);

//tie the write channels 
assign DMA_if.awready 	= 1'b1;
assign DMA_if.wready 	= 1'b1;
assign DMA_if.bid 		= 1'b0;
assign DMA_if.bresp 	= 1'b0;
assign DMA_if.bvalid 	= 1'b0;


//read state machine
typedef enum logic [2 : 0] {RDIDLE, RDDATA1, RDDATA2, RDDATA3, RDHOLD, RDWAIT} axi_DMA_rd_states;
axi_DMA_rd_states DMA_rd_state, DMA_rd_next; 
logic [15 : 0] rdid, rdid_next;
//ignore the rdlen signal
//logic [7 : 0] rdlen, rdlen_next;
//assume rdsize is always 63
//logic [2 : 0] rdsize, rdsize_next;

logic 	[`ADDR_WIDTH - 1 : 0] 				rd_addrA;
logic 	[`ADDR_WIDTH - 1 : 0] 				rd_addrB;

logic 	[7 : 0] 							rd_transaction_len_counter, rd_transaction_len_counter_next; 	// this is used to count len in each transaction, it references the actual transfer number, represent how many transfer have happened, fixed to 63 max
//logic [$clog2(`MAX_LEN * 8 * 2) - 1 : 0] 	rd_addr_latch, rd_addr_latch_next; 
logic 	[$clog2(`MAX_LEN * 8 * 2) : 0] 		rd_length_counter, rd_length_counter_next;	// this is used to count the total amount of byte that has transferred, it is used to generate the read_finish signal to the fifo 
logic 	[$clog2(`MAX_LEN * 8 * 2) : 0] 		rd_length_counter_q1, rd_length_counter_q2;	// this is used to count the total amount of byte that has transferred, it is used to generate the read_finish signal to the fifo 
logic 	[511 : 0] 	rdata_hold_latch, rdata_hold_latch_next;	//hold the output data when rready is not set

logic 	[5 : 0] 							arvalid_counter, arvalid_counter_next; //this counter is used to count the number of read requests received, by counting the arvalid signal. The count is used to maintain an order of the ar channel and the rd channel, rd channel response have to come after an ar channel request, currently support 64 outstanding ar requests
logic 										arvalid_counter_incr, arvalid_counter_decr;

//tie arready, ignore the input addr, assume it always goes from 0 to 16k or
//32k
assign DMA_if.arready = 1;

//state machine to maintain the arvalid counter
always_ff @(posedge clk) begin
	if(!rstn) begin
		arvalid_counter <= `SD 0;
	end else begin
		arvalid_counter <= `SD arvalid_counter_next;
	end
end

assign arvalid_counter_incr = DMA_if.arready & DMA_if.arvalid;
assign arvalid_counter_decr = rd_transaction_len_counter == 63 ? DMA_if.rready & DMA_if.rvalid : 0;

always_comb begin
	case({arvalid_counter_incr, arvalid_counter_decr})
		2'b00: begin
			arvalid_counter_next = arvalid_counter;
		end
		2'b01: begin
			arvalid_counter_next = arvalid_counter - 1;
		end
		2'b10: begin
			arvalid_counter_next = arvalid_counter + 1;
		end
		2'b11: begin
			arvalid_counter_next = arvalid_counter;
		end
	endcase
end
//assert that the counter cannot decrement when counter equals to zero
assert property (@(posedge clk) !(arvalid_counter_decr && (arvalid_counter == 0)));

//rdid latch, assume DMA does not change id when accessing the FIFO addr space
always_ff @(posedge clk) begin
	if(!rstn) begin
		rdid 	<= `SD 0;
	end else begin
		rdid 	<= `SD rdid_next;
	end
end
always_comb begin
	if(DMA_if.arvalid && DMA_if.arready) begin
		rdid_next 	= DMA_if.arid;
	end else begin
		rdid_next 	= rdid;
	end
end

generate
	if(`LINE_SIZE == 4) begin
	//if LINE_SIZE == 4,in this case the two polys are stored in succession,
	//with poly a comes before poly b
		always_ff @(posedge clk) begin
			if(!rstn) begin
				DMA_rd_state 				<= `SD RDIDLE;
				rd_length_counter 			<= `SD 0;
				rd_transaction_len_counter 	<= `SD 0;
				rdata_hold_latch 			<= `SD 0;
				rd_length_counter_q1 		<= `SD 0;
				rd_length_counter_q2 		<= `SD 0;
			end else begin
				DMA_rd_state 				<= `SD DMA_rd_next;
				rd_length_counter 			<= `SD rd_length_counter_next;
				rd_transaction_len_counter 	<= `SD rd_transaction_len_counter_next;
				rdata_hold_latch 			<= `SD rdata_hold_latch_next;
				rd_length_counter_q1 		<= `SD rd_length_counter;
				rd_length_counter_q2 		<= `SD rd_length_counter_q1;
			end
		end

		always_comb begin
			case(DMA_rd_state)
				RDIDLE: begin
				//wait for arvalid, and jump to RDDATA1 state. 
				//Compared to write, rd needs to happen after ar channel has
				//a request, so read need to wait for arvalid signal
					//state machine signals
					if(arvalid_counter != 0) begin
						DMA_rd_next = RDDATA1;
					end else begin
						DMA_rd_next = RDIDLE;
					end
					rd_length_counter_next 			= 0;
					rd_transaction_len_counter_next = 0;

					//DMA if output signals
					DMA_if.rvalid 	= 0;
					DMA_if.rlast 	= 0;

					//FIFO output signals
					read_ports_0.rd_finish = 1;
					read_ports_1.rd_finish = 1;

					rdata_hold_latch_next = DMA_if.rdata;
				end
				RDDATA1: begin
				//since there is a two-cycle latency in the fifo ram module,
				//need to have a have a transition state for the first read,
				//no data is actually transferred to AXI in this state
					//state machine signals
					DMA_rd_next 					= RDDATA2;
					rd_length_counter_next 			= rd_length_counter + 64;
					rd_transaction_len_counter_next = rd_transaction_len_counter;

					//DMA if output signals
					DMA_if.rvalid 	= 0;
					DMA_if.rlast 	= 0;

					//FIFO output signals
					read_ports_0.rd_finish = 0;
					read_ports_1.rd_finish = 0;

					rdata_hold_latch_next = DMA_if.rdata;
				end
				RDDATA2: begin
				//since there is a two-cycle latency in the fifo ram module,
				//need to have a have a transition state for the first read,
				//no data is actually transferred to AXI in this state
					//state machine signals
					DMA_rd_next 					= RDDATA3;
					rd_length_counter_next 			= rd_length_counter + 64;
					rd_transaction_len_counter_next = rd_transaction_len_counter;

					//DMA if output signals
					DMA_if.rvalid 	= 0;
					DMA_if.rlast 	= 0;

					//FIFO output signals
					read_ports_0.rd_finish = 0;
					read_ports_1.rd_finish = 0;

					rdata_hold_latch_next = DMA_if.rdata;
				end
				RDDATA3: begin
				//this state put data on the AXI bus
					//state machine signals
					if(DMA_if.rready) begin
						DMA_rd_next 					= rd_transaction_len_counter == 63 ? RDWAIT : RDDATA3;
						rd_length_counter_next 			= rd_length_counter + 64;
						rd_transaction_len_counter_next = rd_transaction_len_counter + 1;
					end else begin
						DMA_rd_next 					= RDHOLD;
						rd_length_counter_next 			= rd_length_counter;
						rd_transaction_len_counter_next = rd_transaction_len_counter;
					end

					//DMA if output signals
					DMA_if.rvalid 	= 1;
					DMA_if.rlast 	= rd_transaction_len_counter == 63 ? 1 : 0;

					//FIFO output signals
					read_ports_0.rd_finish = 0;
					read_ports_1.rd_finish = 0;

					rdata_hold_latch_next = DMA_if.rdata;
				end

				RDHOLD: begin
				// this state holds the output data until the rready is set
					//state machine signals
					if(DMA_if.rready) begin
						DMA_rd_next 					= rd_transaction_len_counter == 63 ? RDWAIT : RDDATA1;
						rd_length_counter_next 			= rd_transaction_len_counter == 63 ? rd_length_counter + 64 : rd_length_counter - 64;
						rd_transaction_len_counter_next = rd_transaction_len_counter + 1;
					end else begin
						DMA_rd_next 					= RDHOLD;
						rd_length_counter_next 			= rd_length_counter;
						rd_transaction_len_counter_next = rd_transaction_len_counter;
					end

					//DMA if output signals
					DMA_if.rvalid 	= 1;
					DMA_if.rlast 	= rd_transaction_len_counter == 63 ? 1 : 0;

					//FIFO output signals
					read_ports_0.rd_finish = 0;
					read_ports_1.rd_finish = 0;

					rdata_hold_latch_next = rdata_hold_latch;
				end
				
				RDWAIT: begin
				//this state waits for the next write transaction 
					//state machine signals
					case(config_ports.length)
						1024: begin
						//1k length of poly, total length is 16K
							case({rd_length_counter[$clog2(`MAX_LEN * 8 * 2) - 1], arvalid_counter != 0})
								2'b11: begin
									DMA_rd_next 			= RDDATA1;
									rd_length_counter_next 	= 0;
								end
								2'b10: begin
									DMA_rd_next 			= RDIDLE;
									rd_length_counter_next 	= 0;
								end
								2'b01: begin
									DMA_rd_next 			= RDDATA1;
									rd_length_counter_next 	= rd_length_counter - 64 * 2;
								end
								2'b00: begin
									DMA_rd_next 			= RDWAIT;
									rd_length_counter_next 	= rd_length_counter - 64 * 2;
								end
							endcase
						end
						2048: begin
						//2K length of poly, total length is 32K
							case({rd_length_counter[$clog2(`MAX_LEN * 8 * 2)], arvalid_counter != 0})
								2'b11: begin
									DMA_rd_next 			= RDDATA1;
									rd_length_counter_next 	= 0;
								end
								2'b10: begin
									DMA_rd_next 			= RDIDLE;
									rd_length_counter_next 	= 0;
								end
								2'b01: begin
									DMA_rd_next 			= RDDATA1;
									rd_length_counter_next 	= rd_length_counter - 64 * 2;
								end
								2'b00: begin
									DMA_rd_next 			= RDWAIT;
									rd_length_counter_next 	= rd_length_counter - 64 * 2;
								end
							endcase
						end
						default: begin
							DMA_rd_next 			= RDIDLE;
							rd_length_counter_next 	= 0;
						end
					endcase
					rd_transaction_len_counter_next = 0; 

					rdata_hold_latch_next = DMA_if.rdata;
					//DMA if output signals
					DMA_if.rvalid 	= 0;
					DMA_if.rlast 	= 0;

					//FIFO output signals
					case(config_ports.length)
						1024: begin
						//1k length of poly, total length is 16K
							if(rd_length_counter[$clog2(`MAX_LEN * 8 * 2) - 1]) begin
								read_ports_0.rd_finish = 1;
								read_ports_1.rd_finish = 1;
							end else begin
								read_ports_0.rd_finish = 0;
								read_ports_1.rd_finish = 0;
							end
						end 
						2048: begin
						//2k length of poly, total length is 32K
							if(rd_length_counter[$clog2(`MAX_LEN * 8 * 2)]) begin
								read_ports_0.rd_finish = 1;
								read_ports_1.rd_finish = 1;
							end else begin
								read_ports_0.rd_finish = 0;
								read_ports_1.rd_finish = 0;
							end
						end
						default: begin
							read_ports_0.rd_finish = 1;
							read_ports_1.rd_finish = 1;
						end
					endcase
				end
				default: begin
					//state machine signals
					DMA_rd_next 					= RDIDLE;
					rd_length_counter_next 			= 0;
					rd_transaction_len_counter_next = 0;

					//DMA if output signals
					DMA_if.rvalid 	= 0;
					DMA_if.rlast 	= 0;

					//FIFO output signals
					read_ports_0.rd_finish = 1;
					read_ports_1.rd_finish = 1;
					rdata_hold_latch_next = 0;
				end
			endcase
		end

		//data assignment
		always_comb begin
			case({config_ports.length, (DMA_rd_state == RDHOLD)})
				{12'd1024,1'b0}: begin
					for(integer j = 0; j < `LINE_SIZE; j++) begin
						 DMA_if.rdata[`LINE_SIZE * 0 * 64 + j * 64 +: 64] = rd_length_counter_q2[$clog2(`MAX_LEN * 8 * 2) - 2] ? 
							 												{{(64 - `BIT_WIDTH){1'b0}}, read_ports_1.dA[j * `BIT_WIDTH +: `BIT_WIDTH]} : 
							 												{{(64 - `BIT_WIDTH){1'b0}}, read_ports_0.dA[j * `BIT_WIDTH +: `BIT_WIDTH]};
						 DMA_if.rdata[`LINE_SIZE * 1 * 64 + j * 64 +: 64] = rd_length_counter_q2[$clog2(`MAX_LEN * 8 * 2) - 2] ? 
							 												{{(64 - `BIT_WIDTH){1'b0}}, read_ports_0.dB[j * `BIT_WIDTH +: `BIT_WIDTH]} : 
																			{{(64 - `BIT_WIDTH){1'b0}}, read_ports_1.dB[j * `BIT_WIDTH +: `BIT_WIDTH]};
					end
				end
				{12'd1024,1'b1}: begin
						 DMA_if.rdata = rdata_hold_latch;
				end
				{12'd2048, 1'b0}: begin
					for(integer j = 0; j < `LINE_SIZE; j++) begin
						 DMA_if.rdata[`LINE_SIZE * 0 * 64 + j * 64 +: 64] = rd_length_counter_q2[$clog2(`MAX_LEN * 8 * 2) - 1] ? 
							 												{{(64 - `BIT_WIDTH){1'b0}}, read_ports_1.dA[j * `BIT_WIDTH +: `BIT_WIDTH]} : 
							 												{{(64 - `BIT_WIDTH){1'b0}}, read_ports_0.dA[j * `BIT_WIDTH +: `BIT_WIDTH]};
						 DMA_if.rdata[`LINE_SIZE * 1 * 64 + j * 64 +: 64] = rd_length_counter_q2[$clog2(`MAX_LEN * 8 * 2) - 1] ? 
							 												{{(64 - `BIT_WIDTH){1'b0}}, read_ports_0.dB[j * `BIT_WIDTH +: `BIT_WIDTH]} : 
																			{{(64 - `BIT_WIDTH){1'b0}}, read_ports_1.dB[j * `BIT_WIDTH +: `BIT_WIDTH]};
					end
				end
				{12'd2048,1'b1}: begin
						 DMA_if.rdata = rdata_hold_latch;
				end
				default: begin
					for(integer j = 0; j < `LINE_SIZE; j++) begin
						 DMA_if.rdata[`LINE_SIZE * 0 * 64 + j * 64 +: 64] = rd_length_counter_q2[$clog2(`MAX_LEN * 8 * 2) - 1] ? 
							 												{{(64 - `BIT_WIDTH){1'b0}}, read_ports_1.dA[j * `BIT_WIDTH +: `BIT_WIDTH]} : 
							 												{{(64 - `BIT_WIDTH){1'b0}}, read_ports_0.dA[j * `BIT_WIDTH +: `BIT_WIDTH]};
						 DMA_if.rdata[`LINE_SIZE * 1 * 64 + j * 64 +: 64] = rd_length_counter_q2[$clog2(`MAX_LEN * 8 * 2) - 1] ? 
							 												{{(64 - `BIT_WIDTH){1'b0}}, read_ports_0.dB[j * `BIT_WIDTH +: `BIT_WIDTH]} : 
																			{{(64 - `BIT_WIDTH){1'b0}}, read_ports_1.dB[j * `BIT_WIDTH +: `BIT_WIDTH]};
					end
				end
			endcase
		end			
		

		//addr assignment, when `LINE_SIZE == 4
		assign rd_addrA = rd_length_counter[$clog2(8 * `LINE_SIZE) +: `ADDR_WIDTH];
		assign rd_addrB = rd_length_counter[$clog2(8 * `LINE_SIZE) +: `ADDR_WIDTH] + 1;

		assign read_ports_0.addrA = rd_addrA;
		assign read_ports_0.addrB = rd_addrB;
		//since the two poly are concatenated when programming the fifo, need
		//to remap the addr for poly b when length is 1024
		always_comb begin
			case(config_ports.length)
				1024: begin
					read_ports_1.addrA = {1'b0, rd_addrA[`ADDR_WIDTH - 2 : 0]};
					read_ports_1.addrB = {1'b0, rd_addrB[`ADDR_WIDTH - 2 : 0]};
				end
				2048: begin
					read_ports_1.addrA = rd_addrA;
					read_ports_1.addrB = rd_addrB;
				end
				default: begin
					read_ports_1.addrA = rd_addrA;
					read_ports_1.addrB = rd_addrB;
				end
			endcase
		end

		//signals always tied 
		assign DMA_if.rresp 	= 0;	//read response is always 0
		assign DMA_if.rid 		= rdid;

	end else begin
	//if LINE_SIZE == 2, in this case, the two input polys are stored in
	//paralle. For example, in a 512 bit transfer with addr from 0 to 63, the
	//first 32 bytes are for poly a, and the second 32 bytes are for poly b.
	//This should be mapped when SH is pining the memory for DMA 
		always_ff @(posedge clk) begin
			if(!rstn) begin
				DMA_rd_state 				<= `SD RDIDLE;
				rd_length_counter 			<= `SD 0;
				rd_transaction_len_counter 	<= `SD 0;
				rdata_hold_latch 			<= `SD 0;
				//rd_length_counter_q1 		<= `SD 0;
				//rd_length_counter_q2 		<= `SD 0;
			end else begin
				DMA_rd_state 				<= `SD DMA_rd_next;
				rd_length_counter 			<= `SD rd_length_counter_next;
				rd_transaction_len_counter 	<= `SD rd_transaction_len_counter_next;
				rdata_hold_latch 			<= `SD rdata_hold_latch_next;
				//rd_length_counter_q1 		<= `SD rd_length_counter;
				//rd_length_counter_q2 		<= `SD rd_length_counter_q1;
			end
		end

		always_comb begin
			case(DMA_rd_state)
				RDIDLE: begin
				//wait for arvalid, and jump to ARREADY state. 
				//can merge ARREADY state with this state by setting arready
				//always high for better transaction efficiency, but that 
				//can lead to freq degradation, so for now keep them seperated 
					//state machine signals
					if(arvalid_counter != 0) begin
						DMA_rd_next = RDDATA1;
					end else begin
						DMA_rd_next = RDIDLE;
					end
					rd_length_counter_next 			= 0;
					rd_transaction_len_counter_next = 0;

					//DMA if output signals
					DMA_if.rvalid 	= 0;
					DMA_if.rlast 	= 0;

					//FIFO output signals
					read_ports_0.rd_finish = 1;
					read_ports_1.rd_finish = 1;

					rdata_hold_latch_next = DMA_if.rdata;
				end
				RDDATA1: begin
				//since there is a two-cycle latency in the fifo ram module,
				//need to have a have a transition state for the first read,
				//no data is actually transferred to AXI in this state
					//state machine signals
					DMA_rd_next 					= RDDATA2;
					rd_length_counter_next 			= rd_length_counter + 32;
					rd_transaction_len_counter_next = rd_transaction_len_counter;

					//DMA if output signals
					DMA_if.rvalid 	= 0;
					DMA_if.rlast 	= 0;

					//FIFO output signals
					read_ports_0.rd_finish = 0;
					read_ports_1.rd_finish = 0;

					rdata_hold_latch_next = DMA_if.rdata;
				end
				RDDATA2: begin
				//since there is a two-cycle latency in the fifo ram module,
				//need to have a have a transition state for the first read,
				//no data is actually transferred to AXI in this state
					//state machine signals
					DMA_rd_next 					= RDDATA3;
					rd_length_counter_next 			= rd_length_counter + 32;
					rd_transaction_len_counter_next = rd_transaction_len_counter;

					//DMA if output signals
					DMA_if.rvalid 	= 0;
					DMA_if.rlast 	= 0;

					//FIFO output signals
					read_ports_0.rd_finish = 0;
					read_ports_1.rd_finish = 0;

					rdata_hold_latch_next = DMA_if.rdata;
				end
				RDDATA3: begin
				//this state put data on the AXI bus
					//state machine signals
					if(DMA_if.rready) begin
						DMA_rd_next 					= rd_transaction_len_counter == 63 ? RDWAIT : RDDATA3;
						rd_length_counter_next 			= rd_length_counter + 32;
						rd_transaction_len_counter_next = rd_transaction_len_counter + 1;
					end else begin
						DMA_rd_next 					= RDHOLD;
						rd_length_counter_next 			= rd_length_counter;
						rd_transaction_len_counter_next = rd_transaction_len_counter;
					end

					//DMA if output signals
					DMA_if.rvalid 	= 1;
					DMA_if.rlast 	= rd_transaction_len_counter == 63 ? 1 : 0;

					//FIFO output signals
					read_ports_0.rd_finish = 0;
					read_ports_1.rd_finish = 0;

					rdata_hold_latch_next = DMA_if.rdata;
				end

				RDHOLD: begin
				// this state holds the output data until the rready is set
					//state machine signals
					if(DMA_if.rready) begin
						DMA_rd_next 					= rd_transaction_len_counter == 63 ? RDWAIT : RDDATA1;
						rd_length_counter_next 			= rd_transaction_len_counter == 63 ? rd_length_counter + 32 : rd_length_counter - 32;
						rd_transaction_len_counter_next = rd_transaction_len_counter + 1;
					end else begin
						DMA_rd_next 					= RDHOLD;
						rd_length_counter_next 			= rd_length_counter;
						rd_transaction_len_counter_next = rd_transaction_len_counter;
					end

					//DMA if output signals
					DMA_if.rvalid 	= 1;
					DMA_if.rlast 	= rd_transaction_len_counter == 63 ? 1 : 0;

					//FIFO output signals
					read_ports_0.rd_finish = 0;
					read_ports_1.rd_finish = 0;

					rdata_hold_latch_next = rdata_hold_latch;
				end

				RDWAIT: begin
				//this state waits for the next write transaction 
					//state machine signals
					case(config_ports.length)
						1024: begin
						//1k length of poly, total length is 16K
							case({rd_length_counter[$clog2(`MAX_LEN * 8 *2) - 2], arvalid_counter != 0})
								2'b11: begin
									DMA_rd_next 			= RDDATA1;
									rd_length_counter_next 	= 0;
								end
								2'b10: begin
									DMA_rd_next 			= RDIDLE;
									rd_length_counter_next 	= 0;
								end
								2'b01: begin
									DMA_rd_next 			= RDDATA1;
									rd_length_counter_next 	= rd_length_counter - 32 * 2;
								end
								2'b00: begin
									DMA_rd_next 			= RDWAIT;
									rd_length_counter_next 	= rd_length_counter - 32 * 2;
								end
							endcase
						end
						2048: begin
						//2K length of poly, total length is 32K
							case({rd_length_counter[$clog2(`MAX_LEN * 8 *2) - 1], arvalid_counter != 0})
								2'b11: begin
									DMA_rd_next 			= RDDATA1;
									rd_length_counter_next 	= 0;
								end
								2'b10: begin
									DMA_rd_next 			= RDIDLE;
									rd_length_counter_next 	= 0;
								end
								2'b01: begin
									DMA_rd_next 			= RDDATA1;
									rd_length_counter_next 	= rd_length_counter - 32 * 2;
								end
								2'b00: begin
									DMA_rd_next 			= RDWAIT;
									rd_length_counter_next 	= rd_length_counter - 32 * 2;
								end
							endcase
						end
						default: begin
							DMA_rd_next 			= RDIDLE;
							rd_length_counter_next 	= 0;
						end
					endcase
					rd_transaction_len_counter_next = 0; 

					rdata_hold_latch_next = DMA_if.rdata;
					//DMA if output signals
					DMA_if.rvalid 	= 0;
					DMA_if.rlast 	= 0;

					//FIFO output signals
					case(config_ports.length)
						1024: begin
						//1k length of poly, total length is 16K
							if(rd_length_counter[$clog2(`MAX_LEN * 8 *2) - 2]) begin
								read_ports_0.rd_finish = 1;
								read_ports_1.rd_finish = 1;
							end else begin
								read_ports_0.rd_finish = 0;
								read_ports_1.rd_finish = 0;
							end
						end 
						2048: begin
						//2k length of poly, total length is 32K
							if(rd_length_counter[$clog2(`MAX_LEN * 8 *2) - 1]) begin
								read_ports_0.rd_finish = 1;
								read_ports_1.rd_finish = 1;
							end else begin
								read_ports_0.rd_finish = 0;
								read_ports_1.rd_finish = 0;
							end
						end
						default: begin
							read_ports_0.rd_finish = 1;
							read_ports_1.rd_finish = 1;
						end
					endcase
				end
				default: begin
					//state machine signals
					DMA_rd_next 					= RDIDLE;
					rd_length_counter_next 			= 0;
					rd_transaction_len_counter_next = 0;

					//DMA if output signals
					DMA_if.rvalid 	= 0;
					DMA_if.rlast 	= 0;

					//FIFO output signals
					read_ports_0.rd_finish = 1;
					read_ports_1.rd_finish = 1;

					rdata_hold_latch_next = 0;
				end
			endcase
		end

		//data assignment
		always_comb begin
			case(DMA_rd_state) 
				RDHOLD: begin
					DMA_if.rdata = rdata_hold_latch;
				end
				default: begin
					for(integer j = 0; j < `LINE_SIZE; j++) begin
						 DMA_if.rdata[`LINE_SIZE * 0 * 64 + j * 64 +: 64] = {{(64 - `BIT_WIDTH){1'b0}}, read_ports_0.dA[j * `BIT_WIDTH +: `BIT_WIDTH]};
						 DMA_if.rdata[`LINE_SIZE * 1 * 64 + j * 64 +: 64] = {{(64 - `BIT_WIDTH){1'b0}}, read_ports_0.dB[j * `BIT_WIDTH +: `BIT_WIDTH]};
						 DMA_if.rdata[`LINE_SIZE * 2 * 64 + j * 64 +: 64] = {{(64 - `BIT_WIDTH){1'b0}}, read_ports_1.dA[j * `BIT_WIDTH +: `BIT_WIDTH]};
						 DMA_if.rdata[`LINE_SIZE * 3 * 64 + j * 64 +: 64] = {{(64 - `BIT_WIDTH){1'b0}}, read_ports_1.dB[j * `BIT_WIDTH +: `BIT_WIDTH]};
					end
				end
			endcase
		end			

		//addr assignment, when `LINE_SIZE == 2, the two FIFOs are read at
		//the same time, and the outputs are combined into one 512 bit word
		assign rd_addrA = rd_length_counter[$clog2(8 * `LINE_SIZE) +: `ADDR_WIDTH];
		assign rd_addrB = rd_length_counter[$clog2(8 * `LINE_SIZE) +: `ADDR_WIDTH] + 1;

		assign read_ports_0.addrA = rd_addrA;
		assign read_ports_0.addrB = rd_addrB;
		assign read_ports_1.addrA = rd_addrA;
		assign read_ports_1.addrB = rd_addrB;

		//signals always tied 
		assign DMA_if.rresp 	= 0;	//read response is always 0
		assign DMA_if.rid 		= rdid;
	end
endgenerate
endmodule
