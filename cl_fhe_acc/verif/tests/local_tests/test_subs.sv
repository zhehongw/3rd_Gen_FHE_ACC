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
module test_subs #(
	
)(

    );
    logic clk, rstn;

	myFIFO_NTT_source_if dummy_FIFO_ports ();
	//source ports
    myFIFO_NTT_sink_if input_FIFO ();
	//sink ports
    myFIFO_NTT_sink_if output_FIFO ();
  	//config ports
	config_if config_ports();
	logic outer_rd_enable;
	logic [3 : 0] subs_factor;

	//logic [`OPCODE_WIDTH - 1 : 0] opcode;
	//logic [`RLWE_ID_WIDTH - 1 : 0] rlwe_id;
	//logic [`POLY_ID_WIDTH - 1 : 0] poly_id;
	logic ROB_empty_subs;
	
	logic [`LINE_SIZE - 1 : 0] dummy_wen_sel;	
	myFIFO_dummy #(.POINTER_WIDTH(2))dummy_FIFO (
		.clk(clk),
		.rstn(rstn),
		.word_selA(dummy_wen_sel),
		.word_selB(dummy_wen_sel),
		.source_ports(dummy_FIFO_ports),
		.sink_ports(input_FIFO),
		.outer_rd_enable(outer_rd_enable)
	);
	
	subs_module DUT (
		.clk(clk),
		.rstn(rstn),
		.input_FIFO(input_FIFO),
		.out_to_next_stage(output_FIFO),
		.config_ports(config_ports),
		.rd_enable(outer_rd_enable),
		.subs_factor(subs_factor),
		.ROB_empty(ROB_empty_subs)
	);

	//modulus operation parameters
	longint q, length, ilength;
	int k;
	logic [127 : 0] m;

	//ground truth output mem
	logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] iNTT_memA [0 : 2 ** `ADDR_WIDTH - 1];
	logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] iNTT_memB [0 : 2 ** `ADDR_WIDTH - 1];
	logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] iNTT_memC [0 : 2 ** `ADDR_WIDTH - 1];
    
    
    initial begin 
		$monitor("[%t]: rstn = %h, ROB_empty_NTT = %h, dummy_fifo_empty = %h, output_fifo_empty = %h", $time, rstn, ROB_empty_subs, input_FIFO.empty, output_FIFO.empty);
		
		
        if(`LINE_SIZE == 4) begin
		  	$readmemh("subs_input_2k_x4.mem", dummy_FIFO.GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("subs_input_2k_x4.mem", dummy_FIFO.GENERATE_HEADER[1].FIFO.ram);
		  	$readmemh("subs_input_2k_x4.mem", dummy_FIFO.GENERATE_HEADER[2].FIFO.ram);
		  	$readmemh("subs_output0_2k_x4.mem", iNTT_memA);
		  	$readmemh("subs_output1_2k_x4.mem", iNTT_memB);
		    $readmemh("subs_output2_2k_x4.mem", iNTT_memC);
		end else begin
		  	$readmemh("subs_input_2k_x2.mem", dummy_FIFO.GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("subs_input_2k_x2.mem", dummy_FIFO.GENERATE_HEADER[1].FIFO.ram);
		  	$readmemh("subs_input_2k_x2.mem", dummy_FIFO.GENERATE_HEADER[2].FIFO.ram);
		  	$readmemh("subs_output0_2k_x2.mem", iNTT_memA);
		  	$readmemh("subs_output1_2k_x2.mem", iNTT_memB);
		  	$readmemh("subs_output2_2k_x2.mem", iNTT_memC);
		end
		
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

		// ports from ROB initialize
		ROB_empty_subs = 1;

		//output fifo ports initialize
		output_FIFO.addrA = 0;
		output_FIFO.addrB = 0;
		output_FIFO.rd_finish = 1;



		//deassert rstn
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
		rstn = 1;
	

		//first move dummy FIFO wr pointer, dummy FIFO content is initialized
		//by readmemh, so need to move the pointer seperately 
		@(negedge clk);
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 0;
		dummy_FIFO_ports.rlwe_id = 3;
		dummy_FIFO_ports.poly_id = `POLY_A;
		dummy_FIFO_ports.opcode = `RLWESUBS;
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 1;
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 0;
		dummy_FIFO_ports.rlwe_id = 3;
		dummy_FIFO_ports.poly_id = `POLY_B;
		dummy_FIFO_ports.opcode = `RLWESUBS;
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 1;
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 0;
		dummy_FIFO_ports.rlwe_id = 4;
		dummy_FIFO_ports.poly_id = `POLY_A;
		dummy_FIFO_ports.opcode = `RLWESUBS;
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 1;

        //test with subs factor = 0
        subs_factor = 0;
		//reset ROB empty to start the state machine
		@(negedge clk);
		ROB_empty_subs = 0;


		// wait for the first posedge rd_finish of the input fifo of subs module
		@(negedge clk);
		@(negedge clk);
		@(posedge input_FIFO.rd_finish);
		@(posedge clk);
        //test with subs factor = 1
        `SD subs_factor = 1;
        
        @(negedge clk);
		@(posedge input_FIFO.rd_finish);
		@(posedge clk);
        //test with subs factor = 2
        `SD subs_factor = 2;
        
		@(posedge DUT.subs_FIFO_if.full);
		@(negedge clk);
		ROB_empty_subs = 1;

		//verify output fifo content
		@(negedge clk);
		
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.subs_FIFO.GENERATE_HEADER[0].FIFO.ram[i] !== iNTT_memA[i]) begin
				$display("subs not correct at subs factor = 0, addr: %d", i);
			end
		end
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.subs_FIFO.GENERATE_HEADER[1].FIFO.ram[i] !== iNTT_memB[i]) begin
				$display("subs not correct at subs factor = 1, addr: %d", i);
			end
		end
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.subs_FIFO.GENERATE_HEADER[2].FIFO.ram[i] !== iNTT_memC[i]) begin
				$display("subs not correct at subs factor = 2, addr: %d", i);
			end
		end
		
		//read from the output fifo
		@(negedge clk);
		@(negedge clk);
		@(negedge clk);
		output_FIFO.rd_finish = 0;
		@(negedge clk);
		@(negedge clk);
		@(negedge clk);
		output_FIFO.rd_finish = 1;
		@(negedge clk);
		output_FIFO.rd_finish = 0;
		@(negedge clk);
		output_FIFO.rd_finish = 1;
		@(negedge clk);
		output_FIFO.rd_finish = 0;
		@(negedge clk);
		output_FIFO.rd_finish = 1;
		
		//first move dummy FIFO wr pointer, dummy FIFO content is initialized
		//by readmemh, so need to move the pointer seperately 
		@(negedge clk);
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 0;
		dummy_FIFO_ports.rlwe_id = 4;
		dummy_FIFO_ports.poly_id = `POLY_B;
		dummy_FIFO_ports.opcode = `RLWESUBS;
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 1;
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 0;
		dummy_FIFO_ports.rlwe_id = 5;
		dummy_FIFO_ports.poly_id = `POLY_A;
		dummy_FIFO_ports.opcode = `RLWESUBS;
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 1;
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 0;
		dummy_FIFO_ports.rlwe_id = 5;
		dummy_FIFO_ports.poly_id = `POLY_B;
		dummy_FIFO_ports.opcode = `RLWESUBS;
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 1;


		if(`LINE_SIZE == 4) begin
		  	$readmemh("subs_input_2k_x4.mem", dummy_FIFO.GENERATE_HEADER[3].FIFO.ram);
		  	$readmemh("subs_input_2k_x4.mem", dummy_FIFO.GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("subs_input_2k_x4.mem", dummy_FIFO.GENERATE_HEADER[1].FIFO.ram);
		  	$readmemh("subs_output3_2k_x4.mem", iNTT_memA);
		  	$readmemh("subs_output4_2k_x4.mem", iNTT_memB);
		    $readmemh("subs_output5_2k_x4.mem", iNTT_memC);
		end else begin
		  	$readmemh("subs_input_2k_x2.mem", dummy_FIFO.GENERATE_HEADER[3].FIFO.ram);
		  	$readmemh("subs_input_2k_x2.mem", dummy_FIFO.GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("subs_input_2k_x2.mem", dummy_FIFO.GENERATE_HEADER[1].FIFO.ram);
		  	$readmemh("subs_output3_2k_x2.mem", iNTT_memA);
		  	$readmemh("subs_output4_2k_x2.mem", iNTT_memB);
		  	$readmemh("subs_output5_2k_x2.mem", iNTT_memC);
		end
		
		//test with subs factor = 3
        subs_factor = 3;
		//reset ROB empty to start the state machine
		@(negedge clk);
		ROB_empty_subs = 0;


		// wait for the first posedge rd_finish of the input fifo of subs module
		@(negedge clk);
		@(negedge clk);
		@(posedge input_FIFO.rd_finish);
        @(posedge clk);
        //test with subs factor = 4
        `SD subs_factor = 4;
        @(negedge clk);
		@(posedge input_FIFO.rd_finish);
        @(posedge clk);
        //test with subs factor = 5
        `SD subs_factor = 5;
        
		@(posedge DUT.subs_FIFO_if.full);
		@(negedge clk);
		ROB_empty_subs = 1;

		//verify output fifo content
		@(negedge clk);
		
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.subs_FIFO.GENERATE_HEADER[0].FIFO.ram[i] !== iNTT_memA[i]) begin
				$display("subs not correct at subs factor = 3, addr: %d", i);
			end
		end
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.subs_FIFO.GENERATE_HEADER[1].FIFO.ram[i] !== iNTT_memB[i]) begin
				$display("subs not correct at subs factor = 4, addr: %d", i);
			end
		end
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.subs_FIFO.GENERATE_HEADER[2].FIFO.ram[i] !== iNTT_memC[i]) begin
				$display("subs not correct at subs factor = 5, addr: %d", i);
			end
		end
		//read from the output fifo
		@(negedge clk);
		@(negedge clk);
		@(negedge clk);
		output_FIFO.rd_finish = 0;
		@(negedge clk);
		@(negedge clk);
		@(negedge clk);
		output_FIFO.rd_finish = 1;
		@(negedge clk);
		output_FIFO.rd_finish = 0;
		@(negedge clk);
		output_FIFO.rd_finish = 1;
		@(negedge clk);
		output_FIFO.rd_finish = 0;
		@(negedge clk);
		output_FIFO.rd_finish = 1;
		
		//first move dummy FIFO wr pointer, dummy FIFO content is initialized
		//by readmemh, so need to move the pointer seperately 
		@(negedge clk);
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 0;
		dummy_FIFO_ports.rlwe_id = 6;
		dummy_FIFO_ports.poly_id = `POLY_A;
		dummy_FIFO_ports.opcode = `RLWESUBS;
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 1;
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 0;
		dummy_FIFO_ports.rlwe_id = 6;
		dummy_FIFO_ports.poly_id = `POLY_B;
		dummy_FIFO_ports.opcode = `RLWESUBS;
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 1;
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 0;
		dummy_FIFO_ports.rlwe_id = 7;
		dummy_FIFO_ports.poly_id = `POLY_A;
		dummy_FIFO_ports.opcode = `RLWESUBS;
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 1;
		
		if(`LINE_SIZE == 4) begin
		  	$readmemh("subs_input_2k_x4.mem", dummy_FIFO.GENERATE_HEADER[2].FIFO.ram);
		  	$readmemh("subs_input_2k_x4.mem", dummy_FIFO.GENERATE_HEADER[3].FIFO.ram);
		  	$readmemh("subs_input_2k_x4.mem", dummy_FIFO.GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("subs_output6_2k_x4.mem", iNTT_memA);
		  	$readmemh("subs_output7_2k_x4.mem", iNTT_memB);
		    $readmemh("subs_output8_2k_x4.mem", iNTT_memC);
		end else begin
		  	$readmemh("subs_input_2k_x2.mem", dummy_FIFO.GENERATE_HEADER[2].FIFO.ram);
		  	$readmemh("subs_input_2k_x2.mem", dummy_FIFO.GENERATE_HEADER[3].FIFO.ram);
		  	$readmemh("subs_input_2k_x2.mem", dummy_FIFO.GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("subs_output6_2k_x2.mem", iNTT_memA);
		  	$readmemh("subs_output7_2k_x2.mem", iNTT_memB);
		  	$readmemh("subs_output8_2k_x2.mem", iNTT_memC);
		end

		
		
		//test with subs factor = 6
        subs_factor = 6;
		//reset ROB empty to start the state machine
		@(negedge clk);
		ROB_empty_subs = 0;


		// wait for the first posedge rd_finish of the input fifo of subs module
		@(negedge clk);
		@(negedge clk);
		@(posedge input_FIFO.rd_finish);
        @(posedge clk);
        //test with subs factor = 7
        `SD subs_factor = 7;
        @(negedge clk);
		@(posedge input_FIFO.rd_finish);
        @(posedge clk);
        //test with subs factor = 8
        `SD subs_factor = 8;
        
		@(posedge DUT.subs_FIFO_if.full);
		@(negedge clk);
		ROB_empty_subs = 1;

		//verify output fifo content
		@(negedge clk);
		
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.subs_FIFO.GENERATE_HEADER[0].FIFO.ram[i] !== iNTT_memA[i]) begin
				$display("subs not correct at subs factor = 6, addr: %d", i);
			end
		end
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.subs_FIFO.GENERATE_HEADER[1].FIFO.ram[i] !== iNTT_memB[i]) begin
				$display("subs not correct at subs factor = 7, addr: %d", i);
			end
		end
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.subs_FIFO.GENERATE_HEADER[2].FIFO.ram[i] !== iNTT_memC[i]) begin
				$display("subs not correct at subs factor = 8, addr: %d", i);
			end
		end
		//read from the output fifo
		@(negedge clk);
		@(negedge clk);
		@(negedge clk);
		output_FIFO.rd_finish = 0;
		@(negedge clk);
		@(negedge clk);
		@(negedge clk);
		output_FIFO.rd_finish = 1;
		@(negedge clk);
		output_FIFO.rd_finish = 0;
		@(negedge clk);
		output_FIFO.rd_finish = 1;
		
		//first move dummy FIFO wr pointer, dummy FIFO content is initialized
		//by readmemh, so need to move the pointer seperately 
		@(negedge clk);
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 0;
		dummy_FIFO_ports.rlwe_id = 7;
		dummy_FIFO_ports.poly_id = `POLY_B;
		dummy_FIFO_ports.opcode = `RLWESUBS;
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 1;
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 0;
		dummy_FIFO_ports.rlwe_id = 8;
		dummy_FIFO_ports.poly_id = `POLY_A;
		dummy_FIFO_ports.opcode = `RLWESUBS;
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 1;

		if(`LINE_SIZE == 4) begin
		  	$readmemh("subs_input_2k_x4.mem", dummy_FIFO.GENERATE_HEADER[1].FIFO.ram);
		  	$readmemh("subs_input_2k_x4.mem", dummy_FIFO.GENERATE_HEADER[2].FIFO.ram);
		  	$readmemh("subs_output9_2k_x4.mem", iNTT_memA);
		  	$readmemh("subs_output10_2k_x4.mem", iNTT_memB);
		end else begin
		  	$readmemh("subs_input_2k_x2.mem", dummy_FIFO.GENERATE_HEADER[1].FIFO.ram);
		  	$readmemh("subs_input_2k_x2.mem", dummy_FIFO.GENERATE_HEADER[2].FIFO.ram);
		  	$readmemh("subs_output9_2k_x2.mem", iNTT_memA);
		  	$readmemh("subs_output10_2k_x2.mem", iNTT_memB);
		end
		
		
		//test with subs factor = 9
        `SD subs_factor = 9;
		//reset ROB empty to start the state machine
		@(negedge clk);
		ROB_empty_subs = 0;


		// wait for the first posedge rd_finish of the input fifo of subs module
		@(negedge clk);
		@(negedge clk);
		@(posedge input_FIFO.rd_finish);
        @(posedge clk);
        //test with subs factor = 10
        `SD subs_factor = 10;
        
		@(posedge DUT.subs_FIFO_if.full);
		@(negedge clk);
		ROB_empty_subs = 1;

		//verify output fifo content
		@(negedge clk);
		
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.subs_FIFO.GENERATE_HEADER[0].FIFO.ram[i] !== iNTT_memA[i]) begin
				$display("subs not correct at subs factor = 9, addr: %d", i);
			end
		end
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.subs_FIFO.GENERATE_HEADER[1].FIFO.ram[i] !== iNTT_memB[i]) begin
				$display("subs not correct at subs factor = 10, addr: %d", i);
			end
		end
		
		
		
		#1000;
		$finish;
    end
	
	
    always #5 clk = ~clk;
    
endmodule
