// Amazon FPGA Hardware Development Kit
//
// Copyright 2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Amazon Software License (the "License"). You may not use
// this file except in compliance with the License. A copy of the License is
// located at
//
//    http://aws.amazon.com/asl/
//
// or in the "license" file accompanying this file. This file is distributed on
// an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
// implied. See the License for the specific language governing permissions and
// limitations under the License.


module test_ocl_key_load();
import tb_type_defines_pkg::*;
`include "common.vh"

int 			error_count;
int 			timeout_count;
int 			fail;
logic [3 : 0] 	status;

int         	len0;	//32 bit
int        		len1;
logic [31 : 0] 	rdata;
longint 	   	temp = 0;
int 	   		digitG;
int 	   		digitG2;
int 			lwe_q = 512;
logic [64 : 0] 	ddr_addr;
int             fp;
int             r;
reg [1000 : 0]  hdk_name;
string          file_name;
logic [512 : 0] data;


initial begin
	
	logic [63:0] bdr_addr, host_memory_buffer_address;
	
	
	tb.power_up(.clk_recipe_a(ClockRecipe::A1),
	            .clk_recipe_b(ClockRecipe::B0),
	            .clk_recipe_c(ClockRecipe::C0));
	
	tb.nsec_delay(1000);
	tb.poke_stat(.addr(8'h0c), .ddr_idx(0), .data(32'h0000_0000));
	tb.poke_stat(.addr(8'h0c), .ddr_idx(1), .data(32'h0000_0000));
	tb.poke_stat(.addr(8'h0c), .ddr_idx(2), .data(32'h0000_0000));
	
	// AXI_MEMORY_MODEL is used to bypass DDR micron models and run with AXI memory models. More information can be found in the readme.md
      
`ifndef AXI_MEMORY_MODEL      
	// allow memory to initialize
	tb.nsec_delay(27000);
