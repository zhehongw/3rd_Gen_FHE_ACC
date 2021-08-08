#ifndef FHE_ACC_H
#define FHE_ACC_H
#include "params.h"
#include "RLWE.h"
#include "LWE.h"
#include "app.h"

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

#include <vector>
#include <chrono>
#include <memory>
#include <iomanip> 
#include <iostream>
#include <cstdlib>
#include <bitset>
#include <set>
#include <string>



#include <fpga_pci.h>
#include <fpga_mgmt.h>
#include <fpga_dma.h>
#include <utils/lcd.h>

#include <utils/sh_dpi_tasks.h>

/* your header file definitions */
/* SV_TEST macro should be set if SW/HW co-simulation should be enabled */

//CL related defines
//#define BIT_WIDTH 54


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
//#define OR 		0
//#define AND 	1
//#define NOR 	2
//#define NAND 	3
//#define XOR 	4
//#define XNOR 	5

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
#define RGSW_ENC_SK_ADDR	(1ULL << 32)	//a reserved place for the RGSW encrypted secrete key for homo expansion, may change accordingly


namespace FPGA{
	
	int check_slot_config(int slot_id);
	
	static inline int do_dma_read(int fd, uint8_t *buffer, size_t size, uint64_t address, int channel, int slot_id){
	    return fpga_dma_burst_read(fd, buffer, size, address);
	}
	
	static inline int do_dma_write(int fd, uint8_t *buffer, size_t size, uint64_t address, int channel, int slot_id){
	    return fpga_dma_burst_write(fd, buffer, size, address);
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
	
	uint64_t buffer_compare(uint8_t *bufa, uint8_t *bufb, size_t buffer_size);
	//to compare data in two buffers
	
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
		return((uint8_t)((ocl_fifo_state_reg & 255) >> index) & 1);
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
		printf("ROB_full = %d, key_fifo_full = %d, input_fifo_full = %d, output_fifo_full = %d\n", ROB_full, key_load_fifo_full, RLWE_input_FIFO_full, RLWE_output_FIFO_full);
		return;
	}



	static inline void convert_RLWE_to_buffer(const RLWE::RLWE_ciphertext &c_in, uint64_t *out_buffer){
	// this function copy the two polys in the RLWE ciphertext into the 
	// interleaved format buffer that is used on the FPGA, 
	// c_in: the input RLWE to be transfered 
	// out_buffer: an aligned pointer to an array of length 2*N, since it holds the two poly
		if(!c_in.NTT_form){
			std::cout << "convert_RLWE_to_buffer input RLWE needs to be in NTT form!!!" << std::endl;
			return;
		}
		uint64_t *a = (uint64_t*)c_in.a.data();
		uint64_t *b = (uint64_t*)c_in.b.data();
		for(int i = 0; i < (N << 1); i += 8){
			*(out_buffer + i + 0)	= *(a + i / 2 + 0);
			*(out_buffer + i + 1) 	= *(a + i / 2 + 1);
			*(out_buffer + i + 2) 	= *(a + i / 2 + 2);
			*(out_buffer + i + 3) 	= *(a + i / 2 + 3);
			*(out_buffer + i + 4) 	= *(b + i / 2 + 0);
			*(out_buffer + i + 5) 	= *(b + i / 2 + 1);
			*(out_buffer + i + 6) 	= *(b + i / 2 + 2);
			*(out_buffer + i + 7) 	= *(b + i / 2 + 3);
		}
		return;
	}

	static inline RLWE::RLWE_ciphertext convert_buffer_to_RLWE(uint64_t *in_buffer){
	// this function copy interleaved format buffer that is used on the FPGA into a RLWE ciphertext 
	// in_buffer: an aligned pointer to an array of length 2*N, since it holds the two poly
	// return a RLWE ciphertext in NTT form
		RLWE::RLWE_ciphertext c_out;	
		uint64_t *a = (uint64_t*)c_out.a.data();
		uint64_t *b = (uint64_t*)c_out.b.data();
		for(int i = 0; i < (N << 1); i += 8){
			*(a + i / 2 + 0)	= *(in_buffer + i + 0);
			*(a + i / 2 + 1)   	= *(in_buffer + i + 1);	
			*(a + i / 2 + 2)   	= *(in_buffer + i + 2);	
			*(a + i / 2 + 3)   	= *(in_buffer + i + 3);	
			*(b + i / 2 + 0)   	= *(in_buffer + i + 4);	
			*(b + i / 2 + 1)   	= *(in_buffer + i + 5);	
			*(b + i / 2 + 2)   	= *(in_buffer + i + 6);	
			*(b + i / 2 + 3)   	= *(in_buffer + i + 7);	
		}
		c_out.NTT_form = true;
		return(c_out);
	}

