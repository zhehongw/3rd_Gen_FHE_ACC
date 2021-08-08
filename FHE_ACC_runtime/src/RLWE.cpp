#include "RLWE.h"
using namespace std;

namespace RLWE{
	void poly_mult(const ciphertext_t *NTT_a1, const ciphertext_t *NTT_a2, const int length, const ciphertext_t modulo, ciphertext_t *NTT_a3){
		for(int i = 0; i < length; i++){
			NTT_a3[i] = mod_general((long_ciphertext_t)NTT_a1[i] * (long_ciphertext_t)NTT_a2[i],  modulo);
		}
	}
	
	void poly_add(const ciphertext_t *NTT_a1, const ciphertext_t *NTT_a2, const int length, const ciphertext_t modulo, ciphertext_t *NTT_a3){
		for(int i = 0; i < length; i++){
			NTT_a3[i] = mod_general(NTT_a1[i] + NTT_a2[i], modulo);
		}
	}

	void poly_subtraction(const ciphertext_t *NTT_a1, const ciphertext_t *NTT_a2, const int length, const ciphertext_t modulo, ciphertext_t *NTT_a3){
		for(int i = 0; i < length; i++){
			NTT_a3[i] = mod_general((signed_ciphertext_t)NTT_a1[i] - (signed_ciphertext_t)NTT_a2[i], modulo);
		}
	}

	void poly_substitute(const ciphertext_t *a1, const int sub_factor, const int length, const ciphertext_t modulo, ciphertext_t *a_out){
		int32_t power = (length >> sub_factor) + 1;	//the power of x to be substituted 

		for(int32_t i = 0; i < length; i++){
			int32_t i_out = (i * power) % (int32_t)length;
			if(((i * power / length) % 2 ) == 1){
				a_out[i_out] = (modulo - a1[i]) % modulo;	//if flag is true, get the inverse of the number. Generally, 
																//"modulo - a1[i]" is goog enough, but "% modulo" is added 
																//to cover corner case of a1[i] = 0. Without the mod it 
																//would evaluate to modulo, which is wrong.
			}else{
				a_out[i_out] = a1[i];						//else just keep the value unchanged
			}	
		}
	}

	void reverse_array(ciphertext_t *a1, int start, int end){
		while(start < end){
			ciphertext_t tmp = a1[start];
			a1[start] = a1[end];
			a1[end] = tmp;
			start++;
			end--;
		}
	}

	void poly_rotate_time(ciphertext_t *a1, const int rotate_factor, const int length, const ciphertext_t modulo){
		int rf = rotate_factor % length;	//reduce the rotate factor to less than length
		if(rf == 0) return;
											//here I did not take N into account
		if(rf > 0){
			for(int i = length -1; i >= (length-rf); i--){
				a1[i] = mod_general(-(signed_ciphertext_t)a1[i], modulo);
			}
			reverse_array(a1, 0, length - 1);
			reverse_array(a1, 0, rf - 1);
			reverse_array(a1, rf, length - 1);
		} else {
			for(int i = 0; i < (-rf); i++){
				a1[i] = mod_general(-(signed_ciphertext_t)a1[i], modulo);
			}
			reverse_array(a1, 0, (-rf) - 1);
			reverse_array(a1, -rf, length - 1);
			reverse_array(a1, 0, length - 1);
		}
	}


	RLWE_plaintext::RLWE_plaintext(std::vector<ciphertext_t> m_in, bool is_NTT){
		for(int i = 0; i < N; i++){
			m[i] = m_in[i];
		}

		if(is_NTT){
			NTT_form = true;
		}else{
			NTT(m.data(), N, Q, ROU_table);	//in place version of NTT
			NTT_form = true;
		}

		max_noise = 0;
	}

	RLWE_plaintext::RLWE_plaintext(std::vector<ciphertext_t> m_in, ciphertext_t t_RLWE){
		for(int i = 0; i < N; i++){
			m[i] = mod_general((long_ciphertext_t)m_in[i] * (long_ciphertext_t)(Q / t_RLWE), Q);
		}
		NTT(m.data(), N, Q, ROU_table);
		NTT_form = true;
		max_noise = 0;
	}

	void RLWE_plaintext::to_freq_domain(){
		if(!NTT_form){
			NTT(m.data(), N, Q, ROU_table);
			NTT_form = true;
		}
	}

	void RLWE_plaintext::to_time_domain(){
		if(NTT_form){
			iNTT(m.data(), N, Q, iROU_table, iN);
			NTT_form = false;
		}
	}

