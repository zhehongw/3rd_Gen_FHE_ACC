`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/25/2021 04:53:09 PM
// Design Name: 
// Module Name: test_myFIFO
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
module test_poly_MAC #(
)(

    );
    logic clk, rstn;
	
	//source ports
    myFIFO_NTT_sink_if input_FIFO ();
	//sink ports
    myFIFO_NTT_source_if output_FIFO_to_global [1 : 0]();
  	//config ports
	config_if config_ports();

	//logic [`OPCODE_WIDTH - 1 : 0] opcode;
	//logic [`RLWE_ID_WIDTH - 1 : 0] rlwe_id;
	//logic [`POLY_ID_WIDTH - 1 : 0] poly_id;
	//logic ROB_empty_NTT;
	
	myFIFO_NTT_source_if dummy_FIFO_ports ();
	logic [`LINE_SIZE - 1 : 0] dummy_wen_sel;	
	myFIFO_dummy #(.POINTER_WIDTH(3)) dummy_FIFO (
		.clk(clk),
		.rstn(rstn),
		.word_selA(dummy_wen_sel),
		.word_selB(dummy_wen_sel),
		.source_ports(dummy_FIFO_ports),
		.sink_ports(input_FIFO),
		.outer_rd_enable(1'b1)
	);
	
	myFIFO_NTT_source_if key_load_source [1 : 0] ();
	myFIFO_NTT_sink_if key_load_sink [1 : 0] ();
	logic [`LINE_SIZE - 1 : 0] key_load_wen_sel [1 : 0];
	myFIFO_dummy #(.POINTER_WIDTH(3)) key_loading_FIFO [1 : 0](
		.clk(clk),
		.rstn(rstn),
		.word_selA(key_load_wen_sel),
		.word_selB(key_load_wen_sel),
		.source_ports(key_load_source),
		.sink_ports(key_load_sink),
		.outer_rd_enable(1'b1)
	);

	logic [`LINE_SIZE - 1 : 0] global_word_selA [1 : 0];
	logic [`LINE_SIZE - 1 : 0] global_word_selB [1 : 0];
	logic global_inner_rd_enable [1 : 0];
	logic global_outer_rd_enable [1 : 0];
	logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] global_doutA [1 : 0];
	logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] global_doutB [1 : 0];
	myFIFO_NTT_sink_if global_sink_if [1 : 0] ();
	myFIFO_dummy_global global_FIFO [1 : 0](
		.clk(clk),
		.rstn(rstn),
		.word_selA(global_word_selA),
		.word_selB(global_word_selB),
		.inner_rd_enable(global_inner_rd_enable),
		.outer_rd_enable(global_outer_rd_enable),
		.doutA(global_doutA),
		.doutB(global_doutB),
		.source_ports(output_FIFO_to_global),
		.sink_ports(global_sink_if)
	);

	logic [1 : 0] acc_wr_enable;

	acc_top DUT (
		.clk(clk),
		.rstn(rstn),
		.NTT_FIFO(input_FIFO),
		.out_to_next_stage(output_FIFO_to_global),
		.output_wr_enable(acc_wr_enable),
		.outram_doutA(global_doutA),
		.outram_doutB(global_doutB),
		.key_FIFO(key_load_sink),
		.config_ports(config_ports)
	);

	//modulus operation parameters
	longint q, length, ilength;
	int k;
	logic [127 : 0] m;

	//ground truth output mem
	logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] NTT_memA [0 : 2 ** `ADDR_WIDTH - 1];
	logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] NTT_memB [0 : 2 ** `ADDR_WIDTH - 1];
  
	function [63 : 0] mod_sub;
		input [63 : 0] a, b, q;
		mod_sub = (a - b + q) % q;
	endfunction

	function [63 : 0] mod_add;
		input [63 : 0] a, b, q;
		mod_add = (a + b) % q;
	endfunction

	//connect global fifo read/write controll	
	always_comb begin
		global_word_selA[0] = {`LINE_SIZE{acc_wr_enable[0]}};
		global_word_selB[0] = {`LINE_SIZE{acc_wr_enable[0]}};
		global_word_selA[1] = {`LINE_SIZE{acc_wr_enable[1]}};
		global_word_selB[1] = {`LINE_SIZE{acc_wr_enable[1]}};
		global_inner_rd_enable[0] = ~acc_wr_enable[0];
		global_inner_rd_enable[1] = ~acc_wr_enable[1];
	end

    initial begin 
		$monitor("[%t]: rstn = %h, dummy_fifo_empty = %h, global_sink_empty = %h, %h", $time, rstn, input_FIFO.empty, global_sink_if[0].empty, global_sink_if[1].empty);
		
		//initialize
        clk = 0;
        rstn = 0;

		//dummy port initialize
		dummy_wen_sel = 0;
		dummy_FIFO_ports.addrA = 0;
		dummy_FIFO_ports.addrB = 0;
		dummy_FIFO_ports.dA = 0;
		dummy_FIFO_ports.dB = 0;
		dummy_FIFO_ports.wr_finish = 1;
		dummy_FIFO_ports.rlwe_id = 0;
		dummy_FIFO_ports.poly_id = `POLY_A;
		dummy_FIFO_ports.opcode = `RLWESUBS;
		
		//key load fifo initialize
		key_load_wen_sel[0] = 0;
		key_load_source[0].addrA = 0;
		key_load_source[0].addrB = 0;
		key_load_source[0].dA = 0;
		key_load_source[0].dB = 0;
		key_load_source[0].wr_finish = 1;
		key_load_wen_sel[1] = 0;
		key_load_source[1].addrA = 0;
		key_load_source[1].addrB = 0;
		key_load_source[1].dA = 0;
		key_load_source[1].dB = 0;
		key_load_source[1].wr_finish = 1;


		//config_ports initialize
		q = 54'h3F_FFFF_FFFE_D001;
		length = 2048;
		ilength = 54'h3FF7FFFFFED027;
		k = `BIT_WIDTH;
		m = (1 << (k * 2)) / q;

		config_ports.q = q;
		config_ports.m = m[`BIT_WIDTH : 0];
		config_ports.k2 = k * 2;
		config_ports.length = length;
		config_ports.ilength = ilength;
		config_ports.log2_len = $clog2(length);
		config_ports.BG_mask = (1 << 9) - 1; //BG = 512 = 1 << 9
		config_ports.digitG = 6;	//54/9
		config_ports.BG_width = 9;
		config_ports.lwe_q_mask = 512 - 1;
		config_ports.embed_factor = 2 * length / 512;


		//global fifo sink ports initialize
		global_sink_if[0].addrA = 0;
		global_sink_if[0].addrB = 0;
		global_sink_if[0].rd_finish = 1;
		global_sink_if[1].addrA = 0;
		global_sink_if[1].addrB = 0;
		global_sink_if[1].rd_finish = 1;
		global_outer_rd_enable[0] = 1;
		global_outer_rd_enable[1] = 1;
		
		//simulate with 2k length
        //initialize input fifo content
		if(`LINE_SIZE == 4) begin
		  	$readmemh("iNTT_input_2k_0_x4.mem", dummy_FIFO.GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("iNTT_input_2k_1_x4.mem", dummy_FIFO.GENERATE_HEADER[6].FIFO.ram);
		  	$readmemh("iNTT_input_2k_0_x4.mem", NTT_memA);
		  	$readmemh("iNTT_input_2k_1_x4.mem", NTT_memB);
		end else begin
		  	$readmemh("iNTT_input_2k_0_x2.mem", dummy_FIFO.GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("iNTT_input_2k_1_x2.mem", dummy_FIFO.GENERATE_HEADER[6].FIFO.ram);
		  	$readmemh("iNTT_input_2k_0_x2.mem", NTT_memA);
		  	$readmemh("iNTT_input_2k_1_x2.mem", NTT_memB);
		end
		for(integer i = 0; i < length; i++) begin
			//generated block cannot be index by a variable inside an initial
			//or always block, but it can be index by a genvar, like
			//for(genvar i; i < N; i++) begin
			//	always begin
			//		dummy_FIFO.GENERATE_HEADER[i].FIFO.ram;
			//	end
			//end
			//In my use case here, I have to index the blocks explicitly
			dummy_FIFO.GENERATE_HEADER[1].FIFO.ram[i] = 0;
			dummy_FIFO.GENERATE_HEADER[2].FIFO.ram[i] = 0;
			dummy_FIFO.GENERATE_HEADER[3].FIFO.ram[i] = 0;
			dummy_FIFO.GENERATE_HEADER[4].FIFO.ram[i] = 0;
			dummy_FIFO.GENERATE_HEADER[5].FIFO.ram[i] = 0;
		end

		//initialize key load fifo content
		for(integer i = 0; i < length; i++) begin
			for(integer k = 0; k < `LINE_SIZE; k++) begin
				key_loading_FIFO[0].GENERATE_HEADER[0].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;
				key_loading_FIFO[1].GENERATE_HEADER[0].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;

				key_loading_FIFO[0].GENERATE_HEADER[1].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;
				key_loading_FIFO[1].GENERATE_HEADER[1].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;
				
				key_loading_FIFO[0].GENERATE_HEADER[2].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;
				key_loading_FIFO[1].GENERATE_HEADER[2].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;
				
				key_loading_FIFO[0].GENERATE_HEADER[3].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;
				key_loading_FIFO[1].GENERATE_HEADER[3].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;
				
				key_loading_FIFO[0].GENERATE_HEADER[4].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;
				key_loading_FIFO[1].GENERATE_HEADER[4].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;
				
				key_loading_FIFO[0].GENERATE_HEADER[5].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;
				key_loading_FIFO[1].GENERATE_HEADER[5].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;
				
			end
		end

		//deassert rstn
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
		rstn = 1;
	

		//first move dummy FIFO wr pointer, dummy FIFO content is initialized
		//by readmemh, so need to move the pointer seperately 
		@(negedge clk);
		for(integer i = 0; i < 6; i++) begin
			@(negedge clk);
			dummy_FIFO_ports.wr_finish = 0;
			dummy_FIFO_ports.rlwe_id = 3;
			dummy_FIFO_ports.poly_id = `POLY_A;
			dummy_FIFO_ports.opcode = `RLWESUBS;
			@(negedge clk);
			dummy_FIFO_ports.wr_finish = 1;
		end
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 0;
		dummy_FIFO_ports.rlwe_id = 3;
		dummy_FIFO_ports.poly_id = `POLY_B;
		dummy_FIFO_ports.opcode = `RLWESUBS;
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 1;

		//move key_loading FIFO wr pointer, key_loading FIFO content is initialized
		//by readmemh, so need to move the pointer seperately 
		@(negedge clk);
		for(integer i = 0; i < 6; i++) begin
			@(negedge clk);
			key_load_source[0].wr_finish = 0;
            key_load_source[1].wr_finish = 0;
			@(negedge clk);
			key_load_source[0].wr_finish = 1;
			key_load_source[1].wr_finish = 1;
		end



		// wait the output fifo of iNTT to be not empty
		@(negedge clk);
		@(negedge clk);

		@(negedge global_sink_if[1].empty);
		@(negedge clk);

		//verify output fifo content
		@(negedge clk);
		
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			for(integer j = 0; j < `LINE_SIZE; j++) begin	
				if(global_FIFO[0].GENERATE_HEADER[0].FIFO.ram[i][j * `BIT_WIDTH +: `BIT_WIDTH] !== mod_sub(0, NTT_memA[i][j * `BIT_WIDTH +: `BIT_WIDTH], q)) begin
					$display("poly MAC not correct at poly 0 addr: %d, %d", i, j);
				end
			end
		end
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			for(integer j = 0; j < `LINE_SIZE; j++) begin	
				if(global_FIFO[1].GENERATE_HEADER[0].FIFO.ram[i][j * `BIT_WIDTH +: `BIT_WIDTH] !== mod_sub(NTT_memB[i][j * `BIT_WIDTH +: `BIT_WIDTH], NTT_memA[i][j * `BIT_WIDTH +: `BIT_WIDTH], q)) begin
					$display("poly MAC not correct at poly 1 addr: %d, %d", i, j);
				end
			end
		end
		@(negedge clk);
	
		//simulate with 1k length 
		//config_ports initialize
		q = 54'h0000000007FFF801;
		length = 1024;
		ilength = 54'h0000000007FDF803;
		k = 27;
		m = (1 << (k * 2)) / q;

		config_ports.q = q;
		config_ports.m = m[`BIT_WIDTH : 0];
		config_ports.k2 = k * 2;
		config_ports.length = length;
		config_ports.ilength = ilength;
		config_ports.log2_len = $clog2(length);
		config_ports.BG_mask = (1 << 9) - 1; //BG = 512 = 1 << 9
		config_ports.digitG = 3;	//27/9
		config_ports.BG_width = 9;
		config_ports.lwe_q_mask = 512 - 1;
		config_ports.embed_factor = 2 * length / 512;

        //initialize input fifo content
		if(`LINE_SIZE == 4) begin
		  	$readmemh("iNTT_input_1k_x4.mem", dummy_FIFO.GENERATE_HEADER[7].FIFO.ram);
		  	$readmemh("iNTT_input_1k_x4.mem", dummy_FIFO.GENERATE_HEADER[2].FIFO.ram);
		  	$readmemh("iNTT_input_1k_x4.mem", NTT_memA);
		  	$readmemh("iNTT_input_1k_x4.mem", NTT_memB);
		end else begin
		  	$readmemh("iNTT_input_1k_x2.mem", dummy_FIFO.GENERATE_HEADER[7].FIFO.ram);
		  	$readmemh("iNTT_input_1k_x2.mem", dummy_FIFO.GENERATE_HEADER[2].FIFO.ram);
		  	$readmemh("iNTT_input_1k_x2.mem", NTT_memA);
		  	$readmemh("iNTT_input_1k_x2.mem", NTT_memB);
		end
		for(integer i = 0; i < length; i++) begin
			//generated block cannot be index by a variable inside an initial
			//or always block, but it can be index by a genvar, like
			//for(genvar i; i < N; i++) begin
			//	always begin
			//		dummy_FIFO.GENERATE_HEADER[i].FIFO.ram;
			//	end
			//end
			//In my use case here, I have to index the blocks explicitly
			dummy_FIFO.GENERATE_HEADER[0].FIFO.ram[i] = 0;
			dummy_FIFO.GENERATE_HEADER[1].FIFO.ram[i] = 0;
			dummy_FIFO.GENERATE_HEADER[3].FIFO.ram[i] = 0;
			dummy_FIFO.GENERATE_HEADER[4].FIFO.ram[i] = 0;
		end
		//initialize key load fifo content
		for(integer i = 0; i < length; i++) begin
			for(integer k = 0; k < `LINE_SIZE; k++) begin
				key_loading_FIFO[0].GENERATE_HEADER[0].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;
				key_loading_FIFO[1].GENERATE_HEADER[0].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;

				key_loading_FIFO[0].GENERATE_HEADER[1].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;
				key_loading_FIFO[1].GENERATE_HEADER[1].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;
				
				key_loading_FIFO[0].GENERATE_HEADER[2].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;
				key_loading_FIFO[1].GENERATE_HEADER[2].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;
				
				key_loading_FIFO[0].GENERATE_HEADER[3].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;
				key_loading_FIFO[1].GENERATE_HEADER[3].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;
				
				key_loading_FIFO[0].GENERATE_HEADER[6].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;
				key_loading_FIFO[1].GENERATE_HEADER[6].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;
				
				key_loading_FIFO[0].GENERATE_HEADER[7].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;
				key_loading_FIFO[1].GENERATE_HEADER[7].FIFO.ram[i][k * `BIT_WIDTH +: `BIT_WIDTH] = 1;
				
			end
		end
		//first move dummy FIFO wr pointer, dummy FIFO content is initialized
		//by readmemh, so need to move the pointer seperately 
		@(negedge clk);
		for(integer i = 0; i < 3; i++) begin
			@(negedge clk);
			dummy_FIFO_ports.wr_finish = 0;
			dummy_FIFO_ports.rlwe_id = 4;
			dummy_FIFO_ports.poly_id = `POLY_A;
			dummy_FIFO_ports.opcode = `BOOTSTRAP_INIT;
			@(negedge clk);
			dummy_FIFO_ports.wr_finish = 1;
		end

		//move key_loading FIFO wr pointer, key_loading FIFO content is initialized
		//by readmemh, so need to move the pointer seperately 
		@(negedge clk);
		for(integer i = 0; i < 6; i++) begin
			@(negedge clk);
			key_load_source[0].wr_finish = 0;
            key_load_source[1].wr_finish = 0;
			@(negedge clk);
			key_load_source[0].wr_finish = 1;
			key_load_source[1].wr_finish = 1;
		end
		// wait for the global fifo to be full
		@(negedge clk);
		@(negedge clk);
        
        @(posedge acc_wr_enable[1]);
        #10000;                         //to test the wait function
        //move wr pointer by 3 more steps
        @(negedge clk);
		for(integer i = 0; i < 3; i++) begin
			@(negedge clk);
			dummy_FIFO_ports.wr_finish = 0;
			dummy_FIFO_ports.rlwe_id = 4;
			dummy_FIFO_ports.poly_id = `POLY_B;
			dummy_FIFO_ports.opcode = `BOOTSTRAP_INIT;
			@(negedge clk);
			dummy_FIFO_ports.wr_finish = 1;
		end

		@(negedge clk);
		@(posedge output_FIFO_to_global[1].full);
		@(negedge clk);

		//verify output fifo content
		@(negedge clk);
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			for(integer j = 0; j < `LINE_SIZE; j++) begin	
				if(global_FIFO[0].GENERATE_HEADER[1].FIFO.ram[i][j * `BIT_WIDTH +: `BIT_WIDTH] !== mod_add(NTT_memB[i][j * `BIT_WIDTH +: `BIT_WIDTH], NTT_memA[i][j * `BIT_WIDTH +: `BIT_WIDTH], q)) begin
					$display("poly MAC not correct at 1k poly 0 addr: %d, %d", i, j);
				end
			end
		end
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			for(integer j = 0; j < `LINE_SIZE; j++) begin	
				if(global_FIFO[1].GENERATE_HEADER[1].FIFO.ram[i][j * `BIT_WIDTH +: `BIT_WIDTH] !== mod_add(NTT_memB[i][j * `BIT_WIDTH +: `BIT_WIDTH], NTT_memA[i][j * `BIT_WIDTH +: `BIT_WIDTH], q)) begin
					$display("poly MAC not correct at 1k poly 1 addr: %d, %d", i, j);
				end
			end
		end
		@(negedge clk);
		#1000;
 		$finish;
    end
	
	
    always #5 clk = ~clk;
    
endmodule
