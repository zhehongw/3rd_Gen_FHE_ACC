#ifndef LWE_H
#define LWE_H
#include "params.h"
#include "nbt.h"
#include "RLWE.h"
#include "RNG.h"
#include <vector>
#include <iostream>
#include <cstdlib>
#include <bitset>// need to be paired with <string>
#include <string>
#include <utility>
//forward declaration, used when two headers include each other
namespace RLWE{
	class RLWE_ciphertext;
	class RLWE_secretkey;
}

namespace LWE{

	class LWE_plaintext{
	// class for LWE plaintext
		public:
		LWE_plaintext();
		LWE_plaintext(message_t m_in) : m(m_in){};
		// constructor of the class
		// m_in: message to be encrypted, a single integer

		void display();
		// used to print the message m 
		
		//class content
		message_t m; // message to be encrypted, a single integer
	};
	
	class LWE_ciphertext{
	// class for LWE ciphertext
		public:
		LWE_ciphertext() = default;//explicitly initialize all to zero
		LWE_ciphertext(std::vector<ciphertext_t> a_in, ciphertext_t b_in){
		// constructor of the class
		// a_in: an array of the uniform random number
		// b: the encrypted term, <a,s>+e+m(q/t) mod q
			for(int i; i < n; i++) a[i] = a_in[i];
			b = b_in;
		}

		void display() const;
		// used to print the ciphertext
		
		bool operator==(const LWE_ciphertext &other)const{
			if(b != other.b)
				return false;
			for(int i = 0; i < n; i++){
				if(a[i] != other.a[i])
					return false;
			}
			return true;
		}

		//class content
		std::vector<ciphertext_t> a = std::vector<ciphertext_t>(n, 0);
		ciphertext_t b = 0;
	};
	
	class LWE_secretkey: public LWE_ciphertext{
	// class for LWE secretkey, inherited from LWE_ciphertext
	// the difference is that b is always 1
	// the vector a can be drawn uniformly or a short vector in terms of l1 norm or l2 norm
	// here we use uniform short vector, looks like it should be normal distribution 
	
		public:
		LWE_secretkey() = default;
		LWE_secretkey(RNG_uniform &uni_dist);
		// one of the constructor of LWE secret key generation
		// drawing a short vector from an uniform distribution
		// unit_dist: an ternary uniform distribution
		
		LWE_secretkey(std::vector<ciphertext_t> a_in){
		// another constructor that initialize the vector a from a input vector
			for(int i; i < n; i++) a[i] = a_in[i];
			b = 1;
		}
	};

	class keyswitch_key{
	// class for the LWE key switching operation
	// though this is built on LWE ciphertext_t, the modulo is Q rather than q
		public:
		keyswitch_key() = default;
		keyswitch_key(const RLWE::RLWE_secretkey &RLWE_old_key, const LWE_secretkey &new_key, RNG_uniform &uni_dist, RNG_norm &norm_dist);
		//constructor of keyswitch key from RLWE to LWE
		//old_key: RLWE secret key
		//new_key: LWE LWE secret key
		//uni_dist: a uniform distribution mod Q, rather than mod q. So use RLWE distributions on this
		//norm_dist: a normal distribution mod Q, rather than mod q. So use RLWE distriubtions on this
		
		
		//switchkey of size Bks*digitKS*N
		std::vector<std::vector<std::vector<LWE_ciphertext>>> kskey;
	};

	LWE_ciphertext LWE_encrypt(const LWE_secretkey &s, const LWE_plaintext &p, RNG_uniform &uni_dist, RNG_norm &norm_dist);
	// encrypt an LWE message
	// s: LWE secret key
	// p: LWE plaintext
	// uni_dist: uniform distribution 
	// norm_dist: normal distribution 
	// return an LWE_ciphertext
		
	LWE_plaintext LWE_decrypt(const LWE_secretkey &s, const LWE_ciphertext &c);
	// decrypt an LWE ciphertext
	// s: LWE secret key
	// c: LWE ciphertext
	// return an LWE plaintext
	
	LWE_plaintext LWE_decrypt_2(const LWE_secretkey &s, const LWE_ciphertext &c);
	// decrypt an LWE ciphertext with plaintext modulus 2, not to be used in practice
	// s: LWE secret key
	// c: LWE ciphertext
	// return an LWE plaintext

	LWE_ciphertext LWE_evaluate(const LWE_ciphertext &c1, const LWE_ciphertext &c2, const GATES gate);
	// evaluate an operation of the input ciphertext
	// c1: one operand of the evaluation
	// c2: another operand of the evaluation
	// gate: types of gates to be evaluated, support AND, NAND, OR, NOR, XOR, XNOR
	// return an LWE_ciphertext
	
	LWE_ciphertext LWE_eval_NOT(const LWE_ciphertext &c);
	//evaluate the NOT gate on a ciphertext
	//c: the input to be evaluated
	//return: an LWE_ciphertext

	
	LWE_ciphertext LWE_keyswitch(const RLWE::RLWE_ciphertext &RLWE_ctext, const keyswitch_key &kskey);
	//transform an RLWE ciphertext into LWE ciphtext and also switch the key in to the original LWE key
	//it works with mod Q
	//it first transpose the RLWE ciphertext and add a Q/8 to constant term to offset the range from [-Q/8, Q/8] to [0, Q/4]
	//RLWE_ctext: the ciphertext to be switched from, in NTT format
	//kskey: the key switch key
	//return an LWE ciphertext mod Q
	
	ciphertext_t scale_round(ciphertext_t input, ciphertext_t new_mod, ciphertext_t old_mod);
	// a helper function to calculate the scaling round of the input
	// the process is quite mysterious, need further investigation
	// input: the number to be scaled and counded
	// new_mod: the modulo to be scaled to
	// old_mod: the modulo to be scaled from
	// return a scaled and rounded result
		
	LWE_ciphertext LWE_modswitch(const LWE_ciphertext &c_text);
	// to switch an LWE ciphertext from mod Q to mod q, used after key switch
	// c_text: the LWE ciphertext mod Q to be switched
	// return an LWE ciphertext mod q

}
#endif