	void RLWE_plaintext::denoise(){
		this->to_time_domain();

		ciphertext_t Q8 = Q / 8 + 1;
		ciphertext_t negQ8 = Q - Q8;

		#ifdef DEBUG 
			ciphertext_t noise;		//for debug purpose
		#endif

		for(int i = 0; i < N; i++){
			// the coefficients of the polynomail are always Q/8 or -Q/8, 
			// so this decryption only decrypt to these two number
			#ifdef DEBUG
				ciphertext_t tmp = (ciphertext_t)abs((signed_ciphertext_t)m[i] - (signed_ciphertext_t)((m[i] > Q / 2)? negQ8 : Q8));		//for debug purpose
				noise = tmp > noise ? tmp : noise;	//for debug purpose
			#endif

			m[i] = (m[i] > Q / 2)? negQ8 : Q8;	// to remove the noise in the lower bits
		}
		
		#ifdef DEBUG
			cout << "max noise is: " << noise << "\n" << endl; //for debug purpose
			max_noise = noise;
		#endif
		//get the clean NTT_m with no noise
		//this->to_freq_domain();
	}

	void RLWE_plaintext::denoise(ciphertext_t t_RLWE){
		this->to_time_domain();
		ciphertext_t noise = 0;		//for debug purpose
		ciphertext_t scale = Q / t_RLWE;	
		for(int i = 0; i < N; i++){
			ciphertext_t tmp = m[i];		//for debug purpose
			
			m[i] = mod_general(m[i] + (scale / 2), Q);	// to offset the noise in the lower bits
			m[i] = mod_general(m[i] / scale, Q);
			tmp = (ciphertext_t)abs((signed_ciphertext_t)tmp - (signed_ciphertext_t)mod_general((long_ciphertext_t)m[i] * (long_ciphertext_t)(Q / t_RLWE), Q));	
			tmp = (tmp > Q / 2) ? (Q - tmp) : tmp;
			noise = tmp > noise ? tmp : noise;	//for debug purpose
		}
		//cout << "max noise is: " << noise << "\n" << endl; //for debug purpose
		max_noise = noise;
		//get the clean NTT_m with no noise
		//this->to_freq_domain();
	}

	void RLWE_plaintext::display() const{

		cout << "m is" << (NTT_form ? " " : " not ") << "in NTT domain: " << endl;
		for(int i = 0 ; i < N; i++){
			cout << m[i] << "\n";
		}
		cout << endl;
	}

	RLWE_ciphertext::RLWE_ciphertext(const std::vector<ciphertext_t> &a_in, const std::vector<ciphertext_t> &b_in, bool is_NTT){
		for(int i = 0; i < N; i++){
			a[i] = a_in[i];
			b[i] = b_in[i];
		}
		if(is_NTT){
			NTT_form = true;
		}else{
			NTT(a.data(), N, Q, ROU_table);
			NTT(b.data(), N, Q, ROU_table);
			NTT_form = true;
		}
	}

	void RLWE_ciphertext::to_freq_domain(){
		if(!NTT_form){
			NTT(a.data(), N, Q, ROU_table);
			NTT(b.data(), N, Q, ROU_table);
			NTT_form = true;
		}
	}

	void RLWE_ciphertext::to_time_domain(){
		if(NTT_form){
			iNTT(a.data(), N, Q, iROU_table, iN);
			iNTT(b.data(), N, Q, iROU_table, iN);
			NTT_form = false;
		}
	}

	void RLWE_ciphertext::add_to_a(const RLWE_plaintext &input){
		this->to_freq_domain();
		if(input.NTT_form){
			poly_add(a.data(), input.m.data(), N, Q, a.data());
		} else {
			std::vector<ciphertext_t> tmp;
			NTT(input.m.data(), N, Q, ROU_table, tmp.data());
			poly_add(a.data(), tmp.data(), N, Q, a.data());
		}
	}

	void RLWE_ciphertext::add_to_b(const RLWE_plaintext &input){
		this->to_freq_domain();
		if(input.NTT_form){
			poly_add(b.data(), input.m.data(), N, Q, b.data());
		} else {
			std::vector<ciphertext_t> tmp;
			NTT(input.m.data(), N, Q, ROU_table, tmp.data());
			poly_add(b.data(), tmp.data(), N, Q, b.data());
		}
	}

	void RLWE_ciphertext::NTT_a_transpose(){
		this->to_freq_domain();
		ciphertext_t tmp;
		for(int i = 0; i < N/2; i++){
			tmp = a[i];
			a[i] = a[N-1-i];
			a[N-1-i] = tmp;
		}
	}

	void RLWE_ciphertext::display() const{
		cout << "b is in NTT form: " << NTT_form << endl;
		for(int i = 0; i < N; i++){
			cout << b[i] << "\n";
		}
		cout << endl;

		cout << "a is in NTT form:" << NTT_form << endl;;
		for(int i = 0; i < N; i++){
			cout << a[i] << "\n";
		}
		cout << endl;
	}


