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
module test_iNTT #(
	parameter POINTER_WIDTH = 1,
	parameter FIFO_DEPTH = 2**POINTER_WIDTH
)(

    );
    logic clk, rstn;

	myFIFO_NTT_source_if dummy_FIFO_ports [1 : 0] ();
	//source ports
    myFIFO_NTT_sink_if input_FIFO [1 : 0] ();
	//sink ports
    myFIFO_NTT_sink_if output_FIFO [1 : 0] ();
	logic [1 : 0] outer_rd_enable;
  	//config ports
	config_if config_ports();
	//iROU config ports
	ROU_config_if irou_wr_port();

	logic [`LWE_BIT_WIDTH - 1 : 0] init_value;
	logic [`LWE_BIT_WIDTH - 1 : 0] bound1;
	logic [`LWE_BIT_WIDTH - 1 : 0] bound2;

	logic [`OPCODE_WIDTH - 1 : 0] opcode;
	logic ROB_empty_iNTT;
	
	logic [`LINE_SIZE - 1 : 0] dummy_wen_sel;	
	myFIFO_dummy dummy_FIFO [1 : 0] (
		.clk(clk),
		.rstn(rstn),
		.word_selA(dummy_wen_sel),
		.word_selB(dummy_wen_sel),
		.source_ports(dummy_FIFO_ports),
		.sink_ports(input_FIFO),
		.outer_rd_enable(2'b11)
	);

	iNTT_module DUT(
		.clk(clk),
		.rstn(rstn),
		.input_FIFO(input_FIFO),
		.out_to_next_stage(output_FIFO),
		.outer_rd_enable(outer_rd_enable),
		.config_ports(config_ports),
		.irou_wr_port(irou_wr_port),
		.init_value(init_value),
		.bound1(bound1),
		.bound2(bound2),
		.opcode_in(opcode),
		.ROB_empty_iNTT(ROB_empty_iNTT)
	);	
    
	//modulus operation parameters
	longint q, length, ilength;
	int k;
	logic [127 : 0] m;

	//ground truth output mem
	logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] NTT_memA [0 : 2 ** `ADDR_WIDTH - 1];
	logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] NTT_memB [0 : 2 ** `ADDR_WIDTH - 1];
    logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] init_mem [0 : 2 ** `ADDR_WIDTH - 1];
    
    initial begin 
		$monitor("[%t]: rstn = %h, dummy_fifo_empty_a = %h, dummy_fifo_empty_b = %h, output_fifo_empty_a = %h, output_fifo_empty_b = %h", $time, rstn, input_FIFO[0].empty, input_FIFO[1].empty, output_FIFO[0].empty, output_FIFO[1].empty);
        if(`LINE_SIZE == 4) begin
		  $readmemh("iROU_table_2k_x4.mem", DUT.irou_table.ram);
		  $readmemh("iNTT_input_2k_0_x4.mem", dummy_FIFO[0].GENERATE_HEADER[0].FIFO.ram);
		  $readmemh("iNTT_input_2k_1_x4.mem", dummy_FIFO[1].GENERATE_HEADER[0].FIFO.ram);
		  $readmemh("NTT_input_2k_0_x4.mem", NTT_memA);
		  $readmemh("NTT_input_2k_1_x4.mem", NTT_memB);
		  $readmemh("acc_init_1k_x4.mem", init_mem);
		end else begin
		  $readmemh("iROU_table_2k_x2.mem", DUT.irou_table.ram);
		  $readmemh("iNTT_input_2k_0_x2.mem", dummy_FIFO[0].GENERATE_HEADER[0].FIFO.ram);
		  $readmemh("iNTT_input_2k_1_x2.mem", dummy_FIFO[1].GENERATE_HEADER[0].FIFO.ram);
		  $readmemh("NTT_input_2k_0_x2.mem", NTT_memA);
		  $readmemh("NTT_input_2k_1_x2.mem", NTT_memB);
		  $readmemh("acc_init_1k_x2.mem", init_mem);
		end
		
		//initialize
        clk = 0;
        rstn = 0;
		//dummy port initialize
		dummy_wen_sel = 0;
		dummy_FIFO_ports[0].addrA = 0;
		dummy_FIFO_ports[0].addrB = 0;
		dummy_FIFO_ports[0].dA = 0;
		dummy_FIFO_ports[0].dB = 0;
		dummy_FIFO_ports[0].wr_finish = 1;
		dummy_FIFO_ports[0].rlwe_id = 0;
		dummy_FIFO_ports[0].poly_id = 0;
		dummy_FIFO_ports[0].opcode = 0;
		dummy_FIFO_ports[1].addrA = 0;
		dummy_FIFO_ports[1].addrB = 0;
		dummy_FIFO_ports[1].dA = 0;
		dummy_FIFO_ports[1].dB = 0;
		dummy_FIFO_ports[1].wr_finish = 1;
		dummy_FIFO_ports[1].rlwe_id = 0;
		dummy_FIFO_ports[1].poly_id = 0;
		dummy_FIFO_ports[1].opcode = 0;

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

		//irou_config ports initialize, disable with we = 0
		irou_wr_port.we = 0;
		irou_wr_port.addr = 0;
		irou_wr_port.din = 0;

		// ports from ROB initialize
		init_value = 0;
		bound1 = 3 * (512 / 8);
		bound2 = (bound1 + 512 / 2) % 512;
		opcode = `RLWESUBS;
		ROB_empty_iNTT = 1;

		//output fifo ports initialize
		outer_rd_enable = 1;
		output_FIFO[0].addrA = 0;
		output_FIFO[0].addrB = 0;
		output_FIFO[0].dA = 0;
		output_FIFO[0].dB = 0;
		output_FIFO[0].rd_finish = 1;
		output_FIFO[1].addrA = 0;
		output_FIFO[1].addrB = 0;
		output_FIFO[1].dA = 0;
		output_FIFO[1].dB = 0;
		output_FIFO[1].rd_finish = 1;



		//deassert rstn
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
		rstn = 1;
	
        $display("test 2k iNTT");
		//first move dummy FIFO wr pointer, dummy FIFO content is initialized
		//by readmemh, so need to move the pointer seperately 
		@(negedge clk);
		@(negedge clk);
		dummy_FIFO_ports[0].wr_finish = 0;
		dummy_FIFO_ports[1].wr_finish = 0;
		@(negedge clk);
		dummy_FIFO_ports[0].wr_finish = 1;
		dummy_FIFO_ports[1].wr_finish = 1;
		//reset ROB empty to start the state machine
		@(negedge clk);
		ROB_empty_iNTT = 0;


		// wait the output fifo of iNTT to be not empty
		@(negedge clk);
		@(negedge clk);

		@(negedge output_FIFO[1].empty);
		@(negedge clk);
		ROB_empty_iNTT = 1;

		//verify output fifo content
		@(negedge clk);
		
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.out_buffer[0].GENERATE_HEADER[0].FIFO.ram[i] !== NTT_memA[i]) begin
				$display("iNTT not correct at 2k poly a addr: %d", i);
			end
		end
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.out_buffer[1].GENERATE_HEADER[0].FIFO.ram[i] !== NTT_memB[i]) begin
				$display("iNTT not correct at 2k poly b addr: %d", i);
			end
		end
		@(negedge clk);
		
		
