#ifndef RLWE_H
#define RLWE_H
#include "params.h"
#include "RNG.h"
#include "LWE.h"
#include "nbt.h"
#include <vector>
#include <iostream>
#include <cstdlib>
#include <bitset>// need to be paired with <string>
#include <string>
#include <assert.h>
#include <chrono>
#include <math.h>
#include <array>
#include <iomanip>
namespace LWE{
	class LWE_secretkey;
	class keyswitch_key;
	class LWE_ciphertext;
}

namespace RLWE{
	void poly_mult(const ciphertext_t *NTT_a1, const ciphertext_t *NTT_a2, const int length, const ciphertext_t modulo, ciphertext_t *NTT_a3);
	//multiply two NTTed polynomial of size N
	//a1[N]: one polynomial represented by an array of size N
	//a2[N]: one polynomial represented by an array of size N
	//length: the length of the sequence
	//modulo: the modulo to be worked with
	//NTT_a3[N]: the polynomial that take the result
	
	void poly_add(const ciphertext_t *NTT_a1, const ciphertext_t *NTT_a2, const int length, const ciphertext_t modulo, ciphertext_t *NTT_a3);
	//add two polynomial of size N, not necessarily NTTed input, 
	//since no difference between NTTed and no NTTed
	//a1[N]: one polynomial represented by an array of size N
	//a2[N]: one polynomial represented by an array of size N
	//length: the length of the sequence
	//modulo: the modulo to be worked with
	//NTT_a3[N]: the polynomial that takes the result

	void poly_subtraction(const ciphertext_t *NTT_a1, const ciphertext_t *NTT_a2, const int length, const ciphertext_t modulo, ciphertext_t *NTT_a3);
	//subtract polynomial a2 of size N from a1, not necessarily NTTed input, 
	//since no difference between NTTed and no NTTed
	//a1[N]: the polynomial to be subtracted from, represented by an array of size N
	//a2[N]: the polynomial to be subtracted, represented by an array of size N
	//length: the length of the sequence
	//modulo: the modulo to be worked with
	//NTT_a3[N]: the polynomial that takes the result
		
	void poly_substitute(const ciphertext_t *a1, const int sub_factor, const int length, const ciphertext_t modulo, ciphertext_t *a_out);
	// This implements the substitution function from the following paper from Microsoft research
	// Onion Ring ORAM: Efficient Constant Bandwidth Oblivious RAM from (Leveled) TFHE
	// it is used as a subroutine for extracting each single coefficient of a polynomial
	// Mathmetically, what it does is to evaluate a polynomial at a different power of X
	// for example: f(X) = \sum(a_i * X^i), after substitution, it becomes f(X^k),
	// where k = N/(2^sub_factor) + 1, where N is the dimension of the polynomial.
	// Practically, it just inverse some of the coefficients, for example, 
	// if k = N + 1, the result polynomial is just f(X^k) = \sum(a_i * (-1)^i * X^i).
	// Another example, if k = N/2 + 1, then f(X^k) = \sum(a_i * (-1)^(i/2) * X^i).
	// This function can only work in the time domain, it would be interesting to
	// see whether it can be done in the freq domain.
	// a1: the polynomail to be substituted, which has coefficents mod modulo in time domain
	// sub_factor: the substitution factor, it can only be in the range [0, log(N) - 1],
	// the resulting k = N/(2^sub_factor) + 1.
	// length: the length of the polynomial, which should equal to N
	// modulo: the polynomial modulo
	// a_out: the output polynomial 

	void reverse_array(ciphertext_t *a1, int start, int end);
	// this is helper function for poly_rotate to reverse the input array

	void poly_rotate_time(const ciphertext_t *a1, const int rotate_factor, const int length, const ciphertext_t modulo);	
	// This is a helper function that rotates the input polynomial by rotate factor mod 2N, it's an inplace version
	// if rotate factor >0, then it rotate leftward anticyclicly, otherwise it rotates rightward anticyclicly
	// it works in time domain
	// a1[N]: the polynomial to be rotated, in time domain
	// rotate_factor: number of rotation steps, it should be between [-N+1, N-1]

