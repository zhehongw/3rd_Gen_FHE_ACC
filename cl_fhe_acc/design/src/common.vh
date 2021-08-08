`ifndef COMMOM_VH
`define COMMON_VH
//`define DISABLE_VJTAG_DEBUG
`define FPGA_LESS_RST							//this is to use the FPGA in place reset of the ffs, in order to reduce loading of rstn signal
`define SD 				#1
`define BIT_WIDTH 		54							//bit width of a word
`define LINE_SIZE 		2							//number of words in each buffer line, currently only support 2 and 4
`define MAX_LEN 		2048 						//the max length of NTT supported 
`define ADDR_WIDTH 		$clog2(`MAX_LEN/`LINE_SIZE)	//address bit width of buffer 
`define RLWE_ID_WIDTH 	4							//used to identify which RLWE the poly belongs to
`define POLY_ID_WIDTH 	1							//used to identify the polys in an RLWE, 0 for a, 1 for b
`define OPCODE_WIDTH 	3							//used to identify what operation is to be imposed on the poly
`define INTT_NUM 		4							//defines how many iNTT module instantiated, currently only support power of 2
`define INTT_ID_WIDTH 	$clog2(`INTT_NUM)			//used to identify which iNTT is used 
`define KEY_ADDR_WIDTH 34							//defines the bit width of the key load module addr to the DRAM
`define KEY_ADDR_WIDTH_LSB 14							//defines the bit width of the LSB of the key load module addr to the DRAM, since the DDR addr is 1 RLWE aligned (16K min), so there is no need to specify the LSBs 

//LWE related defines
`define LWE_BIT_WIDTH 	10

//define poly id
`define POLY_A 			0
`define POLY_B 			1

//definition of OPCODE
`define BOOTSTRAP 		0
`define RLWESUBS 		1
`define BOOTSTRAP_INIT 	2
`define RLWE_MULT_RGSW 	3
`define INVALIDOP 		4

//define iNTT id
`define INTT0 			0
`define INTT1 			1
`define INTT2 			2

//definition of top fifo modes
`define BTMODE 			1'b0
`define RLWEMODE 		1'b1

//the control/config register addrs in the OCL axil interface
`define ADDR_RLWE_Q 		8'h00 	//this is a 64-bit register, takes two DW
`define ADDR_BARRETT_M 		8'h08 	//this is a 64-bit register, takes two DW
`define ADDR_RLWE_ILEN		8'h10	//this is a 64-bit register, takes two DW
`define ADDR_BG_MASK 		8'h18	//this is a 64-bit register, takes two DW
`define ADDR_BARRETT_K2 	8'h20 	//this is a 7-bit register, takes one DW
`define ADDR_RLWE_LEN		8'h24	//this is a 12-bit register, takes one DW
`define ADDR_LOG2_RLWE_LEN	8'h28 	//this is a 4-bit register, takes one DW
`define ADDR_DIGITG			8'h2C 	//this is a 6-bit register, takes one DW
`define ADDR_BG_WIDTH 		8'h30	//this is a 5-bit register, takes one DW
`define ADDR_LWE_Q_MASK		8'h34	//this is a LWE_BIT_WIDTH-bit register, takes one DW
`define ADDR_EMBED_FACTOR	8'h38	//this is a 4-bit register, takes one DW
`define ADDR_TOP_FIFO_MODE	8'h3C	//this is a 1-bit register, takes one DW
//registers for the bootstrap init bound1 of different gates, 
`define ADDR_OR_BOUND1		8'h40	//this is a LWE_BIT_WIDTH-bit register, takes one DW
`define ADDR_AND_BOUND1		8'h44	//this is a LWE_BIT_WIDTH-bit register, takes one DW
`define ADDR_NOR_BOUND1		8'h48	//this is a LWE_BIT_WIDTH-bit register, takes one DW
`define ADDR_NAND_BOUND1	8'h4C	//this is a LWE_BIT_WIDTH-bit register, takes one DW
`define ADDR_XOR_BOUND1		8'h50	//this is a LWE_BIT_WIDTH-bit register, takes one DW
`define ADDR_XNOR_BOUND1	8'h54	//this is a LWE_BIT_WIDTH-bit register, takes one DW
`define ADDR_INST_IN		8'h58	//this is a 32-bit register, takes one DW, this is used to program the instructions to the chip, write only
`define ADDR_FIFO_STATE		8'h5C	//this is a 8-bit register, takes one DW, this is used to monitor the FIFOs, read only 

//defines for the bootstrap gates 
`define OR 		0
`define AND 	1
`define NOR 	2
`define NAND 	3
`define XOR 	4
`define XNOR 	5

//the twiddle factors base addr for the BAR1 axil interface
`define ROU_BASE_ADDR 0							//this is the base addr of the ROU table, the first addr is ignored, the avilable addr starts from ROU_BASE_ADDR+1
`define ROU_STAGE10_BASE_ADDR 8					//this is the base addr of the ROU table of stage 10, it has 1 element
`define ROU_STAGE9_BASE_ADDR 16					//this is the base addr of the ROU table of stage 9, it has 2 elements
`define ROU_STAGE8_BASE_ADDR 32					//this is the base addr of the ROU table of stage 8, it has 4 element
`define ROU_STAGE7_BASE_ADDR 64					//this is the base addr of the ROU table of stage 7, it has 8 element
`define ROU_STAGE6_BASE_ADDR 128				//this is the base addr of the ROU table of stage 6, it has 16 element
`define ROU_STAGE5_BASE_ADDR 256				//this is the base addr of the ROU table of stage 5, it has 32 element
`define ROU_STAGE4_BASE_ADDR 512				//this is the base addr of the ROU table of stage 4, it has 64 element
`define ROU_STAGE3_BASE_ADDR 1024				//this is the base addr of the ROU table of stage 3, it has 128 element
`define ROU_STAGE2_BASE_ADDR 2048				//this is the base addr of the ROU table of stage 2, it has 256 element
`define ROU_STAGE1_BASE_ADDR 4096				//this is the base addr of the ROU table of stage 1, it has 512 element
`define ROU_STAGE0_BASE_ADDR 8192				//this is the base addr of the ROU table of stage 0, it has 1024 element

`define IROU_BASE_ADDR 16*1024 					//this is the base addr of the iROU table

//AXI4 response 
`define OKAY  	2'b00	
`define EXOKAY	2'b01	
`define SLVERR	2'b10	
`define DECERR	2'b11	 

`endif