	RLWE_secretkey::RLWE_secretkey(RNG_uniform &uni_dist){
		signed_ciphertext_t s;
		ciphertext_t ss;

		#ifdef DEBUG
			int count = 0;
		#endif

		do{
			s = 0;
			ss = 0;
			for(int i = 0; i < N; i++){
				signed_ciphertext_t tmp = uni_dist.generate_uniform() % (signed_ciphertext_t)Q;
				b[i] = 0;
				//cout << a[i] << " ";
				s += tmp;
				ss += abs(tmp);
				a[i] = mod_general(tmp, Q);
			}
			//cout << endl;
		#ifdef DEBUG
				cout << "s = " << s << endl;
				cout << "ss = " << ss << endl;
				count++;
		}while((abs(s) > 200 || ss > 1300) && count < 3);//this comparison bound should be tested	
		#else
		}while(abs(s) > 200 || ss > 1300);	// ss range is too small in most cases, check definition
												// if ss is uniform from {-1, 0, 1} then the mean would 
												// be 1000/3, way larger than 100
												// use normal distribution to fix this
		#endif

		b[0] = 1;
		NTT(a.data(), N, Q, ROU_table);
		NTT(b.data(), N, Q, ROU_table);
		NTT_form = true;
	}

	RLWE_secretkey::RLWE_secretkey(std::vector<ciphertext_t> a_in){
	// another constructor that initialize the vector a from a input vector
		for(int i = 0; i < N; i++) {
			a[i] = a_in[i];
			b[i] = 0;
		}
		b[0] = 1;
		NTT(a.data(), N, Q, ROU_table);
		NTT(b.data(), N, Q, ROU_table);
		NTT_form = true;
	}

	keyswitch_key::keyswitch_key(const RLWE_secretkey &old_key, const RLWE_secretkey &new_key, RNG_uniform &uni_dist, RNG_norm &norm_dist){
		if(!old_key.NTT_form || !new_key.NTT_form){
			std::cout << "input keys are not in NTT form" << std::endl;
		}
		std::vector<RLWE_ciphertext> v(digitKS_R);
		RLWE_secretkey tmp_key = old_key;

		for(uint32_t i = 0; i < digitKS_R; i++){
			RLWE_ciphertext c0;

			for(int j = 0; j < N; j++){
				c0.a[j] = mod_general(uni_dist.generate_uniform(), Q);
				c0.b[j] = mod_general(norm_dist.generate_norm(E_rlwe), Q);
				//c0.b[j] = 0;	//added for debug purpose
			}
			c0.NTT_form = false;
			c0.to_freq_domain();
			
			for(int j = 0; j < N; j++){
				c0.b[j] = mod_general((long_ciphertext_t)c0.a[j] * (long_ciphertext_t)new_key.a[j] + (long_ciphertext_t)c0.b[j] + (long_ciphertext_t)tmp_key.a[j], Q);
			}
			//c0.to_time_domain();
			v[i] = std::move(c0);

			for(int j = 0; j < N; j++){
				tmp_key.a[j] = mod_general((long_ciphertext_t)Bks_R * (long_ciphertext_t)tmp_key.a[j], Q);
			}
		}
		RLWE_kskey = std::move(v);
	}

	RLWE_ciphertext RLWE_encrypt(const RLWE_secretkey &s, const RLWE_plaintext &p, RNG_uniform &uni_dist, RNG_norm &norm_dist){
		if(!s.NTT_form || !p.NTT_form){
			std::cout << "secret key or plaintext is not in NTT format" << std::endl;
		}

		RLWE_ciphertext c_text;
		for(int i = 0; i < N; i++){
			c_text.a[i] = mod_general(uni_dist.generate_uniform(), Q);
			c_text.b[i] = mod_general(norm_dist.generate_norm(E_rlwe), Q);
			//c_text.b[i] = 0;	//added for debug purpose
		}
		c_text.NTT_form = false;
		c_text.to_freq_domain();

		for(int i = 0; i < N; i++){
			c_text.b[i] = mod_general((long_ciphertext_t)c_text.a[i] * (long_ciphertext_t)s.a[i] + (long_ciphertext_t)c_text.b[i] + (long_ciphertext_t)p.m[i], Q);	//this works with encoded m, so no scaling with Q/t
		}
		//c_text.to_time_domain();

		return(c_text);
	}

	RLWE_plaintext RLWE_decrypt(const RLWE_secretkey &s, const RLWE_ciphertext &c){
		if(!s.NTT_form || !c.NTT_form){
			std::cout << "secret key or the ciphertext is not in NTT form" << std::endl;
		}
		RLWE_plaintext p_text;
		for(int i = 0; i < N; i++){
			p_text.m[i] = mod_general((long_ciphertext_t)c.a[i] * (long_ciphertext_t)s.a[i], Q);
			p_text.m[i] = mod_general((signed_long_ciphertext_t)c.b[i] - (signed_long_ciphertext_t)p_text.m[i], Q);
			//p_text.m[i] = mod_general(c.b[i] - p_text.m[i], Q);
		}
		p_text.NTT_form = true;
		//p_text.to_time_domain();
		p_text.denoise();		//removed for debug purpose
		return(p_text);
	}

	RLWE_plaintext RLWE_decrypt(const RLWE_secretkey &s, const RLWE_ciphertext &c, const ciphertext_t t_RLWE){
		if(!s.NTT_form || !c.NTT_form){
			std::cout << "secret key or the ciphertext is not in NTT form" << std::endl;
		}
		RLWE_plaintext p_text;
		for(int i = 0; i < N; i++){
			p_text.m[i] = mod_general((long_ciphertext_t)c.a[i] * (long_ciphertext_t)s.a[i], Q);
			p_text.m[i] = mod_general((signed_long_ciphertext_t)c.b[i] - (signed_long_ciphertext_t)p_text.m[i], Q);
		}
		p_text.NTT_form = true;
		//p_text.to_time_domain();
		p_text.denoise(t_RLWE);		//removed for debug purpose
		return(p_text);
	}

	RLWE_ciphertext RLWE_addition(const RLWE_ciphertext &c1, const RLWE_ciphertext &c2){
		if(!c1.NTT_form || !c2.NTT_form){
			std::cout << "one of the operand is not in NTT format" << std::endl;
		}
		RLWE_ciphertext c_text;
		poly_add(c1.a.data(), c2.a.data(), N, Q, c_text.a.data());
		poly_add(c1.b.data(), c2.b.data(), N, Q, c_text.b.data());
		c_text.NTT_form = true;

		return(c_text);
	}
	
	RLWE_ciphertext RLWE_subtraction(const RLWE_ciphertext &c1, const RLWE_ciphertext &c2){
		if(!c1.NTT_form || !c2.NTT_form){
			std::cout << "one of the operand is not in NTT format" << std::endl;
		}
		RLWE_ciphertext c_text;
		poly_subtraction(c1.a.data(), c2.a.data(), N, Q, c_text.a.data());
		poly_subtraction(c1.b.data(), c2.b.data(), N, Q, c_text.b.data());
		c_text.NTT_form = true;

		return(c_text);
	}	

	RLWE_ciphertext RLWE_rotate_time(const RLWE_ciphertext &c1, const int rotate_factor){
		RLWE_ciphertext tmp = c1;
		tmp.to_time_domain();
		poly_rotate_time(tmp.a.data(), rotate_factor, N, Q);
		poly_rotate_time(tmp.b.data(), rotate_factor, N, Q);
		// this function does not update freq domain, postpone the NTT until necessary
		//tmp.to_freq_domain();
		return(tmp);
	}

	RLWE_ciphertext RLWE_rotate_freq(const RLWE_ciphertext &c1, const int log_rotate_factor, const bool forward){
		if(!c1.NTT_form){
			std::cout << "input is not in NTT format" << std::endl;
		}
		RLWE_ciphertext tmp;
		if(forward){
			for(int i = 0; i < N; i++){
				tmp.a[i] = mod_general((long_ciphertext_t)c1.a[i] * (long_ciphertext_t)rotate_poly_forward[log_rotate_factor][i], Q);
				tmp.b[i] = mod_general((long_ciphertext_t)c1.b[i] * (long_ciphertext_t)rotate_poly_forward[log_rotate_factor][i], Q);
			}
		} else {
			for(int i = 0; i < N; i++){
				tmp.a[i] = mod_general((long_ciphertext_t)c1.a[i] * (long_ciphertext_t)rotate_poly_backward[log_rotate_factor][i], Q);
				tmp.b[i] = mod_general((long_ciphertext_t)c1.b[i] * (long_ciphertext_t)rotate_poly_backward[log_rotate_factor][i], Q);
			}
		}
		tmp.NTT_form = true;
		//tmp.to_time_domain();
		return(tmp);
	}

	RLWE_ciphertext RLWE_mult_NTT_poly(const RLWE_ciphertext &c1, const std::vector<ciphertext_t> NTT_poly){
		RLWE_ciphertext tmp;
		for(int i = 0; i < N; i++){
			tmp.a[i] = mod_general((long_ciphertext_t)c1.a[i] * (long_ciphertext_t)NTT_poly[i], Q);
			tmp.b[i] = mod_general((long_ciphertext_t)c1.b[i] * (long_ciphertext_t)NTT_poly[i], Q);
		}	
		tmp.NTT_form = true;
		//this function does not update the time domain, postpone until necessary
		//tmp.to_time_domain();
		return(tmp);
	}

	RLWE_ciphertext RLWE_substitute(const RLWE_ciphertext c1, const int sub_factor){
		if(c1.NTT_form){
			RLWE_ciphertext in = c1;
			in.to_time_domain();
			RLWE_ciphertext tmp;
			poly_substitute(in.a.data(), sub_factor, N, Q, tmp.a.data());
			poly_substitute(in.b.data(), sub_factor, N, Q, tmp.b.data());
			tmp.NTT_form = false;	
			tmp.to_freq_domain();
			return(tmp);
		} else {
			RLWE_ciphertext tmp;
			poly_substitute(c1.a.data(), sub_factor, N, Q, tmp.a.data());
			poly_substitute(c1.b.data(), sub_factor, N, Q, tmp.b.data());
			tmp.NTT_form = false;	
			tmp.to_freq_domain();
			return(tmp);
		}
	}

	RLWE_ciphertext RLWE_keyswitch(const RLWE_ciphertext &c, const keyswitch_key &kskey){
		if(!c.NTT_form){
			std::cout << "input is not in NTT form" << std::endl;
		}
		RLWE_ciphertext output;
		for(int i = 0; i < N; i++){
			output.b[i] = c.b[i];
		}
		output.NTT_form = true;

		std::vector<RLWE_ciphertext> decomp = digit_decompose(c, digitKS_R, Bks_R_mask, Bks_R_bits);
	
		//RLWE_ciphertext temp;
		//temp.NTT_form = true;	
		for(uint32_t i = 0; i < digitKS_R; i++){
			RLWE_ciphertext mult = RLWE_mult_NTT_poly(kskey.RLWE_kskey[i], decomp[i].a);
			//used for generating verification data for hardware
			//std::cout << "in RLWE keyswitch loop " << i << std::endl;	
			//std::cout << "decomposed poly a " << i << std::endl;
			//for(int k = 0; k < N; k++) {
			//	std::cout << std::hex << std::uppercase << std::setw(14) << std::setfill('0') << decomp[i].a[k] << std::endl;
			//}

			//std::cout << "multed RLWE poly a " << i << std::endl;
			//for(int k = 0; k < N; k++) {
			//	std::cout << std::hex << std::uppercase << std::setw(14) << std::setfill('0') << mult.a[k] << std::endl;
			//}
			//std::cout << "multed RLWE poly b " << i << std::endl;
			//for(int k = 0; k < N; k++) {
			//	std::cout << std::hex << std::uppercase << std::setw(14) << std::setfill('0') << mult.b[k] << std::endl;
			//}

			//temp = RLWE_addition(temp, mult);
			//std::cout << "acced RLWE poly a " << i << std::endl;
			//for(int k = 0; k < N; k++) {
			//	std::cout << std::hex << std::uppercase << std::setw(14) << std::setfill('0') << temp.a[k] << std::endl;
			//}
			//std::cout << "acced RLWE poly b " << i << std::endl;
			//for(int k = 0; k < N; k++) {
			//	std::cout << std::hex << std::uppercase << std::setw(14) << std::setfill('0') << temp.b[k] << std::endl;
			//}
			output = RLWE_subtraction(output, mult);
		}
		//output = RLWE_subtraction(output, temp);
		//output.to_time_domain();
		return(output);
	}

	RGSW_plaintext::RGSW_plaintext(const ciphertext_t m_in){
		ciphertext_t mm = (((m_in % q) + q) % q) * (2 * N / q);	// transfer input number into a positive number within [0, q-1]
																// and multiply it by 2N/q to embed it into [0, 2N-1]
		RLWE_plaintext tmp;
		ciphertext_t sign = 1;
		if(mm >= (ciphertext_t)N){	//embed mm into the [0, N-1] since the polynomail is only N order,
						//and use the sign as another indicator to cover [0, 2N-1]
			mm -= N;
			sign = Q - 1;	// equals to -1 mod Q
		}
		tmp.m[mm] = sign;
		tmp.NTT_form = false;
		tmp.to_freq_domain();
		m = tmp;
	}

	RGSW_plaintext::RGSW_plaintext(const bool m_in){
		RLWE_plaintext tmp;
		tmp.m[0] = ciphertext_t(m_in);	//only encrypts one bit
		tmp.NTT_form = false;
		tmp.to_freq_domain();
		m = tmp;
	}
	
	RGSW_plaintext::RGSW_plaintext(const RLWE_plaintext &m_in){
		m = m_in;
		m.to_freq_domain();
	}

	void RGSW_plaintext::mult_constant_number(const ciphertext_t pBG){
		for(int i = 0; i < N; i++){
			m.m[i] = mod_general((long_ciphertext_t)pBG * (long_ciphertext_t)m.m[i], Q);
			//m.NTT_m[i] = mod_general((long_ciphertext_t)pBG * (long_ciphertext_t)m.NTT_m[i], Q);
		}
	}


	RGSW_ciphertext::RGSW_ciphertext(){
		std::vector<std::vector<RLWE_ciphertext>> c_tmp(digitG);
		
		for(uint32_t i = 0; i < digitG; i++){
			std::vector<RLWE_ciphertext> c_row(2);	// to use std::move, need to redefine a vector in each loop
			c_tmp[i] = std::move(c_row);
		}
		c_text = std::move(c_tmp);
	}



	RGSW_ciphertext::RGSW_ciphertext(const RGSW_plaintext &m_in, const RLWE_secretkey &z, RNG_uniform &uni_dist, RNG_norm &norm_dist){
		RGSW_plaintext m = m_in;
		RLWE_plaintext dummy; //dummy RLWE_plaintext, equal to zero, in NTT form
		std::vector<std::vector<RLWE_ciphertext>> c_tmp(digitG);
		
		for(uint32_t i = 0; i < digitG; i++){
			std::vector<RLWE_ciphertext> c_row(2);	// to use std::move, need to redefine a vector in each loop
			c_row[0] = RLWE_encrypt(z, dummy, uni_dist, norm_dist);
			c_row[0].add_to_a(m.m);
			c_row[1] = RLWE_encrypt(z, dummy, uni_dist, norm_dist);
			c_row[1].add_to_b(m.m);
			c_tmp[i] = std::move(c_row);
			m.mult_constant_number(BG);
		}

		c_text = std::move(c_tmp);
	}

	bootstrap_key::bootstrap_key(const LWE::LWE_secretkey &s_in, const RLWE_secretkey &z_in, RNG_uniform &uni_dist, RNG_norm &norm_dist){
		ciphertext_t powbr;
		std::vector<std::vector<std::vector<RGSW_ciphertext>>> btkey_tmp(Br);

		for(uint32_t i = 0; i < Br; i++){
			std::vector<std::vector<RGSW_ciphertext>> bt_d2(digitR);
			powbr = 1;
			for(uint32_t j = 0; j < digitR; j++){
				std::vector<RGSW_ciphertext> bt_d3(n);
				for(int k = 0; k < n; k++){
					RGSW_plaintext tmp = RGSW_plaintext(mod_pow2(mod_pow2(i * powbr, q) * s_in.a[k], q));	//in the PALISADE implementation, there is a signed convertion here, 
																					//but I don't think it's necessary here, 
																					//since the signed number is handled in the constructor of RGSW_plaintext. 
																					//furthermore, the s_in.a[j] is already converted from signed to unsigned, 
																					//there's no need to convert it back.
																					//the signed conversion only need to take place in two sites I think, 
																					//one is the construction of the secret keys and ciphertexts, 
																					//another is when converting between mod q and mod Q with Q not a power of 2, 
					RGSW_ciphertext c_tmp = RGSW_ciphertext(tmp, z_in, uni_dist, norm_dist);
					bt_d3[k] = std::move(c_tmp);
				}
				bt_d2[j] = std::move(bt_d3);
				powbr = mod_pow2(powbr * Br, q);
			}
			btkey_tmp[i] = std::move(bt_d2);
		}
		btkey = std::move(btkey_tmp);
	}


	// need to add a poly decompose function that only works on poly, rather than RLWE ciphertext
	//void poly_digit_decompose(const ciphertext_t *NTT_poly, ciphertext_t **decomp_poly, const ciphertext_t decomp_length, const ciphertext_t mod_mask, const ciphertext_t division_bits){
	//	ciphertext_t iNTT_poly[N];
	//	iNTT(NTT_poly, N, Q, iROU_table, iN, iNTT_poly);
	//	
	//	for(uint32_t i = 0; i < decomp_length; i++){
	//		for(int j = 0; j < N; j++){
	//			decomp_poly[i][j] = iNTT_poly[j] & mod_mask;
	//			iNTT_poly[j] >>= division_bits;
	//		}
	//		NTT(decomp_poly[i], N, Q, ROU_table);
	//	}
	//}

		std::vector<RLWE_ciphertext> digit_decompose(const RLWE_ciphertext &RLWE_ctext, const ciphertext_t decomp_length, const ciphertext_t mod_mask, const ciphertext_t division_bits){
		std::vector<RLWE_ciphertext> RLWE_prime_c(decomp_length);
		RLWE_ciphertext RLWE_c = RLWE_ctext;
		RLWE_c.to_time_domain();
		for(int i = 0; i < N; i++){
			for(uint32_t j = 0; j < decomp_length; j++){
				RLWE_prime_c[j].a[i] = RLWE_c.a[i] & mod_mask;	//mod
				RLWE_c.a[i] >>= division_bits;					//division
				RLWE_prime_c[j].b[i] = RLWE_c.b[i] & mod_mask;
				RLWE_c.b[i] >>= division_bits;
			}
		}
		for(uint32_t i = 0; i < decomp_length; i++){
			RLWE_prime_c[i].NTT_form = false;
			RLWE_prime_c[i].to_freq_domain();
		}
		return(RLWE_prime_c);
	}
	
	RLWE_ciphertext RLWE_mult_RGSW(const RLWE_ciphertext &acc, const RGSW_ciphertext &input){
		std::vector<RLWE_ciphertext> decomp = digit_decompose(acc, digitG, BG_mask, BGbits);
		RLWE_ciphertext tmp;
		for(uint32_t i = 0; i < digitG; i++){
			tmp = RLWE_addition(RLWE_mult_NTT_poly(input.c_text[i][0], decomp[i].a), tmp);
			tmp = RLWE_addition(RLWE_mult_NTT_poly(input.c_text[i][1], decomp[i].b), tmp);
		}
		//for(uint32_t i = 0; i < digitG; i++){
		//	std::cout << "in RLWE_mult_RGSW loop a, " << i << std::endl;
		//	std::cout << "decomposed " << i << " RLWE poly a" << std::endl;
		//	for(int j = 0; j < N; j++) {
		//		cout << hex << uppercase << setw(14) << setfill('0') << decomp[i].a[j] << endl;
		//	}
		//	std::cout << "RGSW " << i << ", " << 0 << " poly a" << std::endl;
		//	for(int j = 0; j < N; j++) {
		//		cout << hex << uppercase << setw(14) << setfill('0') << input.c_text[i][0].a[j] << endl;
		//	}
		//	std::cout << "RGSW " << i << ", " << 0 << " poly b" << std::endl;
		//	for(int j = 0; j < N; j++) {
		//		cout << hex << uppercase << setw(14) << setfill('0') << input.c_text[i][0].b[j] << endl;
		//	}
		//	
		//	tmp = RLWE_addition(RLWE_mult_NTT_poly(input.c_text[i][0], decomp[i].a), tmp);
		//	
		//	std::cout << "tmp acc" << i << ", " << 0 << " poly a" << std::endl;
		//	for(int j = 0; j < N; j++) {
		//		cout << hex << uppercase << setw(14) << setfill('0') << tmp.a[j] << endl;
		//	}
		//	std::cout << "tmp acc" << i << ", " << 0 << " poly b" << std::endl;
		//	for(int j = 0; j < N; j++) {
		//		cout << hex << uppercase << setw(14) << setfill('0') << tmp.b[j] << endl;
		//	}
		//}
		//for(uint32_t i = 0; i < digitG; i++){
		//	std::cout << "in RLWE_mult_RGSW loop b, " << i << std::endl;
		//	std::cout << "decomposed " << i << " RLWE poly b" << std::endl;
		//	for(int j = 0; j < N; j++) {
		//		cout << hex << uppercase << setw(14) << setfill('0') << decomp[i].b[j] << endl;
		//	}
		//	std::cout << "RGSW " << i << ", " << 1 << " poly a" << std::endl;
		//	for(int j = 0; j < N; j++) {
		//		cout << hex << uppercase << setw(14) << setfill('0') << input.c_text[i][1].a[j] << endl;
		//	}
		//	std::cout << "RGSW " << i << ", " << 1 << " poly b" << std::endl;
		//	for(int j = 0; j < N; j++) {
		//		cout << hex << uppercase << setw(14) << setfill('0') << input.c_text[i][1].b[j] << endl;
		//	}

		//	tmp = RLWE_addition(RLWE_mult_NTT_poly(input.c_text[i][1], decomp[i].b), tmp);

		//	std::cout << "tmp acc" << i << ", " << 0 << " poly a" << std::endl;
		//	for(int j = 0; j < N; j++) {
		//		cout << hex << uppercase << setw(14) << setfill('0') << tmp.a[j] << endl;
		//	}
		//	std::cout << "tmp acc" << i << ", " << 0 << " poly b" << std::endl;
		//	for(int j = 0; j < N; j++) {
		//		cout << hex << uppercase << setw(14) << setfill('0') << tmp.b[j] << endl;
		//	}
		//}
		tmp.NTT_form = true;
		//tmp.to_time_domain();
		return(tmp);
	}
	
	RLWE_ciphertext acc_initialization(const ciphertext_t &embed_factor, const ciphertext_t &bound1, const ciphertext_t &bound2, const ciphertext_t &value){
		//set the mapping results
		ciphertext_t Q8 = Q/8 + 1;
		ciphertext_t negQ8 = Q - Q8;
		
		RLWE_ciphertext acc;
		for(ciphertext_t i = 0; i < q2; i++){
			ciphertext_t tmp = mod_pow2((signed_ciphertext_t)value - (signed_ciphertext_t)i, q); 
			if(bound1 < bound2){
				acc.b[i*embed_factor] = ((tmp >= bound1) && (tmp < bound2)) ? negQ8 : Q8;
			}else{
				acc.b[i*embed_factor] = ((tmp >= bound2) && (tmp < bound1)) ? Q8 : negQ8;
			}
		}

		acc.NTT_form = false;
		acc.to_freq_domain();
		return(acc);
	}

	LWE::LWE_ciphertext eval_bootstrap(const LWE::LWE_ciphertext &c1, const LWE::LWE_ciphertext &c2, const bootstrap_key &btkey, const LWE::keyswitch_key &kskey, const GATES gate){
		if(c1 == c2){
			cout << "Please only use independent ciphertexts!!!" << endl;
			exit(1);
		}
		//evaluate the NAND 
		//auto start = std::chrono::high_resolution_clock::now();
		LWE::LWE_ciphertext c_text = LWE::LWE_evaluate(c1, c2, gate);	// hold the evaluation
	
		//auto after_eval = std::chrono::high_resolution_clock::now();
		//std::cout << "evaluate takes: " << std::chrono::duration_cast<std::chrono::milliseconds>(after_eval - start).count() << " ms" << endl;
		
		//set mapping range
		ciphertext_t q_bound1, q_bound2;
		q_bound1 = mod_pow2(gate_constant[gate], q);
		q_bound2 = mod_pow2(q_bound1 + q2, q); 

		//set embed factor from q to 2N
		ciphertext_t p = 2 * N / q;
		
		//initialize the accumulator 
		RLWE_ciphertext acc = acc_initialization(p, q_bound1, q_bound2, c_text.b);
		
		//auto after_init = std::chrono::high_resolution_clock::now();
		//std::cout << "acc init takes: " << std::chrono::duration_cast<std::chrono::milliseconds>(after_init - after_eval).count() << " ms" << endl;

		//start bootstrapping
		//1. accumulate
		for(int i = 0; i < n; i++){
			//ciphertext_t nega = mod_pow2(-((signed_ciphertext_t)c_text.a[i]), q);
			ciphertext_t nega = (q - c_text.a[i]) % q;	//addtive inverse of "a" equals to modulo - a
			for(uint32_t j = 0; j < digitR; j++){
				ciphertext_t residu = nega % Br;
					if(residu > 0){	//actually != 0 is good enough
						//auto bf_acc_mult = std::chrono::high_resolution_clock::now();
						acc = RLWE_mult_RGSW(acc, btkey.btkey[residu][j][i]);
						//auto af_acc_mult = std::chrono::high_resolution_clock::now();
						//std::cout << "acc mult takes: " << std::chrono::duration_cast<std::chrono::microseconds>(af_acc_mult - bf_acc_mult).count() << " us" << endl;
					}
				nega /= Br;
			}
		}
		
		//auto after_acc = std::chrono::high_resolution_clock::now();
		//std::cout << "acc takes: " << std::chrono::duration_cast<std::chrono::milliseconds>(after_acc - after_init).count() << " ms" << endl;

		//2.transfer acc to LWE ciphertext_t, key switch
		//in the PALISADE, the Q/8 is added to the coefficient of acc.b[0]
		//I incorporate it into the key switch function
		LWE::LWE_ciphertext lwe_modQ = LWE::LWE_keyswitch(acc, kskey);

		//auto after_key_switch = std::chrono::high_resolution_clock::now();
		//std::cout << "key switch takes: " << std::chrono::duration_cast<std::chrono::milliseconds>(after_key_switch - after_acc).count() << " ms" << endl;

		//3.mod switch from mod Q to mod q
		LWE::LWE_ciphertext result = LWE::LWE_modswitch(lwe_modQ);

		//auto after_mod_switch = std::chrono::high_resolution_clock::now();
		//std::cout << "mod switch takes: " << std::chrono::duration_cast<std::chrono::milliseconds>(after_mod_switch - after_key_switch).count() << " ms" << endl;
		return(result);
	}

	RLWE_ciphertext CMUX(const RLWE_ciphertext &c0, const RLWE_ciphertext &c1, const RGSW_ciphertext &SEL){
		RLWE_ciphertext diff = RLWE_subtraction(c1, c0);
		RLWE_ciphertext mult = RLWE_mult_RGSW(diff, SEL);
		RLWE_ciphertext result = RLWE_addition(mult, c0);
		return(result);
	}



	RLWE_ciphertext blind_rotate_full(const RLWE_ciphertext &c_in, const int b, const std::vector<int> &a, const std::vector<RGSW_ciphertext> &C){
		if(a.size() != C.size()){
			cout << "The sizes of rotation vector and control vector are not equal!!!" << endl;
			exit(1);
		}
		//rotate based on b, public
		RLWE_ciphertext acc;
		if(b != 0){
			acc = RLWE_rotate_time(c_in, b);
		}else{
			acc = c_in;
		}	
		acc.to_time_domain();
		// no need to update to freq domain here, postpone it until after all CMUX

		//rotate based on a, private
		for(uint32_t i = 0; i < a.size(); i++){
			RLWE_ciphertext tmp = RLWE_rotate_time(acc, a[i]);
			tmp.to_freq_domain();
			acc.to_freq_domain();
			acc = CMUX(acc, tmp, C[i]);
			acc.to_time_domain();
		}
		acc.to_freq_domain();
		return(acc);
	}

	RLWE_ciphertext blind_rotate(const RLWE_ciphertext &c_in, const bool forward, const std::vector<RGSW_ciphertext> &C){
		if(num_rotate_poly != C.size()){
			cout << "The sizes of rotation vector and control vector are not equal!!!" << endl;
			exit(1);
		}
		//rotate based on a, private
		RLWE_ciphertext acc = c_in;
		acc.to_freq_domain();
		for(uint32_t i = 0; i < num_rotate_poly; i++){
			RLWE_ciphertext tmp = RLWE_rotate_freq(acc, i, forward);
			acc = CMUX(acc, tmp, C[i]);
		}
		//acc.to_time_domain();
		return(acc);
	}


}
