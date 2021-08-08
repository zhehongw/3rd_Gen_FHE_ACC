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


module test_dma_poly_write();
//switch the config_ports.top_fifo_mode to RLWEMODE
   import tb_type_defines_pkg::*;
`include "common.vh"
   int error_count;
   int timeout_count;
   int fail;
   logic [3:0] status;

   //transfer1 - length less than 64 byte.
   int         	len0 = 2048;
   int        	len1 = 4096*8;
   logic [31 : 0]	rdata;
   longint 	   	temp = 0;
   longint      input_counter = 0;
   initial begin

      logic [63:0] host_memory_buffer_address;


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

      $display("[%t] : Initializing registers with OCL-AXIL", $realtime);
	  tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_RLWE_LEN}), .data(32'd2048));
	  tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_TOP_FIFO_MODE}), .data({{31{1'b0}}, `RLWEMODE}));	//RLWEMODE
      tb.nsec_delay(1000);
  
      $display("[%t] : Read registers with OCL-AXIL", $realtime);  
      tb.peek_ocl(.addr({{(64-8){1'b0}}, `ADDR_RLWE_LEN}), .data(rdata));
      if(rdata != 32'd2048) begin         
        $error("[%t] : RLWE_LEN register incorrect", $realtime);
        $display("[%t] : RLWE_LEN register = %d", $realtime, rdata);  
      end else begin
        $display("[%t] : RLWE_LEN register = %d", $realtime, rdata);  
      end
      
	  tb.peek_ocl(.addr({{(64-8){1'b0}}, `ADDR_TOP_FIFO_MODE}), .data(rdata));	//RLWEMODE
      if(rdata != {{31{1'b0}}, `RLWEMODE}) begin         
        $error("[%t] : FIFO_MODE register incorrect", $realtime);
        $display("[%t] : FIFO_MODE register = %d", $realtime, rdata);  
      end else begin
        $display("[%t] : FIFO_MODE register = %d", $realtime, rdata);  
      end
      
      $display("[%t] : Initializing buffers", $realtime);

      host_memory_buffer_address = 64'h0000_0000_0000;

      //Queue data to be transfered to CL DDR
      //tb.que_buffer_to_cl(.chan(0), .src_addr(host_memory_buffer_address), .cl_addr(64'h0000_0000_0000), .len(len0) ); // move buffer to DDR 0
      tb.que_buffer_to_cl(.chan(0), .src_addr(host_memory_buffer_address), .cl_addr(64'h0000_0000_1f00), .len(len0) ); // move buffer to DDR 0
      // Put test pattern in host memory
      for (int i = 0 ; i < len0; i++) begin
         tb.hm_put_byte(.addr(host_memory_buffer_address), .d(8'hAA));
         host_memory_buffer_address++;
      end

      host_memory_buffer_address = 64'h0004_0000_0000;

      //Queue data to be transfered to CL RLWE poly fifo, first RLWE
      tb.que_buffer_to_cl(.chan(1), .src_addr(host_memory_buffer_address), .cl_addr(64'h0004_0000_0000), .len(len1) ); // move buffer to CL RLWE poly buffer
      // Put test pattern in host memory
	  for (longint i = 0 ; i < len1/8; i++) begin
		 temp = input_counter;
		 for(int j = 0; j < 8; j++) begin
         	tb.hm_put_byte(.addr(host_memory_buffer_address), .d(byte'(temp & 255)));
			temp = temp >> 8;
         	host_memory_buffer_address++;
		 end
		 input_counter++;
      end

      $display("[%t] : starting H2C DMA channels, first RLWE", $realtime);

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
      $display("[%t] : Waiting for DMA write transfers to complete first RLWE", $realtime);
      #2us;
      
      //Queue data to be transfered to CL RLWE poly fifo
      tb.que_buffer_to_cl(.chan(1), .src_addr(host_memory_buffer_address), .cl_addr(64'h0004_0000_0000), .len(len1) ); // move buffer to CL RLWE poly buffer
      // Put test pattern in host memory
	  for (longint i = 0 ; i < len1/8; i++) begin
		 temp = input_counter;
		 for(int j = 0; j < 8; j++) begin
         	tb.hm_put_byte(.addr(host_memory_buffer_address), .d(byte'(temp & 255)));
			temp = temp >> 8;
         	host_memory_buffer_address++;
		 end
		 input_counter++;
      end

      $display("[%t] : starting H2C DMA channels, second RLWE", $realtime);

      //Start transfers of data to CL DDR
      //tb.start_que_to_cl(.chan(0));
      tb.start_que_to_cl(.chan(1));
      //tb.start_que_to_cl(.chan(2));
      //tb.start_que_to_cl(.chan(3));

      // wait for dma transfers to complete
      timeout_count = 0;
      do begin
         //status[0] = tb.is_dma_to_cl_done(.chan(0));
         status[1] = tb.is_dma_to_cl_done(.chan(1));
         //status[2] = tb.is_dma_to_cl_done(.chan(2));
         //status[3] = tb.is_dma_to_cl_done(.chan(3));
         status[0] = 1;
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
      $display("[%t] : Waiting for DMA write transfers to complete second RLWE", $realtime);
      #2us;
      
      //Queue data to be transfered to CL RLWE poly fifo
      tb.que_buffer_to_cl(.chan(1), .src_addr(host_memory_buffer_address), .cl_addr(64'h0004_0000_0000), .len(len1) ); // move buffer to CL RLWE poly buffer
      // Put test pattern in host memory
	  for (longint i = 0 ; i < len1/8; i++) begin
		 temp = input_counter;
		 for(int j = 0; j < 8; j++) begin
         	tb.hm_put_byte(.addr(host_memory_buffer_address), .d(byte'(temp & 255)));
			temp = temp >> 8;
         	host_memory_buffer_address++;
		 end
		 input_counter++;
      end

      $display("[%t] : starting H2C DMA channels, third RLWE", $realtime);

      //Start transfers of data to CL DDR
      //tb.start_que_to_cl(.chan(0));
      tb.start_que_to_cl(.chan(1));
      //tb.start_que_to_cl(.chan(2));
      //tb.start_que_to_cl(.chan(3));

      // wait for dma transfers to complete
      timeout_count = 0;
      do begin
         //status[0] = tb.is_dma_to_cl_done(.chan(0));
         status[1] = tb.is_dma_to_cl_done(.chan(1));
         //status[2] = tb.is_dma_to_cl_done(.chan(2));
         //status[3] = tb.is_dma_to_cl_done(.chan(3));
         status[0] = 1;
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
      $display("[%t] : Waiting for DMA write transfers to complete third RLWE", $realtime);
      #2us;

     //Queue data to be transfered to CL RLWE poly fifo
      tb.que_buffer_to_cl(.chan(1), .src_addr(host_memory_buffer_address), .cl_addr(64'h0004_0000_0000), .len(len1) ); // move buffer to CL RLWE poly buffer
      // Put test pattern in host memory
	  for (longint i = 0 ; i < len1/8; i++) begin
		 temp = input_counter;
		 for(int j = 0; j < 8; j++) begin
         	tb.hm_put_byte(.addr(host_memory_buffer_address), .d(byte'(temp & 255)));
			temp = temp >> 8;
         	host_memory_buffer_address++;
		 end
		 input_counter++;
      end

      $display("[%t] : starting H2C DMA channels, fourth RLWE", $realtime);

      //Start transfers of data to CL DDR
      //tb.start_que_to_cl(.chan(0));
      tb.start_que_to_cl(.chan(1));
      //tb.start_que_to_cl(.chan(2));
      //tb.start_que_to_cl(.chan(3));

      // wait for dma transfers to complete
      timeout_count = 0;
      do begin
         //status[0] = tb.is_dma_to_cl_done(.chan(0));
         status[1] = tb.is_dma_to_cl_done(.chan(1));
         //status[2] = tb.is_dma_to_cl_done(.chan(2));
         //status[3] = tb.is_dma_to_cl_done(.chan(3));
         status[0] = 1;
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
      $display("[%t] : Waiting for DMA write transfers to complete fourth RLWE", $realtime);
      #2us;


      $display("[%t] : starting C2H DMA channels ", $realtime);
       
      // read the data from cl and put it in the host memory
      host_memory_buffer_address = 64'h0_0001_0800;
      tb.que_cl_to_buffer(.chan(0), .dst_addr(host_memory_buffer_address), .cl_addr(64'h0000_0000_1f00), .len(len0) ); // move DDR0 to buffer
      //tb.que_cl_to_buffer(.chan(0), .dst_addr(host_memory_buffer_address), .cl_addr(64'h0000_0000_0000), .len(len0) ); // move DDR0 to buffer

      //Start transfers of data from CL DDR
      tb.start_que_to_buffer(.chan(0));

      // wait for dma transfers to complete
      timeout_count = 0;
      do begin
         status[0] = tb.is_dma_to_buffer_done(.chan(0));
         //status[1] = tb.is_dma_to_buffer_done(.chan(1));
         //status[2] = tb.is_dma_to_buffer_done(.chan(2));
         //status[3] = tb.is_dma_to_buffer_done(.chan(3));
         status[1] = 1;
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

      // DDR 0
      // Compare the data in host memory with the expected data
      $display("[%t] : DMA buffer from DDR 0", $realtime);

      host_memory_buffer_address = 64'h0_0001_0800;
      for (int i = 0 ; i<len0 ; i++) begin
         if (tb.hm_get_byte(.addr(host_memory_buffer_address + i)) !== 8'hAA) begin
            $error("[%t] : *** ERROR *** DDR0 Data mismatch, addr:%0x read data is: %0x",
                     $realtime, (host_memory_buffer_address + i), tb.hm_get_byte(.addr(host_memory_buffer_address + i)));
            error_count++;
         end
      end

      
      $display("[%t] : Finish comparison", $realtime);
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