	static inline RLWE::RLWE_ciphertext dma_read_RLWE(const int fd, int *rc, uint64_t *in_buffer, const uint64_t addr){
		// this fucntion read one RLWE from DMA
		// fd: fd for the DMA
		// rc: return value in case dma read fails
		// in_buffer: a read buffer for the DMA
		// addr: addr to be read
		// return RLWE ciphertext being read
		*rc = fpga_dma_burst_read(fd, (uint8_t *)in_buffer, (size_t)(N * 2 * 8), addr);
		return convert_buffer_to_RLWE(in_buffer);
	}

	static inline int dma_write_RLWE(const int fd, const RLWE::RLWE_ciphertext &c_in, uint64_t *out_buffer, const uint64_t addr){
		// this fucntion writes one RLWE to DMA
		// fd: fd for the DMA
		// c_in: input RLWE
		// out_buffer: a write buffer for the DMA
		// addr: addr to be written
		// return success or not
		convert_RLWE_to_buffer(c_in, out_buffer);
		return fpga_dma_burst_write(fd, (uint8_t *)out_buffer, (size_t)(N * 2 * 8), addr);
	}
	

	int dma_write_bootstrap_key(const int slot_id, const RLWE::bootstrap_key &bt_key);
	// this function transfer the bootstrap key to the FPGA DDR with dma

	int dma_write_subs_key(const int slot_id, const application::substitute_key &subs_key);
	// this function transfer the rlwesubs key to the FPGA DDR with dma

	int dma_write_RGSW_enc_sk(const int slot_id, const RLWE::RGSW_ciphertext &enc_sec);
	// this function transfer the RGSW encrypted secret key to the FPGA DDR with dma for the homo expansion operation 

	int dma_read_compare_bootstrap_key(const int slot_id, const RLWE::bootstrap_key &bt_key);
	// this function read the bootstrap key from the FPGA DDR with dma and compare with ground truth

	int dma_read_compare_subs_key(const int slot_id, const application::substitute_key &subs_key);
	// this function read the rlwesubs key from the FPGA DDR with dma and compare with ground truth
	
	int dma_read_compare_RGSW_enc_sk(const int slot_id, const RLWE::RGSW_ciphertext &enc_sec);
	// this function read the RGSW encrypted secret key from the FPGA DDR with dma and compare with ground truth

	LWE::LWE_ciphertext fpga_eval_bootstrap_x1(const LWE::LWE_ciphertext &c1, const LWE::LWE_ciphertext &c2, const LWE::keyswitch_key &kskey, const GATES gate, const pci_bar_handle_t ocl_bar_handle, int *rc, int read_fd);
	// this the wraper fucntion that contains all the evaluation and bootstrap subroutines with fpga
	// c1: an LWE_ciphertext to be evaluated 
	// c2: an LWE ciphertext to be evaluated
	// kskey: the key switch key
	// gate: the binary gate to be evaluated 
	// ocl_bar_handle: pci_bar_handle_t from top application function
	// rc: used to return error value
	// read_fd: dma read queue fd from the top application function
	// return a bootstrapped LWE ciphertext
	
	std::vector<LWE::LWE_ciphertext> fpga_eval_bootstrap_x4(const std::vector<LWE::LWE_ciphertext> &c1, const std::vector<LWE::LWE_ciphertext> &c2, const LWE::keyswitch_key &kskey, const std::vector<GATES> gate, const pci_bar_handle_t ocl_bar_handle, int *rc, int read_fd);
	// this the wraper fucntion that contains all the evaluation and bootstrap subroutines with fpga
	// c1: a vector of LWE_ciphertexts to be evaluated 
	// c2: a vector of LWE ciphertexts to be evaluated
	// kskey: the key switch key
	// gate: a vector of binary gates to be evaluated 
	// ocl_bar_handle: pci_bar_handle_t from top application function
	// rc: used to return error value
	// read_fd: dma read queue fd from the top application function
	// return a vector of bootstrapped LWE ciphertexts
	
	std::vector<LWE::LWE_ciphertext> fpga_eval_bootstrap_x8(const std::vector<LWE::LWE_ciphertext> &c1, const std::vector<LWE::LWE_ciphertext> &c2, const LWE::keyswitch_key &kskey, const std::vector<GATES> gate, const pci_bar_handle_t ocl_bar_handle, int *rc, int read_fd);
	// this the wraper fucntion that contains all the evaluation and bootstrap subroutines with fpga
	// c1: a vector of LWE_ciphertexts to be evaluated 
	// c2: a vector of LWE ciphertexts to be evaluated
	// kskey: the key switch key
	// gate: a vector of binary gates to be evaluated 
	// ocl_bar_handle: pci_bar_handle_t from top application function
	// rc: used to return error value
	// read_fd: dma read queue fd from the top application function
	// return a vector of bootstrapped LWE ciphertexts

