#include "LWE.h"

using namespace std;
namespace LWE{
	LWE_plaintext::LWE_plaintext(){
		m = 0;
	}
	void LWE_plaintext::display(){
		bitset<32> temp(m);
		cout << "message is \t" << temp << endl;
	}

	void LWE_ciphertext::display() const{
		cout << "b is " << b << endl;
		cout << "a is ";
		for(int i = 0; i < n; i++){
			cout << a[i] << " ";
		}
		cout << endl;
	}

	LWE_secretkey::LWE_secretkey(RNG_uniform &uni_dist){
		signed_ciphertext_t s;
		ciphertext_t ss;
		#ifdef DEBUG
			int count = 0;
		#endif

		do{
			s = 0;
			ss = 0;
			for(int i = 0; i < n; i++){
				signed_ciphertext_t tmp = uni_dist.generate_uniform() % (signed_ciphertext_t)q;
				//cout << a[i] << " ";
				s += tmp;
				ss += abs(tmp);
				a[i] = mod_pow2(tmp, q);
			}
			//cout << endl;
		#ifdef DEBUG
			cout << "s = " << s << endl;
			cout << "ss = " << ss << endl;
			count++;
		}while((abs(s) > 100 || ss > 350) && count < 3);//this comparison bound should be tested
		#else
		}while(abs(s) > 200 || ss > 700);	// ss range is too small in most cases, check definition
												// if ss is uniform from {-1, 0, 1} then the mean would 
												// be 1000/3, way larger than 100
												// use normal distribution to fix this
												// this limit needs to be verified
		#endif
		b = 1;
	}

	keyswitch_key::keyswitch_key(const RLWE::RLWE_secretkey &RLWE_old_key, const LWE_secretkey &new_key, RNG_uniform &uni_dist, RNG_norm &norm_dist){
		//new_key is built based on mod q
		//need to first switch the new_key to mod Q
		//this is not a general modulo switch process
		//only works in the current setting that 
		//the old modulo is q, and the new one is Q,
		//with Q > q
		LWE_secretkey nkey_modQ = new_key;
		//uint32_t diff = (Q > q) ? Q - (uint32_t)q : (uint32_t)q - Q;
		ciphertext_t diff = Q - (ciphertext_t)q;
		for(int i = 0; i < n; i++){
			if(nkey_modQ.a[i] >= q2){
				nkey_modQ.a[i] += diff;	// mapping negative number mod q to the same negative number mod Q
										// for example, 511 = -1 mod 512, and Q-1 = -1 mod Q, so we need 
										// to map 511 to Q-1 by adding Q-512 to 511.
										// Since element a[i] is gauranteed to be less than 512, there's
										// no need to mod Q again.
										// for positive number mod q, there's no need to remap, just leave
										// it be
			}
		}
		
		std::vector<std::vector<std::vector<LWE_ciphertext>>> result(Bks);
		
		RLWE::RLWE_secretkey old_key = RLWE_old_key;
		old_key.to_time_domain();	//make sure old key is in time domain

		for(ciphertext_t i = 0; i < Bks; i++){
			ciphertext_t powks = 1;

			std::vector<std::vector<LWE_ciphertext>> vector1(digitKS);
			for(ciphertext_t j = 0; j < digitKS; j++){
				std::vector<LWE_ciphertext> vector2(N);
				for(int k = 0; k < N; k++){
					LWE_ciphertext c_text;
					ciphertext_t mult = mod_general((long_ciphertext_t)mod_general((long_ciphertext_t)i * (long_ciphertext_t)powks, Q) * (long_ciphertext_t)old_key.a[k], Q);
					c_text.b = mod_general((signed_ciphertext_t)norm_dist.generate_norm(E_rlwe) + (signed_ciphertext_t)mult, Q);	//need to test this E, looks like the E_rlwe is needed here, E is too large I guess
					//c_text.b = mod_general(0 + (int64_t)mult, Q);	//for debug use//need to test this E, looks like the E_rlwe is needed here, E is too large I guess

					for(int h = 0; h < n; h++){
						c_text.a[h] = mod_general(uni_dist.generate_uniform(), Q);
						c_text.b = mod_general(c_text.b + mod_general((long_ciphertext_t)c_text.a[h] * (long_ciphertext_t)nkey_modQ.a[h], Q), Q); 
					}
					vector2[k] = std::move(c_text);
				}
				vector1[j] = std::move(vector2);
				powks = mod_general((long_ciphertext_t)powks * (long_ciphertext_t)Bks, Q);
			}
			result[i] = std::move(vector1);
		}
		kskey = std::move(result);
	}

	LWE_ciphertext LWE_encrypt(const LWE_secretkey &s, const LWE_plaintext &p, RNG_uniform &uni_dist, RNG_norm &norm_dist){
		#ifdef DEBUG
			LWE_ciphertext c_text;
			ciphertext_t e = norm_dist.generate_norm(E) % q;	// negative number with abs < q, mod q stays the same 
																// here error/noise is kept as signed number
			//cout << "noise = \t" << e << endl; 
			bitset<64>  m_scaled(p.m * (q / t));
			//cout << "scaled message =" << p.m*(q/t) << endl;
			//cout << "scaled message =" << m_scaled << endl;

			c_text.b = mod_pow2(e + (signed_ciphertext_t)(p.m * (q/t)), q);
			bitset<64> pre_en_b(c_text.b);
			//cout << "e+(q/t)m = \t" << c_text.b << endl;
			//cout << "e+(q/t)m = \t" << pre_en_b << endl;
			
			//compute inner product
			for(int i = 0; i < n; i++){
				c_text.a[i] = mod_pow2(uni_dist.generate_uniform(), q);
				//cout << "a[" << i << "] = " << c_text.a[i] << endl;
				c_text.b = mod_pow2(c_text.b + c_text.a[i] * s.a[i], q);
				bitset<64> en_b(c_text.b);
				//cout << "e+(q/t)m+as= \t" << c_text.b << endl;
			}

			return c_text;
		#else
			LWE_ciphertext c_text;
			c_text.b = mod_pow2(norm_dist.generate_norm(E) + (signed_ciphertext_t)(p.m * (q / t)), q);
			//c_text.b = mod_pow2((0 + p.m * (q / t)), q);	//no noise, for debug purpose
			
			//compute inner product
			for(int i = 0; i < n; i++){
				c_text.a[i] = mod_pow2(uni_dist.generate_uniform(), q);
				c_text.b = mod_pow2(c_text.b + mod_pow2(c_text.a[i] * s.a[i], q), q);
			}

			return c_text;
		#endif
	}

	LWE_plaintext LWE_decrypt(const LWE_secretkey &s, const LWE_ciphertext &c){
		#ifdef DEBUG
			LWE_plaintext p_text;
			p_text.m = c.b;
			//cout << "b = " << p_text.m << endl;

			// compute inner product
			for(int i = 0; i < n; i++){
				//cout << "a[" << i << "] = " << c.a[i] << endl;
				p_text.m = mod_pow2(p_text.m - c.a[i] * s.a[i], q);
				//cout << "b-as = " << p_text.m << endl;
			}
			bitset<32> de_b(p_text.m);
			//cout << "pre round b =\t" << p_text.m << endl;
			//cout << "pre round b =\t" << de_b << endl;
			p_text.m = mod_pow2(p_text.m + (E * 2), q);
			p_text.m = p_text.m * t / q; 
			return p_text;
		#else
			LWE_plaintext p_text;
			p_text.m = c.b;
			// compute inner product
			for(int i = 0; i < n; i++){
				p_text.m = mod_pow2(p_text.m - c.a[i] * s.a[i], q);
			}
			p_text.m = mod_pow2(p_text.m + (E * 2), q); 	// several caveats here 
																		// 1. while decrypte, there's no need to mod q during the inner product
																		// 2. the additional "+ q" is needed only because the % operation is not 
																		// exactly mod operation from a mathmatical point of view. % q maps numbers 
																		// into [-q+1, q-1], while mod q maps number into [-q/2, q/2-1] or [0,q-1], 
																		// by "+ q", the range is maped back to the mathmatical definition. So in 
																		// hardware implementation, there's no need to add this extra q, 
																		// where mod is computed by truncating the number directly. And also note that
																		// in the hardware case, there's no difference in treating the number as 
																		// signed or unsigned, they are basically the same. But it might matter when
																		// doing the homomorphic decryption 
																		// 3. the "E*2 = q/8 = |e| * 2" it to offset the number when noise is negative.
																		// This is to fulfill the nearest integer rounding that is required by the 
																		// algorithm, with only integer operation and no comparison involved. 
			p_text.m = p_text.m * t / q;
			return p_text;
		#endif
	}

	LWE_plaintext LWE_decrypt_2(const LWE_secretkey &s, const LWE_ciphertext &c){
		LWE_plaintext p_text;
		p_text.m = c.b;
		for(int i = 0; i < n; i++){
			p_text.m = mod_pow2(p_text.m - c.a[i] * s.a[i], q);
		}
		p_text.m = mod_pow2(p_text.m + (E * 2), q);
		p_text.m = p_text.m * 2 / q; // changed plaintext modulus t to 2
		return p_text;
	}

	LWE_ciphertext LWE_evaluate(const LWE_ciphertext &c1, const LWE_ciphertext &c2, const GATES gate){
		LWE_ciphertext c_text;
		if(gate == XOR || gate == XNOR){
		//for XOR and XNOR the evaluation is done by 2*(c1-c2) mod q, but should I give tigher noise bound for this?
			c_text.b = mod_pow2(2 * (c1.b - c2.b), q);	// no need to add q/8, it's added while decrypt
																					// and no need to add q/2, it's done by changing the maping range
			for(int i = 0; i < n; i++){
				c_text.a[i] = mod_pow2(2 * (c1.a[i] - c2.a[i]), q);
			}

		}else{
		//for other gates OR/AND/NOR/NAND, use (c1+c2) mod q
			c_text.b = mod_pow2(c1.b + c2.b, q);	// no need to add q/8, it's added while decrypt
													// and no need to add q/2, it's done by changing the maping range
			for(int i = 0; i < n; i++){
				c_text.a[i] = mod_pow2(c1.a[i] + c2.a[i], q);
			}
		}
		return c_text;
	}

	LWE_ciphertext LWE_eval_NOT(const LWE_ciphertext &c){
		LWE_ciphertext c_text;
		for(int i = 0; i < n; i++){
			c_text.a[i] = mod_pow2(q - c.a[i], q);
		}
		c_text.b = mod_pow2((q / 4) - c.b, q);
		return c_text;
	}

	LWE_ciphertext LWE_keyswitch(const RLWE::RLWE_ciphertext &RLWE_ctext, const keyswitch_key &kskey){
		LWE_ciphertext new_ctext;
		RLWE::RLWE_ciphertext old_ctext = RLWE_ctext;
		//first transpose the RLWE ciphertext
		old_ctext.NTT_a_transpose();
		old_ctext.to_time_domain();
		ciphertext_t Q8 = Q/8 + 1;
		new_ctext.b = mod_general(old_ctext.b[0] + Q8, Q); 	//not sure why Q/8 + 1, instead of Q/8
		for(int i = 0; i < N; i++){
			ciphertext_t atmp = old_ctext.a[i];
			for(uint32_t j = 0; j < digitKS; j++){
				ciphertext_t a_dcomp = atmp % Bks;	//uses positive number decompose
				for(int k = 0; k < n; k++){
					new_ctext.a[k] = mod_general((signed_ciphertext_t)new_ctext.a[k] - (signed_ciphertext_t)kskey.kskey[a_dcomp][j][i].a[k], Q);	//not sure why has to be signed 
				}
				new_ctext.b = mod_general((signed_ciphertext_t)new_ctext.b - (signed_ciphertext_t)kskey.kskey[a_dcomp][j][i].b, Q);
				atmp /= Bks;
			}
		}
		return(new_ctext);	
	}

	ciphertext_t scale_round(ciphertext_t input, ciphertext_t new_mod, ciphertext_t old_mod){
		// in the PALISADE library, it is implemented with double type
		// I converted it into integer operation here
		// need to be verifyed, seems to work
		return((ciphertext_t)(((long_ciphertext_t)old_mod + 2*(long_ciphertext_t)input*(long_ciphertext_t)new_mod)/(2*(long_ciphertext_t)old_mod)));
	}

	LWE_ciphertext LWE_modswitch(const LWE_ciphertext &c_text){
		LWE_ciphertext tmp;
		for(int i = 0; i < n; i++){
			tmp.a[i] = scale_round(c_text.a[i], q, Q);
		}
		tmp.b = scale_round(c_text.b, q, Q);
		return(tmp);
	}
}
