`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2021 03:28:24 PM
// Design Name: 
// Module Name: fhe_acc_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: this is the top wrapper that contains all the subblocks of the
// system
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "common.vh"
module fhe_acc_top #(
    parameter STAGES = $clog2(`MAX_LEN)
)(
	input clk, rstn,
	//axil to ocl
	axi_bus_if.to_master 	sh_cl_ocl_bus,
	
	//axil to bar1
	axi_bus_if.to_master 	sh_cl_bar1_bus,
	
	//axi to dma pcis
	axi_bus_if.to_master 	sh_cl_dma_pcis_bus,

	//debug ports to ila
	axi_bus_if				sh_cl_dma_pcis_q,
	axi_bus_if 				lcl_cl_sh_ddrb_q3,
	axi_bus_if 				lcl_cl_sh_RLWE_input_FIFO_q3,
	axi_bus_if 				lcl_cl_sh_RLWE_output_FIFO_q3,
	axi_bus_if 				fhe_core_ddr_master_bus_q2,
	ROU_config_if 			rou_wr_port [0 : STAGES - 1],
	ROU_config_if 			irou_wr_port,

	//axi to ddra	
	axi_bus_if.to_slave 	lcl_cl_sh_ddrb
);

//top config signals
config_if config_signals();


(* dont_touch = "true" *) logic axil_ocl_rstn;
//reset synchronizer
pipeline #(.BIT_WIDTH(1), .STAGE_NUM(4)) AXIL_OCL_RST_N (.clk(clk), .rstn(1'b1), .pipe_in(rstn), .pipe_out(axil_ocl_rstn));

logic [`OPCODE_WIDTH - 1 : 0] 	ROB_opcode;
logic [2 : 0]					ROB_gate;
logic 							ROB_wr_en;
logic [`INTT_ID_WIDTH - 1 : 0]	ROB_iNTT_id;
logic [`LWE_BIT_WIDTH - 1 : 0]	ROB_init_value;
logic [3 : 0]					ROB_subs_factor;
logic							ROB_full;
logic							ROB_empty;

logic 													key_load_wr_en;
logic [`OPCODE_WIDTH - 1 : 0]							key_load_opcode;
logic [`KEY_ADDR_WIDTH - `KEY_ADDR_WIDTH_LSB - 1 : 0]  	key_load_base_addr;
logic 													key_load_fifo_full;
logic 													key_load_fifo_empty;

logic	RLWE_input_FIFO_full;
logic	RLWE_input_FIFO_empty;
logic	RLWE_output_FIFO_full;
logic	RLWE_output_FIFO_empty;