`endif
	$display("[%t] : Test 2k length, RGSW", $realtime);
	// simulate with 2k length 
	
	digitG = 3;
	digitG2 = digitG * 2;
	$display("[%t] : Initializing registers with OCL-AXIL", $realtime);
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_RLWE_LEN}), .data(32'd1024));
    tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_LWE_Q_MASK}), .data(32'd511));
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_DIGITG}), .data(digitG));	
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_OR_BOUND1}), .data(lwe_q/8*5));	
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_AND_BOUND1}), .data(lwe_q/8*7));	
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_NOR_BOUND1}), .data(lwe_q/8*1));	
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_NAND_BOUND1}), .data(lwe_q/8*3));
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_XOR_BOUND1}), .data(lwe_q/8*5));	
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_XNOR_BOUND1}), .data(lwe_q/8*1));
	tb.nsec_delay(1000);
  
//	$display("[%t] : Read registers with OCL-AXIL", $realtime);  
//	tb.peek_ocl(.addr({{(64-8){1'b0}}, `ADDR_RLWE_LEN}), .data(rdata));
//	$display("[%t] : RLWE_LEN register = %d", $realtime, rdata);  
//	tb.peek_ocl(.addr({{(64-8){1'b0}}, `ADDR_DIGITG}), .data(rdata));
//	$display("[%t] : DigitG register = %d", $realtime, rdata);  
//	tb.peek_ocl(.addr({{(64-8){1'b0}}, `ADDR_OR_BOUND1}), .data(rdata));
//	$display("[%t] : or bound1 register = %d", $realtime, rdata);  
//	tb.peek_ocl(.addr({{(64-8){1'b0}}, `ADDR_AND_BOUND1}), .data(rdata));
//	$display("[%t] : and bound1 register = %d", $realtime, rdata);  
//	tb.peek_ocl(.addr({{(64-8){1'b0}}, `ADDR_NOR_BOUND1}), .data(rdata));
//	$display("[%t] : nor bound1 register = %d", $realtime, rdata);  
//	tb.peek_ocl(.addr({{(64-8){1'b0}}, `ADDR_NAND_BOUND1}), .data(rdata));
//	$display("[%t] : nand bound1 register = %d", $realtime, rdata);  
//	tb.peek_ocl(.addr({{(64-8){1'b0}}, `ADDR_XOR_BOUND1}), .data(rdata));
//	$display("[%t] : xor bound1 register = %d", $realtime, rdata);  
//	tb.peek_ocl(.addr({{(64-8){1'b0}}, `ADDR_XNOR_BOUND1}), .data(rdata));
//	$display("[%t] : xnor bound1 register = %d", $realtime, rdata);  
      
	$display("[%t] : Initializing buffers", $realtime);

	len0 = 4096 * 8 * digitG2;
	len1 = 4096 * 8;
	
	host_memory_buffer_address = 64'h0000_0000_0000;
	ddr_addr = 64'h0000_1111_C000;

	//Queue data to be transfered to CL DDR
	tb.que_buffer_to_cl(.chan(0), .src_addr(host_memory_buffer_address), .cl_addr(ddr_addr), .len(64) ); // move buffer to DDR 0
	// Put test pattern in host memory
	for (int i = 0 ; i < 32; i++) begin
	   tb.hm_put_byte(.addr(host_memory_buffer_address), .d(8'hA0));
	   host_memory_buffer_address++;
	end
	for (int i = 32 ; i < 64; i++) begin
	   tb.hm_put_byte(.addr(host_memory_buffer_address), .d(8'hB0));
	   host_memory_buffer_address++;
	end

	ddr_addr = ddr_addr + 32 * 1024;
	tb.que_buffer_to_cl(.chan(1), .src_addr(host_memory_buffer_address), .cl_addr(ddr_addr), .len(64) ); // move buffer to DDR 0
	// Put test pattern in host memory
	for (int i = 0 ; i < 32; i++) begin
	   tb.hm_put_byte(.addr(host_memory_buffer_address), .d(8'hA1));
	   host_memory_buffer_address++;
	end
	for (int i = 32 ; i < 64; i++) begin
	   tb.hm_put_byte(.addr(host_memory_buffer_address), .d(8'hB1));
	   host_memory_buffer_address++;
	end

	ddr_addr = ddr_addr + 32 * 1024;
	tb.que_buffer_to_cl(.chan(2), .src_addr(host_memory_buffer_address), .cl_addr(ddr_addr), .len(64) ); // move buffer to DDR 0
	// Put test pattern in host memory
	for (int i = 0 ; i < 32; i++) begin
	   tb.hm_put_byte(.addr(host_memory_buffer_address), .d(8'hA2));
	   host_memory_buffer_address++;
	end
	for (int i = 32 ; i < 64; i++) begin
	   tb.hm_put_byte(.addr(host_memory_buffer_address), .d(8'hB2));
	   host_memory_buffer_address++;
	end

	ddr_addr = ddr_addr + 32 * 1024;
	tb.que_buffer_to_cl(.chan(3), .src_addr(host_memory_buffer_address), .cl_addr(ddr_addr), .len(64) ); // move buffer to DDR 0
	// Put test pattern in host memory
	for (int i = 0 ; i < 32; i++) begin
	   tb.hm_put_byte(.addr(host_memory_buffer_address), .d(8'hA3));
	   host_memory_buffer_address++;
	end
	for (int i = 32 ; i < 64; i++) begin
	   tb.hm_put_byte(.addr(host_memory_buffer_address), .d(8'hB3));
	   host_memory_buffer_address++;
	end

	$display("[%t] : starting H2C DMA channels ", $realtime);
	
	//Start transfers of data to CL DDR
	tb.start_que_to_cl(.chan(0));
	tb.start_que_to_cl(.chan(1));
	tb.start_que_to_cl(.chan(2));
	tb.start_que_to_cl(.chan(3));
	
	// wait for dma transfers to complete
	timeout_count = 0;
	do begin
	   status[0] = tb.is_dma_to_cl_done(.chan(0));
	   status[1] = tb.is_dma_to_cl_done(.chan(1));
	   status[2] = tb.is_dma_to_cl_done(.chan(2));
	   status[3] = tb.is_dma_to_cl_done(.chan(3));
	   //status[0] = 1;
	   //status[1] = 1;
	   //status[2] = 1;
	   //status[3] = 1;
	   #10ns;
	   timeout_count++;
	end while ((status != 4'hf) && (timeout_count < 4000));
	
	if (timeout_count >= 4000) begin
	   $error("[%t] : *** ERROR *** Timeout waiting for dma transfers from cl", $realtime);
	   error_count++;
	end
	
	// DMA transfers are posted writes. The above code checks only if the dma transfer is setup and done. 
	// We need to wait for writes to finish to memory before issuing reads.
	$display("[%t] : Waiting for DMA write transfers to complete", $realtime);
	#2us;


	ddr_addr = ddr_addr + 32 * 1024;
	tb.que_buffer_to_cl(.chan(0), .src_addr(host_memory_buffer_address), .cl_addr(ddr_addr), .len(64) ); // move buffer to DDR 0
	// Put test pattern in host memory
	for (int i = 0 ; i < 32; i++) begin
	   tb.hm_put_byte(.addr(host_memory_buffer_address), .d(8'hA4));
	   host_memory_buffer_address++;
	end
	for (int i = 32 ; i < 64; i++) begin
	   tb.hm_put_byte(.addr(host_memory_buffer_address), .d(8'hB4));
	   host_memory_buffer_address++;
	end

	ddr_addr = ddr_addr + 32 * 1024;
	tb.que_buffer_to_cl(.chan(1), .src_addr(host_memory_buffer_address), .cl_addr(ddr_addr), .len(64) ); // move buffer to DDR 0
	// Put test pattern in host memory
	for (int i = 0 ; i < 32; i++) begin
	   tb.hm_put_byte(.addr(host_memory_buffer_address), .d(8'hA5));
	   host_memory_buffer_address++;
	end
	for (int i = 32 ; i < 64; i++) begin
	   tb.hm_put_byte(.addr(host_memory_buffer_address), .d(8'hB5));
	   host_memory_buffer_address++;
	end

	$display("[%t] : starting H2C DMA channels ", $realtime);
	
	//Start transfers of data to CL DDR
	tb.start_que_to_cl(.chan(0));
	tb.start_que_to_cl(.chan(1));
	//tb.start_que_to_cl(.chan(2));
	//tb.start_que_to_cl(.chan(3));
	
	// wait for dma transfers to complete
	timeout_count = 0;
	do begin
	   status[0] = tb.is_dma_to_cl_done(.chan(0));
	   status[1] = tb.is_dma_to_cl_done(.chan(1));
	   //status[2] = tb.is_dma_to_cl_done(.chan(2));
	   //status[3] = tb.is_dma_to_cl_done(.chan(3));
	   //status[0] = 1;
	   //status[1] = 1;
	   status[2] = 1;
	   status[3] = 1;
	   #10ns;
	   timeout_count++;
	end while ((status != 4'hf) && (timeout_count < 4000));
	
	if (timeout_count >= 4000) begin
	   $error("[%t] : *** ERROR *** Timeout waiting for dma transfers from cl", $realtime);
	   error_count++;
	end
	
	// DMA transfers are posted writes. The above code checks only if the dma transfer is setup and done. 
	// We need to wait for writes to finish to memory before issuing reads.
	$display("[%t] : Waiting for DMA write transfers to complete", $realtime);
	#2us;



	// read the data from cl and put it in the host memory
	host_memory_buffer_address = 64'h0_0010_0000;
	ddr_addr = 64'h0000_1111_C000;
	tb.que_cl_to_buffer(.chan(0), .dst_addr(host_memory_buffer_address), .cl_addr(ddr_addr), .len(64) ); // move DDR0 to buffer
	
	host_memory_buffer_address = host_memory_buffer_address + 64;
	ddr_addr = ddr_addr + 32 * 1024;
	tb.que_cl_to_buffer(.chan(1), .dst_addr(host_memory_buffer_address), .cl_addr(ddr_addr), .len(64) ); // move DDR0 to buffer
	
	host_memory_buffer_address = host_memory_buffer_address + 64;
	ddr_addr = ddr_addr + 32 * 1024;
	tb.que_cl_to_buffer(.chan(2), .dst_addr(host_memory_buffer_address), .cl_addr(ddr_addr), .len(64) ); // move DDR0 to buffer
	
	host_memory_buffer_address = host_memory_buffer_address + 64;
	ddr_addr = ddr_addr + 32 * 1024;
	tb.que_cl_to_buffer(.chan(3), .dst_addr(host_memory_buffer_address), .cl_addr(ddr_addr), .len(64) ); // move DDR0 to buffer
	
	//Start transfers of data from CL DDR
	tb.start_que_to_buffer(.chan(0));
	tb.start_que_to_buffer(.chan(1));
	tb.start_que_to_buffer(.chan(2));
	tb.start_que_to_buffer(.chan(3));
	// wait for dma transfers to complete
	timeout_count = 0;
	do begin
	   status[0] = tb.is_dma_to_buffer_done(.chan(0));
	   status[1] = tb.is_dma_to_buffer_done(.chan(1));
	   status[2] = tb.is_dma_to_buffer_done(.chan(2));
	   status[3] = tb.is_dma_to_buffer_done(.chan(3));
	   //status[0] = 1;
	   //status[1] = 1;
	   //status[2] = 1;
	   //status[3] = 1;
	   #10ns;
	   timeout_count++;
	end while ((status != 4'hf) && (timeout_count < 1000));
	
	if (timeout_count >= 1000) begin
	   $error("[%t] : *** ERROR *** Timeout waiting for dma transfers from cl", $realtime);
	   error_count++;
	end
	#1us;

	host_memory_buffer_address = host_memory_buffer_address + 64;
	ddr_addr = ddr_addr + 32 * 1024;
	tb.que_cl_to_buffer(.chan(0), .dst_addr(host_memory_buffer_address), .cl_addr(ddr_addr), .len(64) ); // move DDR0 to buffer
	
	host_memory_buffer_address = host_memory_buffer_address + 64;
	ddr_addr = ddr_addr + 32 * 1024;
	tb.que_cl_to_buffer(.chan(1), .dst_addr(host_memory_buffer_address), .cl_addr(ddr_addr), .len(64) ); // move DDR0 to buffer
	
	//Start transfers of data from CL DDR
	tb.start_que_to_buffer(.chan(0));
	tb.start_que_to_buffer(.chan(1));
	//tb.start_que_to_buffer(.chan(2));
	//tb.start_que_to_buffer(.chan(3));
	// wait for dma transfers to complete
	timeout_count = 0;
	do begin
	   status[0] = tb.is_dma_to_buffer_done(.chan(0));
	   status[1] = tb.is_dma_to_buffer_done(.chan(1));
	   //status[2] = tb.is_dma_to_buffer_done(.chan(2));
	   //status[3] = tb.is_dma_to_buffer_done(.chan(3));
	   //status[0] = 1;
	   //status[1] = 1;
	   status[2] = 1;
	   status[3] = 1;
	   #10ns;
	   timeout_count++;
	end while ((status != 4'hf) && (timeout_count < 1000));
	
	if (timeout_count >= 1000) begin
	   $error("[%t] : *** ERROR *** Timeout waiting for dma transfers from cl", $realtime);
	   error_count++;
	end
	#1us;

	host_memory_buffer_address = 64'h0_0010_0000;
	for (int i = 0 ; i < 64 * digitG * 2 ; i++) begin
	      	$display("[%t] : DDR0 data, addr:%0x read data is: %0x",
	      	         $realtime, (host_memory_buffer_address + i), tb.hm_get_byte(.addr(host_memory_buffer_address + i)));
	end
	

//	// Compare the data in host memory with the expected data
//	$display("[%t] : DMA buffer from DDR 0", $realtime);
//	
//	host_memory_buffer_address = 64'h0_0010_0000;
//	for (int i = 0 ; i < len0 / 8 ; i++) begin
//	    temp = i;
//	    for(int j = 0; j < 8; j++) begin
//	   	if (tb.hm_get_byte(.addr(host_memory_buffer_address)) !== (temp & 255)) begin
//	      	$error("[%t] : *** ERROR *** DDR0 Data mismatch, addr:%0x read data is: %0x",
//	      	         $realtime, (host_memory_buffer_address), tb.hm_get_byte(.addr(host_memory_buffer_address)));
//	  	end
//	  	host_memory_buffer_address++;
//	  	temp = temp >> 8;
//	    end
//	end
	
	
	$display("[%t] : Finish comparison 2k length", $realtime);
	
    ddr_addr = 64'h0000_1111_C000;
	$display("[%t] : Program the chip for key loading ", $realtime);
	//RLWESUBS op, AND gate, init value 5, key addr ddr_addr[14 +: 17]
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_INST_IN}), .data({2'd1, 4'd7, 9'd9, ddr_addr[14 +: 17]}));
	//BOOTSTRAP op, AND gate, init value 5, key addr ddr_addr[14 +: 17]
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_INST_IN}), .data({2'd2, 3'd4, 10'd9, ddr_addr[14 +: 17]}));
	
	$display("[%t] : Wait for the internal key loading ", $realtime);
	#15us;
	// Power down
	#500ns;
	tb.power_down();
	
	//---------------------------
	// Report pass/fail status
	//---------------------------
	$display("[%t] : Checking total error count...", $realtime);
	if (error_count > 0) begin
	   fail = 1;
	end
	$display("[%t] : Detected %3d errors during this test", $realtime, error_count);
	
	if (fail || (tb.chk_prot_err_stat())) begin
	   $error("[%t] : *** TEST FAILED ***", $realtime);
	end else begin
	   $display("[%t] : *** TEST PASSED ***", $realtime);
	end
	
	$finish;
end // initial begin

endmodule // test_dram_dma