	class RLWE_plaintext{
	// class for RLWE plaintext
	// the coefficients of the plaintext in FHEW need only to be Q/8 or -Q/8(7Q/8)
	// So this RLWE will no use the scaling of the plaintext with Q/t
	// and the type is ciphertext_t, rather than plaintext_t
		public:
		RLWE_plaintext() = default; 	//explicitly set m to zero vector
		RLWE_plaintext(std::vector<ciphertext_t> m_in, bool is_NTT);
		// a dedicated constructor for FHEW bootstraping
		// it only takes time domain vector that contains either Q/8 or -Q/8
		// or freq domain vector coverted from the above
		// m_in[N]: message to be encrypted, a array of diemnsion N 
		// is_NTT: whether the input sequence is in NTT form
		
		RLWE_plaintext(std::vector<ciphertext_t> m_in, ciphertext_t t_RLWE);
		// a more general constructor of the class, that encode the input by multiplying Q/t_RLWE
		// this only works with time domain vector
		// this should be used when dealing with Second Generation ciphertexts
		// m_in[N]: message to be encrypted, an array of diemnsion N 
		// t_RLWE: the plaintext modulo
		
		void to_freq_domain();
		//transform the NTT_m to m by inverse NTT
		void to_time_domain();	
		//transform the m to NTT_m by NTT
		void denoise();
		// to remove the noise in the decrypted plaintext
		// and report the size of noise
		// change the message into time domain
		
		void denoise(ciphertext_t t_RLWE);
		// a more general version of denoise, the plaintext is recovered by 
		// first adding Q/(4*t) then dividing it by Q/t_RLWE
		// it should be worked together with the above constructor for second generation ciphertexts
		// t_RLWE: the plaintext modulo
		// change the message into time domain
		
		void display() const;
		// used to print the message m 
		
		//class content
		std::vector<ciphertext_t> m = std::vector<ciphertext_t>(N, 0); // message to be encrypted, a array of diemnsion N, in linear order
		//ciphertext_t NTT_m[N]; // NTT of the message to be encrypted, a array of diemnsion N, in bit reverse order
		bool NTT_form = true;	//this indicates whether the m[N] is in NTT form or not, true for yes, false for no
		ciphertext_t max_noise = 0;

	};

	class RLWE_ciphertext{
	// class for RLWE ciphertext
		public:
		RLWE_ciphertext() = default; // set all elements expilicitly to zero
		RLWE_ciphertext(const std::vector<ciphertext_t> &a_in, const std::vector<ciphertext_t> &b_in, bool is_NTT); // the array is initialized by the braces {}
		// constructor of the class, it also performs the approiate transforms it with NTT/iNTT
		// a_in: an array of the uniform random number
		// b_in: the encrypted term, polynomial_mult(a,s)+e+m mod Q, the m is predefined, so no scaling with it
		// is_NTT: whether the input sequence is in NTT form or not
		
		void display() const;
		// used to print the ciphertext
		void to_freq_domain();
		//transform the m to NTT_m by NTT
		void to_time_domain();	
		//transform the NTT_m to m by inverse NTT
		void add_to_a(const RLWE_plaintext &input);
		void add_to_b(const RLWE_plaintext &input);
		//two helper function to add a RLWE 
		//plaintext(a polynomail that is either in NTT form or not), 
		//to either a or b, the result is in NTT format 
		void NTT_a_transpose();
		//transpose NTT_a in frequency domain, to make it be ready for 
		//RLWE to LWE key switch, it only update the NTT_a, does not update a by iNTT
		
		
		//class content
		std::vector<ciphertext_t> a = std::vector<ciphertext_t>(N, 0);
		std::vector<ciphertext_t> b = std::vector<ciphertext_t>(N, 0);
		//ciphertext_t NTT_a[N];
		//ciphertext_t NTT_b[N];
		bool NTT_form = true;
	};

