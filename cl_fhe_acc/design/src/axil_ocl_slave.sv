`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/24/2021 08:50:59 PM
// Design Name: 
// Module Name: axil_ocl_slave
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: this module is used to program the control/config registers,
// currently set all registers addr DW aligned, so no need to worry about the
// wstrb signal, and for the axil light no need to take care of the burst
// functionality
//
// This module also functions as the instruction dispatch module to the ROB
// and key load module. 
// The structure of the instruction is listed below, instrutctions are 32-bit 
// 
// Bootstrap_init
// The key addr space is 2 GB, 31 bit, but the increment is only 1 RLWE aligned,
// and the min size of 1 RLWE is 16k, so the lower 14 bits are masked.
// leaves 17 bits for addr
// MSB 								LSB
// |2b, opcode|3b gate|10b init value|17b key addr| 
// 
// Bootstrap
// The key addr space is 2 GB, 31 bit, but the increment is only 1 RLWE aligned,
// and the min size of 1 RLWE is 16k, so the lower 14 bits are masked.
// leaves 20 bits for addr
// MSB 								LSB
// |2b, opcode|10b unused |20b key addr| 
//
// RLWE_subs
// The key addr space is 2 GB, 31 bit, but the increment is only 1 RLWE aligned,
// and the min size of 1 RLWE is 16k, so the lower 14 bits are masked.
// leaves 17 bits for addr
// MSB 								LSB
// |2b, opcode|4b subsfactor|6b unused |20b key addr| 
// 
// RLWE mult RGSW
// The key addr space is 2 GB, 31 bit, but the increment is only 1 RLWE aligned,
// and the min size of 1 RLWE is 16k, so the lower 14 bits are masked.
// leaves 17 bits for addr
// MSB 								LSB
// |2b, opcode|10b unused |20b key addr| 
//
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "common.vh"
module axil_ocl_slave #(
)( 
    input 	clk, 
	input 	rstn,
	//axil to sh
    axi_bus_if.to_master sh_cl_ocl_bus,
	
	//ports for the ROB inst write 
	output logic [`OPCODE_WIDTH - 1 : 0] 	ROB_opcode_out,
	output logic [2 : 0]					ROB_gate_out,
	output logic 							ROB_wr_en,
	output logic [`INTT_ID_WIDTH - 1 : 0]	ROB_iNTT_id_out,
	output logic [`LWE_BIT_WIDTH - 1 : 0]	ROB_init_value_out,
	output logic [3 : 0]					ROB_subs_factor_out,
	input 									ROB_full,
	input 									ROB_empty,

	//ports for the key load module inst write
	output logic 							key_load_wr_en,
	output logic [`OPCODE_WIDTH - 1 : 0]	key_load_opcode_out,
	output logic [`KEY_ADDR_WIDTH - `KEY_ADDR_WIDTH_LSB - 1 : 0]  key_load_base_addr_out,
	input 									key_load_fifo_full,
	input 									key_load_fifo_empty,

	//ports from the global input RLWE FIFO
	input 									RLWE_input_FIFO_full,
	input 									RLWE_input_FIFO_empty,
	//ports from the global output RLWE FIFO
	input 									RLWE_output_FIFO_full,
	input 									RLWE_output_FIFO_empty,

	//configuration bus
	//config_if.to_block config_ports
	
	//seperate the config ports for easier synth/impl constraint specification
	//RLWE related ports
	output logic 	[`BIT_WIDTH - 1 : 0] 	q_out,			//RLWE modulo
	output logic 	[`BIT_WIDTH : 0] 		m_out,			//barrett reduction precompute for q
	output logic 	[6 : 0] 				k2_out, 		//barrett reduction precompute k * 2
	output logic 	[11 : 0]				length_out, 	// length of RLWE sequence
	output logic 	[`BIT_WIDTH - 1 : 0]	ilength_out, 	// multiplicative inverse of length over RLWE module
	output logic 	[3 : 0]					log2_len_out, 	//log2(length)
	output logic 	[`BIT_WIDTH - 1 : 0]	BG_mask_out,	//to mask the number for BG decompse
	output logic 	[5 : 0]					digitG_out,		//logBG(Q)_out, defines the number of decomposed polynomial
	output logic 	[4 : 0]					BG_width_out, 	// width of BG mask_out, used to shift the mask 
	//LWE related ports
	output logic 	[`LWE_BIT_WIDTH - 1 : 0]  	lwe_q_mask_out, 	// LWE modulo_out, in mask form. if q is 512_out, then lwe_q_mask = 511
	output logic 	[3 : 0]					embed_factor_out, 	// this is embed_factor used in the acc init process_out, it only support 4 or 8_out, so at most 4 bits_out, embed_factor = 2 * N / lwe_q
	//input output RLWE FIFO mode selection
	output logic 	top_fifo_mode_out,							//this is used to mux the top fifo input output interface

	//the following are the gate bound1 for the bootstrap init process_out, the
	//bound2 is calculated from them
	output logic 	[`LWE_BIT_WIDTH - 1 : 0] 	or_bound1_out,		//OR gate
	output logic 	[`LWE_BIT_WIDTH - 1 : 0] 	and_bound1_out,		//AND gate
	output logic 	[`LWE_BIT_WIDTH - 1 : 0] 	nor_bound1_out,		//NOR gate
	output logic 	[`LWE_BIT_WIDTH - 1 : 0] 	nand_bound1_out,	//NAND gate
	output logic 	[`LWE_BIT_WIDTH - 1 : 0] 	xor_bound1_out,		//XOR gate
	output logic 	[`LWE_BIT_WIDTH - 1 : 0] 	xnor_bound1_out,	//XNOR gate

	//the following are the gate bound2 for the bootstrap init process_out, the
	//bound2 is calculated from bound1 + lwe_q/2
	output logic 	[`LWE_BIT_WIDTH - 1 : 0] 	or_bound2_out,		//OR gate
	output logic 	[`LWE_BIT_WIDTH - 1 : 0] 	and_bound2_out,		//AND gate
	output logic 	[`LWE_BIT_WIDTH - 1 : 0] 	nor_bound2_out,		//NOR gate
	output logic 	[`LWE_BIT_WIDTH - 1 : 0] 	nand_bound2_out,	//NAND gate
	output logic 	[`LWE_BIT_WIDTH - 1 : 0] 	xor_bound2_out,		//XOR gate
	output logic 	[`LWE_BIT_WIDTH - 1 : 0] 	xnor_bound2_out		//XNOR gate

);


