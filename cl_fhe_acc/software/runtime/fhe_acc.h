#ifndef FHE_ACC_H
#define FHE_ACC_H
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdarg.h>
#include <assert.h>
#include <string.h>
#include <unistd.h>
#include <math.h>
#include <time.h>
#include <fcntl.h>
#include <errno.h>
#include <malloc.h>
#include <poll.h>
#include <unistd.h>

#ifdef SV_TEST
	#include "fpga_pci_sv.h"
#else
	#include <fpga_pci.h>
	#include <fpga_mgmt.h>
	#include <fpga_dma.h>
	#include <utils/lcd.h>
#endif

#include <utils/sh_dpi_tasks.h>

/* your header file definitions */
/* SV_TEST macro should be set if SW/HW co-simulation should be enabled */

//CL related defines
#define BIT_WIDTH 54


//defines follow the CL common defines
//Config reg addr defines
#define ADDR_RLWE_Q 		UINT64_C(0x00) 	//this is a 64-bit register, takes two DW
#define ADDR_BARRETT_M 		UINT64_C(0x08) 	//this is a 64-bit register, takes two DW
#define ADDR_RLWE_ILEN		UINT64_C(0x10)	//this is a 64-bit register, takes two DW
#define ADDR_BG_MASK 		UINT64_C(0x18)	//this is a 64-bit register, takes two DW

#define ADDR_BARRETT_K2 	UINT64_C(0x20) 	//this is a 7-bit register, takes one DW
#define ADDR_RLWE_LEN		UINT64_C(0x24)	//this is a 12-bit register, takes one DW
#define ADDR_LOG2_RLWE_LEN	UINT64_C(0x28) 	//this is a 4-bit register, takes one DW
#define ADDR_DIGITG			UINT64_C(0x2C) 	//this is a 6-bit register, takes one DW
#define ADDR_BG_WIDTH 		UINT64_C(0x30)	//this is a 5-bit register, takes one DW
#define ADDR_LWE_Q_MASK		UINT64_C(0x34)	//this is a LWE_BIT_WIDTH-bit register, takes one DW
#define ADDR_EMBED_FACTOR	UINT64_C(0x38)	//this is a 4-bit register, takes one DW
#define ADDR_TOP_FIFO_MODE	UINT64_C(0x3C)	//this is a 1-bit register, takes one DW

//registers for the bootstrap bound1 of different gates, 
#define ADDR_OR_BOUND1		UINT64_C(0x40)	//this is a LWE_BIT_WIDTH-bit register, takes one DW
#define ADDR_AND_BOUND1		UINT64_C(0x44)	//this is a LWE_BIT_WIDTH-bit register, takes one DW
#define ADDR_NOR_BOUND1		UINT64_C(0x48)	//this is a LWE_BIT_WIDTH-bit register, takes one DW
#define ADDR_NAND_BOUND1	UINT64_C(0x4C)	//this is a LWE_BIT_WIDTH-bit register, takes one DW
#define ADDR_XOR_BOUND1		UINT64_C(0x50)	//this is a LWE_BIT_WIDTH-bit register, takes one DW
#define ADDR_XNOR_BOUND1	UINT64_C(0x54)	//this is a LWE_BIT_WIDTH-bit register, takes one DW

#define ADDR_INST_IN		UINT64_C(0x58)	//this is a 32-bit register, takes one DW, this is used to program the instructions to the chip, write only
#define ADDR_FIFO_STATE		UINT64_C(0x5C)	//this is a 8-bit register, takes one DW, this is used to monitor the FIFOs, read only 

//used to index the bits of the fifo state reg
#define ROB_EMPTY 				7
#define KEY_LOAD_FIFO_EMPTY 	6
#define RLWE_INPUT_FIFO_EMPTY 	5
#define RLWE_OUTPUT_FIFO_EMPTY 	4
#define ROB_FULL 				3
#define KEY_LOAD_FIFO_FULL 		2
#define RLWE_INPUT_FIFO_FULL 	1
#define RLWE_OUTPUT_FIFO_FULL 	0


//defines of opcode
#define BOOTSTRAP 		0
#define RLWESUBS 		1
#define BOOTSTRAP_INIT 	2
#define RLWE_MULT_RGSW 	3

//defines of the top fifo mode
#define BTMODE 		0
#define RLWEMODE 	1