	class RLWE_secretkey: public RLWE_ciphertext{
	// class for RLWE secretkey, inherited from RLWE_ciphertext
	// the difference is that b is always 1
	// the vector a can be drawn uniformly or a short vector in terms of l1 norm or l2 norm
	// here we use uniform short vector, looks like it should be normal distribution
	// secretkey is always in NTT form
	
		public:
		RLWE_secretkey() = default;
		RLWE_secretkey(RNG_uniform &uni_dist);
		// one of the constructor of LWE secret key generation
		// drawing a short vector from an uniform distribution
		// uni_dist: an uniform ternary distribution
		
		RLWE_secretkey(std::vector<ciphertext_t> a_in);
		// another constructor that initialize the vector a from a input vector
		// that is in the time domain

	};

	class keyswitch_key{
		// class for the RLWE key switching operation
		// be aware that this is different from the LWE keyswitch key
		public:
		keyswitch_key() = default;
		keyswitch_key(const RLWE_secretkey &old_key, const RLWE_secretkey &new_key, RNG_uniform &uni_dist, RNG_norm &norm_dist);
		//constructor of keyswitch key from RLWE to LWE
		//old_key: a RLWE secret key to be encrypted by the new key
		//new_key: the new RLWE secret key to be switched to
		//uni_dist: a uniform distribution mod Q, use RLWE distributions on this
		//norm_dist: a normal distribution mod Q, use RLWE distriubtions on this
		
		//switchkey of size digitKS_R
		std::vector<RLWE_ciphertext> RLWE_kskey;
	};

	RLWE_ciphertext RLWE_encrypt(const RLWE_secretkey &s, const RLWE_plaintext &p, RNG_uniform &uni_dist, RNG_norm &norm_dist);
	// encrypt an RLWE message
	// s: RLWE secret key, in NTT format
	// p: RLWE plaintext, in NTT format
	// uni_dist: uniform distribution 
	// norm_dist: normal distribution 
	// return an RLWE_ciphertext in NTT format
	
	RLWE_plaintext RLWE_decrypt(const RLWE_secretkey &s, const RLWE_ciphertext &c);
	// decrypt an RLWE ciphertext
	// this function is mainly used when debugging the code, since RLWE
	// ciphertext is just a intermediate element of all the high level operations,
	// no need to decrypt RLWE ciphertext in actual applications 
	// s: RLWE secret key
	// c: RLWE ciphertext
	// return an RLWE plaintext in time domain
	
	RLWE_plaintext RLWE_decrypt(const RLWE_secretkey &s, const RLWE_ciphertext &c, const ciphertext_t t_RLWE);
	// decrypt an RLWE ciphertext, this is a more general version to include some second gen feature
	// this function is mainly used when debugging the code, since RLWE
	// ciphertext is just a intermediate element of all the high level operations,
	// no need to decrypt RLWE ciphertext in actual applications 
	// s: RLWE secret key
	// c: RLWE ciphertext
	// t_RLWE: the RLWE plaintext modulo, used for encode the number of the plaintext 
	// return an RLWE plaintext in time domain

	RLWE_ciphertext RLWE_addition(const RLWE_ciphertext &c1, const RLWE_ciphertext &c2);
	// add two RLWE_ciphertext 
	// c1: one operand of the evaluation, iN NTT form
	// c2: another operand of the evaluation, in NTT form
	// return an RLWE_ciphertext in NTT format

	RLWE_ciphertext RLWE_subtraction(const RLWE_ciphertext &c1, const RLWE_ciphertext &c2);
	// subtract RLWE_ciphertext c2 from RLWE_ciphertext c1
	// c1: one operand of the evaluation
	// c2: another operand of the evaluation
	// return an RLWE_ciphertext in NTT format
	