axi_bus_if sh_cl_ocl_bus_q();
axi_bus_if sh_cl_ocl_bus_q2();

//---------------------------------
// flop the input OCL bus
//---------------------------------
axi_register_slice_light AXIL_OCL_REG_SLC_1 (
	.aclk          (clk),
	.aresetn       (rstn),
	.s_axi_awaddr  (sh_cl_ocl_bus.awaddr[31:0]),
	.s_axi_awvalid (sh_cl_ocl_bus.awvalid),
	.s_axi_awready (sh_cl_ocl_bus.awready),
	.s_axi_wdata   (sh_cl_ocl_bus.wdata[31:0]),
	.s_axi_wstrb   (sh_cl_ocl_bus.wstrb[3:0]),
	.s_axi_wvalid  (sh_cl_ocl_bus.wvalid),
	.s_axi_wready  (sh_cl_ocl_bus.wready),
	.s_axi_bresp   (sh_cl_ocl_bus.bresp),
	.s_axi_bvalid  (sh_cl_ocl_bus.bvalid),
	.s_axi_bready  (sh_cl_ocl_bus.bready),
	.s_axi_araddr  (sh_cl_ocl_bus.araddr[31:0]),
	.s_axi_arvalid (sh_cl_ocl_bus.arvalid),
	.s_axi_arready (sh_cl_ocl_bus.arready),
	.s_axi_rdata   (sh_cl_ocl_bus.rdata[31:0]),
	.s_axi_rresp   (sh_cl_ocl_bus.rresp),
	.s_axi_rvalid  (sh_cl_ocl_bus.rvalid),
	.s_axi_rready  (sh_cl_ocl_bus.rready),
	
	.m_axi_awaddr  (sh_cl_ocl_bus_q.awaddr[31:0]), 
	.m_axi_awvalid (sh_cl_ocl_bus_q.awvalid),
	.m_axi_awready (sh_cl_ocl_bus_q.awready),
	.m_axi_wdata   (sh_cl_ocl_bus_q.wdata[31:0]),  
	.m_axi_wstrb   (sh_cl_ocl_bus_q.wstrb[3:0]),
	.m_axi_wvalid  (sh_cl_ocl_bus_q.wvalid), 
	.m_axi_wready  (sh_cl_ocl_bus_q.wready), 
	.m_axi_bresp   (sh_cl_ocl_bus_q.bresp),  
	.m_axi_bvalid  (sh_cl_ocl_bus_q.bvalid), 
	.m_axi_bready  (sh_cl_ocl_bus_q.bready), 
	.m_axi_araddr  (sh_cl_ocl_bus_q.araddr[31:0]), 
	.m_axi_arvalid (sh_cl_ocl_bus_q.arvalid),
	.m_axi_arready (sh_cl_ocl_bus_q.arready),
	.m_axi_rdata   (sh_cl_ocl_bus_q.rdata[31:0]),  
	.m_axi_rresp   (sh_cl_ocl_bus_q.rresp),  
	.m_axi_rvalid  (sh_cl_ocl_bus_q.rvalid), 
	.m_axi_rready  (sh_cl_ocl_bus_q.rready)
);