//to prevent the port from being optimized out by synth/impl, which helps to
//add timing constraint on the ports
(* dont_touch = "yes" *) axil_ocl_slave #() AXIL_OCL_SLV ( 
    .clk(clk), 
	.rstn(axil_ocl_rstn),
	//axil to sh
    .sh_cl_ocl_bus(sh_cl_ocl_bus),
	
	//ports for the ROB inst write 
	.ROB_opcode_out(ROB_opcode),
	.ROB_gate_out(ROB_gate),
	.ROB_wr_en(ROB_wr_en),
	.ROB_iNTT_id_out(ROB_iNTT_id),
	.ROB_init_value_out(ROB_init_value),
	.ROB_subs_factor_out(ROB_subs_factor),
	.ROB_full(ROB_full),
	.ROB_empty(ROB_empty),

	//ports for the key load module inst write
	.key_load_wr_en(key_load_wr_en),
	.key_load_opcode_out(key_load_opcode),
	.key_load_base_addr_out(key_load_base_addr),
	.key_load_fifo_full(key_load_fifo_full),
	.key_load_fifo_empty(key_load_fifo_empty),

	//ports from the global input RLWE FIFO
	.RLWE_input_FIFO_full(RLWE_input_FIFO_full),
	.RLWE_input_FIFO_empty(RLWE_input_FIFO_empty),
	//ports from the global output RLWE FIFO
	.RLWE_output_FIFO_full(RLWE_output_FIFO_full),
	.RLWE_output_FIFO_empty(RLWE_output_FIFO_empty),

	//configuration bus
	//.config_ports(config_signals)
	//seperate the config ports for easier synth/impl constraint specification
	//RLWE related ports
	.q_out(config_signals.q),			//RLWE modulo
	.m_out(config_signals.m),			//barrett reduction precompute for q
	.k2_out(config_signals.k2), 		//barrett reduction precompute k * 2
	.length_out(config_signals.length), 	// length of RLWE sequence
	.ilength_out(config_signals.ilength), 	// multiplicative inverse of length over RLWE module
	.log2_len_out(config_signals.log2_len), 	//log2(config_signals.length)
	.BG_mask_out(config_signals.BG_mask),	//to mask the number for BG decompse
	.digitG_out(config_signals.digitG),		//logBG(config_signals.Q)_out(config_signals.), defines the number of decomposed polynomial
	.BG_width_out(config_signals.BG_width), 	// width of BG mask_out(config_signals.), used to shift the mask 
	//LWE related ports
	.lwe_q_mask_out(config_signals.lwe_q_mask), 	// LWE modulo_out(config_signals.), in mask form. if q is 512_out(config_signals.), then lwe_q_mask = 511
	.embed_factor_out(config_signals.embed_factor), 	// this is embed_factor used in the acc init process_out(config_signals.), it only support 4 or 8_out(config_signals.), so at most 4 bits_out(config_signals.), embed_factor = 2 * N / lwe_q
	//input output RLWE FIFO mode selection
	.top_fifo_mode_out(config_signals.top_fifo_mode),							//this is used to mux the top fifo input output interface

	//the following are the gate bound1 for the bootstrap init process_out(config_signals.), the
	//bound2 is calculated from them
	.or_bound1_out(config_signals.or_bound1),		//OR gate
	.and_bound1_out(config_signals.and_bound1),		//AND gate
	.nor_bound1_out(config_signals.nor_bound1),		//NOR gate
	.nand_bound1_out(config_signals.nand_bound1),	//NAND gate
	.xor_bound1_out(config_signals.xor_bound1),		//XOR gate
	.xnor_bound1_out(config_signals.xnor_bound1),	//XNOR gate

	//the following are the gate bound2 for the bootstrap init process_out(config_signals.), the
	//bound2 is calculated from bound1 + lwe_q/2
	.or_bound2_out(config_signals.or_bound2),		//OR gate
	.and_bound2_out(config_signals.and_bound2),		//AND gate
	.nor_bound2_out(config_signals.nor_bound2),		//NOR gate
	.nand_bound2_out(config_signals.nand_bound2),	//NAND gate
	.xor_bound2_out(config_signals.xor_bound2),		//XOR gate
	.xnor_bound2_out(config_signals.xnor_bound2)	//XNOR gate
);


//pipeline stage for place and route 
logic [`OPCODE_WIDTH - 1 : 0] 	ROB_opcode_q;
logic [2 : 0]					ROB_gate_q;
logic 							ROB_wr_en_q;
logic [`INTT_ID_WIDTH - 1 : 0]	ROB_iNTT_id_q;
logic [`LWE_BIT_WIDTH - 1 : 0]	ROB_init_value_q;
logic [3 : 0]					ROB_subs_factor_q;

logic 													key_load_wr_en_q;
logic [`OPCODE_WIDTH - 1 : 0]							key_load_opcode_q;
logic [`KEY_ADDR_WIDTH - `KEY_ADDR_WIDTH_LSB - 1 : 0]  	key_load_base_addr_q;

pipeline #(.BIT_WIDTH(`OPCODE_WIDTH + 3 + 1 + `INTT_ID_WIDTH + `LWE_BIT_WIDTH + 4), .STAGE_NUM(4)) ROB_INPUT_PIPE (.clk(clk), .rstn(1'b1), .pipe_in({ROB_opcode, ROB_gate, ROB_wr_en, ROB_iNTT_id, ROB_init_value, ROB_subs_factor}), .pipe_out({ROB_opcode_q, ROB_gate_q, ROB_wr_en_q, ROB_iNTT_id_q, ROB_init_value_q, ROB_subs_factor_q}));


pipeline #(.BIT_WIDTH(1 + `OPCODE_WIDTH + `KEY_ADDR_WIDTH - `KEY_ADDR_WIDTH_LSB), .STAGE_NUM(4)) KEY_LOAD_INPUT_PIPE (.clk(clk), .rstn(1'b1), .pipe_in({key_load_wr_en, key_load_opcode, key_load_base_addr}), .pipe_out({key_load_wr_en_q, key_load_opcode_q, key_load_base_addr_q}));


(* dont_touch = "true" *) logic axil_bar1_rstn;
//reset synchronizer
pipeline #(.BIT_WIDTH(1), .STAGE_NUM(4)) AXIL_BAR1_RST_N (.clk(clk), .rstn(1'b1), .pipe_in(rstn), .pipe_out(axil_bar1_rstn));

//ROU_config_if rou_wr_port [0 : STAGES - 1] ();
//ROU_config_if irou_wr_port ();