	RLWE_ciphertext RLWE_rotate_time(const RLWE_ciphertext &c1, const int rotate_factor);
	// rotate a RLWE ciphertext by the rotate factor, this function does not update the 
	// freq domain, postpone it until necessary
	// it operates on time domain
	// c1: the RLWE to be rotated
	// rotate_factor: the amount of steps to be rotated
	// return an RLWE_ciphertext in time domain
	
	//RLWE_ciphertext RLWE_add_constant(const RLWE_ciphertext &c1, const RLWE_ciphertext &c2);
	// add a constant polynomail to RLWE_ciphertext
	// c1: one operand of the evaluation
	// c2: another operand of the evaluation
	// return an RLWE_ciphertext
	// no direct RLWE ciphtexts multiplication required 
	
	RLWE_ciphertext RLWE_rotate_freq(const RLWE_ciphertext &c1, const int log_rotate_factor, const bool forward);
	// rotate a RLWE ciphertext by the rotate factor
	// it operates on freq domain
	// c1: the RLWE to be rotated in NTT format
	// log_rotate_factor: the log of amount of steps to be rotate, it is used to index the prebuilt vector of rotate polys
	// forward: the direction of the rotattion, ture is forward, false is backward
	// return an RLWE_ciphertext in NTT format

	RLWE_ciphertext RLWE_mult_NTT_poly(const RLWE_ciphertext &c1, const std::vector<ciphertext_t> NTT_poly);
	// multiply an RLWE ciphertext with a NTTed polynomial, this function does not update
	// the time domain, postpone it until necessary 
	// c1: RLWE RLWE_ciphertext in NTT format
	// NTT_poly: an NTTed polynomial
	// return an RLWE_ciphertext in NTT format
	
	RLWE_ciphertext RLWE_substitute(const RLWE_ciphertext c1, const int sub_factor);
	// This implements the substitution function from the following paper from Microsoft research
	// Onion Ring ORAM: Efficient Constant Bandwidth Oblivious RAM from (Leveled) TFHE
	// it is used as a subroutine for extracting each single coefficient of a polynomial
	// Mathmetically, what it does is to evaluate a polynomial at a different power of X
	// for example: f(X) = \sum(a_i * X^i), after substitution, it becomes f(X^k),
	// where k = N/(2^sub_factor) + 1, where N is the dimension of the polynomial.
	// Practically, it just inverse some of the coefficients, for example, 
	// if k = N + 1, the result polynomial is just f(X^k) = \sum(a_i * (-1)^i * X^i).
	// Another example, if k = N/2 + 1, then f(X^k) = \sum(a_i * (-1)^(i/2) * X^i).
	// This function can only work in the time domain, it would be interesting to
	// see whether it can be done in the freq domain.
	// c1: the RLWE ciphertext to be substituted
	// sub_factor: the substitution factor, it can only be in the range [0, log(N) - 1],
	// the resulting k = N/(2^sub_factor) + 1.
	// return a ciphertext that is substituted

	RLWE_ciphertext RLWE_keyswitch(const RLWE_ciphertext &c, const keyswitch_key &kskey);
	// RLWE key switch function that switch the RLWE ciphertet from one secret key
	// to another secret key
	// c: the input RLWE ciphertext in NTT format
	// kskey: the RLWE key switch key, in NTT format
	// output: a new RLWE ciphertext that is under the new key in NTT format

	class RGSW_plaintext{
	//class for RGSW plaintext
	//it is a polynomial that is all zero except for the mth order
		public:
		RGSW_plaintext() = default;
		RGSW_plaintext(const ciphertext_t m_in);
		//constructor of the RGSW plaintext
		//m_in: a number to be encrypted by RGSW,
		//note that the input is not a polynomial, but a number
		RGSW_plaintext(const bool m_in);
		//constructor of the RGSW plaintext, this is used for the leveled CMUX of TFHE,
		//m_in: a one bit number, that is either 0 or 1
		