//defines of the bootstrap gates
#define OR 		0
#define AND 	1
#define NOR 	2
#define NAND 	3
#define XOR 	4
#define XNOR 	5

//defines of the twiddle factor address through the BAR1 interface
#define ROU_BASE_ADDR 			UINT64_C(0)					//this is the base addr of the ROU table, the first addr is ignored, the avilable addr starts from ROU_BASE_ADDR+1
#define ROU_STAGE10_BASE_ADDR 	UINT64_C(8)					//this is the base addr of the ROU table of stage 10, it has 1 element
#define ROU_STAGE9_BASE_ADDR 	UINT64_C(16)				//this is the base addr of the ROU table of stage 9, it has 2 elements
#define ROU_STAGE8_BASE_ADDR 	UINT64_C(32)				//this is the base addr of the ROU table of stage 8, it has 4 element
#define ROU_STAGE7_BASE_ADDR 	UINT64_C(64)				//this is the base addr of the ROU table of stage 7, it has 8 element
#define ROU_STAGE6_BASE_ADDR 	UINT64_C(128)				//this is the base addr of the ROU table of stage 6, it has 16 element
#define ROU_STAGE5_BASE_ADDR 	UINT64_C(256)				//this is the base addr of the ROU table of stage 5, it has 32 element
#define ROU_STAGE4_BASE_ADDR 	UINT64_C(512)				//this is the base addr of the ROU table of stage 4, it has 64 element
#define ROU_STAGE3_BASE_ADDR 	UINT64_C(1024)				//this is the base addr of the ROU table of stage 3, it has 128 element
#define ROU_STAGE2_BASE_ADDR 	UINT64_C(2048)				//this is the base addr of the ROU table of stage 2, it has 256 element
#define ROU_STAGE1_BASE_ADDR 	UINT64_C(4096)				//this is the base addr of the ROU table of stage 1, it has 512 element
#define ROU_STAGE0_BASE_ADDR 	UINT64_C(8192)				//this is the base addr of the ROU table of stage 0, it has 1024 element
#define IROU_BASE_ADDR 			UINT64_C(16*1024) 			//this is the base addr of the iROU table


#define DDR_ADDR 			0
#define INPUT_FIFO_ADDR		(1ULL << 34)
#define OUTPUT_FIFO_ADDR	((1ULL << 34) + (1ULL << 15))

#ifdef SV_TEST
# define log_error(...) printf(__VA_ARGS__); printf("\n")
# define log_info(...) printf(__VA_ARGS__); printf("\n")
#endif




//global constants of config regs
uint32_t 	BG; 
uint64_t 	RLWE_Q;
uint32_t 	BARRETT_K;
uint64_t 	BARRETT_M;
uint64_t 	RLWE_ILENGTH;
uint32_t 	BG_MASK;
uint32_t 	RLWE_LENGTH;
uint32_t 	BARRETT_K2;

uint32_t  	LOG2_RLWE_LEN;

uint32_t 	DIGITG;
uint32_t  	DIGITG2;

uint32_t 	BG_WIDTH;

uint32_t 	LWE_Q;
uint32_t 	EMBED_FACTOR;
uint32_t 	TOP_FIFO_MODE;

//currently other Bases are not included here, like Bks, etc.
uint32_t gate_constant[6];


#ifndef SV_TEST
/*
 * check if the corresponding AFI is loaded
 */
int check_afi_ready(int slot_id);

//void usage(char* program_name);

int check_slot_config(int slot_id);

#endif

static inline int do_dma_read(int fd, uint8_t *buffer, size_t size,
    uint64_t address, int channel, int slot_id)
{
#if defined(SV_TEST)
    sv_fpga_start_cl_to_buffer(slot_id, channel, size, (uint64_t) buffer, address);
    return 0;
#else
    return fpga_dma_burst_read(fd, buffer, size, address);
#endif
}

static inline int do_dma_write(int fd, uint8_t *buffer, size_t size,
    uint64_t address, int channel, int slot_id)
{
#if defined(SV_TEST)
    sv_fpga_start_buffer_to_cl(slot_id, channel, size, (uint64_t) buffer, address);
    return 0;
#else
    return fpga_dma_burst_write(fd, buffer, size, address);
#endif
}