	std::vector<LWE::LWE_ciphertext> fpga_eval_bootstrap_x12(const std::vector<LWE::LWE_ciphertext> &c1, const std::vector<LWE::LWE_ciphertext> &c2, const LWE::keyswitch_key &kskey, const std::vector<GATES> gate, const pci_bar_handle_t ocl_bar_handle, int *rc, int read_fd);
	// this the wraper fucntion that contains all the evaluation and bootstrap subroutines with fpga
	// c1: a vector of LWE_ciphertexts to be evaluated 
	// c2: a vector of LWE ciphertexts to be evaluated
	// kskey: the key switch key
	// gate: a vector of binary gates to be evaluated 
	// ocl_bar_handle: pci_bar_handle_t from top application function
	// rc: used to return error value
	// read_fd: dma read queue fd from the top application function
	// return a vector of bootstrapped LWE ciphertexts

	std::vector<LWE::LWE_ciphertext> fpga_eval_bootstrap_x16(const std::vector<LWE::LWE_ciphertext> &c1, const std::vector<LWE::LWE_ciphertext> &c2, const LWE::keyswitch_key &kskey, const std::vector<GATES> gate, const pci_bar_handle_t ocl_bar_handle, int *rc, int read_fd);
	// this the wraper fucntion that contains all the evaluation and bootstrap subroutines with fpga
	// c1: a vector of LWE_ciphertexts to be evaluated 
	// c2: a vector of LWE ciphertexts to be evaluated
	// kskey: the key switch key
	// gate: a vector of binary gates to be evaluated 
	// ocl_bar_handle: pci_bar_handle_t from top application function
	// rc: used to return error value
	// read_fd: dma read queue fd from the top application function
	// return a vector of bootstrapped LWE ciphertexts

	std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> fpga_expand_RLWE(const RLWE::RLWE_ciphertext &c1, const pci_bar_handle_t ocl_bar_handle, int *rc, int read_fd, int write_fd);
	// expand RLWE function that is used to extract each coefficient of the 
	// encrypted polynomial with fpga
	// c1: the input RLWE_ciphertext to be extracted: RLWE(\sum(b_i * X^i))
	// ocl_bar_handle: pci_bar_handle_t from top application function
	// rc: used to return error value
	// read_fd: dma read queue fd from the top application function
	// write_fd: dma write queue fd from the top application function
	// return a shared_ptr of vector of expanded RLWE ciphertext with length N:
	// result[i] = RLWE(N * b_i * X^i) 
	

	std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> fpga_expand_RLWE_cont_rd_wr(const RLWE::RLWE_ciphertext &c1, const pci_bar_handle_t ocl_bar_handle, int *rc, int read_fd, int write_fd);


	std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> fpga_expand_RLWE_batch_rd_wr(const RLWE::RLWE_ciphertext &c1, const pci_bar_handle_t ocl_bar_handle, int *rc, int read_fd, int write_fd);

	std::shared_ptr<std::vector<RLWE::RGSW_ciphertext>> fpga_homo_expand(const std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> &packed_bits, const pci_bar_handle_t ocl_bar_handle, int *rc, int read_fd, int write_fd);
	// this is the homoexpand function from the following paper
	// Onion Ring ORAM: Efficient Constant Bandwidth Oblivious RAM from (Leveled) TFHE
	// which basically transfers packed encrypted bits in RLWE ciphertext into 
	// a vector of RGSW ciphertext that encrypte each bits with fpga
	// packed_bits: a pointer to a vector of size digitG that contains 
	// encrypted bits in RLWE ciphertext: RLWE(\sum(b_i * iN * BG^k * X^i)), 
	// notice that iN is multiplied, so after expand_RLWE, it will automatically be 
	// scaled to RLWE(N * b_i * iN * BG^k) = RLWE(b_i * BG^k)
	// rc: used to return error value
	// read_fd: dma read queue fd from the top application function
	// write_fd: dma write queue fd from the top application function
	// return a shared_ptr of a vector of RGSW ciphtexts with each RGSW encrypt 
	// one bit of information from each coefficient of an RLWE ciphertext


//debug codes

	std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> fpga_RLWE_subs_test(const RLWE::RLWE_ciphertext &c1, const RLWE::RLWE_secretkey &sk, const application::substitute_key &subs_key, const pci_bar_handle_t ocl_bar_handle, int *rc, int read_fd, int write_fd);



	//LWE::LWE_ciphertext fpga_eval_bootstrap_step_by_step(const LWE::LWE_ciphertext &c1, const LWE::LWE_ciphertext &c2, const LWE::keyswitch_key &kskey, const GATES gate, const pci_bar_handle_t ocl_bar_handle, int *rc, int read_fd);




	int dma_test(int slot_id);
	//test the dma function to the DDR, input fifo and output fifo
	
	
	
	int rlwesubs_dual_test(int slot_id);
	//test the rlwesubs function with two input rlwes 
	
	int bootstrap_init_test(int slot_id);
	//test the bootstrap init function 
	
	int bootstrap_test(int slot_id);
	// test the bootstrap function 
	
	int rlwe_mult_rgsw_test(int slot_id);
	//test the rlwe mult rgsw function


}
#endif
