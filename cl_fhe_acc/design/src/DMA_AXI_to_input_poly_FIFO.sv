`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/25/2021 10:25:14 AM
// Design Name: 
// Module Name: DMA_AXI_to_input_poly_FIFO
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// This a interface conversion module for the DMA communication between SH and
// onchip input RLWE/poly FIFO, it connects two poly fifos, one for poly a, one for
// poly b. It can be either written or read. 
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
module DMA_AXI_to_input_poly_FIFO #(
	parameter POINTER_WIDTH = 2,
	parameter BUFFER_DEPTH = 2**POINTER_WIDTH
)(
	input clk, rstn,

	config_if.to_top config_ports,
	//axi port for DMA access
	axi_bus_if.to_master DMA_if,

	//write port to the FIFO
    myFIFO_NTT_source_if.to_FIFO write_ports_0,   	// for poly a 
    myFIFO_NTT_source_if.to_FIFO write_ports_1,   	// for poly b
	output logic write_enable_0,							//explicit write enable signal 
	output logic write_enable_1,							//explicit write enable signal 
	
	//read port to the FIFO
	myFIFO_NTT_sink_if.to_FIFO read_ports_0,
	myFIFO_NTT_sink_if.to_FIFO read_ports_1
);

//write state machine
typedef enum logic [2 : 0] {WRIDLE, WREADY, BVALID, WRWAIT} axi_DMA_wr_states;
axi_DMA_wr_states DMA_wr_state, DMA_wr_next; 

//ignore wid for axi4
logic [15 : 0] wrid, wrid_next;		//assume that the DMA does not change awid when writing the whole FIFO space 	

//ignore the wrlen signal
//logic [7 : 0] wrlen, wrlen_next;

//assume wrsize is always 63
//logic [2 : 0] wrsize, wrsize_next;

logic [`ADDR_WIDTH - 1 : 0] 				wr_addrA;
logic [`ADDR_WIDTH - 1 : 0] 				wr_addrB;

//if the DMA follow the SH assigned addr exactly, wr_addr_latch and
//wr_length_counter are basically the same, for now let me keep it seprate
//for debug purpose 
//logic [$clog2(`MAX_LEN * 8 * 2) - 1 : 0] 	wr_addr_latch, wr_addr_latch_next; 
logic [$clog2(`MAX_LEN * 8 * 2) : 0] 		wr_length_counter, wr_length_counter_next;	// this is used to count the amount of byte that has transferred, it is used to generate the write_finish signal to the fifo 

//tie aw channel, ignore the input addr, assume it always goes from 0 to 16k
//or 32k, according to the length of poly
assign DMA_if.awready = 1;

//awid latch, for now assume that the DMA does not change id when accessing the FIFO addr space
always_ff @(posedge clk) begin
	if(!rstn) begin
		wrid 		<= `SD 0;
	end else begin
		wrid		<= `SD wrid_next;
	end
end

always_comb begin
	if(DMA_if.awvalid && DMA_if.awready) begin
		wrid_next 	= DMA_if.awid;
	end else begin
		wrid_next 	= wrid;
	end
end

//for different LINE_SIZE, take different state machine and data mapping,
//currently only support LINE_SIZE == 4 or 2
generate 
	if(`LINE_SIZE == 4) begin
	//if LINE_SIZE == 4, in this case the two polys are stored in succession,
	//with poly a comes before poly b
		always_ff @(posedge clk) begin
			if(!rstn) begin
				DMA_wr_state 		<= `SD WRIDLE;
				wr_length_counter	<= `SD 0;
				wrid 				<= `SD 0;
			end else begin
				DMA_wr_state 		<= `SD DMA_wr_next;
				wr_length_counter	<= `SD wr_length_counter_next;
				wrid				<= `SD wrid_next;
			end
		end
		
		always_comb begin
			case(DMA_wr_state) 
				WRIDLE: begin
				//wait for wvalid, and jump to WAITWDATA state. 
				//no need to wait for awvalid, since wvalid must come after
				//awvalid
				
					//state machine signals
					if(DMA_if.wvalid) begin
						DMA_wr_next = WREADY;
					end else begin
						DMA_wr_next = WRIDLE;
					end
					wr_length_counter_next	= 0;
					
					//DMA if output signals
					DMA_if.wready 		= 0;
					DMA_if.bvalid 		= 0;
					
					//FIFO output signals
					write_ports_0.wr_finish = 1;
					write_ports_1.wr_finish = 1;
					write_enable_0 			= 0;
					write_enable_1 			= 0;
				end
				WREADY: begin
				//this state write data to the FIFO	
					//state machine signals
					if(DMA_if.wlast) begin //use wlast as the AXI write finish signal, this save the length counter 
						DMA_wr_next 			= BVALID;
					end else begin
						DMA_wr_next 			= WREADY;
					end
					if(DMA_if.wvalid) begin
						wr_length_counter_next 	= wr_length_counter + 64;	//length increment is 64
					end else begin
						wr_length_counter_next 	= wr_length_counter;
					end
					//DMA if output signals
					DMA_if.wready 		= 1;
					DMA_if.bvalid 		= 0;

					//FIFO output signals
					write_ports_0.wr_finish = 0;
					write_ports_1.wr_finish = 0;
					case(config_ports.length)
						1024:begin
							write_enable_0 			= DMA_if.wvalid ? ~wr_length_counter[$clog2(`MAX_LEN * 8 * 2) - 2] : 0; 
							write_enable_1 			= DMA_if.wvalid ? wr_length_counter[$clog2(`MAX_LEN * 8 * 2) - 2] : 0;
						end
						2048:begin
							write_enable_0 			= DMA_if.wvalid ? ~wr_length_counter[$clog2(`MAX_LEN * 8 * 2) - 1] : 0; 
							write_enable_1 			= DMA_if.wvalid ? wr_length_counter[$clog2(`MAX_LEN * 8 * 2) - 1] : 0;
						end
						default: begin
							write_enable_0 			= 0; 
							write_enable_1 			= 0;
						end
					endcase
				end
				BVALID: begin
				//this state signals the write response channel 
					//state machine signals
					if(DMA_if.bready) begin
						DMA_wr_next = WRWAIT;
					end else begin
						DMA_wr_next = BVALID;
					end
					wr_length_counter_next 	= wr_length_counter;

					//DMA if output signals
					DMA_if.wready 		= 0;
					DMA_if.bvalid 		= 1;

					//FIFO output signals
					write_ports_0.wr_finish = 0;
					write_ports_1.wr_finish = 0;
					write_enable_0 			= 0;
					write_enable_1 			= 0;
				end
				WRWAIT: begin
				//this state waits for the next write transaction
					//state machine signals 
					case(config_ports.length)
						1024: begin
						//1k length of poly, total length is 16K
							case({wr_length_counter[$clog2(`MAX_LEN * 8 * 2) - 1], DMA_if.wvalid})
								2'b11: begin
									DMA_wr_next 			= WREADY;
									wr_length_counter_next 	= 0;
								end
								2'b10: begin
									DMA_wr_next 			= WRIDLE;
									wr_length_counter_next 	= 0;
								end
								2'b01: begin
									DMA_wr_next 			= WREADY;
									wr_length_counter_next 	= wr_length_counter;
								end
								2'b00: begin
									DMA_wr_next 			= WRWAIT;
									wr_length_counter_next 	= wr_length_counter;
								end
							endcase
						end 
						2048: begin
						//2k length of poly, total length is 32K
							case({wr_length_counter[$clog2(`MAX_LEN * 8 * 2)], DMA_if.wvalid})
								2'b11: begin
									DMA_wr_next 			= WREADY;
									wr_length_counter_next 	= 0;
								end
								2'b10: begin
									DMA_wr_next 			= WRIDLE;
									wr_length_counter_next 	= 0;
								end
								2'b01: begin
									DMA_wr_next 			= WREADY;
									wr_length_counter_next 	= wr_length_counter;
								end
								2'b00: begin
									DMA_wr_next 			= WRWAIT;
									wr_length_counter_next 	= wr_length_counter;
								end
							endcase
						end
						default: begin
							DMA_wr_next 			= WRIDLE;
							wr_length_counter_next 	= 0;
						end
					endcase

					//DMA if output signals
					DMA_if.wready 		= 0;
					DMA_if.bvalid 		= 0;

					//FIFO output signals
					case(config_ports.length)
						1024: begin
						//1k length of poly, total length is 16K
							if(wr_length_counter[$clog2(`MAX_LEN * 8 * 2) - 1]) begin
								write_ports_0.wr_finish = 1;
								write_ports_1.wr_finish = 1;
							end else begin
								write_ports_0.wr_finish = 0;
								write_ports_1.wr_finish = 0;
							end
						end 
						2048: begin
						//2k length of poly, total length is 32K
							if(wr_length_counter[$clog2(`MAX_LEN * 8 * 2)]) begin
								write_ports_0.wr_finish = 1;
								write_ports_1.wr_finish = 1;
							end else begin
								write_ports_0.wr_finish = 0;
								write_ports_1.wr_finish = 0;
							end
						end
						default: begin
							write_ports_0.wr_finish = 1;
							write_ports_1.wr_finish = 1;
						end
					endcase
					write_enable_0 			= 0;
					write_enable_1 			= 0;
				end
				default: begin
					//state machine signals
					DMA_wr_next 			= WRIDLE;
					wr_length_counter_next	= 0;
					
					//DMA if output signals
					DMA_if.wready 		= 0;
					DMA_if.bvalid 		= 0;
					
					//FIFO output signals
					write_ports_0.wr_finish = 1;
					write_ports_1.wr_finish = 1;
					write_enable_0 			= 0;
					write_enable_1 			= 0;
				end
			endcase
		end
		
		//data assignment, for now ignore wstrb signal, take it as all one
		always_comb begin
			for(integer j = 0; j < `LINE_SIZE; j++) begin
				write_ports_0.dA[j * `BIT_WIDTH +: `BIT_WIDTH] = DMA_if.wdata[`LINE_SIZE * 0 * 64 + j * 64 +: `BIT_WIDTH];
				write_ports_0.dB[j * `BIT_WIDTH +: `BIT_WIDTH] = DMA_if.wdata[`LINE_SIZE * 1 * 64 + j * 64 +: `BIT_WIDTH];
				write_ports_1.dA[j * `BIT_WIDTH +: `BIT_WIDTH] = DMA_if.wdata[`LINE_SIZE * 0 * 64 + j * 64 +: `BIT_WIDTH];
				write_ports_1.dB[j * `BIT_WIDTH +: `BIT_WIDTH] = DMA_if.wdata[`LINE_SIZE * 1 * 64 + j * 64 +: `BIT_WIDTH];
			end
		end
		
		//addr assignment, when `LINE_SIZE == 4, the two FIFOs are written
		//seperately 
		assign wr_addrA = wr_length_counter[$clog2(8 * `LINE_SIZE) +: `ADDR_WIDTH];
		assign wr_addrB = wr_length_counter[$clog2(8 * `LINE_SIZE) +: `ADDR_WIDTH] + 1;

		assign write_ports_0.addrA = wr_addrA;
		assign write_ports_0.addrB = wr_addrB;
		//since the two poly are concatenated when programming the fifo, need
		//to remap the addr for poly b when length is 1024
		always_comb begin
			case(config_ports.length) 
				1024: begin
					write_ports_1.addrA = {1'b0, wr_addrA[`ADDR_WIDTH - 2 : 0]};
					write_ports_1.addrB = {1'b0, wr_addrB[`ADDR_WIDTH - 2 : 0]};
				end
				2048: begin
					write_ports_1.addrA = wr_addrA;
					write_ports_1.addrB = wr_addrB;
				end
				default: begin
					write_ports_1.addrA = wr_addrA;
					write_ports_1.addrB = wr_addrB;
				end
			endcase
		end
		//signals always tied 
		assign DMA_if.bresp 	= 0;	//write response is always 0
		assign DMA_if.bid 		= wrid;
		assign DMA_if.wid 		= 0;
	
	end else begin
	//if LINE_SIZE == 2, in this case, the two input polys are stored in
	//paralle. For example, in a 512 bit transfer with addr from 0 to 63, the
	//first 32 bytes are for poly a, and the second 32 bytes are for poly b.
	//And they are write to the same address.
	//This should be mapped when SH is pining the memory for DMA.
	
		always_ff @(posedge clk) begin
			if(!rstn) begin
				DMA_wr_state 		<= `SD WRIDLE;
				wr_length_counter	<= `SD 0;
			end else begin
				DMA_wr_state 		<= `SD DMA_wr_next;
				wr_length_counter	<= `SD wr_length_counter_next;
			end
		end

		always_comb begin
			case(DMA_wr_state) 
				WRIDLE: begin
				//wait for wvalid, and jump to WREADY state. 
				
					//state machine signals
					if(DMA_if.wvalid) begin
						DMA_wr_next = WREADY;
					end else begin
						DMA_wr_next = WRIDLE;
					end
					wr_length_counter_next	= 0;
					
					//DMA if output signals
					DMA_if.wready 		= 0;
					DMA_if.bvalid 		= 0;
					
					//FIFO output signals
					write_ports_0.wr_finish = 1;
					write_ports_1.wr_finish = 1;
					write_enable_0 			= 0;
					write_enable_1 			= 0;
				end
				WREADY: begin
				//this state write data to the FIFO	
					//state machine signals
					if(DMA_if.wlast) begin //use wlast as the AXI write finish signal, this save the length counter 
						DMA_wr_next 			= BVALID;
					end else begin
						DMA_wr_next 			= WREADY;
					end

					if(DMA_if.wvalid) begin
						wr_length_counter_next 	= wr_length_counter + 32;	//length increment is 32
					end else begin
						wr_length_counter_next 	= wr_length_counter;
					end

					//DMA if output signals
					DMA_if.wready 		= 1;
					DMA_if.bvalid 		= 0;

					//FIFO output signals
					write_ports_0.wr_finish = 0;
					write_ports_1.wr_finish = 0;
					//since the two poly fifos are written at the same time,
					//the two fifo are enabled at the same time
					write_enable_0 			= DMA_if.wvalid;
					write_enable_1 			= DMA_if.wvalid;
				end
				BVALID: begin
				//this state signals the write response channel 
					//state machine signals
					if(DMA_if.bready) begin
						DMA_wr_next = WRWAIT;
					end else begin
						DMA_wr_next = BVALID;
					end
					wr_length_counter_next 	= wr_length_counter;

					//DMA if output signals
					DMA_if.wready 		= 0;
					DMA_if.bvalid 		= 1;

					//FIFO output signals
					write_ports_0.wr_finish = 0;
					write_ports_1.wr_finish = 0;
					write_enable_0 			= 0;
					write_enable_1 			= 0;

				end
				WRWAIT: begin
				//this state waits for the next write transaction
					//state machine signals 
					case(config_ports.length)
						1024: begin
						//1k length of poly, total length is 16K
							case({wr_length_counter[$clog2(`MAX_LEN * 8 * 2) - 2], DMA_if.wvalid})
								2'b11: begin
									DMA_wr_next 			= WREADY;
									wr_length_counter_next 	= 0;
								end
								2'b10: begin
									DMA_wr_next 			= WRIDLE;
									wr_length_counter_next 	= 0;
								end
								2'b01: begin
									DMA_wr_next 			= WREADY;
									wr_length_counter_next 	= wr_length_counter;
								end
								2'b00: begin
									DMA_wr_next 			= WRWAIT;
									wr_length_counter_next 	= wr_length_counter;
								end
							endcase
						end 
						2048: begin
						//2k length of poly, total length is 32K
							case({wr_length_counter[$clog2(`MAX_LEN * 8 * 2) - 1], DMA_if.wvalid})
								2'b11: begin
									DMA_wr_next 			= WREADY;
									wr_length_counter_next 	= 0;
								end
								2'b10: begin
									DMA_wr_next 			= WRIDLE;
									wr_length_counter_next 	= 0;
								end
								2'b01: begin
									DMA_wr_next 			= WREADY;
									wr_length_counter_next 	= wr_length_counter;
								end
								2'b00: begin
									DMA_wr_next 			= WRWAIT;
									wr_length_counter_next 	= wr_length_counter;
								end
							endcase
						end
						default: begin
							DMA_wr_next 			= WRIDLE;
							wr_length_counter_next 	= 0;
						end
					endcase

					//DMA if output signals
					DMA_if.wready 		= 0;
					DMA_if.bvalid 		= 0;

					//FIFO output signals
					case(config_ports.length)
						1024: begin
						//1k length of poly, total length is 16K, but since
						//the two polys are written at the same time, only 8K
						//length is tracked
							if(wr_length_counter[$clog2(`MAX_LEN * 8 * 2) - 2]) begin
								write_ports_0.wr_finish = 1;
								write_ports_1.wr_finish = 1;
							end else begin
								write_ports_0.wr_finish = 0;
								write_ports_1.wr_finish = 0;
							end
						end 
						2048: begin
						//2k length of poly, total length is 32K, but since
						//the two polys are written at the same time, only 16K
						//length is tracked
							if(wr_length_counter[$clog2(`MAX_LEN * 8 * 2) - 1]) begin
								write_ports_0.wr_finish = 1;
								write_ports_1.wr_finish = 1;
							end else begin
								write_ports_0.wr_finish = 0;
								write_ports_1.wr_finish = 0;
							end
						end
						default: begin
							write_ports_0.wr_finish = 1;
							write_ports_1.wr_finish = 1;
						end
					endcase
					write_enable_0 			= 0;
					write_enable_1 			= 0;
				end
				default: begin
					//state machine signals
					DMA_wr_next 			= WRIDLE;
					wr_length_counter_next	= 0;
					
					//DMA if output signals
					DMA_if.wready 		= 0;
					DMA_if.bvalid 		= 0;
					
					//FIFO output signals
					write_ports_0.wr_finish = 1;
					write_ports_1.wr_finish = 1;
					write_enable_0 			= 0;
					write_enable_1 			= 0;
				end
			endcase
		end
		
		//data assignment, for now ignore wstrb signal, take it as all one
		always_comb begin
			for(integer j = 0; j < `LINE_SIZE; j++) begin
				write_ports_0.dA[j * `BIT_WIDTH +: `BIT_WIDTH] = DMA_if.wdata[`LINE_SIZE * 0 * 64 + j * 64 +: `BIT_WIDTH];
				write_ports_0.dB[j * `BIT_WIDTH +: `BIT_WIDTH] = DMA_if.wdata[`LINE_SIZE * 1 * 64 + j * 64 +: `BIT_WIDTH];
				write_ports_1.dA[j * `BIT_WIDTH +: `BIT_WIDTH] = DMA_if.wdata[`LINE_SIZE * 2 * 64 + j * 64 +: `BIT_WIDTH];
				write_ports_1.dB[j * `BIT_WIDTH +: `BIT_WIDTH] = DMA_if.wdata[`LINE_SIZE * 3 * 64 + j * 64 +: `BIT_WIDTH];
			end
		end
		
		//addr assignment, when `LINE_SIZE == 2, the two FIFOs are written at
		//the same time
		assign wr_addrA = wr_length_counter[$clog2(8 * `LINE_SIZE) +: `ADDR_WIDTH];
		assign wr_addrB = wr_length_counter[$clog2(8 * `LINE_SIZE) +: `ADDR_WIDTH] + 1;

		assign write_ports_0.addrA = wr_addrA;
		assign write_ports_0.addrB = wr_addrB;
		assign write_ports_1.addrA = wr_addrA;
		assign write_ports_1.addrB = wr_addrB;

		//signals always tied 
		assign DMA_if.bresp 	= 0;	//write response is always 0
		assign DMA_if.bid 		= wrid;
		assign DMA_if.wid 		= 0;
	end
endgenerate



//read state machine
typedef enum logic [2 : 0] {RDIDLE, RDDATA1, RDDATA2, RDDATA3, RDHOLD, RDWAIT} axi_DMA_rd_states;
axi_DMA_rd_states DMA_rd_state, DMA_rd_next; 
logic [15 : 0] rdid, rdid_next;		//for now assume the DMA does not change id during accessing the FIFO addr space
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

logic 	[4 : 0] 							arvalid_counter, arvalid_counter_next; //this counter is used to count the number of read requests received, by counting the arvalid signal. The count is used to maintain an order of the ar channel and the rd channel, rd channel response have to come after an ar channel request, currently support 32 outstanding ar requests
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
assert property (@(posedge clk) !(arvalid_counter_incr && (arvalid_counter == 31)));

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
				//this state waits for the next read transaction 
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
							if(wr_length_counter[$clog2(`MAX_LEN * 8 * 2)]) begin
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
							if(wr_length_counter[$clog2(`MAX_LEN * 8 *2) - 1]) begin
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