int OCL_config_wr_rd(int slot_id);
// Write and read the config registers with OCL 

int OCL_config_wr_one_addr(int slot_id, uint64_t ocl_addr, uint32_t data);
// Write one addr of the config registers with OCL, addr 32b aligned 

int OCL_config_rd_one_addr(int slot_id, uint64_t ocl_addr, uint32_t* data);
// Read one addr of the config registers with OCL, addr 32b aligned 

int BAR1_ROU_table_2k_wr(int slot_id);
// Write ROU iROu table for 2k length with BAR1

int BAR1_ROU_table_1k_wr(int slot_id);
// Write ROU iROU table for 1k length with BAR1

//static inline int do_dma_read(int fd, uint8_t *buffer, size_t size, uint64_t address, int channel, int slot_id);
//static inline int do_dma_write(int fd, uint8_t *buffer, size_t size, uint64_t address, int channel, int slot_id);

uint64_t buffer_compare(uint8_t *bufa, uint8_t *bufb, size_t buffer_size);
//to compare data in two buffers


#ifdef SV_TEST
void setup_send_rdbuf_to_c(uint8_t *read_buffer, size_t buffer_size);

int send_rdbuf_to_c(char* rd_buf);
#endif

int dma_test(int slot_id);
//test the dma function to the DDR, input fifo and output fifo


static inline uint32_t form_instruction(uint32_t opcode, uint32_t gate, uint32_t init_value, uint32_t subs_factor, uint32_t key_addr){
	uint32_t inst;
	switch(opcode){
		case BOOTSTRAP:
			inst = (opcode << 30) | key_addr;
			break;
		case RLWESUBS:
			inst = (opcode << 30) | (subs_factor << 26) | key_addr;
			break;
		case BOOTSTRAP_INIT:
			inst = (opcode << 30) | (gate << 27) | (init_value << 17) | (key_addr & ((1UL << 17) - 1));
			break;
		case RLWE_MULT_RGSW:
			inst = (opcode << 30) | key_addr;
	} 
	return(inst);
}

static inline int get_fifo_state(uint32_t ocl_fifo_state_reg, uint32_t index){
	return((uint8_t)(ocl_fifo_state_reg >> index) & 1);
}

static inline void print_fifo_states(uint32_t ocl_fifo_state_reg){
	int ROB_empty, key_load_fifo_empty, RLWE_input_FIFO_empty, RLWE_output_FIFO_empty; 
	int ROB_full, key_load_fifo_full, RLWE_input_FIFO_full, RLWE_output_FIFO_full;
	
	ROB_empty 				= (uint8_t)(ocl_fifo_state_reg >> 7) & 1;
	key_load_fifo_empty 	= (uint8_t)(ocl_fifo_state_reg >> 6) & 1;
	RLWE_input_FIFO_empty 	= (uint8_t)(ocl_fifo_state_reg >> 5) & 1;
	RLWE_output_FIFO_empty 	= (uint8_t)(ocl_fifo_state_reg >> 4) & 1;
	ROB_full 				= (uint8_t)(ocl_fifo_state_reg >> 3) & 1;
	key_load_fifo_full 		= (uint8_t)(ocl_fifo_state_reg >> 3) & 1;
	RLWE_input_FIFO_full 	= (uint8_t)(ocl_fifo_state_reg >> 1) & 1;
	RLWE_output_FIFO_full 	= (uint8_t)(ocl_fifo_state_reg >> 0) & 1;

	printf("ROB_empty = %d, key_fifo_empty = %d, input_fifo_empty = %d, output_fifo_empty = %d\n", ROB_empty, key_load_fifo_empty, RLWE_input_FIFO_empty, RLWE_output_FIFO_empty);
	printf("ROB_full = %d, key_fifo_full = %d, input_fifo_full = %d, output_fifo_full =%d\n", ROB_full, key_load_fifo_full, RLWE_input_FIFO_full, RLWE_output_FIFO_full);
	return;
}

int rlwesubs_dual_test(int slot_id);
//test the rlwesubs function with two input rlwes 

int bootstrap_init_test(int slot_id);
//test the bootstrap init function 

int rlwe_mult_rgsw_test(int slot_id);
//test the rlwe mult rgsw function

int bootstrap_test(int slot_id);
//test the bootstrap instruction 

#endif