axi_register_slice_light AXIL_OCL_REG_SLC_2 (
	.aclk          (clk),
	.aresetn       (rstn),
	.s_axi_awaddr  (sh_cl_ocl_bus_q.awaddr[31:0]),
	.s_axi_awvalid (sh_cl_ocl_bus_q.awvalid),
	.s_axi_awready (sh_cl_ocl_bus_q.awready),
	.s_axi_wdata   (sh_cl_ocl_bus_q.wdata[31:0]),
	.s_axi_wstrb   (sh_cl_ocl_bus_q.wstrb[3:0]),
	.s_axi_wvalid  (sh_cl_ocl_bus_q.wvalid),
	.s_axi_wready  (sh_cl_ocl_bus_q.wready),
	.s_axi_bresp   (sh_cl_ocl_bus_q.bresp),
	.s_axi_bvalid  (sh_cl_ocl_bus_q.bvalid),
	.s_axi_bready  (sh_cl_ocl_bus_q.bready),
	.s_axi_araddr  (sh_cl_ocl_bus_q.araddr[31:0]),
	.s_axi_arvalid (sh_cl_ocl_bus_q.arvalid),
	.s_axi_arready (sh_cl_ocl_bus_q.arready),
	.s_axi_rdata   (sh_cl_ocl_bus_q.rdata[31:0]),
	.s_axi_rresp   (sh_cl_ocl_bus_q.rresp),
	.s_axi_rvalid  (sh_cl_ocl_bus_q.rvalid),
	.s_axi_rready  (sh_cl_ocl_bus_q.rready),
	
	.m_axi_awaddr  (sh_cl_ocl_bus_q2.awaddr[31:0]), 
	.m_axi_awvalid (sh_cl_ocl_bus_q2.awvalid),
	.m_axi_awready (sh_cl_ocl_bus_q2.awready),
	.m_axi_wdata   (sh_cl_ocl_bus_q2.wdata[31:0]),  
	.m_axi_wstrb   (sh_cl_ocl_bus_q2.wstrb[3:0]),
	.m_axi_wvalid  (sh_cl_ocl_bus_q2.wvalid), 
	.m_axi_wready  (sh_cl_ocl_bus_q2.wready), 
	.m_axi_bresp   (sh_cl_ocl_bus_q2.bresp),  
	.m_axi_bvalid  (sh_cl_ocl_bus_q2.bvalid), 
	.m_axi_bready  (sh_cl_ocl_bus_q2.bready), 
	.m_axi_araddr  (sh_cl_ocl_bus_q2.araddr[31:0]), 
	.m_axi_arvalid (sh_cl_ocl_bus_q2.arvalid),
	.m_axi_arready (sh_cl_ocl_bus_q2.arready),
	.m_axi_rdata   (sh_cl_ocl_bus_q2.rdata[31:0]),  
	.m_axi_rresp   (sh_cl_ocl_bus_q2.rresp),  
	.m_axi_rvalid  (sh_cl_ocl_bus_q2.rvalid), 
	.m_axi_rready  (sh_cl_ocl_bus_q2.rready)
);