		RGSW_plaintext(const RLWE_plaintext &m_in);
		//constructor of the RGSW plaintext, this is used for packed RGSW plaintext
		//m_in: a RLWE_plaintext
		
		void mult_constant_number(const ciphertext_t pBG);
		//helper function to multiply a const number to the plaintext
		//pBG: the number to be multiplied
		RLWE_plaintext m; 
	};

	class RGSW_ciphertext{
	// class for RGSW ciphtertext
		public:
		RGSW_ciphertext();
		RGSW_ciphertext(const std::vector<std::vector<RLWE_ciphertext>> &c_in){
			c_text = std::move(c_in);
		}
		RGSW_ciphertext(const RGSW_plaintext &m_in, const RLWE_secretkey &z, RNG_uniform &uni_dist, RNG_norm &norm_dist);
		// constructor of the RGSW ciphertext_t
		// m_in: RGSW plaintext to be encrypted
		// z: RGSW secret key, which is the same type as RLWE secretkey
		// uni_dist: a uniform distribution
		// norm_dist: a normal distribution
		
		//RGSW ciphertext of dimension digitG*2, in NTT form
		std::vector<std::vector<RLWE_ciphertext>> c_text;
	};
	
	class bootstrap_key{
	// class for the bootstrap key
	// it contains Br*logBr(q)*n RGSW ciphertexts	
		public:
		bootstrap_key() = default;
		bootstrap_key(const LWE::LWE_secretkey &s_in, const RLWE_secretkey &z_in, RNG_uniform &uni_dist, RNG_norm &norm_dist);
		//constructor for bootstrap key
		//s_in: the input LWE secretkey to be encrypted 
		//z_in: the RLWE secretkey
		//uni_dist: RLWE uniform distribution
		//norm_dist: RLWE normal distribution 
		
		//bootstrap key of dimension Br*digitR*n	
		std::vector<std::vector<std::vector<RGSW_ciphertext>>> btkey;
	};

	//void poly_digit_decompose(const ciphertext_t *NTT_poly, ciphertext_t **decomp_poly, const ciphertext_t decomp_length, const ciphertext_t mod_mask, const ciphertext_t division_bits);
	//helper function to get the digit decompse of a polynomial, works on the time domain first and then
	//converted to freq domain
	//this is used for RLWE keyswitch for efficiency
	//NTT_poly: input polynomial, in NTT format
	//decomp_poly: an array of poly that is the BG decomposation of the input, with length decomp_length
	//decomp_length: the decomposition length
	//mod_mask: a mask to perform mod operation, if mod base is 512, then it is 511
	//division_bits: use right shift as division, if mod base is 512, then it is 9
	//the implementation of the PALISADE lib is confusing, I don't think signed decomposition is needed
	//so I just do positive number decomposition, since the input are all mod Q numbers which are already 
	//mapped to positive 

	std::vector<RLWE_ciphertext> digit_decompose(const RLWE_ciphertext &RLWE_ctext, const ciphertext_t decomp_length, const ciphertext_t mod_mask, const ciphertext_t division_bits);
	//helper function to get the digit decompse of a RLWE ciphertext, works on the time domain first and then
	//converted to freq domain, so make sure the time domain of the input ciphertext is valid
	//RLWE_ctext: input RLWE ciphertext, in NTT format
	//RLWE_pirme_c: a array of RLWE that is the BG decomposation of the input, with length decomp_length
	//decomp_length: the decomposition length
	//mod_mask: a mask to perform mod operation, if mod base is 512, then it is 511
	//division_bits: use right shift as division, if mod base is 512, then it is 9
	//the implementation of the PALISADE lib is confusing, I don't think signed decomposition is needed
	//so I just do positive number decomposition, since the input are all mod Q numbers which are already 
	//mapped to positive 
	
