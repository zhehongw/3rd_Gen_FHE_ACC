#include "app.h"

namespace application{
	substitute_key::substitute_key(const RLWE::RLWE_secretkey &sk_in, RNG_uniform &uni_dist, RNG_norm &norm_dist){
		std::vector<RLWE::RLWE_secretkey> key_vector(digitN);
		RLWE::RLWE_secretkey sk = sk_in;
		sk.to_time_domain();
		for(int i = 0; i < digitN; i++){
			RLWE::RLWE_secretkey tmp_key;
			tmp_key.NTT_form = false;
			RLWE::poly_substitute(sk.a.data(), i, N, Q, tmp_key.a.data());
			RLWE::poly_substitute(sk.b.data(), i, N, Q, tmp_key.b.data());
			tmp_key.to_freq_domain();
			
			key_vector[i] = std::move(tmp_key);
		}
		sk.to_freq_domain();
		std::vector<RLWE::keyswitch_key> ks_vector(digitN);
		for(int i = 0; i < digitN; i++){
			RLWE::keyswitch_key tmp_ks_key(key_vector[i], sk, uni_dist, norm_dist);
			ks_vector[i] = std::move(tmp_ks_key);
		}
		subs_key = std::move(ks_vector);
	}	

	std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> expand_RLWE(const RLWE::RLWE_ciphertext &c1, const substitute_key &subs_key){
		std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> result = std::make_unique<std::vector<RLWE::RLWE_ciphertext>>(N);
		(*result)[0] = c1;
		int inner_loop = 1; 	//2 to the power of i
		for(uint16_t i = 0; i < digitN; i++){
			for(int j = 0; j < inner_loop; j++){
				//auto bf_subs = std::chrono::high_resolution_clock::now();
				RLWE::RLWE_ciphertext subs = RLWE::RLWE_keyswitch(RLWE::RLWE_substitute((*result)[j], i), subs_key.subs_key[i]);
				//auto af_subs = std::chrono::high_resolution_clock::now();
				//std::cout << "RLWE subs takes " << std::chrono::duration_cast<std::chrono::microseconds>(af_subs - bf_subs).count() << " us" << std::endl;
				//used for generating verification data for hardware
				//if(i == 0) {
				//	std::cout << "RLWE key switch key" << std::endl;
				//	for(uint16_t m = 0; m < digitKS_R; m++){
				//		std::cout << "RLWE " << m << std::endl;
				//		std::cout << "poly a" << std::endl;
				//		for(int k = 0; k < N; k++) {
				//			std::cout << std::hex << std::uppercase << std::setw(14) << std::setfill('0') << subs_key.subs_key[i].RLWE_kskey[m].a[k] << std::endl;
				//		}
				//		std::cout << "poly b" << std::endl;
				//		for(int k = 0; k < N; k++) {
				//			std::cout << std::hex << std::uppercase << std::setw(14) << std::setfill('0') << subs_key.subs_key[i].RLWE_kskey[m].b[k] << std::endl;
				//		}
				//	}
				//	std::cout << "RLWE input" << std::endl;
				//	std::cout << "poly a" << std::endl;
				//	for(int k = 0; k < N; k++) {
				//		std::cout << std::hex << std::uppercase << std::setw(14) << std::setfill('0') << (*result)[0].a[k] << std::endl;
				//	}
				//	std::cout << "poly b" << std::endl;
				//	for(int k = 0; k < N; k++) {
				//		std::cout << std::hex << std::uppercase << std::setw(14) << std::setfill('0') << (*result)[0].b[k] << std::endl;
				//	}
				//	std::cout << "RLWE output" << std::endl;
				//	std::cout << "poly a" << std::endl;
				//	for(int k = 0; k < N; k++) {
				//		std::cout << std::hex << std::uppercase << std::setw(14) << std::setfill('0') << subs.a[k] << std::endl;
				//	}
				//	std::cout << "poly b" << std::endl;
				//	for(int k = 0; k < N; k++) {
				//		std::cout << std::hex << std::uppercase << std::setw(14) << std::setfill('0') << subs.b[k] << std::endl;
				//	}
				//}
				RLWE::RLWE_ciphertext tmp 	= (*result)[j];
				(*result)[j] 				= RLWE::RLWE_addition(tmp, subs);
				(*result)[j + inner_loop] 	= RLWE::RLWE_rotate_freq(RLWE::RLWE_subtraction(tmp, subs), i, false);
			}
			inner_loop *= 2;
		}
		return(result);
	}

	std::shared_ptr<std::vector<RLWE::RGSW_ciphertext>> homo_expand(const std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> &packed_bits, const RLWE::RGSW_ciphertext &enc_sec, const substitute_key &subs_key){
		auto result = std::make_shared<std::vector<RLWE::RGSW_ciphertext>>(N);
		std::vector<std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>>> unpacked_bits(digitG);
		for(uint16_t i = 0; i < digitG; i++){
			unpacked_bits[i] = expand_RLWE((*packed_bits)[i], subs_key);
		}
		for(uint16_t i = 0; i < N; i++){
			std::vector<std::vector<RLWE::RLWE_ciphertext>> vec_tmp(digitG);
			for(uint16_t j = 0; j < digitG; j++){
				std::vector<RLWE::RLWE_ciphertext> RLWE_vec(2);
				RLWE_vec[0] = std::move(RLWE::RLWE_mult_RGSW((*(unpacked_bits[j]))[i], enc_sec));
				RLWE_vec[1] = std::move((*(unpacked_bits[j]))[i]);
				vec_tmp[j] = std::move(RLWE_vec);	
			}
			RLWE::RGSW_ciphertext RGSW_tmp(vec_tmp);
			(*result)[i] = std::move(RGSW_tmp);
		}
		return(result);
	}

}
