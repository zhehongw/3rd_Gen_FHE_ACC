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
module test_NTT_top #(
	parameter STAGES = $clog2(`MAX_LEN)
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
	//iROU config ports
	ROU_config_if rou_wr_port [0 : STAGES - 1] ();

	//logic [`OPCODE_WIDTH - 1 : 0] opcode;
	//logic [`RLWE_ID_WIDTH - 1 : 0] rlwe_id;
	//logic [`POLY_ID_WIDTH - 1 : 0] poly_id;
	logic ROB_empty_NTT;
	
	logic [`LINE_SIZE - 1 : 0] dummy_wen_sel;	
	myFIFO_dummy dummy_FIFO (
		.clk(clk),
		.rstn(rstn),
		.word_selA(dummy_wen_sel),
		.word_selB(dummy_wen_sel),
		.source_ports(dummy_FIFO_ports),
		.sink_ports(input_FIFO),
		.outer_rd_enable(1'b1)
	);
	
	NTT_top DUT (
		.clk(clk),
		.rstn(rstn),
		.input_FIFO(input_FIFO),
		.out_to_next_stage(output_FIFO),
		.config_ports(config_ports),
		.ROB_empty_NTT(ROB_empty_NTT),
		.rou_wr_port(rou_wr_port)
	);

	//modulus operation parameters
	longint q, length, ilength;
	int k;
	logic [127 : 0] m;

	//ground truth output mem
	logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] iNTT_memA [0 : 2 ** `ADDR_WIDTH - 1];
	logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] iNTT_memB [0 : 2 ** `ADDR_WIDTH - 1];
    
    genvar i;
    generate 
        //irou_config ports initialize, disable with we = 0
        for(i = 0; i < STAGES; i++) begin
            assign rou_wr_port[i].we = 0;
		    assign rou_wr_port[i].addr = 0;
		    assign rou_wr_port[i].din = 0;
        end
    endgenerate 
    
    initial begin 
		$monitor("[%t]: rstn = %h, ROB_empty_NTT = %h, dummy_fifo_empty = %h, output_fifo_empty = %h", $time, rstn, ROB_empty_NTT, input_FIFO.empty, output_FIFO.empty);
		
		//load ROU
		$readmemh("ROU_table_2k_stage0.mem", DUT.leading_stage_10.local_rou.ram);
		$readmemh("ROU_table_2k_stage1.mem", DUT.leading_stage_9.local_rou.ram);
		$readmemh("ROU_table_2k_stage2.mem", DUT.GENERATE_STAGE[8].stage.local_rou.ram);
		$readmemh("ROU_table_2k_stage3.mem", DUT.GENERATE_STAGE[7].stage.local_rou.ram);
		$readmemh("ROU_table_2k_stage4.mem", DUT.GENERATE_STAGE[6].stage.local_rou.ram);
		$readmemh("ROU_table_2k_stage5.mem", DUT.GENERATE_STAGE[5].stage.local_rou.ram);
		$readmemh("ROU_table_2k_stage6.mem", DUT.GENERATE_STAGE[4].stage.local_rou.ram);
		$readmemh("ROU_table_2k_stage7.mem", DUT.GENERATE_STAGE[3].stage.local_rou.ram);
		$readmemh("ROU_table_2k_stage8.mem", DUT.GENERATE_STAGE[2].stage.local_rou.ram);

		
        if(`LINE_SIZE == 4) begin
		  	$readmemh("NTT_input_2k_0_x4.mem", dummy_FIFO.GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("NTT_input_2k_1_x4.mem", dummy_FIFO.GENERATE_HEADER[1].FIFO.ram);
		  	$readmemh("iNTT_input_2k_0_x4.mem", iNTT_memA);
		  	$readmemh("iNTT_input_2k_1_x4.mem", iNTT_memB);
		  	$readmemh("ROU_table_2k_stage9_x2.mem", DUT.GENERATE_STAGE[1].stage.local_rou.ram);
		    $readmemh("ROU_table_2k_stage10_x4.mem", DUT.GENERATE_STAGE[0].stage.local_rou.ram);
		end else begin
		  	$readmemh("NTT_input_2k_0_x2.mem", dummy_FIFO.GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("NTT_input_2k_1_x2.mem", dummy_FIFO.GENERATE_HEADER[1].FIFO.ram);
		  	$readmemh("iNTT_input_2k_0_x2.mem", iNTT_memA);
		  	$readmemh("iNTT_input_2k_1_x2.mem", iNTT_memB);
		  	$readmemh("ROU_table_2k_stage9.mem", DUT.GENERATE_STAGE[1].stage.local_rou.ram);
		    $readmemh("ROU_table_2k_stage10_x2.mem", DUT.GENERATE_STAGE[0].stage.local_rou.ram);
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
		ROB_empty_NTT = 1;

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

		//reset ROB empty to start the state machine
		@(negedge clk);
		ROB_empty_NTT = 0;


		// wait the output fifo of iNTT to be not empty
		@(negedge clk);
		@(negedge clk);

		@(posedge DUT.GENERATE_STAGE[0].stage.output_FIFO.full);
		@(negedge clk);
		ROB_empty_NTT = 0;

		//verify output fifo content
		@(negedge clk);
		
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.GENERATE_STAGE[0].stage.out_buffer.GENERATE_HEADER[0].FIFO.ram[i] !== iNTT_memA[i]) begin
				$display("NTT not correct at first poly addr: %d", i);
			end
		end
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.GENERATE_STAGE[0].stage.out_buffer.GENERATE_HEADER[1].FIFO.ram[i] !== 0) begin
				$display("NTT not correct at second poly addr: %d", i);
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
		@(posedge DUT.GENERATE_STAGE[0].stage.output_FIFO.full);
		//verify output fifo content
		@(negedge clk);
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.GENERATE_STAGE[0].stage.out_buffer.GENERATE_HEADER[0].FIFO.ram[i] !== 0) begin
				$display("NTT not correct at third poly addr: %d", i);
			end
		end
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.GENERATE_STAGE[0].stage.out_buffer.GENERATE_HEADER[1].FIFO.ram[i] !== 0) begin
				$display("NTT not correct at fourth poly addr: %d", i);
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
		@(posedge DUT.GENERATE_STAGE[0].stage.output_FIFO.full);
		//verify output fifo content
		@(negedge clk);
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.GENERATE_STAGE[0].stage.out_buffer.GENERATE_HEADER[0].FIFO.ram[i] !== 0) begin
				$display("NTT not correct at fifth poly addr: %d", i);
			end
		end
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.GENERATE_STAGE[0].stage.out_buffer.GENERATE_HEADER[1].FIFO.ram[i] !== 0) begin
				$display("NTT not correct at sixth poly addr: %d", i);
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
		@(negedge output_FIFO.empty);
		@(negedge clk);
		ROB_empty_NTT = 1;
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.GENERATE_STAGE[0].stage.out_buffer.GENERATE_HEADER[0].FIFO.ram[i] !== iNTT_memB[i]) begin
				$display("NTT not correct at seventh poly addr: %d", i);
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
		@(negedge clk);
		
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
		
		//load ROU
		//$readmemh("ROU_table_2k_stage0.mem", DUT.leading_stage_10.local_rou.ram);
		$readmemh("ROU_table_1k_stage0.mem", DUT.leading_stage_9.local_rou.ram);
		$readmemh("ROU_table_1k_stage1.mem", DUT.GENERATE_STAGE[8].stage.local_rou.ram);
		$readmemh("ROU_table_1k_stage2.mem", DUT.GENERATE_STAGE[7].stage.local_rou.ram);
		$readmemh("ROU_table_1k_stage3.mem", DUT.GENERATE_STAGE[6].stage.local_rou.ram);
		$readmemh("ROU_table_1k_stage4.mem", DUT.GENERATE_STAGE[5].stage.local_rou.ram);
		$readmemh("ROU_table_1k_stage5.mem", DUT.GENERATE_STAGE[4].stage.local_rou.ram);
		$readmemh("ROU_table_1k_stage6.mem", DUT.GENERATE_STAGE[3].stage.local_rou.ram);
		$readmemh("ROU_table_1k_stage7.mem", DUT.GENERATE_STAGE[2].stage.local_rou.ram);

		
        if(`LINE_SIZE == 4) begin
		  	$readmemh("NTT_input_1k_x4.mem", dummy_FIFO.GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("NTT_input_1k_x4.mem", dummy_FIFO.GENERATE_HEADER[1].FIFO.ram);
		  	$readmemh("iNTT_input_1k_x4.mem", iNTT_memA);
		  	$readmemh("ROU_table_1k_stage8_x2.mem", DUT.GENERATE_STAGE[1].stage.local_rou.ram);
		    $readmemh("ROU_table_1k_stage9_x4.mem", DUT.GENERATE_STAGE[0].stage.local_rou.ram);
		end else begin
		  	$readmemh("NTT_input_1k_x2.mem", dummy_FIFO.GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("NTT_input_1k_x2.mem", dummy_FIFO.GENERATE_HEADER[1].FIFO.ram);
		  	$readmemh("iNTT_input_1k_x2.mem", iNTT_memA);
		  	$readmemh("ROU_table_1k_stage8.mem", DUT.GENERATE_STAGE[1].stage.local_rou.ram);
		    $readmemh("ROU_table_1k_stage9_x2.mem", DUT.GENERATE_STAGE[0].stage.local_rou.ram);
		end

		//first move dummy FIFO wr pointer, dummy FIFO content is initialized
		//by readmemh, so need to move the pointer seperately 
		@(negedge clk);
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 0;
		dummy_FIFO_ports.rlwe_id = 4;
		dummy_FIFO_ports.poly_id = `POLY_A;
		dummy_FIFO_ports.opcode = `BOOTSTRAP_INIT;
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 1;
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 0;
		dummy_FIFO_ports.rlwe_id = 4;
		dummy_FIFO_ports.poly_id = `POLY_B;
		dummy_FIFO_ports.opcode = `BOOTSTRAP;
		@(negedge clk);
		dummy_FIFO_ports.wr_finish = 1;

		//reset ROB empty to start the state machine
		@(negedge clk);
		ROB_empty_NTT = 0;

		@(negedge clk);
		@(posedge DUT.GENERATE_STAGE[0].stage.output_FIFO.full);

		//verify output fifo content
		@(negedge clk);
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.GENERATE_STAGE[0].stage.out_buffer.GENERATE_HEADER[0].FIFO.ram[i] !== 0) begin
				$display("NTT not correct at eighth poly addr: %d", i);
			end
		end
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.GENERATE_STAGE[0].stage.out_buffer.GENERATE_HEADER[1].FIFO.ram[i] !== iNTT_memA[i]) begin
				$display("NTT not correct at nineth poly addr: %d", i);
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
		@(posedge DUT.GENERATE_STAGE[0].stage.output_FIFO.full);

		//verify output fifo content
		@(negedge clk);
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.GENERATE_STAGE[0].stage.out_buffer.GENERATE_HEADER[0].FIFO.ram[i] !== iNTT_memA[i]) begin
				$display("NTT not correct at eighth poly addr: %d", i);
			end
		end
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.GENERATE_STAGE[0].stage.out_buffer.GENERATE_HEADER[1].FIFO.ram[i] !== 0) begin
				$display("NTT not correct at nineth poly addr: %d", i);
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
		@(posedge DUT.GENERATE_STAGE[0].stage.output_FIFO.full);
		@(negedge clk);
		ROB_empty_NTT = 1;
		//verify output fifo content
		@(negedge clk);
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.GENERATE_STAGE[0].stage.out_buffer.GENERATE_HEADER[0].FIFO.ram[i] !== 0) begin
				$display("NTT not correct at eighth poly addr: %d", i);
			end
		end
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.GENERATE_STAGE[0].stage.out_buffer.GENERATE_HEADER[1].FIFO.ram[i] !== 0) begin
				$display("NTT not correct at nineth poly addr: %d", i);
			end
		end	

//		//read from the output fifo
//		@(negedge clk);
//		@(negedge clk);
//		@(negedge clk);
//		output_FIFO.rd_finish = 0;
//		@(negedge clk);
//		@(negedge clk);
//		@(negedge clk);
//		output_FIFO.rd_finish = 1;
//		@(negedge clk);
//		@(negedge clk);
//		@(negedge clk);
//		output_FIFO.rd_finish = 0;
//		@(negedge clk);
//		output_FIFO.rd_finish = 1;

//		if(`LINE_SIZE == 4) begin
//		  	$readmemh("RLWExRGSW_inputrlwe_1k_a_time_domain_x4.mem", dummy_FIFO.GENERATE_HEADER[0].FIFO.ram);
//		  	$readmemh("RLWExRGSW_inputrlwe_1k_b_time_domain_x4.mem", dummy_FIFO.GENERATE_HEADER[1].FIFO.ram);
//		  	$readmemh("iNTT_input_1k_x4.mem", iNTT_memA);
//		  	$readmemh("ROU_table_1k_stage8_x2.mem", DUT.GENERATE_STAGE[1].stage.local_rou.ram);
//		    $readmemh("ROU_table_1k_stage9_x4.mem", DUT.GENERATE_STAGE[0].stage.local_rou.ram);
//		end else begin
//		  	$readmemh("RLWExRGSW_inputrlwe_1k_a_time_domain_x2.mem", dummy_FIFO.GENERATE_HEADER[0].FIFO.ram);
//		  	$readmemh("RLWExRGSW_inputrlwe_1k_b_time_domain_x2.mem", dummy_FIFO.GENERATE_HEADER[1].FIFO.ram);
//		  	$readmemh("iNTT_input_1k_x2.mem", iNTT_memA);
//		  	$readmemh("ROU_table_1k_stage8.mem", DUT.GENERATE_STAGE[1].stage.local_rou.ram);
//		    $readmemh("ROU_table_1k_stage9_x2.mem", DUT.GENERATE_STAGE[0].stage.local_rou.ram);
//		end