axil_bar1_slave #(.STAGES(STAGES), .COL_WIDTH(`BIT_WIDTH / 2)) AXIL_BAR1_SLV (         
	.clk(clk), 
	.rstn(axil_bar1_rstn),

    .sh_cl_bar1_bus(sh_cl_bar1_bus),

    .rou_wr_port(rou_wr_port),
	.irou_wr_port(irou_wr_port)
);


(* dont_touch = "true" *) logic cl_dma_pcis_slv_rstn;
//reset synchronizer
pipeline #(.BIT_WIDTH(1), .STAGE_NUM(4)) DMA_PCIS_RST_N (.clk(clk), .rstn(1'b1), .pipe_in(rstn), .pipe_out(cl_dma_pcis_slv_rstn));

axi_bus_if fhe_core_ddr_master_bus();
axi_bus_if lcl_cl_sh_RLWE_input_FIFO();
axi_bus_if lcl_cl_sh_RLWE_output_FIFO();

//debug ports
//axi_bus_if 				lcl_cl_sh_ddrb_q3;
//axi_bus_if 				lcl_cl_sh_RLWE_input_FIFO_q3;
//axi_bus_if 				lcl_cl_sh_RLWE_output_FIFO_q3;
//axi_bus_if 				fhe_core_ddr_master_bus_q2;


cl_dma_pcis_slv CL_DMA_PCIS_SLV(
    .aclk(clk),
    .aresetn(cl_dma_pcis_slv_rstn),

    .sh_cl_dma_pcis_bus(sh_cl_dma_pcis_bus),
    .fhe_core_ddr_master_bus(fhe_core_ddr_master_bus),

    .lcl_cl_sh_ddrb(lcl_cl_sh_ddrb),
    .lcl_cl_sh_RLWE_input_FIFO(lcl_cl_sh_RLWE_input_FIFO),
    .lcl_cl_sh_RLWE_output_FIFO(lcl_cl_sh_RLWE_output_FIFO),

	.lcl_cl_sh_ddrb_q3(lcl_cl_sh_ddrb_q3),
	.lcl_cl_sh_RLWE_input_FIFO_q3(lcl_cl_sh_RLWE_input_FIFO_q3),
	.lcl_cl_sh_RLWE_output_FIFO_q3(lcl_cl_sh_RLWE_output_FIFO_q3),
	.fhe_core_ddr_master_bus_q2(fhe_core_ddr_master_bus_q2),
    .sh_cl_dma_pcis_q(sh_cl_dma_pcis_q)
);


(* dont_touch = "true" *) logic rlwe_input_fifo_rstn;
//reset synchronizer
pipeline #(.BIT_WIDTH(1), .STAGE_NUM(4)) RLWE_INPUT_RST_N (.clk(clk), .rstn(1'b1), .pipe_in(rstn), .pipe_out(rlwe_input_fifo_rstn));

myFIFO_NTT_sink_if input_fifo_to_iNTT [1 : 0] ();
myFIFO_NTT_source_if acc_to_input_fifo [1 : 0] ();
logic [1 : 0] acc_to_input_fifo_wr_enable;
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] input_fifo_to_acc_rd_doutA [1 : 0];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] input_fifo_to_acc_rd_doutB [1 : 0];

RLWE_input_FIFO #(.POINTER_WIDTH(2)) RLWE_INPUT_FIFO (
	.clk(clk),
   	.rstn(rlwe_input_fifo_rstn),

	.config_ports(config_signals),
	
	//axi port for DMA access
	.DMA_if(lcl_cl_sh_RLWE_input_FIFO),

	//read ports to iNTT module
	.iNTT_ports(input_fifo_to_iNTT),
	
	//write ports acc module
	.acc_ports(acc_to_input_fifo),

	//wr enable from acc module
	.acc_wr_enable(acc_to_input_fifo_wr_enable),

	//read out data to acc module
	.acc_rd_doutA(input_fifo_to_acc_rd_doutA),
	.acc_rd_doutB(input_fifo_to_acc_rd_doutB),

	//ports to the top ctrl
	.empty(RLWE_input_FIFO_empty), 
	.full(RLWE_input_FIFO_full)
);

(* dont_touch = "true" *) logic rlwe_output_fifo_rstn;
//reset synchronizer
pipeline #(.BIT_WIDTH(1), .STAGE_NUM(4)) RLWE_OUTPUT_RST_N (.clk(clk), .rstn(1'b1), .pipe_in(rstn), .pipe_out(rlwe_output_fifo_rstn));

