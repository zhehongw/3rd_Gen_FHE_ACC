#ifndef PARAMS_H
#define PARAMS_H
#include "nbt.h"
#include <stdint.h>
#include <cmath>
#include <iostream>
#include <vector>
#include <array>
#include <experimental/array>

//define all LWE parameters
//deine the dimensin of LWE ciphtertext
extern int n;

//define LWE plaintext modulus
extern uint16_t t;

//define the LWE ciphertext modulus
extern ciphertext_t q;

extern ciphertext_t q2;

//define the noise bound of LWE ciphertext
extern ciphertext_t E;

//define secret key sample range for LWE
extern ciphertext_t LWE_sk_range;

//define mean and stddev of normal distribution of the LWE
extern ciphertext_t LWE_mean;
extern double LWE_stddev;

//define all RLWE/RGSW parameters
//define the order of RLWE/RGSW cyclotomic polynomial, 
//order of the 2Nth cyclotomic polynomial is N, with N being a power of 2
extern int N;

extern int N2;

extern uint16_t digitN;

//define secret key sample range for RLWE
extern ciphertext_t RLWE_sk_range;

//define mean and stddev of normal distribution of the RLWE
extern ciphertext_t RLWE_mean;
extern double RLWE_stddev;

//define the noise bound of the RLWE, it seems E_rlwe = omega(\sqrt(log(n)))
//which in this case is around 3, so for now just put an arbitrary small number
//need verification
extern ciphertext_t E_rlwe;

//define the RLWE/RGSW plaintext modulus
//support STD128 bit security

//as will see, the coefficients of the plaintext polynomial 
//are in the set {0, 1, -1}, so two bit plaintext modulus
extern int t_rlwe;

//define number of bit of RLWE modulo Q
extern uint16_t nbit;

//define the RLWE/RGSW ciphertext modulus, a prime
extern ciphertext_t Q;

//define the barrett reduction mu factor
//extern const long_ciphertext_t mu_factor;

// the inverse of N mod Q, with N * iN = 1 mod Q 
extern ciphertext_t iN;	

//primitive 2Nth root of unity
extern ciphertext_t ROU;

//twiddle factor table for NTT, in bit reverse order, dynamically allocated 
extern ciphertext_t *ROU_table;	//need to find a way to make these constant
//twiddle factor table for iNTT, in bit reverse order
extern ciphertext_t *iROU_table;	//need to find a way to make these constant

//define the decompse base of the RGSW ciphertext
//const ciphertext_t BG = 1 << 11;
extern ciphertext_t BG;
extern ciphertext_t BGbits;			// number of bits of BG, used for division
extern ciphertext_t BG_mask;		// a mask with lower 9 bits all one 

//define the size of the RGSW scheme, it is defined as digitG = logBG(Q) 
extern ciphertext_t digitG;
extern ciphertext_t digitG2;

//define the refresh base for homomorphically evaluate the decryption 
extern ciphertext_t Br;
extern ciphertext_t digitR;

//define the key switch base for RLWE-to-LWE key switching, note that it's with respect to Q not q
extern ciphertext_t Bks;
//const ciphertext_t Bks = 2;
extern ciphertext_t digitKS;

//define the key switch base for RLWE-to-RLWE key switching, note that it's with respect to Q 
extern ciphertext_t Bks_R;		//for now set this the same as the BG, and also other parameters related to it
extern ciphertext_t Bks_R_bits;	//number bits of Bks_R, used for division 
extern ciphertext_t digitKS_R;
extern ciphertext_t Bks_R_mask;

//defines the types of gates 
enum GATES {OR, AND, NOR, NAND, XOR, XNOR};

//define the mapping range constant of each type of gates
extern ciphertext_t gate_constant[6];

//define the number of rotate polynomials, so that rotation can be done 
//in a binary decomposed fashion
const uint16_t num_rotate_poly = 11;

//define a forward ploynomial rotation polynomials in NTT form
//which are vectors of form V[j] = X^(2^j), where 2^j is the rotation factor
extern std::vector<std::vector<ciphertext_t>> rotate_poly_forward;

//define a backward ploynomial rotation polynomials in NTT form
//which are vectors of form V[j] = -X^(2^j) = (Q-1)X^(2^j), where 2^j is the rotation factor
extern std::vector<std::vector<ciphertext_t>> rotate_poly_backward;

///////////////////////////////////////////////////
//
// Parameters for FPGA
// 
///////////////////////////////////////////////////
extern uint32_t 	BARRETT_K;
extern uint64_t 	BARRETT_M;
extern uint32_t 	BARRETT_K2;
extern uint32_t  	LOG2_RLWE_LEN;
extern uint32_t 	EMBED_FACTOR;
extern uint32_t 	TOP_FIFO_MODE;


void root_of_unity_table(const ciphertext_t &ROU, const ciphertext_t &modulo, const int order, ciphertext_t *ROU_table, ciphertext_t *iROU_table);
//generate the calculated table of power of the ROU and iROU, in bit reverse order
//ROU: the input root of unity
//modulo: the target modulo, prime
//order: the order of the polynomial, i.e. the size of the table
//ROU_table: a preset array to hold the ROU table
//iROU_table: a preset array to hold the iROU table

std::vector<std::vector<ciphertext_t>> rotate_vector_gen(const bool forward);
// this is a helper function that generates the vector of rotation polynomials in NTT form
// it uses malloc, so remember to free the allocated memory when main finishes
// forward: whether it generates forward rotate poly or backward rotate poly, true for forward, false for backward
// return: a vector of rotate poly



#endif