	RLWE_ciphertext RLWE_mult_RGSW(const RLWE_ciphertext &acc, const RGSW_ciphertext &input);
	//this is the add to accumulator function in the original paper
	//the main step in the bootstrapping operation
	//acc: an RLWE RLWE ciphertext in NTT form
	//input: the RGSW ciphertext to be accumulated
	//return: an accumulated RLWE ciphertext 
	
	RLWE_ciphertext acc_initialization(const ciphertext_t &embed_factor, const ciphertext_t &bound1, const ciphertext_t &bound2, const ciphertext_t &value);
	//this it the function to initialize the accumulator to NTT form
	//embed_factor: the mult factor to embed q into 2N
	//bound1: the decision boundary one 
	//bound2: the decision boundary two
	//value: the value to initialize acc to


	LWE::LWE_ciphertext eval_bootstrap(const LWE::LWE_ciphertext &c1, const LWE::LWE_ciphertext &c2, const bootstrap_key &btkey, const LWE::keyswitch_key &kskey, const GATES gate);
	// this the wraper fucntion that contains all the evaluation and bootstrap subroutines
	// c1: an LWE_ciphertext to be evaluated 
	// c2: an LWE ciphertext to be evaluated
	// btkey: the bootstrap key or refresh key
	// kskey: the key switch key

	RLWE_ciphertext CMUX(const RLWE_ciphertext &c0, const RLWE_ciphertext &c1, const RGSW_ciphertext &SEL);
	// this is a subroutine from TFHE that can be used to perform leveled homomorphic binary functions
	// it is called CMUX, which evidently homomorphically evaluate a MUX gate following the equation
	// output = (c1 - c0) * SEL + c0, if SEL is 0, c0 is selected, viceversa
	// c0: a RLWE ciphertext in NTT form
	// c1: a RLWE ciphertext in NTT form
	// SEL: a RGSW ciphertext that encrypts one select bit
	// return the selected RLWE ciphertext in NTT form

	RLWE_ciphertext blind_rotate_full(const RLWE_ciphertext &c_in, const int b, const std::vector<int> &a, const std::vector<RGSW_ciphertext> &C);
	// this is a subroutine from TFHE that can be used to perform leveled homomorphic binary functions
	// it is called blind_rotate, which basically rotates the encrypted polynomial as directed by the input
	// by applying the CMUX function
	// this version rotates in the time domain
	// Output: A RLWE sample of X^(−ρ)*v where ρ = b + sum(si.ai) mod 2N, and v is the original polynomial in NTT form
	// c_in: input RLWE ciphertext in NTT form
	// b: is the public rotation parameter, in the range [-N+1, N-1], no encryption need, if b > 0, then it rotates toward higher power, otherwise, toward lower power. The same applies to a.
	// a: is a vector of private rotation parameters, working with the RGSW ciphertext vector C
	// C: is a vector of RGSW_ciphertext that controls the private rotation
	
	RLWE_ciphertext blind_rotate(const RLWE_ciphertext &c_in, const bool forward, const std::vector<RGSW_ciphertext> &C);
	// this is a reduced version of the subroutine from TFHE that can be used to perform leveled homomorphic binary functions
	// it is called blind_rotate, which basically rotates the encrypted polynomial as directed by the input
	// by applying the CMUX function
	// this version rotates in the freq_domain, and does not have the public rotate part
	// also in the private rotate part, it can only rotate in a predefined direction, indicated by "forward"
	// and with a set of predefined binary steps: 1, 2, 4, 8 ..., up to num_rotate_poly
	// Output: A RLWE sample of X^(−ρ)*v where ρ = sum(si.ai) mod 2N, and v is the original polynomial in NTT form
	// c_in: input RLWE ciphertext in NTT form
	// forward: the direction of the rotation, true for forward, false for backward
	// C: is a vector of RGSW_ciphertext that controls the private rotation, the size of the vector is num_rotate_poly
	
}
#endif
