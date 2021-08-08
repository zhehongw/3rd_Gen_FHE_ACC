#ifndef TEST_H
#define TEST_H
#include "params.h"
#include "nbt.h"
#include "RNG.h"
#include "LWE.h"
#include "RLWE.h"
#include "app.h"
#include "myfpga.h"
#include <iostream>
#include <iomanip>
#include <bitset>
#include <string>
#include <cassert>
#include <set>
#include <chrono>

namespace test{
	void print_sequence(const ciphertext_t *a, const int length);
	//helper function to print the content of a sequence
	//a: the sequence to be printed 
	//length: the length of the sequence

	void LWE_en_decrypt(RNG_uniform &uni_dist, RNG_norm &norm_dist, const LWE::LWE_secretkey &sk);
	// this is to test the basic decyption and encryption of the LWE scheme

	void LWE_NAND(RNG_uniform &uni_dist, RNG_norm &norm_dist, const LWE::LWE_secretkey &sk);
	// try addition of two ciphertexts and one bias ciphertext to get NAND of two plaintexts

	void scale_mod();
	// this is to test the scale and mod operation in the LWE rounding step 

	void prime();
	//test the MR primality test

	void verify_iN();
	//verify whether iN is correct

	void verify_ROU();
	//verify the ROU is correct 

	void verify_NTT();
	//verify the NTT/iNTT is correct 

	void RLWE_en_decrypt(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk);
	//verify the RLWE encrypt and decrypt

	void modswitch();
	//verify switching from a mod Q LWE to mod q LWE

	void RLWE_transpose(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk);
	//verify the transpose function of RLWE ciphertext

	void keyswitch(RNG_uniform &RLWE_uni_dist, RNG_norm &RLWE_norm_dist, const LWE::LWE_secretkey &LWE_sk, const RLWE::RLWE_secretkey &RLWE_sk, const LWE::keyswitch_key &ks_key);
	//verify switching from a RLWE key to LWE key

	int bootstrapping(RNG_uniform &uni_dist, RNG_norm &norm_dist, const LWE::LWE_secretkey &sk, const RLWE::bootstrap_key &btkey, const LWE::keyswitch_key &kskey);
	//verify the bootstrapping process 
	//uni_dist: LWE unifrom distribution
	//norm_dist: LWE normal distribution 
	//return: how many times it fails

	void RLWE_mult_RGSW(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk);
	//test RLWE ciphertext mult RGSW ciphertext, this only works with zero noise in the RLWE ciphertext
	//uni_dist: RLWE unifrom distribution
	//norm_dist: RLWE normal distribution 

	void acc_initialize();
	//verify correctness of acc initialize 

	void RGSW_decompose(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk);
	//verify correctness of RGSW decompose, this test only works with zero noise in RLWE ciphertext

	void digit_decompose();
	//test whether the NTT decompose is equivalent to time domain decompose
	//the answer seems to be no, but is there a way to do decompose in NTT domain?

	void RLWE_keyswitch(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &old_key, const RLWE::RLWE_secretkey &new_key, const RLWE::keyswitch_key &ks_key_R);
	//verify the RLWE key switch function 
	
	void CMUX(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk);
	// verify the CMUX function of TFHE
	
	void blind_rotate_time(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk);
	// verify the blind rotate function in time domain

	void blind_rotate_freq(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk);
	// verify the blind rotate function in freq domain 
	
	void RLWE_expansion(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk);
	//verify the RLWE expansion function 
	//expand one RLWE ciphertext to N RLWE ciphertexts
	//each encrypts a coefficient of the input RLWE ciphertext
	
	void homo_expansion(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk);
	// verify the homo_expand function
	// expand one RLWE ciphertext to N RGSW ciphertexts
	// each encrypts a coefficient of the input RLWE ciphertext

	void homo_expansion_and_tree_selection(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk);
	// verify the homo_expand function
	// expand one RLWE ciphertext to N RGSW ciphertexts
	// each encrypts a coefficient of the input RLWE ciphertext
	
	void substitue_RLWE_noise_increase(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk);
	// to test the noise increase of RLWE substitue
	// basically subs the polynomail variable X with X^k, where k = N/(2^subs_factor) + 1
	
	void poly_substitute();
	// verify the poly substitute function and the poly expansion scheme in RLWE plaintext

	void RGSW_packing(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk);
	// to test the idea of packing selection bits of CMUX in a RGSW ciphertext and operate in 
	// a SIMD fashion 

	void RGSW_packing_and_tree_selection(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk);
	// to test the idea of packing selection bits of CMUX in a RGSW ciphertext and operate in 
	// a SIMD fashion, and through the binary selection tree
	
	void barrett_reduction();
	// intial test of battett reduction 
	
	int fpga_bootstrapping_test(RNG_uniform &uni_dist, RNG_norm &norm_dist, const LWE::LWE_secretkey &sk, const LWE::keyswitch_key &kskey, int slot_id);
	//this function tests the fpga bootstrap operation 


	int fpga_bootstrapping_test_x4(RNG_uniform &uni_dist, RNG_norm &norm_dist, const LWE::LWE_secretkey &sk, const LWE::keyswitch_key &kskey, int slot_id);
	//this function tests the fpga bootstrap operation 4 at a time

	int fpga_bootstrapping_test_x8(RNG_uniform &uni_dist, RNG_norm &norm_dist, const LWE::LWE_secretkey &sk, const LWE::keyswitch_key &kskey, int slot_id);
	//this function tests the fpga bootstrap operation 8 at a time

	int fpga_bootstrapping_test_x12(RNG_uniform &uni_dist, RNG_norm &norm_dist, const LWE::LWE_secretkey &sk, const LWE::keyswitch_key &kskey, int slot_id);
	//this function tests the fpga bootstrap operation 12 at a time

	int fpga_bootstrapping_test_x16(RNG_uniform &uni_dist, RNG_norm &norm_dist, const LWE::LWE_secretkey &sk, const LWE::keyswitch_key &kskey, int slot_id);
	//this function tests the fpga bootstrap operation 12 at a time

	int fpga_RLWE_expansion_test(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk, int slot_id);
	//this function tests the fpga RLWE expansion operation

	int fpga_homo_expansion_test(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk, int slot_id);
	//this function tests the fpga homo expansion operation with fpga

	int fpga_homo_expansion_and_tree_selection_test(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk, int slot_id);
	//this function tests the fpga homo expansion operation and tree selection function with fpga


//debug codes
	int fpga_RLWE_subs_test(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk, int slot_id);


}

#endif
