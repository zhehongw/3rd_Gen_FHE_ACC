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


module test_rou_irou_write();
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
logic [64 : 0] 	ddr_addr;
int             fp;
int             r;
reg [1000 : 0]  cl_dir;
string          file_name;
logic [512 : 0] data;

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

	$display("[%t] : Initializing registers with OCL-AXIL", $realtime);
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
	
	//set cl directory 
	r = $value$plusargs("CL_DIR=%s", cl_dir);

	$display("[%t] : Test 2k length", $realtime);
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
	for(int i = 0; i < rlwe_length * 8; i+=8) begin
		tb.poke_bar1(.addr(i + 16*1024), .data({{5{1'b0}}, irou_table[i / 8][0 +: 27]}));
		tb.poke_bar1(.addr(i + 4 + 16*1024), .data({{5{1'b0}}, irou_table[i / 8][27 +: 27]}));
	end
	tb.nsec_delay(1000);


	$display("[%t] : Finish program rou/irou table 2k length", $realtime);

	$display("[%t] : Test 1k length", $realtime);
	$display("[%t] : Read in rou/irou table from files", $realtime);

	file_name = $sformatf("%0s/verif/tests/mem_init_content/bk/ROU_table_1k_complete.mem", cl_dir);
	$readmemh(file_name, rou_table);

	file_name = $sformatf("%0s/verif/tests/mem_init_content/bk/iROU_table_1k.mem", cl_dir);
	$readmemh(file_name, irou_table);
	
	rlwe_length 	= 1024;
	log2_rlwe_len 	= $clog2(rlwe_length);
	tb.poke_bar1(.addr({{(64-8){1'b0}}, `ADDR_RLWE_LEN}), .data(rlwe_length));
	tb.poke_bar1(.addr({{(64-8){1'b0}}, `ADDR_LOG2_RLWE_LEN}), .data(log2_rlwe_len));
	tb.nsec_delay(1000);

	$display("[%t] : Program ROU table with BAR1-AXIL", $realtime);
	for(int i = 0; i < 1; i++) begin
		tb.poke_bar1(.addr(`ROU_STAGE9_BASE_ADDR + 8 * i), .data({{5{1'b0}}, rou_table[i + 1][0 +: 27]}));
		tb.poke_bar1(.addr(`ROU_STAGE9_BASE_ADDR + 8 * i + 4), .data({{5{1'b0}}, rou_table[i + 1][27 +: 27]}));
	end
	for(int i = 0; i < 2; i++) begin
		tb.poke_bar1(.addr(`ROU_STAGE8_BASE_ADDR + 8 * i), .data({{5{1'b0}}, rou_table[i + 2][0 +: 27]}));
		tb.poke_bar1(.addr(`ROU_STAGE8_BASE_ADDR + 8 * i + 4), .data({{5{1'b0}}, rou_table[i + 2][27 +: 27]}));
	end
	for(int i = 0; i < 4; i++) begin
		tb.poke_bar1(.addr(`ROU_STAGE7_BASE_ADDR + 8 * i), .data({{5{1'b0}}, rou_table[i + 4][0 +: 27]}));
		tb.poke_bar1(.addr(`ROU_STAGE7_BASE_ADDR + 8 * i + 4), .data({{5{1'b0}}, rou_table[i + 4][27 +: 27]}));
	end
	for(int i = 0; i < 8; i++) begin
		tb.poke_bar1(.addr(`ROU_STAGE6_BASE_ADDR + 8 * i), .data({{5{1'b0}}, rou_table[i + 8][0 +: 27]}));
		tb.poke_bar1(.addr(`ROU_STAGE6_BASE_ADDR + 8 * i + 4), .data({{5{1'b0}}, rou_table[i + 8][27 +: 27]}));
	end
	for(int i = 0; i < 16; i++) begin
		tb.poke_bar1(.addr(`ROU_STAGE5_BASE_ADDR + 8 * i), .data({{5{1'b0}}, rou_table[i + 16][0 +: 27]}));
		tb.poke_bar1(.addr(`ROU_STAGE5_BASE_ADDR + 8 * i + 4), .data({{5{1'b0}}, rou_table[i + 16][27 +: 27]}));
	end
	for(int i = 0; i < 32; i++) begin
		tb.poke_bar1(.addr(`ROU_STAGE4_BASE_ADDR + 8 * i), .data({{5{1'b0}}, rou_table[i + 32][0 +: 27]}));
		tb.poke_bar1(.addr(`ROU_STAGE4_BASE_ADDR + 8 * i + 4), .data({{5{1'b0}}, rou_table[i + 32][27 +: 27]}));
	end
	for(int i = 0; i < 64; i++) begin
		tb.poke_bar1(.addr(`ROU_STAGE3_BASE_ADDR + 8 * i), .data({{5{1'b0}}, rou_table[i + 64][0 +: 27]}));
		tb.poke_bar1(.addr(`ROU_STAGE3_BASE_ADDR + 8 * i + 4), .data({{5{1'b0}}, rou_table[i + 64][27 +: 27]}));
	end
	for(int i = 0; i < 128; i++) begin
		tb.poke_bar1(.addr(`ROU_STAGE2_BASE_ADDR + 8 * i), .data({{5{1'b0}}, rou_table[i + 128][0 +: 27]}));
		tb.poke_bar1(.addr(`ROU_STAGE2_BASE_ADDR + 8 * i + 4), .data({{5{1'b0}}, rou_table[i + 128][27 +: 27]}));
	end
	for(int i = 0; i < 256; i++) begin
		tb.poke_bar1(.addr(`ROU_STAGE1_BASE_ADDR + 8 * i), .data({{5{1'b0}}, rou_table[i + 256][0 +: 27]}));
		tb.poke_bar1(.addr(`ROU_STAGE1_BASE_ADDR + 8 * i + 4), .data({{5{1'b0}}, rou_table[i + 256][27 +: 27]}));
	end
	for(int i = 0; i < 512; i++) begin
		tb.poke_bar1(.addr(`ROU_STAGE0_BASE_ADDR + 8 * i), .data({{5{1'b0}}, rou_table[i + 512][0 +: 27]}));
		tb.poke_bar1(.addr(`ROU_STAGE0_BASE_ADDR + 8 * i + 4), .data({{5{1'b0}}, rou_table[i + 512][27 +: 27]}));
	end
	tb.nsec_delay(1000);

	$display("[%t] : Program iROU table with BAR1-AXIL", $realtime);
	for(int i = 0; i < rlwe_length * 8; i+=8) begin
		tb.poke_bar1(.addr(i + 16*1024), .data({{5{1'b0}}, irou_table[i / 8][0 +: 27]}));
		tb.poke_bar1(.addr(i + 4 + 16*1024), .data({{5{1'b0}}, irou_table[i / 8][27 +: 27]}));
	end
	tb.nsec_delay(1000);

	$display("[%t] : Finish program rou/irou table 1k length", $realtime);

	// Power down
	#500ns;
	tb.power_down();
	error_count = 0;	
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