//		//first move dummy FIFO wr pointer, dummy FIFO content is initialized
//		//by readmemh, so need to move the pointer seperately 
//		@(negedge clk);
//		@(negedge clk);
//		dummy_FIFO_ports.wr_finish = 0;
//		dummy_FIFO_ports.rlwe_id = 5;
//		dummy_FIFO_ports.poly_id = `POLY_A;
//		dummy_FIFO_ports.opcode = `BOOTSTRAP;
//		@(negedge clk);
//		dummy_FIFO_ports.wr_finish = 1;
//		@(negedge clk);
//		dummy_FIFO_ports.wr_finish = 0;
//		dummy_FIFO_ports.rlwe_id = 5;
//		dummy_FIFO_ports.poly_id = `POLY_B;
//		dummy_FIFO_ports.opcode = `BOOTSTRAP;
//		@(negedge clk);
//		dummy_FIFO_ports.wr_finish = 1;

//		//reset ROB empty to start the state machine
//		@(negedge clk);
//		ROB_empty_NTT = 0;

//		@(negedge clk);
//		@(posedge DUT.GENERATE_STAGE[0].stage.output_FIFO.full);

//		//verify output fifo content
//		@(negedge clk);
//		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
//			if(DUT.GENERATE_STAGE[0].stage.out_buffer.GENERATE_HEADER[0].FIFO.ram[i] !== 0) begin
//				$display("NTT not correct at first decompose poly addr: %d", i);
//			end
//		end
//		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
//			if(DUT.GENERATE_STAGE[0].stage.out_buffer.GENERATE_HEADER[1].FIFO.ram[i] !== 0) begin
//				$display("NTT not correct at second decompose poly addr: %d", i);
//			end
//		end	

