#ifndef APP_H
#define APP_H

#include "params.h"
#include "RNG.h"
#include "LWE.h"
#include "RLWE.h"
#include "nbt.h"
#include <vector>
#include <iostream>
#include <cstdlib>
#include <bitset>	// need to be paired with <string>
#include <string>
#include <assert.h>
#include <chrono>
#include <math.h>
#include <array>
#include <memory>
#include <iomanip>	// to print out data for hardware verification 

namespace application{
	class substitute_key{
	//class of the substitution key for substitution function 
		public:
		substitute_key() = default;
		substitute_key(const RLWE::RLWE_secretkey &sk_in, RNG_uniform &uni_dist, RNG_norm &norm_dist);
		//constructor of the class
		//sk: the RLWE to be switched to after the substituion
		//uni_dist: uniform distribution
		//norm_dist: normal distribution 
		
		// class content, subs key of digitN dimension RLWE keyswitch key
		std::vector<RLWE::keyswitch_key> subs_key;
		// a vector of RLWE keyswitch keys, each index i holds a RLWE 
		// keyswitch key that switches from a secret key sk(X^K) to sk(X), 
		// where k = n/(2^i) + 1
	};

	std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> expand_RLWE(const RLWE::RLWE_ciphertext &c1, const substitute_key &subs_key);
	// expand RLWE function that is used to extract each coefficient of the 
	// encrypted polynomial
	// c1: the input RLWE_ciphertext to be extracted: RLWE(\sum(b_i * X^i))
	// subs_key: a vector of RLWE keyswitch key
	// return a shared_ptr of vector of expanded RLWE ciphertext with length N:
	// result[i] = RLWE(N * b_i * X^i) 

	std::shared_ptr<std::vector<RLWE::RGSW_ciphertext>> homo_expand(const std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> &packed_bits, const RLWE::RGSW_ciphertext &enc_sec, const substitute_key &subs_key);
	// this is the homoexpand function from the following paper
	// Onion Ring ORAM: Efficient Constant Bandwidth Oblivious RAM from (Leveled) TFHE
	// which basically transfers packed encrypted bits in RLWE ciphertext into 
	// a vector of RGSW ciphertext that encrypte each bits
	// packed_bits: a pointer to a vector of size digitG that contains 
	// encrypted bits in RLWE ciphertext: RLWE(\sum(b_i * iN * BG^k * X^i)), 
	// notice that iN is multiplied, so after expand_RLWE, it will automatically be 
	// scaled to RLWE(N * b_i * iN * BG^k) = RLWE(b_i * BG^k)
	// enc_sec: an RGSW ciphertext that encypts (-s), which is the RLWE secretkey
	// subs_key: the substituion key that is used in the expand RLWE subfunction

	//RLWE::RLWE_ciphertext evaluate_btree(const std::shared_ptr<std::vector<RLWE::RGSW_ciphertext>>);

}

#endif
