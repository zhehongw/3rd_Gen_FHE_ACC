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


module test_fhe_acc_rlwesubs_bkdr();
import tb_type_defines_pkg::*;
`include "common.vh"

int 			error_count;
int 			timeout_count;
int 			fail;
logic [3 : 0] 	status;

int         	len0;	//32 bit
int        		len1;
logic [31 : 0] 	rdata;
logic [7 : 0] 	rbyte;
longint 	   	temp = 0;
logic [63 : 0] 	ddr_addr;
int             fp;
int 			r;
reg [1000 : 0]  hdk_name;
reg [1000 : 0]  cl_dir;
string          file_name;
string          ddr_init_file_name;

logic [512 : 0] data;

logic [63:0] bdr_addr;
logic [63:0] host_memory_buffer_address;

//top config reg
logic [63 : 0] rlwe_q;
logic [127 : 0] barrett_m;
logic [63 : 0] rlwe_ilength;
logic [63 : 0] BG_mask;
logic [31 : 0] rlwe_length;
logic [31 : 0] barrett_k;
logic [31 : 0] barrett_k2;
logic [31 : 0] log2_rlwe_len;
logic [31 : 0] digitG;
logic [31 : 0] digitG2;
logic [31 : 0] BG_width;
logic [31 : 0] lwe_q;
logic [31 : 0] embed_factor;
logic [31 : 0] top_fifo_mode;
logic [31 : 0] BG;

logic [`BIT_WIDTH - 1 : 0] rou_table [0 : `MAX_LEN - 1];
logic [`BIT_WIDTH - 1 : 0] irou_table [0 : `MAX_LEN - 1];

logic [`BIT_WIDTH - 1 : 0] polya [0 : `MAX_LEN - 1];
logic [`BIT_WIDTH - 1 : 0] polyb [0 : `MAX_LEN - 1];


initial begin
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
`else 
	$display("[%t] : USE AXI_MEMORY_MODEL", $realtime);
`endif
	
	$display("[%t] : Disable ECC", $realtime);
	//Disable ECC
	//Write ECC register address in DRAM controller
	tb.poke_stat(.addr(8'h10), .ddr_idx(0), .data(32'h0000_0008));
	tb.poke_stat(.addr(8'h10), .ddr_idx(1), .data(32'h0000_0008));
	tb.poke_stat(.addr(8'h10), .ddr_idx(2), .data(32'h0000_0008));
	
	tb.poke_stat(.addr(8'h14), .ddr_idx(0), .data(32'h0000_0000));
	tb.poke_stat(.addr(8'h14), .ddr_idx(1), .data(32'h0000_0000));
	tb.poke_stat(.addr(8'h14), .ddr_idx(2), .data(32'h0000_0000));
	
		
	$display("[%t] : !!!This testbench only covers `LINE_SZIE == 2!!!", $realtime);
	//set the config regs
	BG 				= 512; 
	rlwe_q 			= 64'h003F_FFFF_FFFE_D001;
	barrett_k 		= `BIT_WIDTH;
	barrett_m 		= (1 << (barrett_k * 2)) / rlwe_q;
	rlwe_ilength 	= 64'h003F_F7FF_FFFE_D027;
	BG_mask 		= BG - 1;
	rlwe_length 	= 32'd2048;
	barrett_k2 		= barrett_k * 2;
	log2_rlwe_len 	= $clog2(rlwe_length);
	digitG 			= 6;
	digitG2 		= digitG * 2;
	BG_width 		= $clog2(BG);
	lwe_q 			= 512;
	embed_factor 	= rlwe_length * 2 / lwe_q;
	top_fifo_mode 	= {{31{1'b0}}, `RLWEMODE};

	$display("[%t] : Initializing config registers with OCL-AXIL", $realtime);
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_RLWE_Q}), .data(rlwe_q[31 : 0]));
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_RLWE_Q + 4}), .data(rlwe_q[63 : 32]));
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_BARRETT_M}), .data(barrett_m[31 : 0]));
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_BARRETT_M + 4}), .data(barrett_m[63 : 32]));
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_RLWE_ILEN}), .data(rlwe_ilength[31 : 0]));
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_RLWE_ILEN + 4}), .data(rlwe_ilength[63 : 32]));
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_BG_MASK}), .data(BG_mask[31 : 0]));
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_BG_MASK + 4}), .data(BG_mask[63 : 32]));

	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_BARRETT_K2}), .data(barrett_k2));
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_RLWE_LEN}), .data(rlwe_length));
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_LOG2_RLWE_LEN}), .data(log2_rlwe_len));
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_DIGITG}), .data(digitG));	
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_BG_WIDTH}), .data(BG_width));	
    tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_LWE_Q_MASK}), .data(lwe_q - 1));
    tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_EMBED_FACTOR}), .data(embed_factor));
    tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_TOP_FIFO_MODE}), .data(top_fifo_mode));

	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_OR_BOUND1}), .data(lwe_q/8*5));	
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_AND_BOUND1}), .data(lwe_q/8*7));	
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_NOR_BOUND1}), .data(lwe_q/8*1));	
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_NAND_BOUND1}), .data(lwe_q/8*3));
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_XOR_BOUND1}), .data(lwe_q/8*5));	
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_XNOR_BOUND1}), .data(lwe_q/8*1));

	tb.nsec_delay(1000);
	
	$display("[%t] : Finish writing config regs", $realtime);

	//set cl directory 
	r = $value$plusargs("CL_DIR=%s", cl_dir);

	$display("[%t] : Read in rou/irou table from files", $realtime);

	file_name = $sformatf("%0s/verif/tests/mem_init_content/bk/ROU_table_2k_complete.mem", cl_dir);
	$readmemh(file_name, rou_table);

	file_name = $sformatf("%0s/verif/tests/mem_init_content/bk/iROU_table_2k.mem", cl_dir);
	$readmemh(file_name, irou_table);

	$display("[%t] : Program ROU table with BAR1-AXIL", $realtime);
	for(int i = 8; i < rlwe_length * 8; i+=8) begin
		tb.poke_bar1(.addr(i), .data({{5{1'b0}}, rou_table[i / 8][0 +: 27]}));
		tb.poke_bar1(.addr(i + 4), .data({{5{1'b0}}, rou_table[i / 8][27 +: 27]}));
	end
	tb.nsec_delay(1000);

	$display("[%t] : Program iROU table with BAR1-AXIL", $realtime);
	for(int i = 8; i < rlwe_length * 8; i+=8) begin
		tb.poke_bar1(.addr(i + 16*1024), .data({{5{1'b0}}, irou_table[i / 8][0 +: 27]}));
		tb.poke_bar1(.addr(i + 4 + 16*1024), .data({{5{1'b0}}, irou_table[i / 8][27 +: 27]}));
	end
	tb.nsec_delay(1000);

	$display("[%t] : Finish program rou/irou table 2k length", $realtime);

	$display("[%t] : Backdoor loading the DDR for the key", $realtime);
    
	ddr_init_file_name = $sformatf("./rlwesubs_key_subs0.mem");
	
	$display("file_name is %0s", ddr_init_file_name);
	  
	fp = $fopen(ddr_init_file_name, "w");	

	bdr_addr = 64'h0000_1111_C000;
	for(int i = 0; i < digitG; i++) begin
		file_name = $sformatf("%0s/verif/tests/mem_init_content/top_verify/rlwesubs/bk/RLWESUBS_keyinput_2k_rlwe_%0d_a0.mem", cl_dir, i);
		$readmemh(file_name, polya);
		file_name = $sformatf("%0s/verif/tests/mem_init_content/top_verify/rlwesubs/bk/RLWESUBS_keyinput_2k_rlwe_%0d_b0.mem", cl_dir, i);
		$readmemh(file_name, polyb);
		for(int k = 0; k < `MAX_LEN; k += 4) begin
			for(int j = 0; j < 512/64/2; j++) begin
				data[j * 64 +: 64] 				= {{(64 - `BIT_WIDTH){1'b0}}, polya[k + j]};
				data[j * 64 + 512 / 2 +: 64] 	= {{(64 - `BIT_WIDTH){1'b0}}, polyb[k + j]};
			end
			$fdisplay(fp, "%0h %0h", bdr_addr, data);
			bdr_addr += 64;
		end
	end

	$fclose(fp);
	
	tb.card.ddr_bdr_ld(ddr_init_file_name);
	
	tb.nsec_delay(500);

	$display("[%t] : Finish backdoor loading the DDR", $realtime);

	$display("[%t] : Test 2k RLWESUBS", $realtime);

	
	$display("[%t] : Read in input RLWE", $realtime);
	file_name = $sformatf("%0s/verif/tests/mem_init_content/top_verify/rlwesubs/bk/RLWESUBS_inputrlwe_2k_a0.mem", cl_dir);
	$readmemh(file_name, polya);

	file_name = $sformatf("%0s/verif/tests/mem_init_content/top_verify/rlwesubs/bk/RLWESUBS_inputrlwe_2k_b0.mem", cl_dir);
	$readmemh(file_name, polyb);

	$display("[%t] : Finish reading in input RLWE", $realtime);

	$display("[%t] : Transfer input RLWE", $realtime);
    $display("[%t] : Initializing buffers", $realtime);
	len1 = 32 * 1024;
    host_memory_buffer_address = 64'h0004_0000_0000;
	tb.que_buffer_to_cl(.chan(0), .src_addr(host_memory_buffer_address), .cl_addr(64'h0004_0000_0000), .len(len1) ); // move buffer to CL RLWE poly buffer
	// Put test pattern in host memory
	for (longint i = 0 ; i < `MAX_LEN; i += 4) begin
		for(int j = 0; j < 4; j++) begin
			temp = {{(64 - `BIT_WIDTH){1'b0}}, polya[i + j]};
			for(int k = 0; k < 8; k++) begin
				tb.hm_put_byte(.addr(host_memory_buffer_address), .d(byte'(temp & 255)));
				temp = temp >> 8;
				host_memory_buffer_address++;
			end
		end
		for(int j = 0; j < 4; j++) begin
			temp = {{(64 - `BIT_WIDTH){1'b0}}, polyb[i + j]};
			for(int k = 0; k < 8; k++) begin
				tb.hm_put_byte(.addr(host_memory_buffer_address), .d(byte'(temp & 255)));
				temp = temp >> 8;
				host_memory_buffer_address++;
			end
		end
	end

    $display("[%t] : starting H2C DMA channels ", $realtime);
	//Start transfers of data to CL DDR
	tb.start_que_to_cl(.chan(0));
	//tb.start_que_to_cl(.chan(1));
	//tb.start_que_to_cl(.chan(2));
	//tb.start_que_to_cl(.chan(3));
	
	// wait for dma transfers to complete
	timeout_count = 0;
	do begin
	   status[0] = tb.is_dma_to_cl_done(.chan(0));
	   //status[1] = tb.is_dma_to_cl_done(.chan(1));
	   //status[2] = tb.is_dma_to_cl_done(.chan(2));
	   //status[3] = tb.is_dma_to_cl_done(.chan(3));
	   status[1] = 1;
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

	$display("[%t] : Finish transferring input RLWE", $realtime);

	$display("[%t] : Write instruction to start the process of input RLWE", $realtime);

    ddr_addr = 64'h0000_1111_C000;		//this is the same as the initial bdr_addr 
	tb.poke_ocl(.addr({{(64-8){1'b0}}, `ADDR_INST_IN}), .data({2'd1, 4'd0, 6'd9, ddr_addr[14 +: 20]}));

	$display("[%t] : Finish writing instruction, wait for the process to complete", $realtime);
	
	// wait for compute to finish
	timeout_count = 0;
	do begin
		#20us;
		tb.peek_ocl(.addr({{(64-8){1'b0}}, `ADDR_FIFO_STATE}), .data(rdata));
		$display("ROB_empty: %b\t key_fifo_empty: %b\t RLWE_input_FIFO_empty : %b\t RLWE_output_FIFO_empty: %b\t ROB_full: %b\t key_fifo_full: %b\t RLWE_input_FIFO_full: %b\t RLWE_output_FIFO_full: %b\t", rdata[7], rdata[6], rdata[5], rdata[4], rdata[3], rdata[2], rdata[1], rdata[0]);	
	   	timeout_count++;
	end while (rdata[4] && (timeout_count < 4000));

	if (timeout_count >= 4000) begin
	   $error("[%t] : *** ERROR *** Timeout waiting for the computation to finish", $realtime);
	   error_count++;
	end else begin
		$display("[%t] : Transfer output RLWE", $realtime);
    	host_memory_buffer_address = 64'h0004_0000_0000 + len1;
		tb.que_cl_to_buffer(.chan(0), .dst_addr(host_memory_buffer_address), .cl_addr(64'h0004_0000_0000 + len1), .len(len1));
		//Start transfers of data from CL DDR
		tb.start_que_to_buffer(.chan(0));
		//tb.start_que_to_buffer(.chan(1));
		//tb.start_que_to_buffer(.chan(2));
		//tb.start_que_to_buffer(.chan(3));
		// wait for dma transfers to complete
		timeout_count = 0;
		do begin
		   status[0] = tb.is_dma_to_buffer_done(.chan(0));
		   //status[1] = tb.is_dma_to_buffer_done(.chan(1));
		   //status[2] = tb.is_dma_to_buffer_done(.chan(2));
		   //status[3] = tb.is_dma_to_buffer_done(.chan(3));
		   //status[0] = 1;
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

		$display("[%t] : Finish transferring output RLWE", $realtime);

		$display("[%t] : Comparing output RLWE", $realtime);
		
		$display("[%t] : Read in ground truth RLWE", $realtime);

		file_name = $sformatf("%0s/verif/tests/mem_init_content/top_verify/rlwesubs/bk/RLWESUBS_outputrlwe_2k_a0.mem", cl_dir);
		$readmemh(file_name, polya);

		file_name = $sformatf("%0s/verif/tests/mem_init_content/top_verify/rlwesubs/bk/RLWESUBS_outputrlwe_2k_b0.mem", cl_dir);
		$readmemh(file_name, polyb);
		$display("[%t] : Finish reading in ground truth RLWE", $realtime);
		
		host_memory_buffer_address = 64'h0004_0000_0000 + len1;
		for (longint i = 0 ; i < `MAX_LEN; i += 4) begin
			for(int j = 0; j < 4; j++) begin
				temp = 0;
				for(int k = 0; k < 8; k++) begin
					rbyte = tb.hm_get_byte(.addr(host_memory_buffer_address));
					temp = temp | (rbyte << (k * 8));
					host_memory_buffer_address++;
				end
				if(temp != {{(64 - `BIT_WIDTH){1'b0}}, polya[i + j]}) begin
					$error("[%t] : *** ERROR *** Output RLWE poly a incorrect at %d, expect: %h, received: %h", $realtime, i+j, polya[i+j], temp);
					error_count++;
				end
			end

			for(int j = 0; j < 4; j++) begin
				temp = 0; 
				for(int k = 0; k < 8; k++) begin
					rbyte = tb.hm_get_byte(.addr(host_memory_buffer_address));
					temp = temp | (rbyte << (k * 8));
					host_memory_buffer_address++;
				end
				if(temp != {{(64 - `BIT_WIDTH){1'b0}}, polyb[i + j]}) begin
					$error("[%t] : *** ERROR *** Output RLWE poly a incorrect at %d, expect: %h, received: %h", $realtime, i+j, polyb[i+j], temp);
					error_count++;
				end
			end
		end
	end

	$display("[%t] : Finish comparing output RLWE", $realtime);

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