//		//read from the output fifo
//		@(negedge clk);
//		@(negedge clk);
//		@(negedge clk);
//		output_FIFO.rd_finish = 0;
//		@(negedge clk);
//		@(negedge clk);
//		@(negedge clk);
//		output_FIFO.rd_finish = 1;
//		@(negedge clk);
//		output_FIFO.rd_finish = 0;
//		@(negedge clk);
//		output_FIFO.rd_finish = 1;

//		@(negedge clk);
//		@(posedge DUT.GENERATE_STAGE[0].stage.output_FIFO.full);

//		//verify output fifo content
//		@(negedge clk);
//		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
//			if(DUT.GENERATE_STAGE[0].stage.out_buffer.GENERATE_HEADER[0].FIFO.ram[i] !== 0) begin
//				$display("NTT not correct at third decompose poly addr: %d", i);
//			end
//		end
//		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
//			if(DUT.GENERATE_STAGE[0].stage.out_buffer.GENERATE_HEADER[1].FIFO.ram[i] !== 0) begin
//				$display("NTT not correct at fourth decompose poly addr: %d", i);
//			end
//		end	
//		//read from the output fifo
//		@(negedge clk);
//		@(negedge clk);
//		@(negedge clk);
//		output_FIFO.rd_finish = 0;
//		@(negedge clk);
//		@(negedge clk);
//		@(negedge clk);
//		output_FIFO.rd_finish = 1;
//		@(negedge clk);
//		output_FIFO.rd_finish = 0;
//		@(negedge clk);
//		output_FIFO.rd_finish = 1;

//		@(negedge clk);
//		@(posedge DUT.GENERATE_STAGE[0].stage.output_FIFO.full);
//		@(negedge clk);
//		ROB_empty_NTT = 1;
//		//verify output fifo content
//		@(negedge clk);
//		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
//			if(DUT.GENERATE_STAGE[0].stage.out_buffer.GENERATE_HEADER[0].FIFO.ram[i] !== 0) begin
//				$display("NTT not correct at fifth decompose poly addr: %d", i);
//			end
//		end
//		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
//			if(DUT.GENERATE_STAGE[0].stage.out_buffer.GENERATE_HEADER[1].FIFO.ram[i] !== 0) begin
//				$display("NTT not correct at sixth decompose poly addr: %d", i);
//			end
//		end	

		#1000;
		$finish;
    end
	
	
    always #5 clk = ~clk;
    
endmodule