myFIFO_NTT_source_if acc_to_output_fifo [1 : 0] ();
logic [1 : 0] acc_to_output_fifo_wr_enable;
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] output_fifo_to_acc_rd_doutA [1 : 0];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] output_fifo_to_acc_rd_doutB [1 : 0];

RLWE_output_FIFO #(.POINTER_WIDTH(1)) RLWE_OUTPUT_FIFO (
	.clk(clk), 
	.rstn(rlwe_output_fifo_rstn),

	.config_ports(config_signals),
	//axi port for DMA access
	.DMA_if(lcl_cl_sh_RLWE_output_FIFO),

	//write ports acc module
	.acc_ports(acc_to_output_fifo),

	//wr enable from acc module
	.acc_wr_enable(acc_to_output_fifo_wr_enable),

	//read out data to acc module
	.acc_rd_doutA(output_fifo_to_acc_rd_doutA),
	.acc_rd_doutB(output_fifo_to_acc_rd_doutB),

	//ports to the top ctrl
	.empty(RLWE_output_FIFO_empty), 
	.full(RLWE_output_FIFO_full)
);


(* dont_touch = "true" *) logic key_load_rstn;
//reset synchronizer
pipeline #(.BIT_WIDTH(1), .STAGE_NUM(4)) KEY_LOAD_RST_N (.clk(clk), .rstn(1'b1), .pipe_in(rstn), .pipe_out(key_load_rstn));


myFIFO_NTT_sink_if key_FIFO_to_poly_mult [1 : 0] ();

key_load_module #(.INST_POINTER_WIDTH(3), .POLY_POINTER_WIDTH(3)) KEY_LOAD (
	.clk(clk),
   	.rstn(key_load_rstn),

	//ports to the top control, for enqueue the addr and opcode 
	.inst_fifo_full(key_load_fifo_full),
	.inst_fifo_empty(key_load_fifo_empty),
	.wr_enable(key_load_wr_en_q), //to enqueue inst fifo
	.opcode_in(key_load_opcode_q),
	.base_addr_in(key_load_base_addr_q),	//key base addr in the CL DRAM. 
									//For RLWE key switch, this is the base
									//addr of the key switch key.
									//For bootstrap, this is the base addr of
									//a RGSW ciphertext 
									//the width is 30-bit, so only 1GB of addr
									//space

	//ports to DDR AXI, to load key from offchip
	.DDR_axi_if(fhe_core_ddr_master_bus),
		
	//ports to poly_mult_RLWE module, to read the poly FIFO
	.key_FIFO_if(key_FIFO_to_poly_mult),
	
	//config ports
	.config_ports(config_signals)
);



(* dont_touch = "true" *) logic compute_chain_top_rstn;
//reset synchronizer
pipeline #(.BIT_WIDTH(1), .STAGE_NUM(4)) COMPUTE_CHAIN_RST_N (.clk(clk), .rstn(1'b1), .pipe_in(rstn), .pipe_out(compute_chain_top_rstn));

myFIFO_NTT_source_if 					acc_RLWE_if [1 : 0] ();
logic [1 : 0] 							acc_RLWE_wr_enable;
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] acc_RLWE_doutA [1 : 0];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] acc_RLWE_doutB [1 : 0];

compute_chain_top #(.STAGES(STAGES)) COMPUTE_CHAIN (
	.clk(clk), 
	.rstn(compute_chain_top_rstn),

	//to top control
	.ROB_wr_en(ROB_wr_en_q),
	.gate_in(ROB_gate_q),
	.opcode_in(ROB_opcode_q),
	.iNTT_id_in(ROB_iNTT_id_q),
	.init_value_in(ROB_init_value_q),
	.subs_factor_in(ROB_subs_factor_q),
	.ROB_full(ROB_full),
	.ROB_empty(ROB_empty),

	//top global buffer read port
	.input_global_RLWE_buffer_if(input_fifo_to_iNTT),
//	output [`RLWE_ID_WIDTH - 1 : 0] 		rlwe_id_out_global_buffer, 
	
	//top global buffer write port, write port needs also to include read
	//functionality 
	.out_global_RLWE_buffer_if(acc_RLWE_if),
	.global_RLWE_buffer_wr_enable(acc_RLWE_wr_enable),
	.global_RLWE_buffer_doutA(acc_RLWE_doutA),
	.global_RLWE_buffer_doutB(acc_RLWE_doutB),
	
	//port to key load module
	.key_FIFO(key_FIFO_to_poly_mult),
	//axi irou write port	
	.irou_wr_port(irou_wr_port),

	//axi rou write port
	.rou_wr_port(rou_wr_port),

	//config ports
	.config_ports(config_signals)
);