//		if(`LINE_SIZE == 4) begin
//		  $readmemh("RLWESUBS_subsrlwe_2k_a0_x4.mem", dummy_FIFO[0].GENERATE_HEADER[1].FIFO.ram);
//		  $readmemh("RLWESUBS_subsrlwe_2k_b0_x4.mem", dummy_FIFO[1].GENERATE_HEADER[1].FIFO.ram);
//		end else begin
//		  $readmemh("RLWESUBS_subsrlwe_2k_a0_x2.mem", dummy_FIFO[0].GENERATE_HEADER[1].FIFO.ram);
//		  $readmemh("RLWESUBS_subsrlwe_2k_b0_x2.mem", dummy_FIFO[1].GENERATE_HEADER[1].FIFO.ram);
//		end
//		//first move dummy FIFO wr pointer, dummy FIFO content is initialized
//		//by readmemh, so need to move the pointer seperately 
//		@(negedge clk);
//		@(negedge clk);
//		dummy_FIFO_ports[0].wr_finish = 0;
//		dummy_FIFO_ports[1].wr_finish = 0;
//		@(negedge clk);
//		dummy_FIFO_ports[0].wr_finish = 1;
//		dummy_FIFO_ports[1].wr_finish = 1;
//		//reset ROB empty to start the state machine
//		@(negedge clk);
//		ROB_empty_iNTT = 0;
//		// wait the output fifo of iNTT to be not empty
//		@(negedge clk);
//		@(negedge clk);

//		@(posedge DUT.out_buffer[1].source_ports.full);
//		@(negedge clk);
//		ROB_empty_iNTT = 1;