`ifndef FPGA_LESS_RST
	//RLWE related registers 
	logic 	[63 : 0] 	q;				//RLWE modulo
	logic 	[63 : 0] 	m;				//barrett reduction precompute for q
	logic 	[6 : 0] 	k2; 			//barrett reduction precompute k * 2
	logic 	[11 : 0]	length; 		// length of RLWE sequence
	logic 	[63 : 0]	ilength; 		// multiplicative inverse of length over RLWE module
	logic 	[3 : 0]	    log2_len; 		//log2(length)
	logic 	[63 : 0]	BG_mask;		//to mask the number for BG decompse
	logic 	[5 : 0]	    digitG;			//logBG(Q), defines the number of decomposed polynomial
	logic 	[4 : 0]	    BG_width; 		// width of BG mask, used to shift the mask 
	//LWE related registers
	logic 	[`LWE_BIT_WIDTH - 1 : 0]  	lwe_q_mask; 	// LWE modulo, in mask form. if q is 512, then lwe_q_mask = 511
	logic 	[3 : 0]	    embed_factor; 	// this is embed_factor used in the acc init process, it only support 4 or 8, so at most 4 bits, embed_factor = 2 * N / lwe_q
	//input output RLWE FIFO mode selection
	logic 				top_fifo_mode;	//this is used to mux the top fifo input output interface

	//the following are the gate bound1 for the bootstrap init process, the
	//bound2 is calculated from them
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	or_bound1;		//OR gate
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	and_bound1;		//AND gate
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	nor_bound1;		//NOR gate
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	nand_bound1;	//NAND gate
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	xor_bound1;		//XOR gate
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	xnor_bound1;	//XNOR gate
	//iNTT id
	logic 	[`INTT_ID_WIDTH - 1 : 0]	iNTT_id;
`else
	//RLWE related registers 
	logic 	[63 : 0] 	q 				= 0;		//RLWE modulo
	logic 	[63 : 0] 	m 				= 0;		//barrett reduction precompute for q
	logic 	[6 : 0] 	k2 				= 0; 		//barrett reduction precompute k * 2
	logic 	[11 : 0]	length 			= 0; 		// length of RLWE sequence
	logic 	[63 : 0]	ilength 		= 0; 		// multiplicative inverse of length over RLWE module
	logic 	[3 : 0]	    log2_len 		= 0; 		//log2(length)
	logic 	[63 : 0]	BG_mask 		= 0;		//to mask the number for BG decompse
	logic 	[5 : 0]	    digitG 			= 0;		//logBG(Q), defines the number of decomposed polynomial
	logic 	[4 : 0]	    BG_width 		= 0; 		// width of BG mask, used to shift the mask 
	//LWE related registers
	logic 	[`LWE_BIT_WIDTH - 1 : 0]  	lwe_q_mask 	= 0; 	// LWE modulo, in mask form. if q is 512, then lwe_q_mask = 511
	logic 	[3 : 0]	    embed_factor 	= 0; 		// this is embed_factor used in the acc init process, it only support 4 or 8, so at most 4 bits, embed_factor = 2 * N / lwe_q
	//input output RLWE FIFO mode selection
	logic 	        	top_fifo_mode 	= 0;		//this is used to mux the top fifo input output interface
	//the following are the gate bound1 for the bootstrap init process, the
	//bound2 is calculated from them
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	or_bound1 	= 0;		//OR gate
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	and_bound1	= 0;		//AND gate
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	nor_bound1	= 0;		//NOR gate
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	nand_bound1	= 0;		//NAND gate
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	xor_bound1 	= 0;		//XOR gate
	logic 	[`LWE_BIT_WIDTH - 1 : 0] 	xnor_bound1	= 0;		//XNOR gate
	//iNTT id
	logic 	[`INTT_ID_WIDTH - 1 : 0]	iNTT_id = 0;
`endif

//the following are the gate bound2 for the bootstrap init process, the
//bound2 is calculated from bound1 + lwe_q/2
logic 	[`LWE_BIT_WIDTH - 1 : 0] 	or_bound2;		//OR gate
logic 	[`LWE_BIT_WIDTH - 1 : 0] 	and_bound2;		//AND gate
logic 	[`LWE_BIT_WIDTH - 1 : 0] 	nor_bound2;		//NOR gate
logic 	[`LWE_BIT_WIDTH - 1 : 0] 	nand_bound2;	//NAND gate
logic 	[`LWE_BIT_WIDTH - 1 : 0] 	xor_bound2;		//XOR gate
logic 	[`LWE_BIT_WIDTH - 1 : 0] 	xnor_bound2;	//XNOR gate

logic 	[63 : 0] 	q_next;				
logic 	[63 : 0] 	m_next;				
logic 	[6 : 0] 	k2_next; 			
logic 	[11 : 0]	length_next; 		
logic 	[63 : 0]	ilength_next; 	
logic 	[3 : 0]	    log2_len_next; 		
logic 	[63 : 0]	BG_mask_next;		
logic 	[5 : 0]	    digitG_next;
logic 	[4 : 0]	    BG_width_next; 		
logic 	[`LWE_BIT_WIDTH - 1 : 0]  	lwe_q_mask_next; 	
logic 	[3 : 0]	    embed_factor_next; 	
logic 	         	top_fifo_mode_next;	
//the following are the gate bound1 for the bootstrap init process, the
//bound2 is calculated from them
logic 	[`LWE_BIT_WIDTH - 1 : 0] 	or_bound1_next;		//OR gate
logic 	[`LWE_BIT_WIDTH - 1 : 0] 	and_bound1_next;	//AND gate
logic 	[`LWE_BIT_WIDTH - 1 : 0] 	nor_bound1_next;	//NOR gate
logic 	[`LWE_BIT_WIDTH - 1 : 0] 	nand_bound1_next;	//NAND gate
logic 	[`LWE_BIT_WIDTH - 1 : 0] 	xor_bound1_next;	//XOR gate
logic 	[`LWE_BIT_WIDTH - 1 : 0] 	xnor_bound1_next;	//XNOR gate
//iNTT id
logic 	[`INTT_ID_WIDTH - 1 : 0]	iNTT_id_next;

//AXIL write request
logic wr_active;
logic [7 : 0] wr_addr; 	//for now only use the lower 8 bit of the input addr, since there are not many registers 

`ifndef FPGA_LESS_RST 
	always_ff @(posedge clk) begin
		if(!rstn) begin
			q 				<= `SD 0;
			m 				<= `SD 0;
			k2 				<= `SD 0;
			length 			<= `SD 0;
			ilength 		<= `SD 0;
			log2_len 		<= `SD 0;
			BG_mask 		<= `SD 0;
			digitG 			<= `SD 0;
			BG_width 		<= `SD 0;
			lwe_q_mask 		<= `SD 0;
			embed_factor 	<= `SD 0;
			top_fifo_mode 	<= `SD 0;
			or_bound1 		<= `SD 0;	
			and_bound1		<= `SD 0;	
			nor_bound1		<= `SD 0;	
			nand_bound1		<= `SD 0;	
			xor_bound1 		<= `SD 0;	
			xnor_bound1		<= `SD 0;	
			iNTT_id 		<= `SD 0;
		end else begin
			q 				<= `SD q_next;
			m 				<= `SD m_next;
			k2 				<= `SD k2_next;
			length 			<= `SD length_next;
			ilength 		<= `SD ilength_next;
			log2_len 		<= `SD log2_len_next;
			BG_mask 		<= `SD BG_mask_next;
			digitG 			<= `SD digitG_next;
			BG_width 		<= `SD BG_width_next;
			lwe_q_mask 		<= `SD lwe_q_mask_next;
			embed_factor 	<= `SD embed_factor_next;
			top_fifo_mode 	<= `SD top_fifo_mode_next;
			or_bound1 		<= `SD or_bound1_next;	
			and_bound1		<= `SD and_bound1_next;	
			nor_bound1		<= `SD nor_bound1_next;	
			nand_bound1		<= `SD nand_bound1_next;	
			xor_bound1 		<= `SD xor_bound1_next;	
			xnor_bound1		<= `SD xnor_bound1_next;	
			iNTT_id 		<= `SD iNTT_id_next;
		end
	end
`else 
	always_ff @(posedge clk) begin
		q 				<= `SD q_next;
		m 				<= `SD m_next;
		k2 				<= `SD k2_next;
		length 			<= `SD length_next;
		ilength 		<= `SD ilength_next;
		log2_len 		<= `SD log2_len_next;
		BG_mask 		<= `SD BG_mask_next;
		digitG 			<= `SD digitG_next;
		BG_width 		<= `SD BG_width_next;
		lwe_q_mask 		<= `SD lwe_q_mask_next;
		embed_factor 	<= `SD embed_factor_next;
		top_fifo_mode 	<= `SD top_fifo_mode_next;
		or_bound1 		<= `SD or_bound1_next;	
		and_bound1		<= `SD and_bound1_next;	
		nor_bound1		<= `SD nor_bound1_next;	
		nand_bound1		<= `SD nand_bound1_next;	
		xor_bound1 		<= `SD xor_bound1_next;	
		xnor_bound1		<= `SD xnor_bound1_next;	
		iNTT_id 		<= `SD iNTT_id_next;
	end
`endif
//aw channel
always_ff @(posedge clk) begin
	if(!rstn)begin
		wr_active 	<= `SD 0;
		wr_addr 	<= `SD 0;
	end else begin
		wr_active 	<= `SD (~wr_active) && (sh_cl_ocl_bus_q2.awvalid || sh_cl_ocl_bus_q2.wvalid) ? 1'b1 :
	   					wr_active && sh_cl_ocl_bus_q2.bready && sh_cl_ocl_bus_q2.bvalid ? 1'b0 : wr_active;
		wr_addr 	<= `SD sh_cl_ocl_bus_q2.awvalid ? sh_cl_ocl_bus_q2.awaddr[7 : 0] : wr_addr;
	end
end
assign sh_cl_ocl_bus_q2.awready = wr_active && sh_cl_ocl_bus_q2.awvalid;

//w channel
assign sh_cl_ocl_bus_q2.wready  = wr_active && sh_cl_ocl_bus_q2.wvalid;

always_comb begin
	//internal registers 
	q_next 				= q; 				
	m_next 				= m; 				
	k2_next            	= k2; 				
	length_next        	= length; 			
	ilength_next       	= ilength; 		
	log2_len_next      	= log2_len; 		
	BG_mask_next       	= BG_mask; 		
	digitG_next        	= digitG; 			
	BG_width_next      	= BG_width; 		
	lwe_q_mask_next    	= lwe_q_mask;	
	embed_factor_next  	= embed_factor;
	top_fifo_mode_next 	= top_fifo_mode; 	
	or_bound1_next 		= or_bound1;
	and_bound1_next  	= and_bound1; 
	nor_bound1_next 	= nor_bound1; 
	nand_bound1_next 	= nand_bound1;	
	xor_bound1_next 	= xor_bound1; 
	xnor_bound1_next 	= xnor_bound1;	
	//output to the following blocks 
	ROB_opcode_out 			= 0;
	ROB_gate_out 			= 0;
	ROB_wr_en 				= 0;
	iNTT_id_next 			= iNTT_id;
	ROB_init_value_out 		= 0;
	ROB_subs_factor_out 	= 0;
	key_load_wr_en 			= 0;
	key_load_opcode_out 	= 0;
	key_load_base_addr_out 	= 0;

	if(sh_cl_ocl_bus_q2.wvalid) begin
		case(wr_addr)
			`ADDR_RLWE_Q: begin
				q_next[31 : 0] 	= sh_cl_ocl_bus_q2.wdata;
			end
			`ADDR_RLWE_Q + 4: begin
				q_next[63 : 32] = sh_cl_ocl_bus_q2.wdata;
			end
			`ADDR_BARRETT_M: begin
				m_next[31 : 0] 	= sh_cl_ocl_bus_q2.wdata;
			end
			`ADDR_BARRETT_M + 4: begin
				m_next[63 : 32] = sh_cl_ocl_bus_q2.wdata;
			end
			`ADDR_RLWE_ILEN: begin		
				ilength_next[31 : 0] 	= sh_cl_ocl_bus_q2.wdata;
			end
			`ADDR_RLWE_ILEN + 4: begin
				ilength_next[63 : 32] 	= sh_cl_ocl_bus_q2.wdata;
			end
			`ADDR_BG_MASK: begin
				BG_mask_next[31 : 0] 	= sh_cl_ocl_bus_q2.wdata;
			end
			`ADDR_BG_MASK + 4: begin
				BG_mask_next[63 : 32] 	= sh_cl_ocl_bus_q2.wdata;
			end
			`ADDR_BARRETT_K2: begin
				k2_next 	= sh_cl_ocl_bus_q2.wdata[6 : 0];
			end
			`ADDR_RLWE_LEN: begin
				length_next 	= sh_cl_ocl_bus_q2.wdata[11 : 0];
			end
			`ADDR_LOG2_RLWE_LEN: begin
				log2_len_next 	= sh_cl_ocl_bus_q2.wdata[3 : 0];
			end
			`ADDR_DIGITG: begin
				digitG_next 	= sh_cl_ocl_bus_q2.wdata[5 : 0];
			end
			`ADDR_BG_WIDTH: begin
				BG_width_next 	= sh_cl_ocl_bus_q2.wdata[4 : 0];
			end
			`ADDR_LWE_Q_MASK: begin
				lwe_q_mask_next 	= sh_cl_ocl_bus_q2.wdata[`LWE_BIT_WIDTH - 1 : 0];
			end
			`ADDR_EMBED_FACTOR: begin
				embed_factor_next 	= sh_cl_ocl_bus_q2.wdata[3 : 0];
			end
			`ADDR_TOP_FIFO_MODE: begin
				top_fifo_mode_next 	= sh_cl_ocl_bus_q2.wdata[0];
			end
			`ADDR_OR_BOUND1: begin
				or_bound1_next 		= sh_cl_ocl_bus_q2.wdata[`LWE_BIT_WIDTH - 1 : 0];
			end
			`ADDR_AND_BOUND1: begin
				and_bound1_next 	= sh_cl_ocl_bus_q2.wdata[`LWE_BIT_WIDTH - 1 : 0];
			end
			`ADDR_NOR_BOUND1: begin
				nor_bound1_next 	= sh_cl_ocl_bus_q2.wdata[`LWE_BIT_WIDTH - 1 : 0];
			end
			`ADDR_NAND_BOUND1: begin
				nand_bound1_next 	= sh_cl_ocl_bus_q2.wdata[`LWE_BIT_WIDTH - 1 : 0];
			end
			`ADDR_XOR_BOUND1: begin
				xor_bound1_next 	= sh_cl_ocl_bus_q2.wdata[`LWE_BIT_WIDTH - 1 : 0];
			end
			`ADDR_XNOR_BOUND1: begin
				xnor_bound1_next 	= sh_cl_ocl_bus_q2.wdata[`LWE_BIT_WIDTH - 1 : 0];
			end
			`ADDR_INST_IN: begin
				ROB_opcode_out 			= sh_cl_ocl_bus_q2.wdata[31 : 30];				//use software to check whether ROB or key load fifo is full
				ROB_gate_out 			= sh_cl_ocl_bus_q2.wdata[29 : 27];
				ROB_wr_en 				= ~(ROB_full | key_load_fifo_full);
				iNTT_id_next 			= (ROB_full || key_load_fifo_full) ? iNTT_id : iNTT_id + 1; 
				ROB_init_value_out 		= sh_cl_ocl_bus_q2.wdata[26 : 17];
				ROB_subs_factor_out 	= sh_cl_ocl_bus_q2.wdata[29 : 26];
				key_load_wr_en 			= ~(ROB_full | key_load_fifo_full);
				key_load_opcode_out 	= sh_cl_ocl_bus_q2.wdata[31 : 30];
				//if the bootstrap init, only 17 bit ddr addr, otherwise, 20 bit
				key_load_base_addr_out 	= sh_cl_ocl_bus_q2.wdata[31 : 30] == `BOOTSTRAP_INIT ? 
											{{3{1'b0}}, sh_cl_ocl_bus_q2.wdata[0 +: (`KEY_ADDR_WIDTH - `KEY_ADDR_WIDTH_LSB - 3)]}
											: sh_cl_ocl_bus_q2.wdata[0 +: `KEY_ADDR_WIDTH - `KEY_ADDR_WIDTH_LSB];
			end
		endcase
	end
end

//b channel
always_ff @(posedge clk)begin
	if(!rstn)begin
		sh_cl_ocl_bus_q2.bvalid	<= `SD 0;
		sh_cl_ocl_bus_q2.bresp 	<= `SD 0;
	end else begin
		sh_cl_ocl_bus_q2.bvalid 	<= `SD ~sh_cl_ocl_bus_q2.bvalid && sh_cl_ocl_bus_q2.wready ? 1'b1 :
									sh_cl_ocl_bus_q2.bvalid && sh_cl_ocl_bus_q2.bready ? 1'b0 : sh_cl_ocl_bus_q2.bvalid;
		sh_cl_ocl_bus_q2.bresp 	<= `SD sh_cl_ocl_bus_q2.wvalid && sh_cl_ocl_bus_q2.wready ? 
									{ROB_full | key_load_fifo_full, 1'b0} : sh_cl_ocl_bus_q2.bresp;
	end
end



//AXIL read request
logic [7 : 0] 	re_addr;
logic [31 : 0]	rdata_mux;
logic arvalid_q;	//all the AXI outputs are not allowed to be dependent 
					//combinatorially on the inputs, but must instead be registered
					//since the arready can be directly dependent on the arvalid combinatorialy,
					//arvalid has to be latched first



//ar channel
always_ff @(posedge clk)begin
	if(!rstn)begin
		arvalid_q 	<= `SD 0;
		re_addr 	<= `SD 0;
	end else begin
		arvalid_q 	<= `SD sh_cl_ocl_bus_q2.arvalid;
		re_addr 	<= `SD sh_cl_ocl_bus_q2.arvalid ? sh_cl_ocl_bus_q2.araddr[7 : 0] : re_addr;
	end
end
assign sh_cl_ocl_bus_q2.arready = arvalid_q && (~sh_cl_ocl_bus_q2.rvalid);

//rd channel
always_ff @(posedge clk)begin
	if(!rstn)begin
		sh_cl_ocl_bus_q2.rvalid 	<= `SD 0;
		sh_cl_ocl_bus_q2.rdata 	<= `SD 0;
	end else if(sh_cl_ocl_bus_q2.rvalid && sh_cl_ocl_bus_q2.rready) begin
		sh_cl_ocl_bus_q2.rvalid 	<= `SD 0;
		sh_cl_ocl_bus_q2.rdata	<= `SD 0;
	end else if(arvalid_q)begin
		sh_cl_ocl_bus_q2.rvalid 	<= `SD 1;
		sh_cl_ocl_bus_q2.rdata[31 : 0] 	<= `SD rdata_mux;
	end
end

assign sh_cl_ocl_bus_q2.rresp = 2'b00;

always_comb begin
	case(re_addr)
		`ADDR_RLWE_Q: begin
			rdata_mux 	= q[31 : 0];
		end
		`ADDR_RLWE_Q + 4: begin
			rdata_mux 	= q[63 : 32];
		end
		`ADDR_BARRETT_M: begin
			rdata_mux 	= m[31 : 0];
		end
		`ADDR_BARRETT_M + 4: begin
			rdata_mux 	= m[63 : 32];
		end
		`ADDR_RLWE_ILEN: begin		
			rdata_mux 	= ilength[31 : 0];
		end
		`ADDR_RLWE_ILEN + 4: begin
			rdata_mux 	= ilength[63 : 32];
		end
		`ADDR_BG_MASK: begin
			rdata_mux 	= BG_mask[31 : 0];
		end
		`ADDR_BG_MASK + 4: begin
			rdata_mux 	= BG_mask[63 : 32];
		end
		`ADDR_BARRETT_K2: begin
			rdata_mux 	= {{25{1'b0}}, k2};
		end
		`ADDR_RLWE_LEN: begin
			rdata_mux 	= {{20{1'b0}}, length};
		end
		`ADDR_LOG2_RLWE_LEN: begin
			rdata_mux 	= {{28{1'b0}}, log2_len};
		end
		`ADDR_DIGITG: begin
			rdata_mux 	= {{26{1'b0}}, digitG};
		end
		`ADDR_BG_WIDTH: begin
			rdata_mux 	= {{27{1'b0}}, BG_width};
		end
		`ADDR_LWE_Q_MASK: begin
			rdata_mux 	= {{(32 - `LWE_BIT_WIDTH){1'b0}}, lwe_q_mask};
		end
		`ADDR_EMBED_FACTOR: begin
			rdata_mux 	= {{28{1'b0}}, embed_factor};
		end
		`ADDR_TOP_FIFO_MODE: begin
			rdata_mux 	= {{31{1'b0}}, top_fifo_mode};
		end
		`ADDR_OR_BOUND1: begin
			rdata_mux 	= {{(32 - `LWE_BIT_WIDTH){1'b0}}, or_bound1};
		end
		`ADDR_AND_BOUND1: begin
			rdata_mux 	= {{(32 - `LWE_BIT_WIDTH){1'b0}}, and_bound1};
		end
		`ADDR_NOR_BOUND1: begin
			rdata_mux 	= {{(32 - `LWE_BIT_WIDTH){1'b0}}, nor_bound1};
		end
		`ADDR_NAND_BOUND1: begin
			rdata_mux 	= {{(32 - `LWE_BIT_WIDTH){1'b0}}, nand_bound1};
		end
		`ADDR_XOR_BOUND1: begin
			rdata_mux 	= {{(32 - `LWE_BIT_WIDTH){1'b0}}, xor_bound1};
		end
		`ADDR_XNOR_BOUND1: begin
			rdata_mux 	= {{(32 - `LWE_BIT_WIDTH){1'b0}}, xnor_bound1};
		end
		`ADDR_FIFO_STATE: begin
		   rdata_mux	= {{(32 - 8){1'b0}}, ROB_empty, key_load_fifo_empty, RLWE_input_FIFO_empty, RLWE_output_FIFO_empty, 
			   				ROB_full, key_load_fifo_full, RLWE_input_FIFO_full, RLWE_output_FIFO_full};
		end
		default: begin
			rdata_mux 	= 32'hDEAD_BEEF; 
		end
	endcase
end

logic [`LWE_BIT_WIDTH : 0] lwe_q, lwe_q2;
assign lwe_q = lwe_q_mask + 1;
assign lwe_q2 = lwe_q >> 1;

//tie the registers to the config ports 
//assign config_ports.q 				= q[`BIT_WIDTH - 1 : 0];
//assign config_ports.m 				= m[`BIT_WIDTH : 0];			
//assign config_ports.k2 				= k2; 		
//assign config_ports.length 			= length; 	
//assign config_ports.ilength 		= ilength[`BIT_WIDTH - 1 : 0]; 	
//assign config_ports.log2_len 		= log2_len; 
//assign config_ports.BG_mask 		= BG_mask[`BIT_WIDTH - 1 : 0];
//assign config_ports.digitG 			= digitG;
//assign config_ports.BG_width 		= BG_width; 
//assign config_ports.lwe_q_mask 		= lwe_q_mask;
//assign config_ports.embed_factor 	= embed_factor; 
//assign config_ports.top_fifo_mode 	= top_fifo_mode;	
//assign config_ports.or_bound1 		= or_bound1;	
//assign config_ports.and_bound1 		= and_bound1;	
//assign config_ports.nor_bound1 		= nor_bound1;	
//assign config_ports.nand_bound1		= nand_bound1;	
//assign config_ports.xor_bound1 		= xor_bound1;	
//assign config_ports.xnor_bound1 	= xnor_bound1;	
//assign config_ports.or_bound2 		= ({1'b0, or_bound1} 	+ lwe_q2) & {1'b0, lwe_q_mask};	
//assign config_ports.and_bound2 		= ({1'b0, and_bound1} 	+ lwe_q2) & {1'b0, lwe_q_mask};	
//assign config_ports.nor_bound2 		= ({1'b0, nor_bound1} 	+ lwe_q2) & {1'b0, lwe_q_mask};	
//assign config_ports.nand_bound2		= ({1'b0, nand_bound1} 	+ lwe_q2) & {1'b0, lwe_q_mask};	
//assign config_ports.xor_bound2 		= ({1'b0, xor_bound1} 	+ lwe_q2) & {1'b0, lwe_q_mask};	
//assign config_ports.xnor_bound2 	= ({1'b0, xnor_bound1} 	+ lwe_q2) & {1'b0, lwe_q_mask};	

assign q_out 				= q[`BIT_WIDTH - 1 : 0];
assign m_out 				= m[`BIT_WIDTH : 0];			
assign k2_out 				= k2; 		
assign length_out 			= length; 	
assign ilength_out  		= ilength[`BIT_WIDTH - 1 : 0]; 	
assign log2_len_out 		= log2_len; 
assign BG_mask_out 			= BG_mask[`BIT_WIDTH - 1 : 0];
assign digitG_out 			= digitG;
assign BG_width_out 		= BG_width; 
assign lwe_q_mask_out 		= lwe_q_mask;
assign embed_factor_out 	= embed_factor; 
assign top_fifo_mode_out 	= top_fifo_mode;	
assign or_bound1_out 		= or_bound1;	
assign and_bound1_out 		= and_bound1;	
assign nor_bound1_out 		= nor_bound1;	
assign nand_bound1_out		= nand_bound1;	
assign xor_bound1_out 		= xor_bound1;	
assign xnor_bound1_out 		= xnor_bound1;	
assign or_bound2_out 		= ({1'b0, or_bound1} 	+ lwe_q2) & {1'b0, lwe_q_mask};	
assign and_bound2_out 		= ({1'b0, and_bound1} 	+ lwe_q2) & {1'b0, lwe_q_mask};	
assign nor_bound2_out 		= ({1'b0, nor_bound1} 	+ lwe_q2) & {1'b0, lwe_q_mask};	
assign nand_bound2_out		= ({1'b0, nand_bound1} 	+ lwe_q2) & {1'b0, lwe_q_mask};	
assign xor_bound2_out 		= ({1'b0, xor_bound1} 	+ lwe_q2) & {1'b0, lwe_q_mask};	
assign xnor_bound2_out 		= ({1'b0, xnor_bound1} 	+ lwe_q2) & {1'b0, lwe_q_mask};	



assign ROB_iNTT_id_out = iNTT_id;
endmodule
