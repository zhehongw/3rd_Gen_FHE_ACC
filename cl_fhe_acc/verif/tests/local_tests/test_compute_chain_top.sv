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
module test_compute_chain_top #(
	parameter STAGES = $clog2(`MAX_LEN)
)(

    );
    logic clk, rstn;

	//top controll signals 
	logic top_wr_en;
	logic [`RLWE_ID_WIDTH - 1 : 0] 	top_rlwe_id;
	logic [2 : 0]					top_gate;
	logic [`OPCODE_WIDTH - 1 : 0] 	top_opcode;
	logic [`INTT_ID_WIDTH - 1 : 0] 	top_iNTT_id;
	logic [`LWE_BIT_WIDTH - 1 : 0]	top_init_value;

	logic [3 : 0]					top_subs_factor;
	logic top_ROB_full;

	//global dummy buffer
	myFIFO_NTT_source_if dummy_FIFO_ports [1 : 0]();
	
	//from global dummy buffer
    myFIFO_NTT_sink_if top_input_FIFO [1 : 0]();
	logic [`RLWE_ID_WIDTH - 1 : 0] 	top_rlwe_id_out_global_buffer;

	//to global dummy buffer
	myFIFO_NTT_source_if top_output_FIFO [1 : 0] ();
	logic [1 : 0] top_global_RLWE_buffer_wr_enable;
		
  	//config ports
	config_if config_ports();
	//ROU config ports
	ROU_config_if rou_wr_port [0 : STAGES - 1] ();

	//iROU config ports
	ROU_config_if irou_wr_port ();

	
	logic [`LINE_SIZE - 1 : 0] dummy_wen_sel;	
	myFIFO_dummy dummy_FIFO [1 : 0](
		.clk(clk),
		.rstn(rstn),
		.word_selA(dummy_wen_sel),
		.word_selB(dummy_wen_sel),
		.source_ports(dummy_FIFO_ports),
		.sink_ports(top_input_FIFO),
		.outer_rd_enable(2'b11)
	);

	myFIFO_NTT_source_if key_load_source [1 : 0] ();
	myFIFO_NTT_sink_if key_load_sink [1 : 0] ();
	logic [`LINE_SIZE - 1 : 0] key_load_wen_sel [1 : 0];
	myFIFO_dummy #(.POINTER_WIDTH(4)) key_loading_FIFO [1 : 0](
		.clk(clk),
		.rstn(rstn),
		.word_selA(key_load_wen_sel),
		.word_selB(key_load_wen_sel),
		.source_ports(key_load_source),
		.sink_ports(key_load_sink),
		.outer_rd_enable(2'b11)
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
		.source_ports(top_output_FIFO),
		.sink_ports(global_sink_if)
	);

	compute_chain_top #(.STAGES(STAGES)) DUT (
		.clk(clk), 
		.rstn(rstn),
		//to top control
		.wr_en(top_wr_en),
		//.rlwe_id_in(top_rlwe_id),
	    .gate_in(top_gate),
		.opcode_in(top_opcode),
		.iNTT_id_in(top_iNTT_id),
		.init_value_in(top_init_value),
		//.bound1_in(top_bound1),
		//.bound2_in(top_bound2),
		.subs_factor_in(top_subs_factor),
		.ROB_full(top_ROB_full),
	
		//top global buffer read port
		.input_global_RLWE_buffer_if(top_input_FIFO),
		//.rlwe_id_out_global_buffer(top_rlwe_id_out_global_buffer), 
		
		//top global buffer write port, write port needs also to include read
		//functionality 
		.out_global_RLWE_buffer_if(top_output_FIFO),
		.global_RLWE_buffer_wr_enable(top_global_RLWE_buffer_wr_enable),
		.global_RLWE_buffer_doutA(global_doutA),
		.global_RLWE_buffer_doutB(global_doutB),
		
		//port to key load module
		.key_FIFO(key_load_sink),
		//axi irou write port	
		.irou_wr_port(irou_wr_port),
	
		//axi rou write port
		.rou_wr_port(rou_wr_port),
	
		//config ports
		.config_ports(config_ports)
	);

	//modulus operation parameters
	longint q, length, ilength;
	int k;
	logic [127 : 0] m;

	//ground truth output mem
	logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] ground_truth_memA [0 : 2 ** `ADDR_WIDTH - 1];
	logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] ground_truth_memB [0 : 2 ** `ADDR_WIDTH - 1];
    
    genvar i;
    generate 
        //irou_config ports initialize, disable with we = 0
        for(i = 0; i < STAGES; i++) begin
            assign rou_wr_port[i].we 	= 0;
		    assign rou_wr_port[i].addr 	= 0;
		    assign rou_wr_port[i].din 	= 0;
        end
    endgenerate 

   	//connect global fifo read/write controll	
	always_comb begin
		global_word_selA[0] 		= {`LINE_SIZE{top_global_RLWE_buffer_wr_enable[0]}};
		global_word_selB[0] 		= {`LINE_SIZE{top_global_RLWE_buffer_wr_enable[0]}};
		global_word_selA[1] 		= {`LINE_SIZE{top_global_RLWE_buffer_wr_enable[1]}};
		global_word_selB[1] 		= {`LINE_SIZE{top_global_RLWE_buffer_wr_enable[1]}};
		global_inner_rd_enable[0] 	= ~top_global_RLWE_buffer_wr_enable[0];
		global_inner_rd_enable[1] 	= ~top_global_RLWE_buffer_wr_enable[1];
	end

    initial begin 
		$monitor("[%t]: rstn = %h, iNTT_rd_finish = %d, ROB_empty_iNTT = %d, subs_rd_finish = %d, ROB_empty_subs = %d, NTT_rd_finish = %d, ROB_empty_NTT = %d", 
		$time, rstn, DUT.rd_finish_iNTT, DUT.ROB_empty_iNTT, DUT.rd_finish_subs, DUT.ROB_empty_subs, DUT.rd_finish_NTT, DUT.ROB_empty_NTT);
		
		//load ROU
		$readmemh("ROU_table_2k_stage0.mem", DUT.NTT.leading_stage_10.local_rou.ram);
		$readmemh("ROU_table_2k_stage1.mem", DUT.NTT.leading_stage_9.local_rou.ram);
		$readmemh("ROU_table_2k_stage2.mem", DUT.NTT.GENERATE_STAGE[8].stage.local_rou.ram);
		$readmemh("ROU_table_2k_stage3.mem", DUT.NTT.GENERATE_STAGE[7].stage.local_rou.ram);
		$readmemh("ROU_table_2k_stage4.mem", DUT.NTT.GENERATE_STAGE[6].stage.local_rou.ram);
		$readmemh("ROU_table_2k_stage5.mem", DUT.NTT.GENERATE_STAGE[5].stage.local_rou.ram);
		$readmemh("ROU_table_2k_stage6.mem", DUT.NTT.GENERATE_STAGE[4].stage.local_rou.ram);
		$readmemh("ROU_table_2k_stage7.mem", DUT.NTT.GENERATE_STAGE[3].stage.local_rou.ram);
		$readmemh("ROU_table_2k_stage8.mem", DUT.NTT.GENERATE_STAGE[2].stage.local_rou.ram);

		
        if(`LINE_SIZE == 4) begin
			//load input RLWE
		  	$readmemh("RLWESUBS_inputrlwe_2k_a0_x4.mem", dummy_FIFO[0].GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("RLWESUBS_inputrlwe_2k_b0_x4.mem", dummy_FIFO[1].GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("RLWESUBS_inputrlwe_2k_a1_x4.mem", dummy_FIFO[0].GENERATE_HEADER[1].FIFO.ram);
		  	$readmemh("RLWESUBS_inputrlwe_2k_b1_x4.mem", dummy_FIFO[1].GENERATE_HEADER[1].FIFO.ram);

			//load RLWE key switch key
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_0_a0_x4.mem", key_loading_FIFO[0].GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_0_b0_x4.mem", key_loading_FIFO[1].GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_1_a0_x4.mem", key_loading_FIFO[0].GENERATE_HEADER[1].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_1_b0_x4.mem", key_loading_FIFO[1].GENERATE_HEADER[1].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_2_a0_x4.mem", key_loading_FIFO[0].GENERATE_HEADER[2].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_2_b0_x4.mem", key_loading_FIFO[1].GENERATE_HEADER[2].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_3_a0_x4.mem", key_loading_FIFO[0].GENERATE_HEADER[3].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_3_b0_x4.mem", key_loading_FIFO[1].GENERATE_HEADER[3].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_4_a0_x4.mem", key_loading_FIFO[0].GENERATE_HEADER[4].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_4_b0_x4.mem", key_loading_FIFO[1].GENERATE_HEADER[4].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_5_a0_x4.mem", key_loading_FIFO[0].GENERATE_HEADER[5].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_5_b0_x4.mem", key_loading_FIFO[1].GENERATE_HEADER[5].FIFO.ram);
			
			$readmemh("RLWESUBS_keyinput_2k_rlwe_0_a1_x4.mem", key_loading_FIFO[0].GENERATE_HEADER[6].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_0_b1_x4.mem", key_loading_FIFO[1].GENERATE_HEADER[6].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_1_a1_x4.mem", key_loading_FIFO[0].GENERATE_HEADER[7].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_1_b1_x4.mem", key_loading_FIFO[1].GENERATE_HEADER[7].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_2_a1_x4.mem", key_loading_FIFO[0].GENERATE_HEADER[8].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_2_b1_x4.mem", key_loading_FIFO[1].GENERATE_HEADER[8].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_3_a1_x4.mem", key_loading_FIFO[0].GENERATE_HEADER[9].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_3_b1_x4.mem", key_loading_FIFO[1].GENERATE_HEADER[9].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_4_a1_x4.mem", key_loading_FIFO[0].GENERATE_HEADER[10].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_4_b1_x4.mem", key_loading_FIFO[1].GENERATE_HEADER[10].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_5_a1_x4.mem", key_loading_FIFO[0].GENERATE_HEADER[11].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_5_b1_x4.mem", key_loading_FIFO[1].GENERATE_HEADER[11].FIFO.ram);
			
			//load irou table
			$readmemh("iROU_table_2k_x4.mem", DUT.iNTT0.irou_table.ram);
			$readmemh("iROU_table_2k_x4.mem", DUT.iNTT1.irou_table.ram);

			//load rou table
		  	$readmemh("ROU_table_2k_stage9_x2.mem", DUT.NTT.GENERATE_STAGE[1].stage.local_rou.ram);
		    $readmemh("ROU_table_2k_stage10_x4.mem", DUT.NTT.GENERATE_STAGE[0].stage.local_rou.ram);
		end else begin
			//load input RLWE
		  	$readmemh("RLWESUBS_inputrlwe_2k_a0_x2.mem", dummy_FIFO[0].GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("RLWESUBS_inputrlwe_2k_b0_x2.mem", dummy_FIFO[1].GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("RLWESUBS_inputrlwe_2k_a1_x2.mem", dummy_FIFO[0].GENERATE_HEADER[1].FIFO.ram);
		  	$readmemh("RLWESUBS_inputrlwe_2k_b1_x2.mem", dummy_FIFO[1].GENERATE_HEADER[1].FIFO.ram);

			//load RLWE key switch key
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_0_a0_x2.mem", key_loading_FIFO[0].GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_0_b0_x2.mem", key_loading_FIFO[1].GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_1_a0_x2.mem", key_loading_FIFO[0].GENERATE_HEADER[1].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_1_b0_x2.mem", key_loading_FIFO[1].GENERATE_HEADER[1].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_2_a0_x2.mem", key_loading_FIFO[0].GENERATE_HEADER[2].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_2_b0_x2.mem", key_loading_FIFO[1].GENERATE_HEADER[2].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_3_a0_x2.mem", key_loading_FIFO[0].GENERATE_HEADER[3].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_3_b0_x2.mem", key_loading_FIFO[1].GENERATE_HEADER[3].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_4_a0_x2.mem", key_loading_FIFO[0].GENERATE_HEADER[4].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_4_b0_x2.mem", key_loading_FIFO[1].GENERATE_HEADER[4].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_5_a0_x2.mem", key_loading_FIFO[0].GENERATE_HEADER[5].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_5_b0_x2.mem", key_loading_FIFO[1].GENERATE_HEADER[5].FIFO.ram);
		  	
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_0_a1_x2.mem", key_loading_FIFO[0].GENERATE_HEADER[6].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_0_b1_x2.mem", key_loading_FIFO[1].GENERATE_HEADER[6].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_1_a1_x2.mem", key_loading_FIFO[0].GENERATE_HEADER[7].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_1_b1_x2.mem", key_loading_FIFO[1].GENERATE_HEADER[7].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_2_a1_x2.mem", key_loading_FIFO[0].GENERATE_HEADER[8].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_2_b1_x2.mem", key_loading_FIFO[1].GENERATE_HEADER[8].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_3_a1_x2.mem", key_loading_FIFO[0].GENERATE_HEADER[9].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_3_b1_x2.mem", key_loading_FIFO[1].GENERATE_HEADER[9].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_4_a1_x2.mem", key_loading_FIFO[0].GENERATE_HEADER[10].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_4_b1_x2.mem", key_loading_FIFO[1].GENERATE_HEADER[10].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_5_a1_x2.mem", key_loading_FIFO[0].GENERATE_HEADER[11].FIFO.ram);
		  	$readmemh("RLWESUBS_keyinput_2k_rlwe_5_b1_x2.mem", key_loading_FIFO[1].GENERATE_HEADER[11].FIFO.ram);

			//load irou table
		  	$readmemh("iROU_table_2k_x2.mem", DUT.iNTT0.irou_table.ram);
			$readmemh("iROU_table_2k_x2.mem", DUT.iNTT1.irou_table.ram);
			
			//load rou table
			$readmemh("ROU_table_2k_stage9.mem", DUT.NTT.GENERATE_STAGE[1].stage.local_rou.ram);
		    $readmemh("ROU_table_2k_stage10_x2.mem", DUT.NTT.GENERATE_STAGE[0].stage.local_rou.ram);
		end


		//initialize
        clk = 0;
        rstn = 0;
		//dummy port initialize
		dummy_wen_sel 					= 0;
		dummy_FIFO_ports[0].addrA 		= 0;
		dummy_FIFO_ports[0].addrB 		= 0;
		dummy_FIFO_ports[0].dA 			= 0;
		dummy_FIFO_ports[0].dB 			= 0;
		dummy_FIFO_ports[0].wr_finish 	= 1;
		dummy_FIFO_ports[0].rlwe_id 	= 0;
		dummy_FIFO_ports[0].poly_id 	= `POLY_A;
		dummy_FIFO_ports[0].opcode 		= `RLWESUBS;
		dummy_FIFO_ports[1].addrA 		= 0;
		dummy_FIFO_ports[1].addrB 		= 0;
		dummy_FIFO_ports[1].dA 			= 0;
		dummy_FIFO_ports[1].dB 			= 0;
		dummy_FIFO_ports[1].wr_finish 	= 1;
		dummy_FIFO_ports[1].rlwe_id 	= 0;
		dummy_FIFO_ports[1].poly_id 	= `POLY_A;
		dummy_FIFO_ports[1].opcode 		= `RLWESUBS;

		//key load fifo initialize
		key_load_wen_sel[0] 			= 0;
		key_load_source[0].addrA 		= 0;
		key_load_source[0].addrB 		= 0;
		key_load_source[0].dA 			= 0;
		key_load_source[0].dB 			= 0;
		key_load_source[0].wr_finish 	= 1;
		key_load_wen_sel[1] 			= 0;
		key_load_source[1].addrA 		= 0;
		key_load_source[1].addrB 		= 0;
		key_load_source[1].dA 			= 0;
		key_load_source[1].dB 			= 0;
		key_load_source[1].wr_finish 	= 1;

		//config_ports initialize
		q 		= 54'h3F_FFFF_FFFE_D001;
		length 	= 2048;
		ilength = 54'h3FF7FFFFFED027;
		k 		= `BIT_WIDTH;
		m 		= (1 << (k * 2)) / q;

		config_ports.q 				= q;
		config_ports.m 				= m[`BIT_WIDTH : 0];
		config_ports.k2 			= k * 2;
		config_ports.length 		= length;
		config_ports.ilength 		= ilength;
		config_ports.log2_len 		= $clog2(length);
		config_ports.BG_mask 		= (1 << 9) - 1; //BG = 512 = 1 << 9
		config_ports.digitG 		= 6;	//54/9
		config_ports.BG_width 		= 9;
		config_ports.lwe_q_mask 	= 512 - 1;
		config_ports.embed_factor 	= 2 * length / 512;

		//irou_config ports initialize, disable with we = 0
		irou_wr_port.we 	= 0;
		irou_wr_port.addr 	= 0;
		irou_wr_port.din 	= 0;

		//global fifo sink ports initialize
		global_sink_if[0].addrA 	= 0;
		global_sink_if[0].addrB 	= 0;
		global_sink_if[0].rd_finish = 1;
		global_sink_if[1].addrA 	= 0;
		global_sink_if[1].addrB 	= 0;
		global_sink_if[1].rd_finish = 1;
		global_outer_rd_enable[0] 	= 1;
		global_outer_rd_enable[1] 	= 1;

		//top control signals init
		top_wr_en 		= 0;
		top_rlwe_id 	= 0;
		top_opcode 		= `RLWESUBS;
		top_iNTT_id 	= 0;
		top_init_value 	= 0;
		top_bound1 		= 3 * (512 / 8);
		top_bound2 		= (top_bound1 + 512 / 2) % 512;
		top_subs_factor = 0;

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
		dummy_FIFO_ports[0].wr_finish 	= 0;
		dummy_FIFO_ports[0].rlwe_id 	= 3;
		dummy_FIFO_ports[0].poly_id 	= `POLY_A;
		dummy_FIFO_ports[0].opcode 		= `RLWESUBS;
		dummy_FIFO_ports[1].wr_finish 	= 0;
		dummy_FIFO_ports[1].rlwe_id 	= 3;
		dummy_FIFO_ports[1].poly_id 	= `POLY_B;
		dummy_FIFO_ports[1].opcode 		= `RLWESUBS;
		@(negedge clk);
		dummy_FIFO_ports[0].wr_finish = 1;
		dummy_FIFO_ports[1].wr_finish = 1;

		@(negedge clk);
		dummy_FIFO_ports[0].wr_finish 	= 0;
		dummy_FIFO_ports[0].rlwe_id 	= 4;
		dummy_FIFO_ports[0].poly_id 	= `POLY_A;
		dummy_FIFO_ports[0].opcode 		= `RLWESUBS;
		dummy_FIFO_ports[1].wr_finish 	= 0;
		dummy_FIFO_ports[1].rlwe_id 	= 4;
		dummy_FIFO_ports[1].poly_id 	= `POLY_B;
		dummy_FIFO_ports[1].opcode 		= `RLWESUBS;
		@(negedge clk);
		dummy_FIFO_ports[0].wr_finish = 1;
		dummy_FIFO_ports[1].wr_finish = 1;
	
		//write inst to ROB
		@(negedge clk);
		top_wr_en 		= 1;
		top_rlwe_id 	= 4;
		top_opcode 		= `RLWESUBS;
		top_iNTT_id 	= 0;
		top_init_value 	= 0;
		top_bound1 		= 0;
		top_bound2 		= 0;
		top_subs_factor = 0;

		@(negedge clk);
		top_wr_en 		= 1;
		top_rlwe_id 	= 5;
		top_opcode 		= `RLWESUBS;
		top_iNTT_id 	= 1;
		top_init_value 	= 0;
		top_bound1 		= 0;
		top_bound2 		= 0;
		top_subs_factor = 0;

		@(negedge clk);
		top_wr_en 		= 0;

        @(negedge clk);
        //move pointer of key load fifo
        for(integer i = 0; i < 12; i++) begin
            key_load_source[0].wr_finish 	= 0;
            key_load_source[1].wr_finish 	= 0;
            @(negedge clk);
            key_load_source[0].wr_finish    = 1;
            key_load_source[1].wr_finish 	= 1;
            @(negedge clk);
        end
        $display("TEST RLWESUBS 2k.");
		@(negedge clk);

		@(posedge top_output_FIFO[1].full);
		@(negedge clk);
		

		//verify output fifo content
		@(negedge clk);

		if(`LINE_SIZE == 4) begin
		  	$readmemh("RLWESUBS_outputrlwe_2k_a0_x4.mem", ground_truth_memA);
		  	$readmemh("RLWESUBS_outputrlwe_2k_b0_x4.mem", ground_truth_memB);
		end else begin
		  	$readmemh("RLWESUBS_outputrlwe_2k_a0_x2.mem", ground_truth_memA);
		  	$readmemh("RLWESUBS_outputrlwe_2k_b0_x2.mem", ground_truth_memB);
		end		

		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(global_FIFO[0].GENERATE_HEADER[0].FIFO.ram[i] !== ground_truth_memA[i]) begin
				$display("RLWESUBS 0 not correct at poly a addr: %d", i);
			end
		end
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(global_FIFO[1].GENERATE_HEADER[0].FIFO.ram[i] !== ground_truth_memB[i]) begin
				$display("RLWESUBS 0 not correct at poly b addr: %d", i);
			end
		end

		if(`LINE_SIZE == 4) begin
		  	$readmemh("RLWESUBS_outputrlwe_2k_a1_x4.mem", ground_truth_memA);
		  	$readmemh("RLWESUBS_outputrlwe_2k_b1_x4.mem", ground_truth_memB);
		end else begin
		  	$readmemh("RLWESUBS_outputrlwe_2k_a1_x2.mem", ground_truth_memA);
		  	$readmemh("RLWESUBS_outputrlwe_2k_b1_x2.mem", ground_truth_memB);
		end		

		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(global_FIFO[0].GENERATE_HEADER[1].FIFO.ram[i] !== ground_truth_memA[i]) begin
				$display("RLWESUBS 1 not correct at poly a addr: %d", i);
			end
		end
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(global_FIFO[1].GENERATE_HEADER[1].FIFO.ram[i] !== ground_truth_memB[i]) begin
				$display("RLWESUBS 1 not correct at poly b addr: %d", i);
			end
		end	

		//read from the output fifo
		@(negedge clk);
		@(negedge clk);
		@(negedge clk);
		global_sink_if[0].rd_finish = 0;
		global_sink_if[1].rd_finish = 0;
		@(negedge clk);
		@(negedge clk);
		@(negedge clk);
		global_sink_if[0].rd_finish = 1;
		global_sink_if[1].rd_finish = 1;
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
		//$readmemh("ROU_table_1k_stage0.mem", DUT.NTT.leading_stage_10.local_rou.ram);
		$readmemh("ROU_table_1k_stage0.mem", DUT.NTT.leading_stage_9.local_rou.ram);
		$readmemh("ROU_table_1k_stage1.mem", DUT.NTT.GENERATE_STAGE[8].stage.local_rou.ram);
		$readmemh("ROU_table_1k_stage2.mem", DUT.NTT.GENERATE_STAGE[7].stage.local_rou.ram);
		$readmemh("ROU_table_1k_stage3.mem", DUT.NTT.GENERATE_STAGE[6].stage.local_rou.ram);
		$readmemh("ROU_table_1k_stage4.mem", DUT.NTT.GENERATE_STAGE[5].stage.local_rou.ram);
		$readmemh("ROU_table_1k_stage5.mem", DUT.NTT.GENERATE_STAGE[4].stage.local_rou.ram);
		$readmemh("ROU_table_1k_stage6.mem", DUT.NTT.GENERATE_STAGE[3].stage.local_rou.ram);
		$readmemh("ROU_table_1k_stage7.mem", DUT.NTT.GENERATE_STAGE[2].stage.local_rou.ram);


		
        if(`LINE_SIZE == 4) begin
			//load input RLWE
		  	$readmemh("RLWExRGSW_inputrlwe_1k_a_x4.mem", dummy_FIFO[0].GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrlwe_1k_b_x4.mem", dummy_FIFO[1].GENERATE_HEADER[0].FIFO.ram);

			//load RLWE key switch key
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_0_0_a_x4.mem", key_loading_FIFO[0].GENERATE_HEADER[12].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_0_0_b_x4.mem", key_loading_FIFO[1].GENERATE_HEADER[12].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_1_0_a_x4.mem", key_loading_FIFO[0].GENERATE_HEADER[13].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_1_0_b_x4.mem", key_loading_FIFO[1].GENERATE_HEADER[13].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_2_0_a_x4.mem", key_loading_FIFO[0].GENERATE_HEADER[14].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_2_0_b_x4.mem", key_loading_FIFO[1].GENERATE_HEADER[14].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_0_1_a_x4.mem", key_loading_FIFO[0].GENERATE_HEADER[15].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_0_1_b_x4.mem", key_loading_FIFO[1].GENERATE_HEADER[15].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_1_1_a_x4.mem", key_loading_FIFO[0].GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_1_1_b_x4.mem", key_loading_FIFO[1].GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_2_1_a_x4.mem", key_loading_FIFO[0].GENERATE_HEADER[1].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_2_1_b_x4.mem", key_loading_FIFO[1].GENERATE_HEADER[1].FIFO.ram);
			
			//load irou table
			$readmemh("iROU_table_1k_x4.mem", DUT.iNTT0.irou_table.ram);
			$readmemh("iROU_table_1k_x4.mem", DUT.iNTT1.irou_table.ram);

			//load rou table
		  	$readmemh("ROU_table_1k_stage8_x2.mem", DUT.NTT.GENERATE_STAGE[1].stage.local_rou.ram);
		    $readmemh("ROU_table_1k_stage9_x4.mem", DUT.NTT.GENERATE_STAGE[0].stage.local_rou.ram);
		end else begin
			//load input RLWE
		  	$readmemh("RLWExRGSW_inputrlwe_1k_a_x2.mem", dummy_FIFO[0].GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrlwe_1k_b_x2.mem", dummy_FIFO[1].GENERATE_HEADER[0].FIFO.ram);

			//load RLWE key switch key
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_0_0_a_x2.mem", key_loading_FIFO[0].GENERATE_HEADER[12].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_0_0_b_x2.mem", key_loading_FIFO[1].GENERATE_HEADER[12].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_1_0_a_x2.mem", key_loading_FIFO[0].GENERATE_HEADER[13].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_1_0_b_x2.mem", key_loading_FIFO[1].GENERATE_HEADER[13].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_2_0_a_x2.mem", key_loading_FIFO[0].GENERATE_HEADER[14].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_2_0_b_x2.mem", key_loading_FIFO[1].GENERATE_HEADER[14].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_0_1_a_x2.mem", key_loading_FIFO[0].GENERATE_HEADER[15].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_0_1_b_x2.mem", key_loading_FIFO[1].GENERATE_HEADER[15].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_1_1_a_x2.mem", key_loading_FIFO[0].GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_1_1_b_x2.mem", key_loading_FIFO[1].GENERATE_HEADER[0].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_2_1_a_x2.mem", key_loading_FIFO[0].GENERATE_HEADER[1].FIFO.ram);
		  	$readmemh("RLWExRGSW_inputrgsw_1k_rlwe_2_1_b_x2.mem", key_loading_FIFO[1].GENERATE_HEADER[1].FIFO.ram);
		  	
			//load irou table
		  	$readmemh("iROU_table_1k_x2.mem", DUT.iNTT0.irou_table.ram);
			$readmemh("iROU_table_1k_x2.mem", DUT.iNTT1.irou_table.ram);
			
			//load rou table
			$readmemh("ROU_table_1k_stage8.mem", DUT.NTT.GENERATE_STAGE[1].stage.local_rou.ram);
		    $readmemh("ROU_table_1k_stage9_x2.mem", DUT.NTT.GENERATE_STAGE[0].stage.local_rou.ram);
		end
		
		//first move dummy FIFO wr pointer, dummy FIFO content is initialized
		//by readmemh, so need to move the pointer seperately 
		@(negedge clk);
		@(negedge clk);
		dummy_FIFO_ports[0].wr_finish 	= 0;
		dummy_FIFO_ports[0].rlwe_id 	= 3;
		dummy_FIFO_ports[0].poly_id 	= `POLY_A;
		dummy_FIFO_ports[0].opcode 		= `RLWESUBS;
		dummy_FIFO_ports[1].wr_finish 	= 0;
		dummy_FIFO_ports[1].rlwe_id 	= 3;
		dummy_FIFO_ports[1].poly_id 	= `POLY_B;
		dummy_FIFO_ports[1].opcode 		= `RLWESUBS;
		@(negedge clk);
		dummy_FIFO_ports[0].wr_finish = 1;
		dummy_FIFO_ports[1].wr_finish = 1;

		//write inst to ROB
		@(negedge clk);
		top_wr_en 		= 1;
		top_rlwe_id 	= 7;
		top_opcode 		= `BOOTSTRAP;
		top_iNTT_id 	= 0;
		top_init_value 	= 0;
		top_bound1 		= 0;
		top_bound2 		= 0;
		top_subs_factor = 0;

		@(negedge clk);
		top_wr_en 		= 0;

        @(negedge clk);
        //move pointer of key load fifo
        for(integer i = 0; i < 6; i++) begin
            key_load_source[0].wr_finish 	= 0;
            key_load_source[1].wr_finish 	= 0;
            @(negedge clk);
            key_load_source[0].wr_finish    = 1;
            key_load_source[1].wr_finish 	= 1;
            @(negedge clk);
        end
		@(negedge clk);
		
        $display("TEST RLWExRGSW 1k.");
        
		@(posedge top_output_FIFO[1].full);
		@(negedge clk);

		//verify output fifo content
		@(negedge clk);

		if(`LINE_SIZE == 4) begin
		  	$readmemh("RLWExRGSW_outputrlwe_1k_a_x4.mem", ground_truth_memA);
		  	$readmemh("RLWExRGSW_outputrlwe_1k_b_x4.mem", ground_truth_memB);
		end else begin
		  	$readmemh("RLWExRGSW_outputrlwe_1k_a_x2.mem", ground_truth_memA);
		  	$readmemh("RLWExRGSW_outputrlwe_1k_b_x2.mem", ground_truth_memB);
		end		
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(global_FIFO[0].GENERATE_HEADER[0].FIFO.ram[i] !== ground_truth_memA[i]) begin
				$display("BOOTSTRAP not correct at poly a addr: %d", i);
			end
		end
		for(integer i = 0; i < length/`LINE_SIZE; i++) begin
			if(global_FIFO[1].GENERATE_HEADER[0].FIFO.ram[i] !== ground_truth_memB[i]) begin
				$display("BOOTSTRAP not correct at poly b addr: %d", i);
			end
		end

		
		#1000;
		$finish;
    end
	
	
    always #5 clk = ~clk;
    
endmodule