//		//verify output fifo content
//		@(negedge clk);
//		$display("poly a");
//	    for(integer i = 0; i < length/`LINE_SIZE; i++) begin
//			$display("%h", DUT.out_buffer[0].GENERATE_HEADER[1].FIFO.ram[i]);
//		end
//		$display("poly b");
//		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
//			$display("%h", DUT.out_buffer[1].GENERATE_HEADER[1].FIFO.ram[i]);
//		end
//		$finish;
		
		$display("test 1k init");
		//simulate the init module 
//		@(negedge clk);
//		dummy_FIFO_ports[0].wr_finish = 0;
//		dummy_FIFO_ports[1].wr_finish = 0;
//		@(negedge clk);
//		dummy_FIFO_ports[0].wr_finish = 1;
//		dummy_FIFO_ports[1].wr_finish = 1;
		
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
		
		// ports from ROB initialize
		init_value = 7;
		bound1 = 3 * (512 / 8);
		bound2 = (bound1 + 512 / 2) % 512;
		opcode = `BOOTSTRAP_INIT;
		ROB_empty_iNTT = 0;
		
		@(negedge clk);
		@(posedge DUT.out_buffer[1].source_ports.full);
		@(negedge clk);
		ROB_empty_iNTT = 1;
		@(negedge clk);
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.out_buffer[0].GENERATE_HEADER[1].FIFO.ram[i] !== 0) begin
				$display("init not correct at poly a addr: %d", i);
			end
		end
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.out_buffer[1].GENERATE_HEADER[1].FIFO.ram[i] !== init_mem[i]) begin
				$display("init not correct at poly b addr: %d", i);
			end
		end
		
	    $display("test 1k iNTT");
		//simulate 1k length iNTT
		//read from the output fifo and write to the dummy fifo
		@(negedge clk);
		output_FIFO[0].rd_finish = 0;
		output_FIFO[1].rd_finish = 0;
		dummy_FIFO_ports[0].wr_finish = 0;
		dummy_FIFO_ports[1].wr_finish = 0;
		@(negedge clk);
		output_FIFO[0].rd_finish = 1;
		output_FIFO[1].rd_finish = 1;
		dummy_FIFO_ports[0].wr_finish = 1;
		dummy_FIFO_ports[1].wr_finish = 1;
		
		//write to the dummy_fifo
		@(negedge clk);
		if(`LINE_SIZE == 4) begin
		  $readmemh("iROU_table_1k_x4.mem", DUT.irou_table.ram);
		  $readmemh("iNTT_input_1k_x4.mem", dummy_FIFO[0].GENERATE_HEADER[1].FIFO.ram);
		  //$readmemh("iNTT_input_1k_x4.mem", dummy_FIFO[1].GENERATE_HEADER[0].FIFO.ram);
		  $readmemh("NTT_input_1k_x4.mem", NTT_memA);
		  //$readmemh("NTT_input_1k_x4.mem", NTT_memB);
		end else begin
		  $readmemh("iROU_table_1k_x2.mem", DUT.irou_table.ram);
		  $readmemh("iNTT_input_1k_x2.mem", dummy_FIFO[0].GENERATE_HEADER[1].FIFO.ram);
		  //$readmemh("iNTT_input_1k_x2.mem", dummy_FIFO[1].GENERATE_HEADER[0].FIFO.ram);
		  $readmemh("NTT_input_1k_x2.mem", NTT_memA);
		  //$readmemh("NTT_input_1k_x2.mem", NTT_memB);
		end
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
            dummy_FIFO[1].GENERATE_HEADER[1].FIFO.ram[i] = 0;
		end
		
		@(negedge clk);
		// ports from ROB initialize
		init_value = 7;
		bound1 = 3 * (512 / 8);
		bound2 = (bound1 + 512 / 2) % 512;
		opcode = `BOOTSTRAP;
		ROB_empty_iNTT = 0;
		
		@(negedge clk);
		@(posedge DUT.out_buffer[1].source_ports.full);
		@(negedge clk);
		ROB_empty_iNTT = 1;		
		
		@(negedge clk);
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.out_buffer[0].GENERATE_HEADER[0].FIFO.ram[i] !== NTT_memA[i]) begin
				$display("iNTT not correct at 1k poly a addr: %d", i);
			end
		end
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(DUT.out_buffer[1].GENERATE_HEADER[0].FIFO.ram[i] !== 0) begin
				$display("iNTT not correct at 1k poly b addr: %d", i);
			end
		end
		
		#100;
		$finish;
    end
	
	
    always #5 clk = ~clk;
    
endmodule