//data mux for the acc port of the input FIFO, output FIFO and
//compute chain

assign acc_to_input_fifo[0].addrA 	= acc_RLWE_if[0].addrA;
assign acc_to_input_fifo[0].addrB 	= acc_RLWE_if[0].addrB;
assign acc_to_input_fifo[0].dA 		= acc_RLWE_if[0].dA;
assign acc_to_input_fifo[0].dB 		= acc_RLWE_if[0].dB;
assign acc_to_input_fifo[1].addrA 	= acc_RLWE_if[1].addrA;
assign acc_to_input_fifo[1].addrB 	= acc_RLWE_if[1].addrB;
assign acc_to_input_fifo[1].dA 		= acc_RLWE_if[1].dA;
assign acc_to_input_fifo[1].dB 		= acc_RLWE_if[1].dB;


assign acc_to_output_fifo[0].addrA 	= acc_RLWE_if[0].addrA;
assign acc_to_output_fifo[0].addrB 	= acc_RLWE_if[0].addrB;
assign acc_to_output_fifo[0].dA 	= acc_RLWE_if[0].dA;
assign acc_to_output_fifo[0].dB 	= acc_RLWE_if[0].dB;
assign acc_to_output_fifo[1].addrA 	= acc_RLWE_if[1].addrA;
assign acc_to_output_fifo[1].addrB 	= acc_RLWE_if[1].addrB;
assign acc_to_output_fifo[1].dA 	= acc_RLWE_if[1].dA;
assign acc_to_output_fifo[1].dB 	= acc_RLWE_if[1].dB;



always_comb begin
	case(config_signals.top_fifo_mode)
		`BTMODE: begin
			acc_to_input_fifo_wr_enable 	= acc_RLWE_wr_enable;
			acc_to_input_fifo[0].wr_finish 	= acc_RLWE_if[0].wr_finish;
			acc_to_input_fifo[1].wr_finish 	= acc_RLWE_if[1].wr_finish;
			
			acc_to_output_fifo_wr_enable 	= 0;
			acc_to_output_fifo[0].wr_finish	= 1;
			acc_to_output_fifo[1].wr_finish	= 1;

			acc_RLWE_if[0].full 			= acc_to_input_fifo[0].full;
			acc_RLWE_if[1].full 			= acc_to_input_fifo[1].full;
			acc_RLWE_doutA[0]				= input_fifo_to_acc_rd_doutA[0];
			acc_RLWE_doutA[1]				= input_fifo_to_acc_rd_doutA[1];
			acc_RLWE_doutB[0]				= input_fifo_to_acc_rd_doutB[0];
			acc_RLWE_doutB[1]				= input_fifo_to_acc_rd_doutB[1];
		end
		`RLWEMODE: begin
			acc_to_input_fifo_wr_enable 	= 0;
			acc_to_input_fifo[0].wr_finish 	= 1;
			acc_to_input_fifo[1].wr_finish 	= 1;

			acc_to_output_fifo_wr_enable 	= acc_RLWE_wr_enable;
			acc_to_output_fifo[0].wr_finish = acc_RLWE_if[0].wr_finish;
			acc_to_output_fifo[1].wr_finish = acc_RLWE_if[1].wr_finish;

			acc_RLWE_if[0].full 			= acc_to_output_fifo[0].full;
			acc_RLWE_if[1].full 			= acc_to_output_fifo[1].full;
			acc_RLWE_doutA[0]				= output_fifo_to_acc_rd_doutA[0];
			acc_RLWE_doutA[1]				= output_fifo_to_acc_rd_doutA[1];
			acc_RLWE_doutB[0]				= output_fifo_to_acc_rd_doutB[0];
			acc_RLWE_doutB[1]				= output_fifo_to_acc_rd_doutB[1];
		end
		default: begin
			acc_to_input_fifo_wr_enable 	= 0;
			acc_to_input_fifo[0].wr_finish 	= 1;
			acc_to_input_fifo[1].wr_finish 	= 1;

			acc_to_output_fifo_wr_enable 	= 0;
			acc_to_output_fifo[0].wr_finish = 1;
			acc_to_output_fifo[1].wr_finish = 1;

			acc_RLWE_if[0].full 			= 1;
			acc_RLWE_if[1].full 			= 1;
			acc_RLWE_doutA[0]				= 0;
			acc_RLWE_doutA[1]				= 0;
			acc_RLWE_doutB[0]				= 0;
			acc_RLWE_doutB[1]				= 0;
		end
	endcase
end	


endmodule
