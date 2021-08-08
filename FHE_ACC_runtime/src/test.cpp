#include "test.h"
using namespace std;
//using namespace LWE;
//using namespace RLWE;
using namespace std::chrono;

namespace test{
	void print_sequence(const ciphertext_t *a, const int length){
		for(int i = 0; i < length; i++){
			cout << a[i] << "\t";
		}
		cout << endl;
	}
	
	
	void LWE_en_decrypt(RNG_uniform &uni_dist, RNG_norm &norm_dist, const LWE::LWE_secretkey &sk){
		LWE::LWE_plaintext p_text(1);
		LWE::LWE_plaintext p_text1(0);
		LWE::LWE_ciphertext c_text;
	
		cout << "Before encryption" << endl;
		cout << "p_text\t";
		p_text.display();
		cout << "p_text1\t";
		p_text1.display();	
	
		cout << "Secret key" << endl;
		sk.display();	
	
		c_text = LWE::LWE_encrypt(sk, p_text, uni_dist, norm_dist);
		cout << "After encryption" << endl;
		cout << "Ciphertext" << endl;
		c_text.display();
	
		p_text1 = LWE::LWE_decrypt(sk, c_text);
		cout << "p_text\t";
		p_text.display();
		cout << "p_text1\t";
		p_text1.display();	
	
		assert(p_text.m == p_text1.m);
	}
	
	void LWE_NAND(RNG_uniform &uni_dist, RNG_norm &norm_dist, const LWE::LWE_secretkey &sk){
		LWE::LWE_plaintext p_text0(0);
		LWE::LWE_plaintext p_text1(1);
		LWE::LWE_plaintext p_text_out(0);
	
		LWE::LWE_ciphertext c_text0;
		LWE::LWE_ciphertext c_text1;
		LWE::LWE_ciphertext c_text_out;
	
		c_text0 = LWE::LWE_encrypt(sk, p_text0, uni_dist, norm_dist);
		c_text1 = LWE::LWE_encrypt(sk, p_text1, uni_dist, norm_dist);
	
		cout << "NAND(0, 0) =\t";
		c_text_out = LWE::LWE_evaluate(c_text0, c_text0, NAND);
		p_text_out = LWE::LWE_decrypt_2(sk, c_text_out);
		cout << p_text_out.m << endl;
		assert(p_text_out.m == 0);	//the evaluate does not add q/2 to the b, so the result here is inverted 
	
		cout << "NAND(0, 1) =\t";
		c_text_out = LWE::LWE_evaluate(c_text0, c_text1, NAND);
		p_text_out = LWE::LWE_decrypt_2(sk, c_text_out);
		cout << p_text_out.m << endl;
		assert(p_text_out.m == 0);
	
		cout << "NAND(1, 0) =\t";
		c_text_out = LWE::LWE_evaluate(c_text1, c_text0, NAND);
		p_text_out = LWE::LWE_decrypt_2(sk, c_text_out);
		cout << p_text_out.m << endl;
		assert(p_text_out.m == 0);
	
		cout << "NAND(1, 1) =\t";
		c_text_out = LWE::LWE_evaluate(c_text1, c_text1, NAND);
		p_text_out = LWE::LWE_decrypt_2(sk, c_text_out);
		cout << p_text_out.m << endl;
		assert(p_text_out.m == 1);
	
	}
	
	
	void scale_mod(){
		bitset<12> origin(0);
		int computed = 0;
		bitset<12> computed_bits(0);
		for(int i = -1024; i < 1024; i += 100){
			origin = bitset<12>(i);
			cout << "origin =\t" << origin << "\t" << i << endl;
			computed = ((i%q) + q + q / 8) % q;
			computed_bits = bitset<12>(computed);
			cout << "computed =\t" << computed_bits << "\t" << computed << endl;
		}
	}
	
	void prime(){
		vector<ciphertext_t> p = {134217497, 134216777, 134216113, 134214539};
		bool is_prime;
		for(auto it = p.begin(); it != p.end(); it++){
			is_prime = MR_primality(*it, 20);
			cout << *it << " is prime " << is_prime << endl;
		}
		vector<ciphertext_t> c = {6705, 6201, 9139, 7187*3583, 134215351, 134216115};
		for(auto it = c.begin(); it != c.end(); it++){
			is_prime = MR_primality(*it, 10);
			cout << *it << " is prime " << is_prime << endl;
		}
	
	}
	
	void verify_iN(){
		long_ciphertext_t mult = (long_ciphertext_t)iN * (long_ciphertext_t)N;
		mult = mult % Q;
		cout << iN << " * " << N << " mod " << Q << " = " << (ciphertext_t)mult << endl; 
	}
	
	void verify_ROU(){
		set<long_ciphertext_t> mult_set;
		long_ciphertext_t mult = (long_ciphertext_t)ROU;
		mult_set.insert(mult);
		for(int i = 1; i < 2*N; i++){
			mult *= ROU;
			mult %= Q;
			mult_set.insert(mult);
			//cout << mult << endl;
			if((mult == 1) && (i != (2*N - 1)))
				cout << "ROU order is not correct: i = " << (i + 1) << " mult = " << (ciphertext_t)mult << endl; 
		}
		if(mult_set.size() != (uint32_t)2*N)
			cout << "ROU is not 2*Nth order: set size = " << mult_set.size() << endl;
		else
			cout << "ROU order is correct" << endl;
	}
	
	
	
	void verify_NTT(){
		//// a toy test for NTT
		//// length of the sequence 
		//cout << "------------------toy example--------------" << endl;
		//int length = 8;
		//cout << "length = " << length << endl;
		//// modulo of the sequence, modulo = 1 mod 2length 
		//ciphertext_t modulo = previous_prime(first_prime(16, length), length);
		//cout << "modulo = " << modulo << endl;
		//// inverse of the length mod modulo
		//ciphertext_t ilength = inverse_mod(length, modulo);
		//cout << "ilength = " << ilength << endl; 
		////2lengthth root of unity
		//ciphertext_t rou = root_of_unity(length, modulo);
		//cout << "rou = " << rou << endl;
		//ciphertext_t rou_t[length];
		//ciphertext_t irou_t[length];
		////test ilength
		//if(mod_general((long_ciphertext_t)length * (long_ciphertext_t)ilength, modulo) != 1){
		//	cout << "length * ilength != 1" << endl;
		//	exit(1);
		//}
		//cout << "length * ilength == 1" << endl;
	
		////test ROU 
		//set<long_ciphertext_t> mult_set;
		//long_ciphertext_t mult = 1;
		//for(int i = 0; i < 2*length; i++){
		//	mult *= rou;
		//	mult %= modulo;
		//	mult_set.insert(mult);
		//	//cout << mult << endl;
		//	if((mult == 1) && (i != (2*length - 1)))
		//		cout << "ROU order is not correct: i = " << (i + 1) << " mult = " << (ciphertext_t)mult << endl; 
		//}
		//if(mult_set.size() != (uint32_t)2*length)
		//	cout << "ROU is not 2*Nth order: set size = " << mult_set.size() << endl;
		//else
		//	cout << "ROU order is correct" << endl;
	
		//root_of_unity_table(rou, modulo, length, rou_t, irou_t);
	
		//ciphertext_t a[length];
		//ciphertext_t a_out[length];
		//ciphertext_t NTT_out[length];
	
		//int sign = 1;
		//for(int i = 0; i < length; i++){
		//	a[i] = mod_general((signed_long_ciphertext_t)(sign * i), modulo);
		//	sign = 0 - sign;
		//}
		//cout << "input sequence: " << endl;
		//for(int i = 0; i < length; i++){
		//	cout << a[i] << "\t";
		//}
		//cout << endl;
	
		//NTT(a, length, modulo, rou_t, NTT_out);	
		//cout << "NTT sequence: " << endl;
		//for(int i = 0; i < length; i++){
		//	cout << NTT_out[i] << "\t";
		//}
		//cout << endl;
		//
		//iNTT(NTT_out, length, modulo, irou_t, ilength, a_out);
	
		//cout << "recovered sequence: " << endl;
		//for(int i = 0; i < length; i++){
		//	cout << a_out[i] << "\t";
		//}
		//cout << endl;
		//for(int i = 0; i < length; i++){
		//	assert(a[i] == a_out[i]);
		//}
	
		cout << "-----------------real example----------------" << endl;
	
		cout << "Q = \t" << hex << uppercase << setw(16) << setfill('0') << Q << endl; 
		cout << "iN = \t" << hex << uppercase << setw(16) << setfill('0') << iN << endl;
		cout << "ROU = \t" << hex << uppercase << setw(16) << setfill('0') << ROU << endl;
		std::vector<ciphertext_t> b(N);
		std::vector<ciphertext_t> b_bk(N);
		std::vector<ciphertext_t> b_out(N);
		std::vector<ciphertext_t> NTT_b_out(N);
	
		int sign = 1;
		for(int i = 0; i < N; i++){
			//b[i] = mod_general((signed_long_ciphertext_t)(sign * i), Q);
			//b[i] = (N - i - 1)/4;
			b[i] = 0;
			sign = 1;
			for(uint16_t j = 0; j < digitG/2; j++){
				b[i] = (b[i] << 18) + (sign == 1 ? (((N - i - 1)/4) << 9) + (i/4) : ((i/4) << 9) + (N - i - 1)/4);
				sign = 0 - sign;
			}
			b_bk[i] = b[i];
		}
		cout << "First 10 of input sequence: " << endl;
		for(int i = 0; i < N; i++){
			cout << hex << uppercase << setw(14) << setfill('0') << b[i] << endl;
		}
		cout << endl;
	
		NTT(b.data(), N, Q, ROU_table, NTT_b_out.data());	
		NTT(b_bk.data(), N, Q, ROU_table);	
		cout << "First 10 of NTT sequence: " << endl;
		for(int i = 0; i < N; i++){
			cout << hex << uppercase << setw(14) << setfill('0') << NTT_b_out[i] << endl;
		}
		cout << endl;
		for(int i = 0; i < N; i++){
			if(b_bk[i] != NTT_b_out[i])
				cout << "in place NTT not correct" << endl;
		}
		
		iNTT(NTT_b_out.data(), N, Q, iROU_table, iN, b_out.data());
		iNTT(b_bk.data(), N, Q, iROU_table, iN);
	
		cout << "First 10 of recovered sequence: " << endl;
		for(int i = 0; i < 10; i++){
			cout << b_out[i] << "\t";
		}
		cout << endl;
	
		for(int i = 0; i < N; i++){
			if(b[i] != b_out[i])
				cout << "in NTT + iNTT not correct" << endl;
			if(b_bk[i] != b_out[i])
				cout << "in place iNTT not correct" << endl;
		}
		cout << "The recovered sequence matches the original one." << endl;
		cout << "ROU table contents" << endl;
		for(int i = 0; i < N; i++){
			cout << hex << uppercase << setw(14) << setfill('0') << ROU_table[i] << endl;
		}
		cout << endl;
		cout << "iROU table contents" << endl;
		for(int i = 0; i < N; i++){
			cout << hex << uppercase << setw(14) << setfill('0') << iROU_table[i] << endl;
		}
		cout << endl;
	}
	
	void RLWE_en_decrypt(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk){
		std::vector<ciphertext_t> poly_a(N);
		std::vector<ciphertext_t> poly_b(N);
		ciphertext_t Q8 = Q/8 + 1;
		ciphertext_t negQ8 = Q - Q8;	
		for(int i = 0; i < N; i++){
			if(i % 2 == 0){
				poly_a[i] = Q8;
				poly_b[i] = negQ8;
			}else{
				poly_a[i] = negQ8;
				poly_b[i] = Q8;
			}
		}
		
		RLWE::RLWE_plaintext pa(poly_a, false);
		RLWE::RLWE_plaintext pb(poly_b, false);
		#ifdef DEBUG
			cout << "pa content:" << endl;
			pa.display();
			cout << "pb content:" << endl;
			pb.display();
		#endif
		RLWE::RLWE_ciphertext c;
		cout << "Encrypting..." << endl;
		c = RLWE::RLWE_encrypt(sk, pa, uni_dist, norm_dist);
		#ifdef DEBUG
			cout << "c content:" << endl;
			c.display();
		#endif
		cout << "Decrypting..." << endl;
		pb = RLWE::RLWE_decrypt(sk, c);
		#ifdef DEBUG
			cout << "pb content recovered:" << endl;
			pb.display();
		#endif
		pa.to_time_domain();
		for(int i = 0; i < N; i++){
			if(pa.m[i] != pb.m[i]){
				cout << "The decrypted sequence is not correct!!!" << endl;
				exit(1);
			}
		}
		cout << "Successfully decrypted." << endl;
	}
	
	void modswitch(){
		RNG_uniform LWE_uni_dist(Q);						// uniform dist for a
		RNG_uniform LWE_uni_dist_key(3);					// normal dist for sk, use a short sk
		RNG_norm LWE_norm_dist(LWE_mean, 10000000*LWE_stddev);		// normal dist for noise e
		LWE::LWE_secretkey LWE_sk_q(LWE_uni_dist_key);			// secret key LWE_sk mod q
	
		//generate a LWE key mod Q from the LWE key mod q
		LWE::LWE_secretkey LWE_sk_Q = LWE_sk_q;					// secret key LWE_sk mod Q
		ciphertext_t diff = Q - (ciphertext_t)q;
		for(int i = 0; i < n; i++){
			if(LWE_sk_Q.a[i] >= q2){
				LWE_sk_Q.a[i] += diff;
			}
		}
		ciphertext_t Q8 = Q / 8 + 1;
		ciphertext_t negQ8 = Q - Q8;
		
		uint32_t noise_bound = Q/16; //if only test the mod switch, this is the max noise bound
	
		//plaintext is 0
		cout << "---------------Encode 0 as 0 mod Q----------------" << endl;
		LWE::LWE_ciphertext c_text_Q;
		c_text_Q.b = mod_general((signed_ciphertext_t)LWE_norm_dist.generate_norm(noise_bound) + (signed_ciphertext_t)(negQ8 + Q8), Q);
		cout << "noise sample = " << LWE_norm_dist.generate_norm(noise_bound) << endl;
		for(int i = 0; i < n; i++){
			c_text_Q.a[i] = mod_general(LWE_uni_dist.generate_uniform(), Q);
			c_text_Q.b = mod_general((long_ciphertext_t)c_text_Q.b + (long_ciphertext_t)c_text_Q.a[i] * (long_ciphertext_t)LWE_sk_Q.a[i], Q);
		}
		cout << "b before mod switch: " << c_text_Q.b << endl;
		//mod switch 
		LWE::LWE_ciphertext c_text_q = LWE::LWE_modswitch(c_text_Q);
		cout << "b after mod switch: " << c_text_q.b << endl;
		
		LWE::LWE_plaintext p_text_q = LWE::LWE_decrypt(LWE_sk_q, c_text_q);
	
		if(p_text_q.m != 0){
			cout << "Mod switch failed" << endl;
			exit(1);
		}
		cout << "Decrypted message is "<< p_text_q.m << endl;
	
		//plaintext is 1
		cout << "---------------Encode 1 as Q/4 + 2 mod Q----------------" << endl;
	
		c_text_Q.b = mod_general((signed_ciphertext_t)LWE_norm_dist.generate_norm(noise_bound) + (signed_ciphertext_t)(Q8 + Q8), Q);
		cout << "noise sample = " << LWE_norm_dist.generate_norm(noise_bound) << endl;
		for(int i = 0; i < n; i++){
			c_text_Q.a[i] = mod_general(LWE_uni_dist.generate_uniform(), Q);
			c_text_Q.b = mod_general((long_ciphertext_t)c_text_Q.b + (long_ciphertext_t)c_text_Q.a[i] * (long_ciphertext_t)LWE_sk_Q.a[i], Q);
		}
		cout << "b before mod switch: " << c_text_Q.b << endl;
	
		//mod switch 
		c_text_q = LWE::LWE_modswitch(c_text_Q);
		cout << "b after mod switch: " << c_text_q.b << endl;
	
		p_text_q = LWE::LWE_decrypt(LWE_sk_q, c_text_q);
	
		if(p_text_q.m != 1){
			cout << "Mod switch failed" << endl;
			exit(1);
		}
		cout << "Decrypted message is "<< p_text_q.m << endl;
	
	}
	
	void RLWE_transpose(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk){
		std::vector<ciphertext_t> poly_a(N);
		ciphertext_t Q8 = Q/8 + 1;
		ciphertext_t negQ8 = Q - Q8;	
		for(int i = 0; i < N; i++){
			if(i % 2 == 0){
				poly_a[i] = Q8;
			}else{
				poly_a[i] = negQ8;
			}
		}
		
		RLWE::RLWE_plaintext pa(poly_a, false);
		#ifdef DEBUG
			cout << "pa content:" << endl;
			pa.display();
		#endif
		
		RLWE::RLWE_ciphertext c1, c2;
	
		cout << "Encrypting..." << endl;
		c1 = RLWE::RLWE_encrypt(sk, pa, uni_dist, norm_dist);
		c2 = c1;
		#ifdef DEBUG
			cout << "1 content:" << endl;
			c1.display();
		#endif
	
		cout << "Transpose NTTa of c2" << endl;
		c2.NTT_a_transpose();
		c2.to_time_domain();
		c1.to_time_domain();
	
		if(c1.a[0] != c2.a[0]){
			cout << "Transpose is not correct" << endl;
			cout << "the elements of 0 index are not equal" << endl;
			exit(1);
		}
			
		for(int i = 1; i < N; i++){
			if((c1.a[i] + c2.a[N-i]) != Q){
				cout << "Transpose is not correct" << endl;
				cout << "the elements of " << i << " index are not inverse of each other" << endl;
				exit(1);
			}
		}
		cout << "Transpose of ciphertext is correct" << endl;
	}
	
	void keyswitch(RNG_uniform &RLWE_uni_dist, RNG_norm &RLWE_norm_dist, const LWE::LWE_secretkey &LWE_sk, const RLWE::RLWE_secretkey &RLWE_sk, const LWE::keyswitch_key &ks_key){
		
		std::vector<ciphertext_t> poly_a(N);
		std::vector<ciphertext_t> poly_b(N);
		ciphertext_t Q8 = Q/8 + 1;
		ciphertext_t negQ8 = Q - Q8;	
		for(int i = 0; i < N; i++){
			if(i % 2 == 0){
				poly_a[i] = Q8;
				poly_b[i] = negQ8;
			}else{
				poly_a[i] = negQ8;
				poly_b[i] = Q8;
			}
		}
		
		RLWE::RLWE_plaintext Rpa(poly_a, false);	//encode 1
		RLWE::RLWE_plaintext Rpb(poly_b, false);	//encode 0
	
		RLWE::RLWE_ciphertext Rca, Rcb;
		cout << "Encrypting..." << endl;
		Rca = RLWE::RLWE_encrypt(RLWE_sk, Rpa, RLWE_uni_dist, RLWE_norm_dist);
		Rcb = RLWE::RLWE_encrypt(RLWE_sk, Rpb, RLWE_uni_dist, RLWE_norm_dist);
		
		auto start = high_resolution_clock::now();
	
		LWE::LWE_ciphertext LcaQ, LcbQ;//mod Q LWE ciphertext
		cout << "Key switching..." << endl;
		LcaQ = LWE::LWE_keyswitch(Rca, ks_key);
		LcbQ = LWE::LWE_keyswitch(Rcb, ks_key);
	
		LWE::LWE_ciphertext Lcaq, Lcbq;//mod q LWE ciphertext
		cout << "Mod switching..." << endl;
		Lcaq = LWE::LWE_modswitch(LcaQ);
		Lcbq = LWE::LWE_modswitch(LcbQ);
		
		auto stop = high_resolution_clock::now();
	
		LWE::LWE_plaintext Lpa, Lpb;
		Lpa = LWE::LWE_decrypt(LWE_sk, Lcaq);
		Lpb = LWE::LWE_decrypt(LWE_sk, Lcbq);
	
		auto duration = duration_cast<milliseconds>(stop - start);
		if(Lpa.m != 1 || Lpb.m != 0){
			cout << "Key switch failed" << endl;
			cout << "Decypted message from a: " << Lpa.m << endl;
			cout << "Decypted message from b: " << Lpb.m << endl;
			exit(1);
		}
		
		cout << "Key switching succeeded, takes " << duration.count() << " ms" << endl;	
		cout << "Decypted message from a: " << Lpa.m << endl;
		cout << "Decypted message from b: " << Lpb.m << endl;
	}
	
	int bootstrapping(RNG_uniform &uni_dist, RNG_norm &norm_dist, const LWE::LWE_secretkey &sk, const RLWE::bootstrap_key &btkey, const LWE::keyswitch_key &kskey){
		LWE::LWE_plaintext p1, p2, p3;
		LWE::LWE_ciphertext c1, c2, c3;
		int count = 0;
		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p1.m = i;
				p2.m = j;
				c1 = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
				c2 = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				
				c3 = RLWE::eval_bootstrap(c1, c2, btkey, kskey, NAND);
	
				p3 = LWE::LWE_decrypt(sk, c3);
				if(p3.m != (((i + j + 2) & 2) >> 1)){
					cout << "Bootstrapping failed!!!" << endl;
					cout << "Bootstrapped result of NAND(" << i << ", " << j << "):" << endl;	
					p3.display();
					count++;
				}
			}
		}
		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p1.m = i;
				p2.m = j;
				c1 = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
				c2 = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				
				c3 = RLWE::eval_bootstrap(c1, c2, btkey, kskey, AND);
	
				p3 = LWE::LWE_decrypt(sk, c3);	
				if(p3.m != (((i + j) & 2) >> 1)){
					cout << "Bootstrapping failed!!!" << endl;
					cout << "Bootstrapped result of AND(" << i << ", " << j << "):" << endl;	
					p3.display();
					count++;
				}
			}
		}
		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p1.m = i;
				p2.m = j;
				c1 = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
				c2 = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				
				c3 = RLWE::eval_bootstrap(c1, c2, btkey, kskey, OR);
	
				p3 = LWE::LWE_decrypt(sk, c3);	
				if(p3.m != ((i | j) & 1)){
					cout << "Bootstrapping failed!!!" << endl;
					cout << "Bootstrapped result of OR(" << i << ", " << j << "):" << endl;	
					p3.display();
					count++;
				}
			}
		}
		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p1.m = i;
				p2.m = j;
				c1 = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
				c2 = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				
				c3 = RLWE::eval_bootstrap(c1, c2, btkey, kskey, NOR);
	
				p3 = LWE::LWE_decrypt(sk, c3);	
				if(p3.m != ((i | j) ^ 1)){
					cout << "Bootstrapping failed!!!" << endl;
					cout << "Bootstrapped result of NOR(" << i << ", " << j << "):" << endl;	
					p3.display();
					count++;
				}
			}
		}
		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p1.m = i;
				p2.m = j;
				c1 = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
				c2 = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				
				c3 = RLWE::eval_bootstrap(c1, c2, btkey, kskey, XOR);
	
				p3 = LWE::LWE_decrypt(sk, c3);	
				if(p3.m != ((i + j) & 1)){
					cout << "Bootstrapping failed!!!" << endl;
					cout << "Bootstrapped result of XOR(" << i << ", " << j << "):" << endl;	
					p3.display();
					count++;
				}
			}
		}
		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p1.m = i;
				p2.m = j;
				c1 = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
				c2 = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				
				c3 = RLWE::eval_bootstrap(c1, c2, btkey, kskey, XNOR);
	
				p3 = LWE::LWE_decrypt(sk, c3);	
				if(p3.m != (((i + j) & 1) ^ 1)){
					cout << "Bootstrapping failed!!!" << endl;
					cout << "Bootstrapped result of XNOR(" << i << ", " << j << "):" << endl;	
					p3.display();
					count++;
				}
			}
		}
	
		for(uint16_t i = 0; i < 2; i++){
			p1.m = i;
			c1 = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
			
			c3 = LWE::LWE_eval_NOT(c1);
	
			p3 = LWE::LWE_decrypt(sk, c3);
			if(p3.m != (i ^ 1)){
				cout << "Bootstrapping failed!!!" << endl;
				cout << "Bootstrapped result of NOT(" << i << "):" << endl;	
				p3.display();
				count++;
			}
		}
		return(count);
	
	}
	
	void RLWE_mult_RGSW(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk){
		//set mapping range
		ciphertext_t q_bound1, q_bound2;
		q_bound1 = mod_pow2((ciphertext_t)(q / 8 * 3), q);
		q_bound2 = mod_pow2((ciphertext_t)(q_bound1 + q2), q); 
	
		//set embed factor from q to N
		ciphertext_t p = 2 * N / q;
		
		//set the mapping results
		ciphertext_t Q8 = Q/8 + 1;
		ciphertext_t negQ8 = Q - Q8;
		cout << Q8 << " " << negQ8 << endl;
	
		ciphertext_t b = 0;//set a plaintext of acc to test
		//initialize the accumulator 
		RLWE::RLWE_ciphertext acc;
		acc = RLWE::acc_initialization(p, q_bound1, q_bound2, b);
		//acc.display();
		
		//cout << "input RLWE content" << endl;
		//cout << "RLWE poly a" << endl;
		//for(int i = 0; i < N; i++){
		//	cout << hex << uppercase << setw(14) << setfill('0') << acc.a[i] << endl;
		//}
		//cout << "RLWE poly b" << endl;
		//for(int i = 0; i < N; i++){
		//	cout << hex << uppercase << setw(14) << setfill('0') << acc.b[i] << endl;
		//}

		RLWE::RLWE_ciphertext acc_time;
		acc_time = acc;
		acc_time.to_time_domain();

		//cout << "input RLWE content time domain" << endl;
		//cout << "RLWE poly a time domain" << endl;
		//for(int i = 0; i < N; i++){
		//	cout << hex << uppercase << setw(14) << setfill('0') << acc_time.a[i] << endl;
		//}
		//cout << "RLWE poly b time domain" << endl;
		//for(int i = 0; i < N; i++){
		//	cout << hex << uppercase << setw(14) << setfill('0') << acc_time.b[i] << endl;
		//}

		for(uint32_t i = 0; i < q; i++){
	
			ciphertext_t m_RGSW = (ciphertext_t) i;	//set an RGSW plaintext 
	
			RLWE::RGSW_plaintext p_RGSW(m_RGSW);
			//p_RGSW.m.display();
	
			RLWE::RGSW_ciphertext c_RGSW(p_RGSW, sk, uni_dist, norm_dist);
			//cout << "input RGSW content" << endl;
			//for(int j = 0; j < 2; j++){
			//	for(uint16_t h = 0; h < digitG; h++) {
			//		cout << "RLWE " << h << ", " << j << endl;
			//		cout << "RLWE poly a" << endl;
			//		for(int k = 0; k < N; k++){
			//			cout << hex << uppercase << setw(14) << setfill('0') << c_RGSW.c_text[h][j].a[k] << endl;
			//		}
			//		cout << "RLWE poly b" << endl;
			//		for(int k = 0; k < N; k++){
			//			cout << hex << uppercase << setw(14) << setfill('0') << c_RGSW.c_text[h][j].b[k] << endl;
			//		}
			//	}
			//}
				
			RLWE::RLWE_ciphertext acc_out;
			acc_out = RLWE::RLWE_mult_RGSW(acc, c_RGSW);

			//cout << "output RLWE content" << endl;
			//cout << "RLWE poly a" << endl;
			//for(int h = 0; h < N; h++){
			//	cout << hex << uppercase << setw(14) << setfill('0') << acc_out.a[h] << endl;
			//}
			//cout << "RLWE poly b" << endl;
			//for(int h = 0; h < N; h++){
			//	cout << hex << uppercase << setw(14) << setfill('0') << acc_out.b[h] << endl;
			//}

			//manually decrypt
			std::vector<ciphertext_t> NTT_m(N);
			for(int h = 0; h < N; h++){
				NTT_m[h] = mod_general((long_ciphertext_t)acc_out.a[h] * (long_ciphertext_t)sk.a[h], Q);
				NTT_m[h] = mod_general((signed_long_ciphertext_t)acc_out.b[h] - (signed_long_ciphertext_t)NTT_m[h], Q);
				//cout << NTT_m[i] << endl;
			}
	
			RLWE::RLWE_plaintext acc_out_p(NTT_m, true);
			acc_out_p.to_time_domain();
	
			RLWE::RLWE_plaintext ground_truth;
			RLWE::poly_mult(acc.b.data(), p_RGSW.m.m.data(), N, Q, ground_truth.m.data());
			ground_truth.NTT_form = true;
			ground_truth.to_time_domain();
			//cout << "groud truth" << endl;
			//ground_truth.display();
	
			//cout << "encrypted mult" << endl;
			//acc_out_p.display();
			for(int h = 0; h < N; h++){
				if(acc_out_p.m[h] != ground_truth.m[h]){
					cout << "encrypted mult VS ground truth failed!!!" << endl;
					cout << "b+m = \t" << ((m_RGSW+b)%q) << "\tground truth coeffi of index 0 = \t" << ground_truth.m[0] << endl;
					cout << "b+m = \t" << ((m_RGSW+b)%q) << "\tencrypted coeffi of index 0 = \t\t" << acc_out_p.m[0] << endl;
					exit(1);
				}
			}
			cout << "b+m = \t" << ((m_RGSW+b)%q) << "\tground truth coeffi of index 0 = \t" << ground_truth.m[0] << endl;
			cout << "b+m = \t" << ((m_RGSW+b)%q) << "\tencrypted coeffi of index 0 = \t\t" << acc_out_p.m[0] << endl;
	
		}
	
	}
	
	void acc_initialize(){
		//set mapping range
		ciphertext_t q_bound1, q_bound2;
		q_bound1 = mod_pow2((ciphertext_t)(q / 8 * 3), q);
		q_bound2 = mod_pow2((ciphertext_t)(q_bound1 + q2), q); 
	
		//set embed factor from q to N
		ciphertext_t p = 2 * N / q;
		
		//set the mapping results
		//ciphertext_t Q8 = Q/8 + 1;
		//ciphertext_t negQ8 = Q - Q8;
		//cout << Q8 << " " << negQ8 << endl;
		//cout << q_bound1 << " " << q_bound2 << endl;
	
		
		ciphertext_t b = 28;//set a plaintext of acc to test
		//these two loops are equivalent
		//loop1
		cout << "poly mult" << endl;
		for(uint32_t j = 0; j < q; j++){
			ciphertext_t m_RGSW = (ciphertext_t) j;	//set an RGSW plaintext 
			RLWE::RGSW_plaintext p_RGSW(m_RGSW);
	
			//initialize the accumulator 
			RLWE::RLWE_ciphertext acc;
			acc = RLWE::acc_initialization(p, q_bound1, q_bound2, b);
	
			RLWE::RLWE_plaintext acc_mult_m;
			RLWE::poly_mult(acc.b.data(), p_RGSW.m.m.data(), N, Q, acc_mult_m.m.data());
			acc_mult_m.NTT_form = true;
			acc_mult_m.to_time_domain();
			//acc_mult_m.display();
			cout << "b+m = \t" << ((m_RGSW+b)%q) << "\tcoeffi of index 0 = " << acc_mult_m.m[0] << endl;
	
		}
	
		//loop2
		cout << "direct initialize" << endl;
		for(uint32_t j = 0; j < q; j++){
			//initialize the accumulator 
			RLWE::RLWE_ciphertext acc;
			acc = RLWE::acc_initialization(p, q_bound1, q_bound2, b+j);
			acc.to_time_domain();
			cout << "b+m = \t" << ((b+j)%q) << "\tcoeffi of index 0 = " << acc.b[0] << endl;
	
		}
		
		b = 7;
		RLWE::RLWE_ciphertext acc;
		acc = RLWE::acc_initialization(p, q_bound1, q_bound2, b);
		acc.to_time_domain();
		cout << "init for b = 7" << endl;
		for(int i = 0; i < N; i++){
			cout << hex << uppercase << setw(14) << setfill('0') << acc.b[i] << endl;
		}	
	}
	
	void RGSW_decompose(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk){
		//set mapping range
		ciphertext_t q_bound1, q_bound2;
		q_bound1 = mod_pow2((ciphertext_t)(q / 8 * 3), q);
		q_bound2 = mod_pow2((ciphertext_t)(q_bound1 + q2), q); 
	
		//set embed factor from q to N
		ciphertext_t p = 2 * N / q;
		
		//set the mapping results
		ciphertext_t Q8 = Q/8 + 1;
		ciphertext_t negQ8 = Q - Q8;
		cout << Q8 << " " << negQ8 << endl;
		//cout << q_bound1 << " " << q_bound2 << endl;
		ciphertext_t b = 0;//set a plaintext of acc to test
	
		cout << "poly mult" << endl;
		for(uint32_t j = 0; j < q; j++){
			ciphertext_t m_RGSW = (ciphertext_t) j;	//set an RGSW plaintext 
			RLWE::RGSW_plaintext p_RGSW(m_RGSW);
			RLWE::RGSW_plaintext p_RGSW_copy(m_RGSW);
	
			//initialize the accumulator 
			RLWE::RLWE_ciphertext acc;
			acc = RLWE::acc_initialization(p, q_bound1, q_bound2, b);
			//cout << "acc content" << endl;
			//acc.to_time_domain();
			//acc.display();
			//acc.to_freq_domain();
	
			std::vector<RLWE::RLWE_ciphertext> decomp_acc;
			
			std::vector<RLWE::RLWE_ciphertext> RLWE_prime_of_m(digitG);
				
			//cout << "BG = " << BG << endl;
			for(uint32_t i = 0; i < digitG; i++){
				//cout << "m * pBG ^ " << i << endl;
				//p_RGSW.m.display();
	
				RLWE_prime_of_m[i] = RLWE::RLWE_encrypt(sk, p_RGSW.m, uni_dist, norm_dist);
				p_RGSW.mult_constant_number(BG);
			}
	
			decomp_acc = RLWE::digit_decompose(acc, digitG, BG_mask, BGbits);
			//std::cout << "decomp size : " << decomp_acc.size() << std::endl;	
			RLWE::RLWE_ciphertext acc_out;
			for(uint32_t i = 0; i < digitG; i++){
				//cout << "\ndecomposed acc" << endl;
				//decomp_acc[i].display();
				//cout << "\nencrypted m*pBG" << endl;
				//RLWE_prime_of_m[i].display();
				RLWE::RLWE_ciphertext mult = RLWE::RLWE_mult_NTT_poly(RLWE_prime_of_m[i], decomp_acc[i].b);
				//cout << "\nmult" << endl;
				//mult.display();
				acc_out = RLWE::RLWE_addition(acc_out, mult);
				//cout << "\nacc_out" << endl;
				//acc_out.display();
			}
	
			//RLWE_plaintext acc_out_p;
			//acc_out_p = RLWE_decrypt(sk, acc_out);//guess should not use decrypt here 
			//decrypt manually a ciphertext without any noise
			std::vector<ciphertext_t> NTT_m(N);
			for(int i = 0; i < N; i++){
				NTT_m[i] = mod_general((long_ciphertext_t)acc_out.a[i] * (long_ciphertext_t)sk.a[i], Q);
				NTT_m[i] = mod_general((signed_long_ciphertext_t)acc_out.b[i] - (signed_long_ciphertext_t)NTT_m[i], Q);
				//cout << NTT_m[i] << endl;
			}
			RLWE::RLWE_plaintext acc_out_p(NTT_m, true);
			acc_out_p.to_time_domain();
	
	
			RLWE::RLWE_plaintext acc_mult_m;
			RLWE::poly_mult(acc.b.data(), p_RGSW_copy.m.m.data(), N, Q, acc_mult_m.m.data());
			acc_mult_m.NTT_form = true;
			acc_mult_m.to_time_domain();
			//cout << "ground truth" << endl;
			//acc_mult_m.display();
			//cout << "encrypted " << endl;
			//acc_out_p.display();
	
			for(int i = 0; i < N; i++){
				if(acc_out_p.m[i] != acc_mult_m.m[i]){
					cout << "RLWE mult failed!!!" << endl;
					break;
				}
			}
			cout << "b+m = \t" << ((m_RGSW+b)%q) << "\tground truth coeffi of index 0 = \t" << acc_mult_m.m[0] << endl;
			cout << "b+m = \t" << ((m_RGSW+b)%q) << "\tencrypted coeffi of index 0 = \t\t" << acc_out_p.m[0] << endl;
		}
	}
	
	void digit_decompose(){
		//set mapping range
		ciphertext_t q_bound1, q_bound2;
		q_bound1 = mod_pow2((ciphertext_t)(q / 8 * 3), q);
		q_bound2 = mod_pow2((ciphertext_t)(q_bound1 + q2), q); 
	
		//set embed factor from q to N
		ciphertext_t p = 2 * N / q;
		
		//set the mapping results
		ciphertext_t Q8 = Q/8 + 1;
		ciphertext_t negQ8 = Q - Q8;
		cout << Q8 << " " << negQ8 << endl;
		//cout << q_bound1 << " " << q_bound2 << endl;
		ciphertext_t b = 0;//set a plaintext of acc to test
		
		//initialize the accumulator 
		RLWE::RLWE_ciphertext acc;
		acc = RLWE::acc_initialization(p, q_bound1, q_bound2, b);
		acc.display();
		std::vector<RLWE::RLWE_ciphertext> decomp_acc_NTT;
		
		//decompose in freq domain
		decomp_acc_NTT = RLWE::digit_decompose(acc, digitG, BG_mask, BGbits);
	
		//decompose in time domain
		RLWE::RLWE_ciphertext decomp_acc_time[digitG];
	
		RLWE::RLWE_ciphertext acc_copy = acc;
		acc_copy.to_time_domain();
		for(int i = 0; i < N; i++){
			for(uint32_t j = 0; j < digitG; j++){
				decomp_acc_time[j].a[i] = acc_copy.a[i] & BG_mask;	//mod
				acc_copy.a[i] >>= BGbits;	//division
				decomp_acc_time[j].b[i] = acc_copy.b[i] & BG_mask;
				acc_copy.b[i] >>= BGbits;
			}
		}
		for(uint32_t i = 0; i < digitG; i++){
			decomp_acc_time[i].NTT_form = false;
			decomp_acc_time[i].to_freq_domain();
		}
	
		for (uint32_t i = 0; i < digitG; i++){
			cout << "freq decompose" << endl;
			decomp_acc_NTT[i].display();
			cout << "time decompose" << endl;
			decomp_acc_time[i].display();
		}
		for(uint32_t i = 0; i < digitG; i++){
			for(int j = 0; j < N; j++){
				if(decomp_acc_NTT[i].b[j] != decomp_acc_time[i].b[j]){
					cout << "freq and time domain results are not equal" << endl;
					cout << "i = " << i << " j = " << j << endl;
					exit(0);
				}
			}
		}
	}

	void RLWE_keyswitch(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &old_key, const RLWE::RLWE_secretkey &new_key, const RLWE::keyswitch_key &ks_key_R){
		std::vector<ciphertext_t> poly_a(N);
		std::vector<ciphertext_t> poly_b(N);
		ciphertext_t Q8 = Q/8 + 1;
		ciphertext_t negQ8 = Q - Q8;	
		for(int i = 0; i < N; i++){
			if(i % 2 == 0){
				poly_a[i] = Q8;
				poly_b[i] = negQ8;
			}else{
				poly_a[i] = negQ8;
				poly_b[i] = Q8;
			}
		}
		
		RLWE::RLWE_plaintext pa(poly_a, false);
		RLWE::RLWE_plaintext pb(poly_b, false);

		#ifdef DEBUG
			cout << "pa content:" << endl;
			pa.display();
			cout << "pb content:" << endl;
			pb.display();
		#endif

		cout << "Encrypting with old key...\n" << endl;
		RLWE::RLWE_ciphertext c = RLWE::RLWE_encrypt(old_key, pa, uni_dist, norm_dist);

		#ifdef DEBUG
			cout << "c content:" << endl;
			c.display();
		#endif
		
		cout << "Decrypting with the old key...\n" << endl;
		pb = RLWE::RLWE_decrypt(old_key, c);

		cout << "RLWE key switching to the new key...\n" << endl;
		auto start = high_resolution_clock::now();
		
		RLWE::RLWE_ciphertext c_sw = RLWE::RLWE_keyswitch(c, ks_key_R);

		auto after_ks = high_resolution_clock::now();
		cout << "RLWE key switch takes: " << duration_cast<microseconds>(after_ks - start).count() << " us\n" << endl;

		cout << "Decrypting with the new key...\n" << endl;
		pb = RLWE::RLWE_decrypt(new_key, c_sw);

		#ifdef DEBUG
			cout << "pb content recovered:" << endl;
			pb.display();
		#endif
		pa.to_time_domain();
		for(int i = 0; i < N; i++){
			if(pa.m[i] != pb.m[i]){
				cout << "The decrypted sequence is not correct!!!" << endl;
				exit(1);
			}
		}
		cout << "RLWE ciphertext after keyswitch successfully decrypted.\n" << endl;

	}

	void CMUX(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk){
		//prepare two RLWE plaintext for MUX inputs 
		std::vector<ciphertext_t> poly_0(N);
		std::vector<ciphertext_t> poly_1(N);
		ciphertext_t Q2 = Q / 2;
		for(int i = 0; i < N; i++){
			if(i % 2 == 0){
				poly_0[i] = Q2;
				poly_1[i] = 0;
			}else{
				poly_0[i] = Q2;
				poly_1[i] = 0;
			}
		}
		
		RLWE::RLWE_plaintext p0(poly_0, false);
		RLWE::RLWE_plaintext p1(poly_1, false);

		RLWE::RLWE_plaintext p_MUXed0(poly_1, false);
		RLWE::RLWE_plaintext p_MUXed1(poly_0, false);
		//prepare two RLWE ciphertext for MUX inputs 
		RLWE::RLWE_ciphertext c0 = RLWE::RLWE_encrypt(sk, p0, uni_dist, norm_dist);
		RLWE::RLWE_ciphertext c1 = RLWE::RLWE_encrypt(sk, p1, uni_dist, norm_dist);

		RLWE::RLWE_plaintext p_bfMUX0 = RLWE::RLWE_decrypt(sk, c0, 2);
		RLWE::RLWE_plaintext p_bfMUX1 = RLWE::RLWE_decrypt(sk, c1, 2);
		
		cout << "before MUX" << endl;
		cout << "c0 max noise " << p_bfMUX0.max_noise << endl;
		cout << "c1 max noise " << p_bfMUX1.max_noise << endl;
	
		//selsect bit for MUX 
		bool m0 = (bool)0;
		bool m1 = (bool)1; 
		
		RLWE::RGSW_plaintext p_RGSW0(m0);
		RLWE::RGSW_plaintext p_RGSW1(m1);
			
		RLWE::RGSW_ciphertext c_RGSW0(p_RGSW0, sk, uni_dist, norm_dist);
		RLWE::RGSW_ciphertext c_RGSW1(p_RGSW1, sk, uni_dist, norm_dist);

		//perform MUX
		
		auto start = high_resolution_clock::now();

		RLWE::RLWE_ciphertext c_MUXed0 = RLWE::CMUX(c0, c1, c_RGSW0);
		RLWE::RLWE_ciphertext c_MUXed1 = RLWE::CMUX(c0, c1, c_RGSW1);

		auto after_CMUX = high_resolution_clock::now();
		cout << "2 CMUX take: " << duration_cast<milliseconds>(after_CMUX - start).count() << " ms\n" << endl;

		p_MUXed0 = RLWE::RLWE_decrypt(sk, c_MUXed0, 2);
		p_MUXed1 = RLWE::RLWE_decrypt(sk, c_MUXed1, 2);
		cout << "after MUX" << endl;
		cout << "c0 max noise " << p_MUXed0.max_noise << endl;
		cout << "c1 max noise " << p_MUXed1.max_noise << endl;
		p0.denoise(2);
		p1.denoise(2);

		
		for(int i = 0; i < N; i++){
			if(p_MUXed0.m[i] != p0.m[i] || p_MUXed1.m[i] != p1.m[i]){
				cout << "encrypted mult VS ground truth failed!!!" << endl;
				exit(1);
			}
		}
		cout << "plaintext 0[0]" << p0.m[0] << endl;
		cout << "plaintext 1[0]" << p1.m[0] << endl;

		cout << "MUXed plaintext 0[0]" << p_MUXed0.m[0] << endl;
		cout << "MUXed plaintext 1[0]" << p_MUXed1.m[0] << endl;

	}

	void blind_rotate_time(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk){
		//prepare two RLWE plaintext for MUX inputs 
		std::vector<ciphertext_t> poly_0(N);
		ciphertext_t Q8 = Q/8 + 1;
		ciphertext_t negQ8 = Q - Q8;	
	
		cout << "Q8: " << Q8 << endl;	
		//initialize the plaintext polynomial
		poly_0[0] = Q8;
		for(int i = 1; i < N; i++){
			poly_0[i] = negQ8;
		}
	

		RLWE::RLWE_plaintext p0(poly_0, false);

		//prepare RLWE ciphertext for rotate
		RLWE::RLWE_ciphertext c = RLWE::RLWE_encrypt(sk, p0, uni_dist, norm_dist);


		for(int i = 0; i < 16; i++){
			vector<int> a = {2, 4, 8};
			bitset<4> b(i);
			vector<RLWE::RGSW_ciphertext> C(3);
			for(int j = 1; j < 4; j++){
				RLWE::RGSW_plaintext p_RGSW(b[j]);
				RLWE::RGSW_ciphertext c_RGSW(p_RGSW, sk, uni_dist, norm_dist);
				C[j-1] = move(c_RGSW);
			}
			
			RLWE::RLWE_ciphertext c_br = RLWE::blind_rotate_full(c, (int)b[0], a, C);
			RLWE::RLWE_plaintext p_br = RLWE::RLWE_decrypt(sk, c_br);
			
			if(p_br.m[i] != Q8){
				cout << "blind rotate by " << i << " is not correct!" << endl;
			   	p_br.display();
				exit(1);
			}
			cout << "blind rotate by " << i << " is correct!" << endl;
		}

		//initialize the plaintext polynomial
		poly_0[N-1] = Q8;
		for(int i = 0; i < N-1; i++){
			poly_0[i] = negQ8;
		}
	

		RLWE::RLWE_plaintext p1(poly_0, false);

		//prepare RLWE ciphertext for rotate
		c = RLWE::RLWE_encrypt(sk, p1, uni_dist, norm_dist);

		for(int i = 0; i < 16; i++){
			vector<int> a = {-2, -4, -8};
			bitset<4> b(i);
			vector<RLWE::RGSW_ciphertext> C(3);
			for(int j = 1; j < 4; j++){
				RLWE::RGSW_plaintext p_RGSW(b[j]);
				RLWE::RGSW_ciphertext c_RGSW(p_RGSW, sk, uni_dist, norm_dist);
				C[j-1] = move(c_RGSW);
			}
			
			RLWE::RLWE_ciphertext c_br = RLWE::blind_rotate_full(c, -(int)b[0], a, C);
			RLWE::RLWE_plaintext p_br = RLWE::RLWE_decrypt(sk, c_br);
			
			if(p_br.m[N-1-i] != Q8){
				cout << "blind rotate by " << -i << " is not correct!" << endl;
			   	p_br.display();
				exit(1);
			}
			cout << "blind rotate by " << -i << " is correct!" << endl;
			
		}
	}

	void blind_rotate_freq(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk){
		//prepare two RLWE plaintext for MUX inputs 
		std::vector<ciphertext_t> poly_0(N);
		ciphertext_t Q8 = Q/8 + 1;
		ciphertext_t negQ8 = Q - Q8;	
	
		cout << "Q8: " << Q8 << endl;	
		//initialize the plaintext polynomial
		for(int i = 0; i < N; i++){
			poly_0[i] = negQ8;
		}
		
			

		RLWE::RLWE_plaintext p0(poly_0, false);

		//prepare RLWE ciphertext for rotate
		RLWE::RLWE_ciphertext c = RLWE::RLWE_encrypt(sk, p0, uni_dist, norm_dist);

		//test forward rotate
		for(int i = 0; i < 1024; i++){
			bitset<num_rotate_poly> b(i);
			vector<RLWE::RGSW_ciphertext> C(num_rotate_poly);
			for(int j = 0; j < num_rotate_poly; j++){
				RLWE::RGSW_plaintext p_RGSW(b[j]);
				RLWE::RGSW_ciphertext c_RGSW(p_RGSW, sk, uni_dist, norm_dist);
				C[j] = move(c_RGSW);
			}

			RLWE::RLWE_ciphertext c_br = RLWE::blind_rotate(c, true, C);
			RLWE::RLWE_plaintext p_br = RLWE::RLWE_decrypt(sk, c_br);
			
			for(int j = 0; j < i; j++){	
				if(p_br.m[j] != Q8){
					cout << "blind rotate by " << i << " is not correct!" << endl;
				   	p_br.display();
					exit(1);
				}
			}
			for(int j = i; j < N; j++){	
				if(p_br.m[j] != negQ8){
					cout << "blind rotate by " << i << " is not correct!" << endl;
				   	p_br.display();
					exit(1);
				}
			}

			cout << "blind rotate by " << i << " is correct!" << endl;
		}

		//initialize the plaintext polynomial
		for(int i = 0; i < N; i++){
			poly_0[i] = negQ8;
		}
	
		RLWE::RLWE_plaintext p1(poly_0, false);

		//prepare RLWE ciphertext for rotate
		c = RLWE::RLWE_encrypt(sk, p1, uni_dist, norm_dist);
		//test backward rotate
		for(int i = 0; i < 1024; i++){
			bitset<num_rotate_poly> b(i);
			vector<RLWE::RGSW_ciphertext> C(num_rotate_poly);
			for(int j = 0; j < num_rotate_poly; j++){
				RLWE::RGSW_plaintext p_RGSW(b[j]);
				RLWE::RGSW_ciphertext c_RGSW(p_RGSW, sk, uni_dist, norm_dist);
				C[j] = move(c_RGSW);
			}
			
			RLWE::RLWE_ciphertext c_br = RLWE::blind_rotate(c, false, C);
			RLWE::RLWE_plaintext p_br = RLWE::RLWE_decrypt(sk, c_br);
			for(int j = 0; j <= N - 1 - i; j++){	
				if(p_br.m[j] != negQ8){
					cout << "blind rotate by " << -i << " is not correct!" << endl;
				   	p_br.display();
					exit(1);
				}
			}
			for(int j = N - i; j < N; j++){
				if(p_br.m[j] != Q8){
					cout << "blind rotate by " << -i << " is not correct!" << endl;
				   	p_br.display();
					exit(1);
				}
			
			}
			cout << "blind rotate by " << -i << " is correct!" << endl;
			
		}
	}

	void RLWE_expansion(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk){
		//cout << "Currently, this test only pass when no noised added and no plaintext denoise" << endl;
		cout << "generating the substitution key" << endl;
		auto before_subs_key = high_resolution_clock::now();
		application::substitute_key subs_key(sk, uni_dist, norm_dist);
		auto after_subs_key = high_resolution_clock::now();

		auto time_subs_key = duration_cast<milliseconds>(after_subs_key - before_subs_key);
		cout << "subs key gen takes " << time_subs_key.count() << " ms" << endl;

		//prepare two RLWE plaintext for RLWE expansion function
		std::vector<ciphertext_t> poly_0(N);
		std::vector<ciphertext_t> poly_1(N);
		ciphertext_t Q2 = Q/2;
		cout << "Q2*iN = " << mod_general((long_ciphertext_t)Q2 * (long_ciphertext_t)iN, Q) << endl;;
		for(int i = 0; i < N; i++){
			poly_0[i] = mod_general((long_ciphertext_t)Q2 * (long_ciphertext_t)iN, Q);
			if(i % 2 == 0){
				poly_1[i] = mod_general(0 * (long_ciphertext_t)iN, Q);
			} else {
				poly_1[i] = mod_general((long_ciphertext_t)Q2 * (long_ciphertext_t)iN, Q);
			}
		}
			
		cout << "before encrypt" << endl;
		RLWE::RLWE_plaintext p0(poly_0, false);	//all one
		RLWE::RLWE_plaintext p1(poly_1, false);	//even index negQ8, odd index Q8

		//prepare two RLWE ciphertext for RLWE expansion function
		cout << "encrypting" << endl;
		RLWE::RLWE_ciphertext c0 = RLWE::RLWE_encrypt(sk, p0, uni_dist, norm_dist);
		RLWE::RLWE_ciphertext c1 = RLWE::RLWE_encrypt(sk, p1, uni_dist, norm_dist);
		
//		{
//			//used for generating verification data for hardware
//			std::cout << "RLWE key switch key" << std::endl;
//			for(uint16_t m = 0; m < digitKS_R; m++){
//				std::cout << "RLWE " << m << std::endl;
//				std::cout << "poly a" << std::endl;
//				for(int k = 0; k < N; k++) {
//					std::cout << std::hex << std::uppercase << std::setw(14) << std::setfill('0') << subs_key.subs_key[0].RLWE_kskey[m].a[k] << std::endl;
//				}
//				std::cout << "poly b" << std::endl;
//				for(int k = 0; k < N; k++) {
//					std::cout << std::hex << std::uppercase << std::setw(14) << std::setfill('0') << subs_key.subs_key[0].RLWE_kskey[m].b[k] << std::endl;
//				}
//			}
//
//			std::cout << "RLWE input" << std::endl;
//			std::cout << "poly a" << std::endl;
//			for(int k = 0; k < N; k++) {
//				std::cout << std::hex << std::uppercase << std::setw(14) << std::setfill('0') << c0.a[k] << std::endl;
//			}
//			std::cout << "poly b" << std::endl;
//			for(int k = 0; k < N; k++) {
//				std::cout << std::hex << std::uppercase << std::setw(14) << std::setfill('0') << c0.b[k] << std::endl;
//			}
//			RLWE::RLWE_ciphertext c0_tmp = c0;
//			c0_tmp.to_time_domain();
//			std::cout << "RLWE input time domain" << std::endl;
//			std::cout << "poly a" << std::endl;
//			for(int k = 0; k < N; k++) {
//				std::cout << std::hex << std::uppercase << std::setw(14) << std::setfill('0') << c0_tmp.a[k] << std::endl;
//			}
//			std::cout << "poly b" << std::endl;
//			for(int k = 0; k < N; k++) {
//				std::cout << std::hex << std::uppercase << std::setw(14) << std::setfill('0') << c0_tmp.b[k] << std::endl;
//			}			
//
//			RLWE::RLWE_ciphertext c0_subs = RLWE::RLWE_substitute(c0, 0);
//			std::cout << "RLWE subs" << std::endl;
//			std::cout << "poly a" << std::endl;
//			for(int k = 0; k < N; k++) {
//				std::cout << std::hex << std::uppercase << std::setw(14) << std::setfill('0') << c0_subs.a[k] << std::endl;
//			}
//			std::cout << "poly b" << std::endl;
//			for(int k = 0; k < N; k++) {
//				std::cout << std::hex << std::uppercase << std::setw(14) << std::setfill('0') << c0_subs.b[k] << std::endl;
//			}
//			
//			RLWE::RLWE_ciphertext c0_ks = RLWE::RLWE_keyswitch(c0_subs, subs_key.subs_key[0]);
//			std::cout << "RLWE output" << std::endl;
//			std::cout << "poly a" << std::endl;
//			for(int k = 0; k < N; k++) {
//				std::cout << std::hex << std::uppercase << std::setw(14) << std::setfill('0') << c0_ks.a[k] << std::endl;
//			}
//			std::cout << "poly b" << std::endl;
//			for(int k = 0; k < N; k++) {
//				std::cout << std::hex << std::uppercase << std::setw(14) << std::setfill('0') << c0_ks.b[k] << std::endl;
//			}
//		}





		ciphertext_t max_noise = 0;	
		//start expansion 
		cout << "expanding ciphertext 0" << endl;
		auto before_expand = high_resolution_clock::now();
		std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> expanded_RLWE_0 = application::expand_RLWE(c0, subs_key);
		auto after_expand = high_resolution_clock::now();

		auto time_expand = duration_cast<milliseconds>(after_expand - before_expand);
		cout << "RLWE expansion takes " << time_expand.count() << " ms" << endl;

		cout << "verifying expansion 0 result" << endl;
		for(int i = 0; i < N; i++){
			RLWE::RLWE_plaintext p_tmp = RLWE::RLWE_decrypt(sk, (*expanded_RLWE_0)[i], 2);
			max_noise = max_noise > p_tmp.max_noise ? max_noise : p_tmp.max_noise;
			if(p_tmp.m[0] != 1){
				cout << "expansion failed!!!" << endl;
				return;
			}
		}

		cout << "expanded poly 0 successfully" << endl;
		cout << "max noise = " << max_noise << endl;

		max_noise = 0;	
		cout << "expanding ciphertext 1" << endl;
		std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> expanded_RLWE_1 = application::expand_RLWE(c1, subs_key);	
		cout << "verifying expansion 1 result" << endl;
		for(int i = 0; i < N; i++){
			RLWE::RLWE_plaintext p_tmp = RLWE::RLWE_decrypt(sk, (*expanded_RLWE_1)[i], 2);
			max_noise = max_noise > p_tmp.max_noise ? max_noise : p_tmp.max_noise;
			if(i % 2 == 1){
				if(p_tmp.m[0] != 1){
					cout << "expansion failed!!!" << endl;
					return;
				}
			} else{
				if(p_tmp.m[0] != 0){
					cout << "expansion failed!!!" << endl;
					return;
				}
			}
		}
		cout << "expanded poly 1 successfully" << endl;
		cout << "max noise = " << max_noise << endl;
	}

	void homo_expansion(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk){
		//cout << "Currently, this test only pass when no noised added and no plaintext denoise" << endl;
		cout << "generating the substitution key" << endl;
		application::substitute_key subs_key(sk, uni_dist, norm_dist);

		cout << "generate RGSW encryption of -s" << endl;
		RLWE::RLWE_secretkey sk_tmp = sk;
		sk_tmp.to_time_domain();
		RLWE::RGSW_plaintext tmp_p_RGSW;
		for(int i = 0; i < N; i++){
			//tmp_p_RGSW.m.m[i] = mod_general((signed_long_ciphertext_t)sk.a[i] * (signed_long_ciphertext_t)(-1), Q);
			tmp_p_RGSW.m.m[i] = (Q - sk_tmp.a[i]) % Q;
		}
		tmp_p_RGSW.m.NTT_form = false;
		tmp_p_RGSW.m.to_freq_domain();
		RLWE::RGSW_ciphertext RGSW_neg_s(tmp_p_RGSW, sk, uni_dist, norm_dist);

		cout << "build packed bits RLWE vector" << endl;
		std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> packed_bits = std::make_unique<std::vector<RLWE::RLWE_ciphertext>>(digitG);
		ciphertext_t pow_BG = 1;
		for(uint16_t i = 0; i < digitG; i++){
			RLWE::RLWE_plaintext tmp_p;
			for(uint16_t j = 0; j < N; j++){
				if(j % 2 == 0){
					tmp_p.m[j] = 0;
				} else {
					tmp_p.m[j] = mod_general((long_ciphertext_t)pow_BG * (long_ciphertext_t)iN, Q);
				}
			}
			tmp_p.NTT_form = false;
			tmp_p.to_freq_domain();
			(*packed_bits)[i] = std::move(RLWE::RLWE_encrypt(sk, tmp_p, uni_dist, norm_dist));
			pow_BG = mod_general((long_ciphertext_t)pow_BG * (long_ciphertext_t)BG, Q);
		}

		cout << "start homo expansion" << endl;
		auto before_expand = high_resolution_clock::now();
		std::shared_ptr<std::vector<RLWE::RGSW_ciphertext>> expanded_RGSW = homo_expand(packed_bits, RGSW_neg_s, subs_key);
		auto after_expand = high_resolution_clock::now();
		cout << "homo expansion takes " << duration_cast<milliseconds>(after_expand - before_expand).count() << " ms" << endl;

		cout << "using expanded RGSW to do CMUX" << endl;
		//prepare two RLWE plaintext for MUX inputs 
		std::vector<ciphertext_t> poly_0(N);
		std::vector<ciphertext_t> poly_1(N);
		ciphertext_t Q2 = Q/2;
		for(int i = 0; i < N; i++){
			if(i % 2 == 0){
				poly_0[i] = Q2;
				poly_1[i] = 0;
			}else{
				poly_0[i] = 0;
				poly_1[i] = Q2;
			}
		}
		cout << "Q2 = " << Q2 << endl;;
		
		
		RLWE::RLWE_plaintext p0(poly_0, false);
		RLWE::RLWE_plaintext p1(poly_1, false);

		std::vector<RLWE::RLWE_plaintext> p_MUXed(N);
		for(int i = 0; i < N; i++){
			if(i % 2 == 0){
				RLWE::RLWE_plaintext tmp(poly_1, false);
				p_MUXed[i] = std::move(tmp);
			} else {
				RLWE::RLWE_plaintext tmp(poly_0, false);
				p_MUXed[i] = std::move(tmp);
			}

		}
		//prepare two RLWE ciphertext for MUX inputs 
		RLWE::RLWE_ciphertext c0 = RLWE::RLWE_encrypt(sk, p0, uni_dist, norm_dist);
		RLWE::RLWE_ciphertext c1 = RLWE::RLWE_encrypt(sk, p1, uni_dist, norm_dist);
		
		//perform MUX
		for(int i = 0; i < N; i++){
			RLWE::RLWE_ciphertext c_MUXed = RLWE::CMUX(c0, c1, (*expanded_RGSW)[i]);
			p_MUXed[i] = std::move(RLWE::RLWE_decrypt(sk, c_MUXed, 2));
		}
		//scale the output 
		p0.denoise(2);	
		p1.denoise(2);	

		for(int i = 0; i < N; i++){
			for (int j = 0; j < N; j++){
				if(i % 2 == 0){
					if(p_MUXed[i].m[j] != p0.m[j]){
						cout << "muxed VS ground truth failed at packed bit " << i << "!!!" << endl;
						cout << "p_MUXed[" << i << "].m[" << j << "] = " << p_MUXed[i].m[j] << endl;
						p_MUXed[i].display();
						return;
					}
				} else {
					if(p_MUXed[i].m[j] != p1.m[j]){
						cout << "muxed VS ground truth failed at packed bit " << i << "!!!" << endl;
						cout << "p_MUXed[" << i << "].m[" << j << "] = " << p_MUXed[i].m[j] << endl;
						p_MUXed[i].display();
						return;
					}
				}
			
			}
		}
		cout << "homo expansion succeeds " << endl;
		cout << "plaintext 0[0]" << p0.m[0] << endl;
		cout << "plaintext 1[0]" << p1.m[0] << endl;

		cout << "MUXed plaintext 0[0]" << p_MUXed[0].m[0] << endl;
		cout << "MUXed plaintext 1[0]" << p_MUXed[1].m[0] << endl;
	}

	void homo_expansion_and_tree_selection(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk){
		//cout << "Currently, this test only pass when no noised added and no plaintext denoise" << endl;
		cout << "generating the substitution key" << endl;
		application::substitute_key subs_key(sk, uni_dist, norm_dist);

		cout << "generate RGSW encryption of -s" << endl;
		RLWE::RLWE_secretkey sk_tmp = sk;
		sk_tmp.to_time_domain();
		RLWE::RGSW_plaintext tmp_p_RGSW;
		for(int i = 0; i < N; i++){
			//tmp_p_RGSW.m.m[i] = mod_general((signed_long_ciphertext_t)sk.a[i] * (signed_long_ciphertext_t)(-1), Q);
			tmp_p_RGSW.m.m[i] = (Q - sk_tmp.a[i]) % Q;
		}
		tmp_p_RGSW.m.NTT_form = false;
		tmp_p_RGSW.m.to_freq_domain();
		RLWE::RGSW_ciphertext RGSW_neg_s(tmp_p_RGSW, sk, uni_dist, norm_dist);

		cout << "build packed bits RLWE vector" << endl;
		auto packed_bits = std::make_unique<std::vector<RLWE::RLWE_ciphertext>>(digitG);
		ciphertext_t pow_BG = 1;
		for(uint16_t i = 0; i < digitG; i++){
			RLWE::RLWE_plaintext tmp_p;
			for(uint16_t j = 0; j < N; j++){
				if(j % 2 == 0){
					tmp_p.m[j] = 0;
				} else {
					tmp_p.m[j] = mod_general((long_ciphertext_t)pow_BG * (long_ciphertext_t)iN, Q);
				}
			}
			tmp_p.NTT_form = false;
			tmp_p.to_freq_domain();
			(*packed_bits)[i] = std::move(RLWE::RLWE_encrypt(sk, tmp_p, uni_dist, norm_dist));
			pow_BG = mod_general((long_ciphertext_t)pow_BG * (long_ciphertext_t)BG, Q);
		}

		cout << "start homo expansion" << endl;
		auto before_expand = high_resolution_clock::now();
		std::shared_ptr<std::vector<RLWE::RGSW_ciphertext>> expanded_RGSW = homo_expand(packed_bits, RGSW_neg_s, subs_key);
		auto after_expand = high_resolution_clock::now();
		cout << "homo expansion takes " << duration_cast<milliseconds>(after_expand - before_expand).count() << " ms" << endl;

		cout << "using expanded RGSW to perform tree selection" << endl;
		cout << "prepare array of RLWE ciphertexts tree selection" << endl; 
		cout << "selected position is 1010101--01010101010, 85--682" << endl;

		uint32_t total_digits = 18;
		uint32_t packed_array_size = 1 << (total_digits - digitN);

		ciphertext_t Q2 = Q/2;
		std::vector<RLWE::RLWE_ciphertext> v_ctext(packed_array_size);
		for(uint32_t i = 0; i < packed_array_size; i++){
			std::vector<ciphertext_t> poly(N);
			uint32_t j = 0;
			for(; j <= i; j++){
				poly[j] = Q2;
			}
			for(; j < (uint32_t)N; j++){
				poly[j] = 0;
			}
			
			RLWE::RLWE_plaintext p(poly, false);
			v_ctext[i] = RLWE::RLWE_encrypt(sk, p, uni_dist, norm_dist);
		}	
		cout << "Q2 = " << Q2 << endl;;

		cout << "binary tree selection with the 18 LSBs from packed RGSW bits" << endl;
		auto before_tree_selection = high_resolution_clock::now();
		for(uint32_t i = digitN; i < total_digits; i++){
			for(uint32_t j = 0; j < packed_array_size; j += 2){
				v_ctext[j/2] = RLWE::CMUX(v_ctext[j], v_ctext[j+1], (*expanded_RGSW)[i]);
			}
			packed_array_size >>= 1;
		}	
		
		auto after_tree_selection = high_resolution_clock::now();
		cout << "tree selection takes " << duration_cast<milliseconds>(after_tree_selection - before_tree_selection).count() << " ms" << endl;

		//RLWE::RLWE_plaintext p_selected = RLWE::RLWE_decrypt(sk, v_ctext[0], 2);

		//cout << "selected ciphertext decrypted" << endl;
		//p_selected.display();

		cout << "blind rotate" << endl;
		std::vector<RLWE::RGSW_ciphertext> rotate_bits(expanded_RGSW->begin(), expanded_RGSW->begin() + digitN);
		if(rotate_bits.size() != (uint32_t)digitN){
			cout << "rotate bits not the same size" << endl;
			exit(1);
		}
			
		auto before_blind_rotate = high_resolution_clock::now();
		RLWE::RLWE_ciphertext c_rotated = RLWE::blind_rotate(v_ctext[0], false, rotate_bits);
		auto after_blind_rotate = high_resolution_clock::now();
		cout << "blind rotate takes " << duration_cast<milliseconds>(after_blind_rotate - before_blind_rotate).count() << " ms" << endl;
	
		RLWE::RLWE_plaintext p_rotated = RLWE::RLWE_decrypt(sk, c_rotated, 2);
		cout << "final plaintext" << endl;
		p_rotated.display();
		cout << "final plaintext[0]" << p_rotated.m[0] << endl;


		//for(int i = 0; i < N; i++){
		//	for (int j = 0; j < N; j++){
		//		if(i % 2 == 0){
		//			if(p_MUXed[i].m[j] != p0.m[j]){
		//				cout << "muxed VS ground truth failed at packed bit " << i << "!!!" << endl;
		//				cout << "p_MUXed[" << i << "].m[" << j << "] = " << p_MUXed[i].m[j] << endl;
		//				p_MUXed[i].display();
		//				return;
		//			}
		//		} else {
		//			if(p_MUXed[i].m[j] != p1.m[j]){
		//				cout << "muxed VS ground truth failed at packed bit " << i << "!!!" << endl;
		//				cout << "p_MUXed[" << i << "].m[" << j << "] = " << p_MUXed[i].m[j] << endl;
		//				p_MUXed[i].display();
		//				return;
		//			}
		//		}
		//	
		//	}
		//}
		//cout << "homo expansion succeeds " << endl;
		//cout << "plaintext 0[0]" << p0.m[0] << endl;
		//cout << "plaintext 1[0]" << p1.m[0] << endl;

		//cout << "MUXed plaintext 0[0]" << p_MUXed[0].m[0] << endl;
		//cout << "MUXed plaintext 1[0]" << p_MUXed[1].m[0] << endl;
	}
	
	void substitue_RLWE_noise_increase(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk){
		cout << "generating the substitution key" << endl;
		application::substitute_key subs_key(sk, uni_dist, norm_dist);
		cout << "Bks_R_bits " << Bks_R_bits << endl;	//number bits of Bks_R, used for division 
		cout << "digitKS_R " << digitKS_R << endl;
		cout << "Bks_R_mask " << Bks_R_mask << endl;
		ciphertext_t pow_2 = 1;
		for(int k = 1; k < 11; k++){
			cout << "------------------ " << k << " levels ---------------------" << endl;
			pow_2 *= 2;
			ciphertext_t inv_multiplier = inverse_mod(pow_2, Q);	
			//prepare two RLWE plaintext for RLWE expansion function
			std::vector<ciphertext_t> poly_0(N);
			std::vector<ciphertext_t> poly_1(N);
			ciphertext_t Q8 = Q/8 + 1;
			ciphertext_t negQ8 = Q - Q8;	
			cout << negQ8 << endl;	
			ciphertext_t Q2 = Q/2 + 1;
			for(int i = 0; i < N; i++){
				//if(i % 2 == 0){
				//	poly_0[i] = mod_general((int64_t)Q8 * (int64_t)inv_multiplier, Q);
				//	poly_1[i] = mod_general((int64_t)negQ8 * (int64_t)inv_multiplier, Q);
				//}else{
				//	poly_0[i] = mod_general((int64_t)negQ8 * (int64_t)inv_multiplier, Q);
				//	poly_1[i] = mod_general((int64_t)Q8 * (int64_t)inv_multiplier, Q);
				//}
				poly_0[i] = mod_general((long_ciphertext_t)Q2 * (long_ciphertext_t)inv_multiplier, Q);
				poly_1[i] = mod_general(0*(long_ciphertext_t)inv_multiplier, Q);
			}
			cout << "Q / 2 = " << (Q / 2) << endl;

			RLWE::RLWE_plaintext p0(poly_0, false);	
			RLWE::RLWE_plaintext p1(poly_1, false);

			//prepare two RLWE ciphertext for RLWE expansion function
			cout << "encrypting" << endl;
			RLWE::RLWE_ciphertext c0 = RLWE::RLWE_encrypt(sk, p0, uni_dist, norm_dist);
			RLWE::RLWE_ciphertext c1 = RLWE::RLWE_encrypt(sk, p1, uni_dist, norm_dist);

			//for(int j = 0; j < N; j++){
			//	c0.b[j] = mod_general((int64_t)c0.b[j] + (int64_t)mod_general((int64_t)Q2 * (int64_t)inv_multiplier, Q), Q);
			//}
			//c0.to_freq_domain();
			cout << "decrypting before expand" << endl;
			//RLWE::RLWE_plaintext p_bfe0 = RLWE::RLWE_decrypt(sk, c0, 2);	
			RLWE::RLWE_plaintext p_bfe1 = RLWE::RLWE_decrypt(sk, c1, 2);	
			//p_bfe0.display();
			//p_bfe1.display();
			for(int i = 0; i < N; i++){
				if(p_bfe1.m[i] != 0){
				//if(p_bfe0.m[i] != 1 || p_bfe1.m[i] != 0){
					cout << "decrypt failed" << endl;
					break;
				}
			}

			//cout << "p_bfe0" << endl;
			//p_bfe0.display();
			//cout << "p_bfe1" << endl;
			//p_bfe1.display();
		
			ciphertext_t max_noise = 0;	
			// start substitute
			cout << "expanding poly 0" << endl;
			std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> result0 = std::make_unique<std::vector<RLWE::RLWE_ciphertext>>(N);
			(*result0)[0] = c0;
			int inner_loop = 1; 	//2 to the power of i
			for(int i = 0; i < k; i++){
				for(int j = 0; j < inner_loop; j++){
					RLWE::RLWE_ciphertext subs = RLWE::RLWE_keyswitch(RLWE::RLWE_substitute((*result0)[j], i), subs_key.subs_key[i]);
					//cout << "decrypt subs at i = " << i << " j = " << j << endl;
					//RLWE::RLWE_plaintext p_tmp = RLWE::RLWE_decrypt(sk, subs, 2);
					RLWE::RLWE_ciphertext tmp = (*result0)[j];
					(*result0)[j] = RLWE::RLWE_addition(tmp, subs);
					(*result0)[j+inner_loop] = RLWE::RLWE_rotate_freq(RLWE::RLWE_subtraction(tmp, subs), i, false);
				}
				inner_loop *= 2;
			}
			for(int j = 0; j < inner_loop; j++){
				cout << "decrypt at" << " j = " << j << endl;
				RLWE::RLWE_plaintext p_tmp = RLWE::RLWE_decrypt(sk, (*result0)[j], 2);
				max_noise = max_noise > p_tmp.max_noise ? max_noise : p_tmp.max_noise;
				
				for(int h = 0; h < N; h += inner_loop){
					if(p_tmp.m[h] != 1){
						cout << "decrypt failed at" << " j = " << j << " h = " << h << endl;
						cout << p_tmp.m[h] << endl;
						return;
					}
					for(int l = 1; l < inner_loop; l++){
						if(p_tmp.m[h+l] != 0){
							cout << "decrypt failed at" << " j = " << j << " h = " << h << endl;
							cout << p_tmp.m[h] << endl;
							return;
						}
					}
				}
			}

			cout << "expanded poly 0 successfully" << endl;
			cout << "max noise = " << max_noise << endl;
			
			max_noise = 0;
			// start substitute
			cout << "expanding poly 1" << endl;
			std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> result1 = std::make_unique<std::vector<RLWE::RLWE_ciphertext>>(N);
			(*result1)[0] = c1;
			inner_loop = 1; 	//2 to the power of i
			for(int i = 0; i < k; i++){
				for(int j = 0; j < inner_loop; j++){
					RLWE::RLWE_ciphertext subs = RLWE::RLWE_keyswitch(RLWE::RLWE_substitute((*result1)[j], i), subs_key.subs_key[i]);
					//cout << "decrypt subs at i = " << i << " j = " << j << endl;
					//RLWE::RLWE_plaintext p_tmp = RLWE::RLWE_decrypt(sk, subs, 2);
					RLWE::RLWE_ciphertext tmp = (*result1)[j];
					(*result1)[j] = RLWE::RLWE_addition(tmp, subs);
					(*result1)[j+inner_loop] = RLWE::RLWE_rotate_freq(RLWE::RLWE_subtraction(tmp, subs), i, false);
				}
				inner_loop *= 2;
				for(int j = 0; j < inner_loop; j++){
					cout << "decrypt at i = " << i << " j = " << j << endl;
					RLWE::RLWE_plaintext p_tmp = RLWE::RLWE_decrypt(sk, (*result1)[j], 2);
					max_noise = max_noise > p_tmp.max_noise ? max_noise : p_tmp.max_noise;
					
					for(int h = 0; h < N; h++){
						if(p_tmp.m[h] != 0){
							cout << "decrypt failed at i = " << i << " j = " << j << " h = " << h << endl;
							return;
						}
					}
				}
			}
			cout << "expanded poly 1 successfully" << endl;
			cout << "max noise = " << max_noise << endl;
		}

		//cout << "decrypting before substitiute" << endl;
		//RLWE::RLWE_plaintext p_bs0 = RLWE::RLWE_decrypt(sk, c0);
		//RLWE::RLWE_plaintext p_bs1 = RLWE::RLWE_decrypt(sk, c1);

		//p_bs0.to_freq_domain();
		//p_bs1.to_freq_domain();

		//cout << "substituting with X^(N+1)" << endl;
		//RLWE::RLWE_ciphertext c_sub0 = RLWE::RLWE_substitute(c0, 0);
		//RLWE::RLWE_ciphertext c_sub1 = RLWE::RLWE_substitute(c1, 0);

		//cout << "switching key" << endl;
		//RLWE::RLWE_ciphertext c_sw0 = RLWE::RLWE_keyswitch(c_sub0, subs_key.subs_key[0]);
		//RLWE::RLWE_ciphertext c_sw1 = RLWE::RLWE_keyswitch(c_sub1, subs_key.subs_key[0]);

		//cout << "decrypting" << endl;
		//RLWE::RLWE_plaintext p_subs0 = RLWE::RLWE_decrypt(sk, c_sw0);
		//RLWE::RLWE_plaintext p_subs1 = RLWE::RLWE_decrypt(sk, c_sw1);

		//for(int i = 0; i < N; i++){
		//	if(p_subs0.m[i] != Q8 || p_subs1.m[i] != negQ8){
		//		cout << "substitute failed" << endl;
		//		cout << "subs0[" << i << "]= " << p_subs0.m[i] << endl; 
		//		cout << "subs1[" << i << "]= " << p_subs1.m[i] << endl; 
		//		exit(1);
		//	}
		//}
	}

	void reverse_array(std::vector<ciphertext_t> *a1, int start, int end){
		while(start < end){
			ciphertext_t tmp = (*a1)[start];
			(*a1)[start] = (*a1)[end];
			(*a1)[end] = tmp;
			start++;
			end--;
		}
	}

	void poly_rotate_time(std::vector<ciphertext_t> *a1, const int rotate_factor, const int length, const ciphertext_t modulo){
	//this is a helper function for the poly_substitute, it is the same as the one in the RLWE.cpp. 
	//But I have no idea why the compiler doesn't let me use that one, so I have to put one in this file
		int rf = rotate_factor % length;	//reduce the rotate factor to less than length
		if(rf == 0) return;
											//here I did not take N into account
		if(rf > 0){
			for(int i = length -1; i >= (length-rf); i--){
				(*a1)[i] = (modulo - (*a1)[i]) % modulo;
				//a1[i] = mod_general(-(int64_t)a1[i], modulo);
			}
			reverse_array(a1, 0, length - 1);
			reverse_array(a1, 0, rf - 1);
			reverse_array(a1, rf, length - 1);
		} else {
			for(int i = 0; i < (-rf); i++){
				//a1[i] = mod_general(-(int64_t)a1[i], modulo);
				(*a1)[i] = (modulo - (*a1)[i]) % modulo;
			}
			reverse_array(a1, 0, (-rf) - 1);
			reverse_array(a1, -rf, length - 1);
			reverse_array(a1, 0, length - 1);
		}
	}

	void poly_substitute(){
		std::vector<std::vector<ciphertext_t>> result(N);	//exceeds stack size, need to use heap
		for(int i = 0; i < N; i++){
			//std::vector<ciphertext_t> tmp(N, 0);
			result[i] = std::move(std::vector<ciphertext_t>(N, 0));
		}
		cout << "subs input" << endl;
		for(int i = 0; i < N; i++){
			result[0][i] = mod_general((long_ciphertext_t)i * (long_ciphertext_t)iN, Q);
			cout << hex << uppercase << setw(14) << setfill('0') << result[0][i] << endl;
		}
	
		for(int i = 0; i < digitN; i++){ 
			std::vector<ciphertext_t> tmp(N);
			std::copy(result[0].begin(), result[0].end(), tmp.data());
			std::vector<ciphertext_t> subs(N);

			RLWE::poly_substitute(tmp.data(), i, N, Q, subs.data());
			cout << "subs output at subs factor = " << i << endl;
			for(int j = 0; j < N; j++){
				cout << hex << uppercase << setw(14) << setfill('0') << subs[j] << endl;
			}
		}

		int inner_loop = 1; 	//2 to the power of i
		for(int i = 0; i < digitN; i++){
			for(int j = 0; j < inner_loop; j++){
				//cout << "at i = " << i << " j = " << j << endl;
				std::vector<ciphertext_t> tmp(N);
				for(int k = 0; k < N; k++){
					tmp[k] = result[j][k];
				}
				std::vector<ciphertext_t> subs(N);
				RLWE::poly_substitute(tmp.data(), i, N, Q, subs.data());
				//cout << "result[i] " << endl;	
				for(int k = 0; k < N; k++){
					result[j][k] = mod_general(tmp[k] + subs[k], Q);
					//cout << result[j][k] << " ";

				}
				//cout << endl;
				//cout << "result[i+inner_loop] " << endl;	
				for(int k = 0; k < N; k++){
					result[j+inner_loop][k] = mod_general((signed_ciphertext_t)tmp[k] - (signed_ciphertext_t)subs[k], Q);
					//cout << result[j+inner_loop][k] << " ";
				}
				//cout << endl;
				poly_rotate_time(&(result[j+inner_loop]), -(1 << i), N, Q);
			}
			inner_loop *= 2;
		}
		
		for(int i = 0; i < N; i++){
			if(result[i][0] != (ciphertext_t)i){
				cout << "constant term not correct!!!" << endl;
				exit(1);
			}
			//cout << "result[" << i << "]" << endl;
			//for(int j = 0; j < N; j++){
				//cout << "at i = " << i << " j = " << j << endl;
				//result[i][j] << " ";
			//}	
			//cout << endl;
			for(int j = 1; j < N; j++){
				if(result[i][j] != 0){
					cout << "higher powers are not zero!!!" << endl;
					cout << "at i = " << i << " j = " << j << endl;
					for(int k = 0; k < N; k++){
						cout << result[i][k] << " ";
					}
					cout << endl;
					//break;
					exit(1);
				}
			}
		}
		cout << "the expansion and substitution in plaintext succeed" << endl;
	}


	void barrett_reduction(){
		ciphertext_t Quo = 18014398509404161;
		cout << "quo = " << Quo << endl;
		ciphertext_t k = 27;
		long_ciphertext_t po2 = (long_ciphertext_t)1 << k;
		po2 = po2 * po2;
		long_ciphertext_t m = (po2 * po2) / (long_ciphertext_t)Quo;
		cout << "m = " << (ciphertext_t)m << endl;
		ciphertext_t a2 = Quo - 1; 
		ciphertext_t flag = 0;
		long_ciphertext_t mask = (po2 << 1) - 1;
		for(ciphertext_t a1 = Quo - 1; a1 > (Quo - 10000); a1 -= 100000000000){
		//for(ciphertext_t a1 = Quo - 1; a1 > ((Quo>>1) + (Quo >> 9)); a1 -= 100000000000){
			long_ciphertext_t prod = (long_ciphertext_t)a1 * (long_ciphertext_t)a2;
			ciphertext_t ground_truth = mod_general(prod, Quo);
			ciphertext_t q1 = prod >> ((k << 1) - 1);
			long_ciphertext_t q2 = (long_ciphertext_t)q1 * m;
			ciphertext_t q3 = q2 >> ((k << 1) + 1);
			ciphertext_t r1 = prod & mask;
			ciphertext_t r2 = (q3 * (long_ciphertext_t)Quo) & mask;
			signed_ciphertext_t r = (signed_ciphertext_t)r1 - (signed_ciphertext_t)r2;
			if(r < 0)
				r = r + po2 * 2;
			//r = r & mask;
			ciphertext_t count = 0;
			while(r >= (signed_ciphertext_t)Quo){
				r = r - (signed_ciphertext_t)Quo;
				count++;
			}
			if(count > 2)
				flag++;
			ciphertext_t residue = r;

			cout << "------------------" << endl;
			cout << a1 << " * " << a2 << endl;;
			//cout << "ground truth = " << ground_truth << endl;
			//cout << "m = " << m << endl;
			cout << "Barrett reduction = " << residue << endl;
			cout << "count = " << count << endl;
			if(ground_truth != residue){
				cout << "not equal" << endl;
				break;
			}
		}
		cout << "flag = " << flag << endl;

		Quo = 134176769;
		k = 28;// with this two step multiplier, k needs to be 28 for 27 bit modulo, seems there are precision losses in the two step multiplier
		po2 = (long_ciphertext_t)1 << k;
		m = (po2 * po2) / (long_ciphertext_t)Quo;
		a2 = Quo - 1; 
		flag = 0;
		mask = (po2 << 1) - 1;
		for(ciphertext_t a1 = Quo - 1; a1 > Quo - 2; a1 -= 1){
		//for(ciphertext_t a1 = Quo - 1; a1 > ((Quo>>1) + (Quo >> 9)); a1 -= 1){
			long_ciphertext_t prod = (long_ciphertext_t)a1 * (long_ciphertext_t)a2;
			ciphertext_t ground_truth = mod_general(prod, Quo);
			ciphertext_t q1 = prod >> (k - 1);
			long_ciphertext_t q2 = (long_ciphertext_t)q1 * m;
			ciphertext_t q3 = q2 >> (k + 1);
			ciphertext_t r1 = prod & mask;
			ciphertext_t r2 = (q3 * (long_ciphertext_t)Quo) & mask;
			signed_ciphertext_t r = (signed_ciphertext_t)r1 - (signed_ciphertext_t)r2;
			if(r < 0)
				r = r + po2 * 2;
			ciphertext_t count = 0;
			while(r >= (signed_ciphertext_t)Quo){
				r = r - (signed_ciphertext_t)Quo;
				count++;
			}
			if(count > 2){
				flag++;
				//break;
			}
			ciphertext_t residue = r;

			cout << "------------------" << endl;
			cout << a1 << " * " << a2 << endl;;
			//cout << "ground truth = " << ground_truth << endl;
			//cout << "m = " << m << endl;
			cout << "Barrett reduction = " << residue << endl;
			cout << "count = " << count << endl;
			if(ground_truth != residue){
				cout << "not equal" << endl;
				break;
			}
		}
		
		cout << "m = " << (ciphertext_t)m << endl;
		cout << "flag = " << flag << endl;



	}


	int fpga_bootstrapping_test(RNG_uniform &uni_dist, RNG_norm &norm_dist, const LWE::LWE_secretkey &sk, const LWE::keyswitch_key &kskey, int slot_id){
		int pf_id = FPGA_APP_PF;
		int bar_id = APP_PF_BAR0;
	    int rc;
	   	int	read_fd = -1;

	    pci_bar_handle_t ocl_bar_handle = PCI_BAR_HANDLE_INIT;

	    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &ocl_bar_handle);
		if(rc != 0){
			std::cout << "Unable to attach to the AFI" << std::endl;
			return(-1);
		}
		
	    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ true);
		if(read_fd < 0){
			std::cout << "unable to open read dma queue" << std::endl;
	    	if (ocl_bar_handle >= 0) {
	    	    rc = fpga_pci_detach(ocl_bar_handle);
	    	    if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    	    }
	    	}
			return(-1);	
		}

		LWE::LWE_plaintext p1, p2, p3;
		LWE::LWE_ciphertext c1, c2, c3;
		int count = 0;
		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p1.m = i;
				p2.m = j;
				c1 = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
				c2 = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				
				c3 = FPGA::fpga_eval_bootstrap_x1(c1, c2, kskey, NAND, ocl_bar_handle, &rc, read_fd);
				if(rc != 0){
					std::cout << "Error in fpga bootstrap!!!" << std::endl;
					if(read_fd >= 0){
						close(read_fd);
					}
	    			if (ocl_bar_handle >= 0) {
	    	    		rc = fpga_pci_detach(ocl_bar_handle);
	    	    		if (rc) {
							std::cout << "Failure while detaching from the fpga." << std::endl;
	    	    		}
	    			}
					return(-1);
				}	

				p3 = LWE::LWE_decrypt(sk, c3);
				if(p3.m != (((i + j + 2) & 2) >> 1)){
					cout << "Bootstrapping failed!!!" << endl;
					cout << "Bootstrapped result of NAND(" << i << ", " << j << "):" << endl;	
					p3.display();
					count++;
				}
			}
		}
		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p1.m = i;
				p2.m = j;
				c1 = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
				c2 = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				
				c3 = FPGA::fpga_eval_bootstrap_x1(c1, c2, kskey, AND, ocl_bar_handle, &rc, read_fd);
				if(rc != 0){
					std::cout << "Error in fpga bootstrap!!!" << std::endl;
					if(read_fd >= 0){
						close(read_fd);
					}
	    			if (ocl_bar_handle >= 0) {
	    	    		rc = fpga_pci_detach(ocl_bar_handle);
	    	    		if (rc) {
							std::cout << "Failure while detaching from the fpga." << std::endl;
	    	    		}
	    			}
					return(-1);
				}	

				p3 = LWE::LWE_decrypt(sk, c3);	
				if(p3.m != (((i + j) & 2) >> 1)){
					cout << "Bootstrapping failed!!!" << endl;
					cout << "Bootstrapped result of AND(" << i << ", " << j << "):" << endl;	
					p3.display();
					count++;
				}
			}
		}
		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p1.m = i;
				p2.m = j;
				c1 = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
				c2 = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				
				c3 = FPGA::fpga_eval_bootstrap_x1(c1, c2, kskey, OR, ocl_bar_handle, &rc, read_fd);
				if(rc != 0){
					std::cout << "Error in fpga bootstrap!!!" << std::endl;
					if(read_fd >= 0){
						close(read_fd);
					}
	    			if (ocl_bar_handle >= 0) {
	    	    		rc = fpga_pci_detach(ocl_bar_handle);
	    	    		if (rc) {
							std::cout << "Failure while detaching from the fpga." << std::endl;
	    	    		}
	    			}
					return(-1);
				}	

				p3 = LWE::LWE_decrypt(sk, c3);	
				if(p3.m != ((i | j) & 1)){
					cout << "Bootstrapping failed!!!" << endl;
					cout << "Bootstrapped result of OR(" << i << ", " << j << "):" << endl;	
					p3.display();
					count++;
				}
			}
		}
		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p1.m = i;
				p2.m = j;
				c1 = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
				c2 = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				
				c3 = FPGA::fpga_eval_bootstrap_x1(c1, c2, kskey, NOR, ocl_bar_handle, &rc, read_fd);
				if(rc != 0){
					std::cout << "Error in fpga bootstrap!!!" << std::endl;
					if(read_fd >= 0){
						close(read_fd);
					}
	    			if (ocl_bar_handle >= 0) {
	    	    		rc = fpga_pci_detach(ocl_bar_handle);
	    	    		if (rc) {
							std::cout << "Failure while detaching from the fpga." << std::endl;
	    	    		}
	    			}
					return(-1);
				}	

				p3 = LWE::LWE_decrypt(sk, c3);	
				if(p3.m != ((i | j) ^ 1)){
					cout << "Bootstrapping failed!!!" << endl;
					cout << "Bootstrapped result of NOR(" << i << ", " << j << "):" << endl;	
					p3.display();
					count++;
				}
			}
		}
		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p1.m = i;
				p2.m = j;
				c1 = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
				c2 = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				
				c3 = FPGA::fpga_eval_bootstrap_x1(c1, c2, kskey, XOR, ocl_bar_handle, &rc, read_fd);
				if(rc != 0){
					std::cout << "Error in fpga bootstrap!!!" << std::endl;
					if(read_fd >= 0){
						close(read_fd);
					}
	    			if (ocl_bar_handle >= 0) {
	    	    		rc = fpga_pci_detach(ocl_bar_handle);
	    	    		if (rc) {
							std::cout << "Failure while detaching from the fpga." << std::endl;
	    	    		}
	    			}
					return(-1);
				}	

				p3 = LWE::LWE_decrypt(sk, c3);	
				if(p3.m != ((i + j) & 1)){
					cout << "Bootstrapping failed!!!" << endl;
					cout << "Bootstrapped result of XOR(" << i << ", " << j << "):" << endl;	
					p3.display();
					count++;
				}
			}
		}
		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p1.m = i;
				p2.m = j;
				c1 = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
				c2 = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				
				c3 = FPGA::fpga_eval_bootstrap_x1(c1, c2, kskey, XNOR, ocl_bar_handle, &rc, read_fd);
				if(rc != 0){
					std::cout << "Error in fpga bootstrap!!!" << std::endl;
					if(read_fd >= 0){
						close(read_fd);
					}
	    			if (ocl_bar_handle >= 0) {
	    	    		rc = fpga_pci_detach(ocl_bar_handle);
	    	    		if (rc) {
							std::cout << "Failure while detaching from the fpga." << std::endl;
	    	    		}
	    			}
					return(-1);
				}	


				p3 = LWE::LWE_decrypt(sk, c3);	
				if(p3.m != (((i + j) & 1) ^ 1)){
					cout << "Bootstrapping failed!!!" << endl;
					cout << "Bootstrapped result of XNOR(" << i << ", " << j << "):" << endl;	
					p3.display();
					count++;
				}
			}
		}
	
		for(uint16_t i = 0; i < 2; i++){
			p1.m = i;
			c1 = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
			
			c3 = LWE::LWE_eval_NOT(c1);
	
			p3 = LWE::LWE_decrypt(sk, c3);
			if(p3.m != (i ^ 1)){
				cout << "Bootstrapping failed!!!" << endl;
				cout << "Bootstrapped result of NOT(" << i << "):" << endl;	
				p3.display();
				count++;
			}
		}

		if(read_fd >= 0){
			close(read_fd);
		}
	    if (ocl_bar_handle >= 0) {
	    	rc = fpga_pci_detach(ocl_bar_handle);
	    	if (rc) {
				std::cout << "Failure while detaching from the fpga." << std::endl;
	    	}
	    }
		return(count);
	}

	int fpga_bootstrapping_test_x4(RNG_uniform &uni_dist, RNG_norm &norm_dist, const LWE::LWE_secretkey &sk, const LWE::keyswitch_key &kskey, int slot_id){
		int pf_id = FPGA_APP_PF;
		int bar_id = APP_PF_BAR0;
	    int rc;
	   	int	read_fd = -1;

	    pci_bar_handle_t ocl_bar_handle = PCI_BAR_HANDLE_INIT;

	    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &ocl_bar_handle);
		if(rc != 0){
			std::cout << "Unable to attach to the AFI" << std::endl;
			return(-1);
		}
		
	    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ true);
		if(read_fd < 0){
			std::cout << "unable to open read dma queue" << std::endl;
	    	if (ocl_bar_handle >= 0) {
	    	    rc = fpga_pci_detach(ocl_bar_handle);
	    	    if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    	    }
	    	}
			return(-1);	
		}

		LWE::LWE_plaintext p1, p2, p3;
		std::vector<LWE::LWE_ciphertext> c1(4);
		std::vector<LWE::LWE_ciphertext> c2(4);
		std::vector<LWE::LWE_ciphertext> c3(4);
		int count = 0;
		
		//NAND
		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p1.m = i;
				p2.m = j;
			
				c1[2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
				c2[2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
			}
		}

		std::cout << "-------------------NAND---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x4(c1, c2, kskey, std::vector<GATES>(4, NAND), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p3 = LWE::LWE_decrypt(sk, c3[2*i + j]);	
				if(p3.m != (((i + j + 2) & 2) >> 1)){
					cout << "Bootstrapping failed!!!" << endl;
					cout << "Bootstrapped result of NAND(" << i << ", " << j << "):" << endl;	
					p3.display();
					count++;
				}
			}
		}

		//AND
		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p1.m = i;
				p2.m = j;
			
				c1[2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
				c2[2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
			}
		}

		std::cout << "-------------------AND---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x4(c1, c2, kskey, std::vector<GATES>(4, AND), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p3 = LWE::LWE_decrypt(sk, c3[2*i + j]);	
				if(p3.m != (((i + j) & 2) >> 1)){
					cout << "Bootstrapping failed!!!" << endl;
					cout << "Bootstrapped result of AND(" << i << ", " << j << "):" << endl;	
					p3.display();
					count++;
				}
			}
		}

		//OR
		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p1.m = i;
				p2.m = j;
			
				c1[2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
				c2[2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
			}
		}

		std::cout << "-------------------OR---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x4(c1, c2, kskey, std::vector<GATES>(4, OR), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p3 = LWE::LWE_decrypt(sk, c3[2*i + j]);	
				if(p3.m != ((i | j) & 1)){
					cout << "Bootstrapping failed!!!" << endl;
					cout << "Bootstrapped result of OR(" << i << ", " << j << "):" << endl;	
					p3.display();
					count++;
				}
			}
		}


		//NOR
		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p1.m = i;
				p2.m = j;
			
				c1[2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
				c2[2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
			}
		}

		std::cout << "-------------------NOR---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x4(c1, c2, kskey, std::vector<GATES>(4, NOR), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p3 = LWE::LWE_decrypt(sk, c3[2*i + j]);	
				if(p3.m != ((i | j) ^ 1)){
					cout << "Bootstrapping failed!!!" << endl;
					cout << "Bootstrapped result of NOR(" << i << ", " << j << "):" << endl;	
					p3.display();
					count++;
				}
			}
		}

		//XOR
		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p1.m = i;
				p2.m = j;
			
				c1[2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
				c2[2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
			}
		}

		std::cout << "-------------------XOR---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x4(c1, c2, kskey, std::vector<GATES>(4, XOR), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p3 = LWE::LWE_decrypt(sk, c3[2*i + j]);	
				if(p3.m != ((i + j) & 1)){
					cout << "Bootstrapping failed!!!" << endl;
					cout << "Bootstrapped result of XOR(" << i << ", " << j << "):" << endl;	
					p3.display();
					count++;
				}
			}
		}

		//XNOR
		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p1.m = i;
				p2.m = j;
			
				c1[2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
				c2[2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
			}
		}

		std::cout << "-------------------XNOR---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x4(c1, c2, kskey, std::vector<GATES>(4, XNOR), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < 2; j++){
				p3 = LWE::LWE_decrypt(sk, c3[2*i + j]);	
				if(p3.m != (((i + j) & 1) ^ 1)){
					cout << "Bootstrapping failed!!!" << endl;
					cout << "Bootstrapped result of XNOR(" << i << ", " << j << "):" << endl;	
					p3.display();
					count++;
				}
			}
		}


		for(uint16_t i = 0; i < 2; i++){
			p1.m = i;
			c1[i] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
			
			c3[i] = LWE::LWE_eval_NOT(c1[i]);
	
			p3 = LWE::LWE_decrypt(sk, c3[i]);
			if(p3.m != (i ^ 1)){
				cout << "Bootstrapping failed!!!" << endl;
				cout << "Bootstrapped result of NOT(" << i << "):" << endl;	
				p3.display();
				count++;
			}
		}

		if(read_fd >= 0){
			close(read_fd);
		}
	    if (ocl_bar_handle >= 0) {
	    	rc = fpga_pci_detach(ocl_bar_handle);
	    	if (rc) {
				std::cout << "Failure while detaching from the fpga." << std::endl;
	    	}
	    }
		return(count);
	}


	int fpga_bootstrapping_test_x8(RNG_uniform &uni_dist, RNG_norm &norm_dist, const LWE::LWE_secretkey &sk, const LWE::keyswitch_key &kskey, int slot_id){
		int pf_id = FPGA_APP_PF;
		int bar_id = APP_PF_BAR0;
	    int rc;
	   	int	read_fd = -1;

	    pci_bar_handle_t ocl_bar_handle = PCI_BAR_HANDLE_INIT;

	    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &ocl_bar_handle);
		if(rc != 0){
			std::cout << "Unable to attach to the AFI" << std::endl;
			return(-1);
		}
		
	    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ true);
		if(read_fd < 0){
			std::cout << "unable to open read dma queue" << std::endl;
	    	if (ocl_bar_handle >= 0) {
	    	    rc = fpga_pci_detach(ocl_bar_handle);
	    	    if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    	    }
	    	}
			return(-1);	
		}

		LWE::LWE_plaintext p1, p2, p3;
		std::vector<LWE::LWE_ciphertext> c1(8);
		std::vector<LWE::LWE_ciphertext> c2(8);
		std::vector<LWE::LWE_ciphertext> c3(8);
		int count = 0;
		
		//NAND
		for(uint16_t k = 0; k < 2; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p1.m = i;
					p2.m = j;
				
					c1[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
					c2[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				}
			}
		}


		std::cout << "-------------------NAND---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x8(c1, c2, kskey, std::vector<GATES>(8, NAND), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t k = 0; k < 2; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p3 = LWE::LWE_decrypt(sk, c3[4*k + 2*i + j]);	
					if(p3.m != (((i + j + 2) & 2) >> 1)){
						cout << "Bootstrapping failed!!!" << endl;
						cout << "Bootstrapped result of NAND(" << i << ", " << j << "):" << endl;	
						p3.display();
						count++;
					}
				}
			}
		}

		//AND
		for(uint16_t k = 0; k < 2; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p1.m = i;
					p2.m = j;
				
					c1[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
					c2[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				}
			}
		}

		std::cout << "-------------------AND---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x8(c1, c2, kskey, std::vector<GATES>(8, AND), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t k = 0; k < 2; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p3 = LWE::LWE_decrypt(sk, c3[4*k + 2*i + j]);	
					if(p3.m != (((i + j) & 2) >> 1)){
						cout << "Bootstrapping failed!!!" << endl;
						cout << "Bootstrapped result of AND(" << i << ", " << j << "):" << endl;	
						p3.display();
						count++;
					}
				}
			}
		}

		//OR
		for(uint16_t k = 0; k < 2; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p1.m = i;
					p2.m = j;
				
					c1[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
					c2[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				}
			}
		}

		std::cout << "-------------------OR---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x8(c1, c2, kskey, std::vector<GATES>(8, OR), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t k = 0; k < 2; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p3 = LWE::LWE_decrypt(sk, c3[4*k + 2*i + j]);	
					if(p3.m != ((i | j) & 1)){
						cout << "Bootstrapping failed!!!" << endl;
						cout << "Bootstrapped result of OR(" << i << ", " << j << "):" << endl;	
						p3.display();
						count++;
					}
				}
			}
		}


		//NOR
		for(uint16_t k = 0; k < 2; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p1.m = i;
					p2.m = j;
				
					c1[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
					c2[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				}
			}
		}

		std::cout << "-------------------NOR---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x8(c1, c2, kskey, std::vector<GATES>(8, NOR), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t k = 0; k < 2; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p3 = LWE::LWE_decrypt(sk, c3[4*k + 2*i + j]);	
					if(p3.m != ((i | j) ^ 1)){
						cout << "Bootstrapping failed!!!" << endl;
						cout << "Bootstrapped result of NOR(" << i << ", " << j << "):" << endl;	
						p3.display();
						count++;
					}
				}
			}
		}

		//XOR
		for(uint16_t k = 0; k < 2; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p1.m = i;
					p2.m = j;
				
					c1[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
					c2[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				}
			}
		}

		std::cout << "-------------------XOR---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x8(c1, c2, kskey, std::vector<GATES>(8, XOR), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t k = 0; k < 2; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p3 = LWE::LWE_decrypt(sk, c3[4*k + 2*i + j]);	
					if(p3.m != ((i + j) & 1)){
						cout << "Bootstrapping failed!!!" << endl;
						cout << "Bootstrapped result of XOR(" << i << ", " << j << "):" << endl;	
						p3.display();
						count++;
					}
				}
			}
		}

		//XNOR
		for(uint16_t k = 0; k < 2; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p1.m = i;
					p2.m = j;
				
					c1[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
					c2[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				}
			}
		}

		std::cout << "-------------------XNOR---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x8(c1, c2, kskey, std::vector<GATES>(8, XNOR), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t k = 0; k < 2; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p3 = LWE::LWE_decrypt(sk, c3[4*k + 2*i + j]);	
					if(p3.m != (((i + j) & 1) ^ 1)){
						cout << "Bootstrapping failed!!!" << endl;
						cout << "Bootstrapped result of XNOR(" << i << ", " << j << "):" << endl;	
						p3.display();
						count++;
					}
				}
			}
		}


		for(uint16_t i = 0; i < 2; i++){
			p1.m = i;
			c1[i] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
			
			c3[i] = LWE::LWE_eval_NOT(c1[i]);
	
			p3 = LWE::LWE_decrypt(sk, c3[i]);
			if(p3.m != (i ^ 1)){
				cout << "Bootstrapping failed!!!" << endl;
				cout << "Bootstrapped result of NOT(" << i << "):" << endl;	
				p3.display();
				count++;
			}
		}

		if(read_fd >= 0){
			close(read_fd);
		}
	    if (ocl_bar_handle >= 0) {
	    	rc = fpga_pci_detach(ocl_bar_handle);
	    	if (rc) {
				std::cout << "Failure while detaching from the fpga." << std::endl;
	    	}
	    }
		return(count);
	}

	int fpga_bootstrapping_test_x12(RNG_uniform &uni_dist, RNG_norm &norm_dist, const LWE::LWE_secretkey &sk, const LWE::keyswitch_key &kskey, int slot_id){
		int pf_id = FPGA_APP_PF;
		int bar_id = APP_PF_BAR0;
	    int rc;
	   	int	read_fd = -1;

	    pci_bar_handle_t ocl_bar_handle = PCI_BAR_HANDLE_INIT;

	    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &ocl_bar_handle);
		if(rc != 0){
			std::cout << "Unable to attach to the AFI" << std::endl;
			return(-1);
		}
		
	    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ true);
		if(read_fd < 0){
			std::cout << "unable to open read dma queue" << std::endl;
	    	if (ocl_bar_handle >= 0) {
	    	    rc = fpga_pci_detach(ocl_bar_handle);
	    	    if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    	    }
	    	}
			return(-1);	
		}

		LWE::LWE_plaintext p1, p2, p3;
		std::vector<LWE::LWE_ciphertext> c1(12);
		std::vector<LWE::LWE_ciphertext> c2(12);
		std::vector<LWE::LWE_ciphertext> c3(12);
		int count = 0;
		
		//NAND
		for(uint16_t k = 0; k < 3; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p1.m = i;
					p2.m = j;
				
					c1[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
					c2[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				}
			}
		}


		std::cout << "-------------------NAND---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x12(c1, c2, kskey, std::vector<GATES>(12, NAND), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t k = 0; k < 3; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p3 = LWE::LWE_decrypt(sk, c3[4*k + 2*i + j]);	
					if(p3.m != (((i + j + 2) & 2) >> 1)){
						cout << "Bootstrapping failed!!!" << endl;
						cout << "Bootstrapped result of NAND(" << i << ", " << j << "):" << endl;	
						p3.display();
						count++;
					}
				}
			}
		}

		//AND
		for(uint16_t k = 0; k < 3; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p1.m = i;
					p2.m = j;
				
					c1[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
					c2[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				}
			}
		}

		std::cout << "-------------------AND---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x12(c1, c2, kskey, std::vector<GATES>(12, AND), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t k = 0; k < 3; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p3 = LWE::LWE_decrypt(sk, c3[4*k + 2*i + j]);	
					if(p3.m != (((i + j) & 2) >> 1)){
						cout << "Bootstrapping failed!!!" << endl;
						cout << "Bootstrapped result of AND(" << i << ", " << j << "):" << endl;	
						p3.display();
						count++;
					}
				}
			}
		}

		//OR
		for(uint16_t k = 0; k < 3; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p1.m = i;
					p2.m = j;
				
					c1[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
					c2[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				}
			}
		}

		std::cout << "-------------------OR---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x12(c1, c2, kskey, std::vector<GATES>(12, OR), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t k = 0; k < 3; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p3 = LWE::LWE_decrypt(sk, c3[4*k + 2*i + j]);	
					if(p3.m != ((i | j) & 1)){
						cout << "Bootstrapping failed!!!" << endl;
						cout << "Bootstrapped result of OR(" << i << ", " << j << "):" << endl;	
						p3.display();
						count++;
					}
				}
			}
		}


		//NOR
		for(uint16_t k = 0; k < 3; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p1.m = i;
					p2.m = j;
				
					c1[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
					c2[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				}
			}
		}

		std::cout << "-------------------NOR---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x12(c1, c2, kskey, std::vector<GATES>(12, NOR), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t k = 0; k < 3; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p3 = LWE::LWE_decrypt(sk, c3[4*k + 2*i + j]);	
					if(p3.m != ((i | j) ^ 1)){
						cout << "Bootstrapping failed!!!" << endl;
						cout << "Bootstrapped result of NOR(" << i << ", " << j << "):" << endl;	
						p3.display();
						count++;
					}
				}
			}
		}

		//XOR
		for(uint16_t k = 0; k < 3; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p1.m = i;
					p2.m = j;
				
					c1[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
					c2[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				}
			}
		}

		std::cout << "-------------------XOR---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x12(c1, c2, kskey, std::vector<GATES>(12, XOR), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t k = 0; k < 3; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p3 = LWE::LWE_decrypt(sk, c3[4*k + 2*i + j]);	
					if(p3.m != ((i + j) & 1)){
						cout << "Bootstrapping failed!!!" << endl;
						cout << "Bootstrapped result of XOR(" << i << ", " << j << "):" << endl;	
						p3.display();
						count++;
					}
				}
			}
		}

		//XNOR
		for(uint16_t k = 0; k < 3; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p1.m = i;
					p2.m = j;
				
					c1[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
					c2[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				}
			}
		}

		std::cout << "-------------------XNOR---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x12(c1, c2, kskey, std::vector<GATES>(12, XNOR), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t k = 0; k < 3; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					p3 = LWE::LWE_decrypt(sk, c3[4*k + 2*i + j]);	
					if(p3.m != (((i + j) & 1) ^ 1)){
						cout << "Bootstrapping failed!!!" << endl;
						cout << "Bootstrapped result of XNOR(" << i << ", " << j << "):" << endl;	
						p3.display();
						count++;
					}
				}
			}
		}


		for(uint16_t i = 0; i < 2; i++){
			p1.m = i;
			c1[i] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
			
			c3[i] = LWE::LWE_eval_NOT(c1[i]);
	
			p3 = LWE::LWE_decrypt(sk, c3[i]);
			if(p3.m != (i ^ 1)){
				cout << "Bootstrapping failed!!!" << endl;
				cout << "Bootstrapped result of NOT(" << i << "):" << endl;	
				p3.display();
				count++;
			}
		}

		if(read_fd >= 0){
			close(read_fd);
		}
	    if (ocl_bar_handle >= 0) {
	    	rc = fpga_pci_detach(ocl_bar_handle);
	    	if (rc) {
				std::cout << "Failure while detaching from the fpga." << std::endl;
	    	}
	    }
		return(count);
	}

	int fpga_bootstrapping_test_x16(RNG_uniform &uni_dist, RNG_norm &norm_dist, const LWE::LWE_secretkey &sk, const LWE::keyswitch_key &kskey, int slot_id){
		int pf_id = FPGA_APP_PF;
		int bar_id = APP_PF_BAR0;
	    int rc;
	   	int	read_fd = -1;

	    pci_bar_handle_t ocl_bar_handle = PCI_BAR_HANDLE_INIT;

	    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &ocl_bar_handle);
		if(rc != 0){
			std::cout << "Unable to attach to the AFI" << std::endl;
			return(-1);
		}
		
	    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ true);
		if(read_fd < 0){
			std::cout << "unable to open read dma queue" << std::endl;
	    	if (ocl_bar_handle >= 0) {
	    	    rc = fpga_pci_detach(ocl_bar_handle);
	    	    if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    	    }
	    	}
			return(-1);	
		}

		LWE::LWE_plaintext p1, p2, p3;
		std::vector<LWE::LWE_ciphertext> c1(10);
		std::vector<LWE::LWE_ciphertext> c2(10);
		std::vector<LWE::LWE_ciphertext> c3(10);
		int count = 0;
		
		//NAND
		for(uint16_t k = 0; k < 4; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					if(4*k + 2*i + j >= 10)
						break;
					p1.m = i;
					p2.m = j;
				
					c1[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
					c2[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				}
			}
		}


		std::cout << "-------------------NAND---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x16(c1, c2, kskey, std::vector<GATES>(10, NAND), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t k = 0; k < 4; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					if(4*k + 2*i + j >= 10)
						break;
					p3 = LWE::LWE_decrypt(sk, c3[4*k + 2*i + j]);	
					if(p3.m != (((i + j + 2) & 2) >> 1)){
						cout << "Bootstrapping failed!!!" << endl;
						cout << "Bootstrapped result of NAND(" << i << ", " << j << "):" << endl;	
						p3.display();
						count++;
					}
				}
			}
		}

		//AND
		for(uint16_t k = 0; k < 4; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					if(4*k + 2*i + j >= 10)
						break;
					p1.m = i;
					p2.m = j;
				
					c1[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
					c2[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				}
			}
		}

		std::cout << "-------------------AND---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x16(c1, c2, kskey, std::vector<GATES>(10, AND), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t k = 0; k < 4; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					if(4*k + 2*i + j >= 10)
						break;
					p3 = LWE::LWE_decrypt(sk, c3[4*k + 2*i + j]);	
					if(p3.m != (((i + j) & 2) >> 1)){
						cout << "Bootstrapping failed!!!" << endl;
						cout << "Bootstrapped result of AND(" << i << ", " << j << "):" << endl;	
						p3.display();
						count++;
					}
				}
			}
		}

		//OR
		for(uint16_t k = 0; k < 4; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					if(4*k + 2*i + j >= 10)
						break;
					p1.m = i;
					p2.m = j;
				
					c1[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
					c2[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				}
			}
		}

		std::cout << "-------------------OR---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x16(c1, c2, kskey, std::vector<GATES>(10, OR), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t k = 0; k < 4; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					if(4*k + 2*i + j >= 10)
						break;
					p3 = LWE::LWE_decrypt(sk, c3[4*k + 2*i + j]);	
					if(p3.m != ((i | j) & 1)){
						cout << "Bootstrapping failed!!!" << endl;
						cout << "Bootstrapped result of OR(" << i << ", " << j << "):" << endl;	
						p3.display();
						count++;
					}
				}
			}
		}


		//NOR
		for(uint16_t k = 0; k < 4; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					if(4*k + 2*i + j >= 10)
						break;
					p1.m = i;
					p2.m = j;
				
					c1[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
					c2[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				}
			}
		}

		std::cout << "-------------------NOR---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x16(c1, c2, kskey, std::vector<GATES>(10, NOR), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t k = 0; k < 4; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					if(4*k + 2*i + j >= 10)
						break;
					p3 = LWE::LWE_decrypt(sk, c3[4*k + 2*i + j]);	
					if(p3.m != ((i | j) ^ 1)){
						cout << "Bootstrapping failed!!!" << endl;
						cout << "Bootstrapped result of NOR(" << i << ", " << j << "):" << endl;	
						p3.display();
						count++;
					}
				}
			}
		}

		//XOR
		for(uint16_t k = 0; k < 4; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					if(4*k + 2*i + j >= 10)
						break;
					p1.m = i;
					p2.m = j;
				
					c1[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
					c2[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				}
			}
		}

		std::cout << "-------------------XOR---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x16(c1, c2, kskey, std::vector<GATES>(10, XOR), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t k = 0; k < 4; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					if(4*k + 2*i + j >= 10)
						break;
					p3 = LWE::LWE_decrypt(sk, c3[4*k + 2*i + j]);	
					if(p3.m != ((i + j) & 1)){
						cout << "Bootstrapping failed!!!" << endl;
						cout << "Bootstrapped result of XOR(" << i << ", " << j << "):" << endl;	
						p3.display();
						count++;
					}
				}
			}
		}

		//XNOR
		for(uint16_t k = 0; k < 4; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					if(4*k + 2*i + j >= 10)
						break;
					p1.m = i;
					p2.m = j;
				
					c1[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
					c2[4*k + 2*i + j] = LWE::LWE_encrypt(sk, p2, uni_dist, norm_dist);
				}
			}
		}

		std::cout << "-------------------XNOR---------------------" << std::endl;
		c3 = FPGA::fpga_eval_bootstrap_x16(c1, c2, kskey, std::vector<GATES>(10, XNOR), ocl_bar_handle, &rc, read_fd);
		if(rc != 0){
			std::cout << "Error in fpga bootstrap!!!" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if (ocl_bar_handle >= 0) {
	    		rc = fpga_pci_detach(ocl_bar_handle);
	    		if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    		}
			}
			return(-1);
		}	

		for(uint16_t k = 0; k < 4; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < 2; j++){
					if(4*k + 2*i + j >= 10)
						break;
					p3 = LWE::LWE_decrypt(sk, c3[4*k + 2*i + j]);	
					if(p3.m != (((i + j) & 1) ^ 1)){
						cout << "Bootstrapping failed!!!" << endl;
						cout << "Bootstrapped result of XNOR(" << i << ", " << j << "):" << endl;	
						p3.display();
						count++;
					}
				}
			}
		}


		for(uint16_t i = 0; i < 2; i++){
			p1.m = i;
			c1[i] = LWE::LWE_encrypt(sk, p1, uni_dist, norm_dist);
			
			c3[i] = LWE::LWE_eval_NOT(c1[i]);
	
			p3 = LWE::LWE_decrypt(sk, c3[i]);
			if(p3.m != (i ^ 1)){
				cout << "Bootstrapping failed!!!" << endl;
				cout << "Bootstrapped result of NOT(" << i << "):" << endl;	
				p3.display();
				count++;
			}
		}

		if(read_fd >= 0){
			close(read_fd);
		}
	    if (ocl_bar_handle >= 0) {
	    	rc = fpga_pci_detach(ocl_bar_handle);
	    	if (rc) {
				std::cout << "Failure while detaching from the fpga." << std::endl;
	    	}
	    }
		return(count);
	}



	int fpga_RLWE_expansion_test(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk, int slot_id){
		int pf_id = FPGA_APP_PF;
		int bar_id = APP_PF_BAR0;
	    int rc;
	   	int	read_fd = -1;
		int write_fd = -1;

		cout << "generating the substitution key" << endl;
		auto before_subs_key = high_resolution_clock::now();
		application::substitute_key subs_key(sk, uni_dist, norm_dist);
		auto after_subs_key = high_resolution_clock::now();

		auto time_subs_key = duration_cast<milliseconds>(after_subs_key - before_subs_key);
		cout << "subs key gen takes " << time_subs_key.count() << " ms" << endl;

		//transfer subskey
		rc = FPGA::dma_write_subs_key(slot_id, subs_key);
		if(rc != 0){
			std::cout << "subskey transfer failed!!!" << std::endl;
			return(-1);
		}

		//read and compare subskey
		//rc = FPGA::dma_read_compare_subs_key(slot_id, subs_key);
		//if(rc != 0){
		//	std::cout << "subskey read and compare failed!!!" << std::endl;
		//	return(-1);
		//}

	    pci_bar_handle_t ocl_bar_handle = PCI_BAR_HANDLE_INIT;

	    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &ocl_bar_handle);
		if(rc != 0){
			std::cout << "Unable to attach to the AFI" << std::endl;
			return(-1);
		}
		
	    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ true);
	    write_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ false);
		if(read_fd < 0 || write_fd < 0){
			std::cout << "unable to open read/write dma queue" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if(write_fd >= 0){
				close(write_fd);
			}
	    	if (ocl_bar_handle >= 0) {
	    	    rc = fpga_pci_detach(ocl_bar_handle);
	    	    if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    	    }
	    	}
			return(-1);	
		}
		for(int loop_counter = 0; loop_counter < 10; loop_counter++){
			std::cout << "in loop " << loop_counter << std::endl;
			//prepare two RLWE plaintexts for RLWE expansion function
			std::vector<ciphertext_t> poly_0(N);
			std::vector<ciphertext_t> poly_1(N);
			ciphertext_t Q2 = Q/2;
			cout << "Q2*iN = " << mod_general((long_ciphertext_t)Q2 * (long_ciphertext_t)iN, Q) << endl;;
			for(int i = 0; i < N; i++){
				poly_0[i] = mod_general((long_ciphertext_t)Q2 * (long_ciphertext_t)iN, Q);
				if(i % 2 == 0){
					poly_1[i] = mod_general(0 * (long_ciphertext_t)iN, Q);
				} else {
					poly_1[i] = mod_general((long_ciphertext_t)Q2 * (long_ciphertext_t)iN, Q);
				}
			}
				
			cout << "before encrypt" << endl;
			RLWE::RLWE_plaintext p0(poly_0, false);	//all one
			RLWE::RLWE_plaintext p1(poly_1, false);	//even index negQ8, odd index Q8

			//prepare two RLWE ciphertexts for RLWE expansion function
			cout << "encrypting" << endl;
			RLWE::RLWE_ciphertext c0 = RLWE::RLWE_encrypt(sk, p0, uni_dist, norm_dist);
			RLWE::RLWE_ciphertext c1 = RLWE::RLWE_encrypt(sk, p1, uni_dist, norm_dist);
			

			ciphertext_t max_noise = 0;	
			//start expansion 
			cout << "expanding ciphertext 0" << endl;
			auto before_expand = high_resolution_clock::now();
			std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> expanded_RLWE_0 = FPGA::fpga_expand_RLWE(c0, ocl_bar_handle, &rc, read_fd, write_fd);
			//std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> expanded_RLWE_0 = FPGA::fpga_expand_RLWE_cont_rd_wr(c0, ocl_bar_handle, &rc, read_fd, write_fd);
			//std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> expanded_RLWE_0 = FPGA::fpga_expand_RLWE_batch_rd_wr(c0, ocl_bar_handle, &rc, read_fd, write_fd);
			auto after_expand = high_resolution_clock::now();

			auto time_expand = duration_cast<milliseconds>(after_expand - before_expand);
			cout << "RLWE expansion takes " << time_expand.count() << " ms" << endl;
	
			if(rc != 0){
				std::cout << "Error while expanding RLWE with fpga" << std::endl;
				if(read_fd >= 0){
					close(read_fd);
				}
				if(write_fd >= 0){
					close(write_fd);
				}
	    		if (ocl_bar_handle >= 0) {
	    		    rc = fpga_pci_detach(ocl_bar_handle);
	    		    if (rc) {
						std::cout << "Failure while detaching from the fpga." << std::endl;
	    		    }
	    		}
				return(-1);	
			}

			cout << "verifying expansion 0 result" << endl;
			for(int i = 0; i < N; i++){
				RLWE::RLWE_plaintext p_tmp = RLWE::RLWE_decrypt(sk, (*expanded_RLWE_0)[i], 2);
				max_noise = max_noise > p_tmp.max_noise ? max_noise : p_tmp.max_noise;
				if(p_tmp.m[0] != 1){
					cout << "expansion failed!!!" << endl;
					if(read_fd >= 0){
						close(read_fd);
					}
					if(write_fd >= 0){
						close(write_fd);
					}
	    			if (ocl_bar_handle >= 0) {
	    			    rc = fpga_pci_detach(ocl_bar_handle);
	    			    if (rc) {
							std::cout << "Failure while detaching from the fpga." << std::endl;
	    			    }
	    			}
					return(-1);
				}
			}

			cout << "expanded poly 0 successfully" << endl;
			cout << "max noise = " << max_noise << endl;

			max_noise = 0;	
			cout << "expanding ciphertext 1" << endl;
			std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> expanded_RLWE_1 = FPGA::fpga_expand_RLWE(c1, ocl_bar_handle, &rc, read_fd, write_fd);	
			//std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> expanded_RLWE_1 = FPGA::fpga_expand_RLWE_cont_rd_wr(c1, ocl_bar_handle, &rc, read_fd, write_fd);	
			//std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> expanded_RLWE_1 = FPGA::fpga_expand_RLWE_batch_rd_wr(c1, ocl_bar_handle, &rc, read_fd, write_fd);	
			if(rc != 0){
				std::cout << "Error while expanding RLWE with fpga" << std::endl;
				if(read_fd >= 0){
					close(read_fd);
				}
				if(write_fd >= 0){
					close(write_fd);
				}
	    		if (ocl_bar_handle >= 0) {
	    		    rc = fpga_pci_detach(ocl_bar_handle);
	    		    if (rc) {
						std::cout << "Failure while detaching from the fpga." << std::endl;
	    		    }
	    		}
				return(-1);	
			}

			cout << "verifying expansion 1 result" << endl;
			for(int i = 0; i < N; i++){
				RLWE::RLWE_plaintext p_tmp = RLWE::RLWE_decrypt(sk, (*expanded_RLWE_1)[i], 2);
				max_noise = max_noise > p_tmp.max_noise ? max_noise : p_tmp.max_noise;
				if(i % 2 == 1){
					if(p_tmp.m[0] != 1){
						cout << "expansion failed!!!" << endl;
						if(read_fd >= 0){
							close(read_fd);
						}
						if(write_fd >= 0){
							close(write_fd);
						}
	    				if (ocl_bar_handle >= 0) {
	    				    rc = fpga_pci_detach(ocl_bar_handle);
	    				    if (rc) {
								std::cout << "Failure while detaching from the fpga." << std::endl;
	    				    }
	    				}
						return(-1);
					}
				} else{
					if(p_tmp.m[0] != 0){
						cout << "expansion failed!!!" << endl;
						if(read_fd >= 0){
							close(read_fd);
						}
						if(write_fd >= 0){
							close(write_fd);
						}
	    				if (ocl_bar_handle >= 0) {
	    				    rc = fpga_pci_detach(ocl_bar_handle);
	    				    if (rc) {
								std::cout << "Failure while detaching from the fpga." << std::endl;
	    				    }
	    				}
						return(-1);
					}
				}
			}
			cout << "expanded poly 1 successfully" << endl;
			cout << "max noise = " << max_noise << endl;
		}
		if(read_fd >= 0){
			close(read_fd);
		}
		if(write_fd >= 0){
			close(write_fd);
		}
	    if (ocl_bar_handle >= 0) {
	        rc = fpga_pci_detach(ocl_bar_handle);
	        if (rc) {
				std::cout << "Failure while detaching from the fpga." << std::endl;
				return(-1);	
	        }
	    }
		return(0);
	}


	int fpga_homo_expansion_test(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk, int slot_id){
		int pf_id = FPGA_APP_PF;
		int bar_id = APP_PF_BAR0;
	    int rc;
	   	int	read_fd = -1;
		int write_fd = -1;

		cout << "generating the substitution key" << endl;
		application::substitute_key subs_key(sk, uni_dist, norm_dist);

		cout << "generate RGSW encryption of -s" << endl;
		RLWE::RLWE_secretkey sk_tmp = sk;
		sk_tmp.to_time_domain();
		RLWE::RGSW_plaintext tmp_p_RGSW;
		for(int i = 0; i < N; i++){
			tmp_p_RGSW.m.m[i] = (Q - sk_tmp.a[i]) % Q;
		}
		tmp_p_RGSW.m.NTT_form = false;
		tmp_p_RGSW.m.to_freq_domain();
		RLWE::RGSW_ciphertext RGSW_neg_s(tmp_p_RGSW, sk, uni_dist, norm_dist);

		//transfer subskey
		rc = FPGA::dma_write_subs_key(slot_id, subs_key);
		if(rc != 0){
			std::cout << "subskey transfer failed!!!" << std::endl;
			return(-1);
		}

		//read and compare subskey
		rc = FPGA::dma_read_compare_subs_key(slot_id, subs_key);
		if(rc != 0){
			std::cout << "subskey read and compare failed!!!" << std::endl;
			return(-1);
		}
		
		//transfer RGSW encrypted -s
		rc = FPGA::dma_write_RGSW_enc_sk(slot_id, RGSW_neg_s);
		if(rc != 0){
			std::cout << " RGSW(-s) transfer failed!!!" << std::endl;
			return(-1);
		}
		
		//read and compare RGSW encrypted -s	
		rc = FPGA::dma_read_compare_RGSW_enc_sk(slot_id, RGSW_neg_s);
		if(rc != 0){
			std::cout << "RGSW(-s) read and compare failed!!!" << std::endl;
			return(-1);
		}

	    pci_bar_handle_t ocl_bar_handle = PCI_BAR_HANDLE_INIT;

	    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &ocl_bar_handle);
		if(rc != 0){
			std::cout << "Unable to attach to the AFI" << std::endl;
			return(-1);
		}
		
	    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ true);
	    write_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ false);
		if(read_fd < 0 || write_fd < 0){
			std::cout << "unable to open read/write dma queue" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if(write_fd >= 0){
				close(write_fd);
			}
	    	if (ocl_bar_handle >= 0) {
	    	    rc = fpga_pci_detach(ocl_bar_handle);
	    	    if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    	    }
	    	}
			return(-1);	
		}

		cout << "build packed bits RLWE vector" << endl;
		auto packed_bits = std::make_unique<std::vector<RLWE::RLWE_ciphertext>>(digitG);
		ciphertext_t pow_BG = 1;
		for(uint16_t i = 0; i < digitG; i++){
			RLWE::RLWE_plaintext tmp_p;
			for(uint16_t j = 0; j < N; j++){
				if(j % 2 == 0){
					tmp_p.m[j] = 0;
				} else {
					tmp_p.m[j] = mod_general((long_ciphertext_t)pow_BG * (long_ciphertext_t)iN, Q);
				}
			}
			tmp_p.NTT_form = false;
			tmp_p.to_freq_domain();
			(*packed_bits)[i] = std::move(RLWE::RLWE_encrypt(sk, tmp_p, uni_dist, norm_dist));
			pow_BG = mod_general((long_ciphertext_t)pow_BG * (long_ciphertext_t)BG, Q);
		}

		cout << "start homo expansion" << endl;
		auto before_expand = high_resolution_clock::now();
		std::shared_ptr<std::vector<RLWE::RGSW_ciphertext>> expanded_RGSW = FPGA::fpga_homo_expand(packed_bits, ocl_bar_handle, &rc, read_fd, write_fd);
		auto after_expand = high_resolution_clock::now();
		cout << "homo expansion takes " << duration_cast<milliseconds>(after_expand - before_expand).count() << " ms" << endl;
		if(rc != 0){
			std::cout << "Error while homo expansion with fpga" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if(write_fd >= 0){
				close(write_fd);
			}
	    	if (ocl_bar_handle >= 0) {
	    	    rc = fpga_pci_detach(ocl_bar_handle);
	    	    if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    	    }
	    	}
			return(-1);	
		}

		cout << "using expanded RGSW to do CMUX" << endl;
		//prepare two RLWE plaintext for MUX inputs 
		std::vector<ciphertext_t> poly_0(N);
		std::vector<ciphertext_t> poly_1(N);
		ciphertext_t Q2 = Q/2;
		for(int i = 0; i < N; i++){
			if(i % 2 == 0){
				poly_0[i] = Q2;
				poly_1[i] = 0;
			}else{
				poly_0[i] = 0;
				poly_1[i] = Q2;
			}
		}
		cout << "Q2 = " << Q2 << endl;;
		
		
		RLWE::RLWE_plaintext p0(poly_0, false);
		RLWE::RLWE_plaintext p1(poly_1, false);

		std::vector<RLWE::RLWE_plaintext> p_MUXed(N);
		for(int i = 0; i < N; i++){
			if(i % 2 == 0){
				RLWE::RLWE_plaintext tmp(poly_1, false);
				p_MUXed[i] = std::move(tmp);
			} else {
				RLWE::RLWE_plaintext tmp(poly_0, false);
				p_MUXed[i] = std::move(tmp);
			}

		}
		//prepare two RLWE ciphertext for MUX inputs 
		RLWE::RLWE_ciphertext c0 = RLWE::RLWE_encrypt(sk, p0, uni_dist, norm_dist);
		RLWE::RLWE_ciphertext c1 = RLWE::RLWE_encrypt(sk, p1, uni_dist, norm_dist);
		
		//perform MUX
		for(int i = 0; i < N; i++){
			RLWE::RLWE_ciphertext c_MUXed = RLWE::CMUX(c0, c1, (*expanded_RGSW)[i]);
			p_MUXed[i] = std::move(RLWE::RLWE_decrypt(sk, c_MUXed, 2));
		}
		//scale the output 
		p0.denoise(2);	
		p1.denoise(2);	

		for(int i = 0; i < N; i++){
			for (int j = 0; j < N; j++){
				if(i % 2 == 0){
					if(p_MUXed[i].m[j] != p0.m[j]){
						cout << "muxed VS ground truth failed at packed bit " << i << "!!!" << endl;
						cout << "p_MUXed[" << i << "].m[" << j << "] = " << p_MUXed[i].m[j] << endl;
						p_MUXed[i].display();
						if(read_fd >= 0){
							close(read_fd);
						}
						if(write_fd >= 0){
							close(write_fd);
						}
	    				if (ocl_bar_handle >= 0) {
	    				    rc = fpga_pci_detach(ocl_bar_handle);
	    				    if (rc) {
								std::cout << "Failure while detaching from the fpga." << std::endl;
								return(-1);	
	    				    }
	    				}
						return(-1);
					}
				} else {
					if(p_MUXed[i].m[j] != p1.m[j]){
						cout << "muxed VS ground truth failed at packed bit " << i << "!!!" << endl;
						cout << "p_MUXed[" << i << "].m[" << j << "] = " << p_MUXed[i].m[j] << endl;
						p_MUXed[i].display();
						if(read_fd >= 0){
							close(read_fd);
						}
						if(write_fd >= 0){
							close(write_fd);
						}
	    				if (ocl_bar_handle >= 0) {
	    				    rc = fpga_pci_detach(ocl_bar_handle);
	    				    if (rc) {
								std::cout << "Failure while detaching from the fpga." << std::endl;
								return(-1);	
	    				    }
	    				}
						return(-1);
					}
				}
			
			}
		}
		cout << "homo expansion succeeds " << endl;
		cout << "plaintext 0[0]" << p0.m[0] << endl;
		cout << "plaintext 1[0]" << p1.m[0] << endl;

		cout << "MUXed plaintext 0[0]" << p_MUXed[0].m[0] << endl;
		cout << "MUXed plaintext 1[0]" << p_MUXed[1].m[0] << endl;
		if(read_fd >= 0){
			close(read_fd);
		}
		if(write_fd >= 0){
			close(write_fd);
		}
	    if (ocl_bar_handle >= 0) {
	        rc = fpga_pci_detach(ocl_bar_handle);
	        if (rc) {
				std::cout << "Failure while detaching from the fpga." << std::endl;
				return(-1);	
	        }
	    }
		return(0);
	}

	int fpga_homo_expansion_and_tree_selection_test(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk, int slot_id){
		int pf_id = FPGA_APP_PF;
		int bar_id = APP_PF_BAR0;
	    int rc;
	   	int	read_fd = -1;
		int write_fd = -1;

		cout << "generating the substitution key" << endl;
		application::substitute_key subs_key(sk, uni_dist, norm_dist);

		cout << "generate RGSW encryption of -s" << endl;
		RLWE::RLWE_secretkey sk_tmp = sk;
		sk_tmp.to_time_domain();
		RLWE::RGSW_plaintext tmp_p_RGSW;
		for(int i = 0; i < N; i++){
			tmp_p_RGSW.m.m[i] = (Q - sk_tmp.a[i]) % Q;
		}
		tmp_p_RGSW.m.NTT_form = false;
		tmp_p_RGSW.m.to_freq_domain();
		RLWE::RGSW_ciphertext RGSW_neg_s(tmp_p_RGSW, sk, uni_dist, norm_dist);

		//transfer subskey
		rc = FPGA::dma_write_subs_key(slot_id, subs_key);
		if(rc != 0){
			std::cout << "subskey transfer failed!!!" << std::endl;
			return(-1);
		}

		//read and compare subskey
		rc = FPGA::dma_read_compare_subs_key(slot_id, subs_key);
		if(rc != 0){
			std::cout << "subskey read and compare failed!!!" << std::endl;
			return(-1);
		}

		//transfer RGSW encrypted -s
		rc = FPGA::dma_write_RGSW_enc_sk(slot_id, RGSW_neg_s);
		if(rc != 0){
			std::cout << " RGSW(-s) transfer failed!!!" << std::endl;
			return(-1);
		}

		//read and compare RGSW encrypted -s	
		rc = FPGA::dma_read_compare_RGSW_enc_sk(slot_id, RGSW_neg_s);
		if(rc != 0){
			std::cout << "RGSW(-s) read and compare failed!!!" << std::endl;
			return(-1);
		}

	    pci_bar_handle_t ocl_bar_handle = PCI_BAR_HANDLE_INIT;

	    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &ocl_bar_handle);
		if(rc != 0){
			std::cout << "Unable to attach to the AFI" << std::endl;
			return(-1);
		}

	    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ true);
	    write_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ false);
		if(read_fd < 0 || write_fd < 0){
			std::cout << "unable to open read/write dma queue" << std::endl;
			if(read_fd >= 0)
				close(read_fd);
			if(write_fd >= 0)
				close(write_fd);
	    	if (ocl_bar_handle >= 0) {
	    	    rc = fpga_pci_detach(ocl_bar_handle);
	    	    if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    	    }
	    	}
			return(-1);	
		}


		cout << "build packed bits RLWE vector" << endl;
		auto packed_bits = std::make_unique<std::vector<RLWE::RLWE_ciphertext>>(digitG);
		ciphertext_t pow_BG = 1;
		for(uint16_t i = 0; i < digitG; i++){
			RLWE::RLWE_plaintext tmp_p;
			for(uint16_t j = 0; j < N; j++){
				if(j % 2 == 0){
					tmp_p.m[j] = 0;
				} else {
					tmp_p.m[j] = mod_general((long_ciphertext_t)pow_BG * (long_ciphertext_t)iN, Q);
				}
			}
			tmp_p.NTT_form = false;
			tmp_p.to_freq_domain();
			(*packed_bits)[i] = std::move(RLWE::RLWE_encrypt(sk, tmp_p, uni_dist, norm_dist));
			pow_BG = mod_general((long_ciphertext_t)pow_BG * (long_ciphertext_t)BG, Q);
		}

		cout << "start homo expansion" << endl;
		auto before_expand = high_resolution_clock::now();
		std::shared_ptr<std::vector<RLWE::RGSW_ciphertext>> expanded_RGSW = FPGA::fpga_homo_expand(packed_bits, ocl_bar_handle, &rc, read_fd, write_fd);
		auto after_expand = high_resolution_clock::now();
		cout << "homo expansion takes " << duration_cast<milliseconds>(after_expand - before_expand).count() << " ms" << endl;
		if(rc != 0){
			std::cout << "Error while homo expansion with fpga" << std::endl;
			if(read_fd >= 0)
				close(read_fd);
			if(write_fd >= 0)
				close(write_fd);
	    	if (ocl_bar_handle >= 0) {
	    	    rc = fpga_pci_detach(ocl_bar_handle);
	    	    if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    	    }
	    	}
			return(-1);	
		}

		cout << "using expanded RGSW to perform tree selection" << endl;
		cout << "prepare array of RLWE ciphertexts tree selection" << endl; 
		cout << "selected position is 1010101--01010101010, 85--682" << endl;

		uint32_t total_digits = 18;
		uint32_t packed_array_size = 1 << (total_digits - digitN);
		cout << "packed array size = " << packed_array_size << endl;
		cout << "total digits = " << total_digits << endl;
		cout << "digitN = " << digitN << endl;
		ciphertext_t Q2 = Q/2;
		std::vector<RLWE::RLWE_ciphertext> v_ctext(packed_array_size);
		for(uint32_t i = 0; i < packed_array_size; i++){
			std::vector<ciphertext_t> poly(N);
			uint32_t j = 0;
			for(; j <= i; j++){
				poly[j] = Q2;
			}
			for(; j < (uint32_t)N; j++){
				poly[j] = 0;
			}
			
			RLWE::RLWE_plaintext p(poly, false);
			v_ctext[i] = RLWE::RLWE_encrypt(sk, p, uni_dist, norm_dist);
		}	
		cout << "Q2 = " << Q2 << endl;;

		cout << "binary tree selection with the 18 LSBs from packed RGSW bits" << endl;

		//setup dma buffer
		uint64_t ddr_addr = (1ULL << 31);
		uint32_t ocl_rd_data;
		long sz = sysconf(_SC_PAGESIZE);
		uint64_t buffer_size 	= N * 2 * 8;
		uint64_t RGSW_size = 2 * digitG * buffer_size;
		uint64_t *read_buffer 	= (uint64_t * ) aligned_alloc(sz, buffer_size);
		uint64_t *write_buffer 	= (uint64_t * ) aligned_alloc(sz, buffer_size);

	    if (read_buffer == NULL || write_buffer == NULL) {
			if(read_buffer != NULL)
				free(read_buffer);
			if(write_buffer != NULL)
				free(write_buffer);	

			if(read_fd >= 0)
				close(read_fd);
			if(write_fd >= 0)
				close(write_fd);
	    	if (ocl_bar_handle >= 0) {
	    	    rc = fpga_pci_detach(ocl_bar_handle);
	    	    if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    	    }
	    	}
			std::cout << "not enough memory to allocate read/write dma buffer" << std::endl; 
			rc = -ENOMEM;
			return(-1);
	    }

		ddr_addr = (1ULL << 31);
		//transfer RGSW to DDR
		std::cout << "transfer RGSWs to DDR" << std::endl; 
		auto bf_RGSW_transfer = high_resolution_clock::now();
		for(uint16_t k = 0; k < total_digits; k++){
			for(uint16_t i = 0; i < 2; i++){
				for(uint16_t j = 0; j < digitG; j++){
					//std::cout << "ddr_addr = " << ddr_addr << std::endl;
					rc = FPGA::dma_write_RLWE(write_fd, (*expanded_RGSW)[k].c_text[j][i], write_buffer, ddr_addr);
					if(rc != 0){
						std::cout << "dma write to ddr fail at i=" << i << ", j=" << j << ", k=" << k << std::endl;
						if(write_buffer != NULL)
							free(write_buffer);
						if(read_buffer != NULL)
							free(read_buffer);
						if(read_fd >= 0)
							close(read_fd);
						if(write_fd >= 0)
							close(write_fd);
	    				if (ocl_bar_handle >= 0) {
	    				    rc = fpga_pci_detach(ocl_bar_handle);
	    				    if (rc) {
								std::cout << "Failure while detaching from the fpga." << std::endl;
	    				    }
	    				}

						return(-1);
					}
					ddr_addr += buffer_size;
				}
			}
		}	
		auto af_RGSW_transfer = high_resolution_clock::now();
		cout << "RGSW transfer takes " << duration_cast<microseconds>(af_RGSW_transfer - bf_RGSW_transfer).count() << " us" << endl;

		//CMUX tree 
		//maunal cmux tree, test each stage time	
		for(uint16_t i = digitN; i < total_digits; i++){
			cout << "in loop " << i << endl;
			//compute all substraction
			auto bf_subtraction = high_resolution_clock::now();
			for(uint16_t j = 1; j < packed_array_size; j += 2){
				v_ctext[j] = RLWE::RLWE_subtraction(v_ctext[j], v_ctext[j-1]);
			}
			auto af_subtraction = high_resolution_clock::now();
			cout << "subtraction takes " << duration_cast<microseconds>(af_subtraction - bf_subtraction).count() << " us" << endl;

			//compute all mult	
			uint16_t fpga_write_idx = 0;
			uint16_t fpga_read_idx = 0;
			ddr_addr = (1ULL << 31) + i * RGSW_size;

			auto bf_mult = high_resolution_clock::now();
			while(fpga_read_idx < (packed_array_size / 2)){
				//check if input fifo is full
				rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
				if(rc != 0){
					if(read_buffer != NULL)
						free(read_buffer);
					if(write_buffer != NULL)
						free(write_buffer);	
					if(read_fd >= 0)
						close(read_fd);
					if(write_fd >= 0)
						close(write_fd);
	    			if (ocl_bar_handle >= 0) {
	    			    rc = fpga_pci_detach(ocl_bar_handle);
	    			    if (rc) {
							std::cout << "Failure while detaching from the fpga." << std::endl;
	    			    }
	    			}
					std::cout << "ocl peek failed!!!" << std::endl;
					return(-1);
				}

				//write new input if not full	
				while(fpga_write_idx < (packed_array_size / 2) && 
					!FPGA::get_fifo_state(ocl_rd_data, RLWE_INPUT_FIFO_FULL) && 
					!FPGA::get_fifo_state(ocl_rd_data, ROB_FULL) && 
					!FPGA::get_fifo_state(ocl_rd_data, KEY_LOAD_FIFO_FULL)){

					//std::cout << "Writing RLWE " << fpga_write_idx << std::endl;
					//write RLWE
					rc = FPGA::dma_write_RLWE(write_fd, v_ctext[(fpga_write_idx << 1) + 1], write_buffer, INPUT_FIFO_ADDR);
					if(rc != 0){
						if(read_buffer != NULL)
							free(read_buffer);
						if(write_buffer != NULL)
							free(write_buffer);	
						if(read_fd >= 0)
							close(read_fd);
						if(write_fd >= 0)
							close(write_fd);
	    				if (ocl_bar_handle >= 0) {
	    				    rc = fpga_pci_detach(ocl_bar_handle);
	    				    if (rc) {
								std::cout << "Failure while detaching from the fpga." << std::endl;
	    				    }
	    				}
						std::cout << "DMA write RLWE failed!!!" << std::endl;
						return(-1);
					}
					//write instruction
	    			rc = fpga_pci_poke(ocl_bar_handle, ADDR_INST_IN, FPGA::form_instruction(RLWE_MULT_RGSW, 0, 0, 0, (uint32_t)(ddr_addr >> 14)));
					if(rc != 0){
						if(read_buffer != NULL)
							free(read_buffer);
						if(write_buffer != NULL)
							free(write_buffer);	
						if(read_fd >= 0)
							close(read_fd);
						if(write_fd >= 0)
							close(write_fd);
	    				if (ocl_bar_handle >= 0) {
	    				    rc = fpga_pci_detach(ocl_bar_handle);
	    				    if (rc) {
								std::cout << "Failure while detaching from the fpga." << std::endl;
	    				    }
	    				}
						std::cout << "ocl poke failed!!!" << std::endl;
						return(-1);
					}

					fpga_write_idx++;
					//check fifo state
					rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
					if(rc != 0){
						if(read_buffer != NULL)
							free(read_buffer);
						if(write_buffer != NULL)
							free(write_buffer);	
						if(read_fd >= 0)
							close(read_fd);
						if(write_fd >= 0)
							close(write_fd);
	    				if (ocl_bar_handle >= 0) {
	    				    rc = fpga_pci_detach(ocl_bar_handle);
	    				    if (rc) {
								std::cout << "Failure while detaching from the fpga." << std::endl;
	    				    }
	    				}
						std::cout << "ocl peek failed!!!" << std::endl;
						return(-1);
					}
					//print_fifo_states(ocl_rd_data);
				}
				do{
					//check if output fifo is not empty
					rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
					if(rc != 0){
						if(read_buffer != NULL)
							free(read_buffer);
						if(write_buffer != NULL)
							free(write_buffer);	
						if(read_fd >= 0)
							close(read_fd);
						if(write_fd >= 0)
							close(write_fd);
	    				if (ocl_bar_handle >= 0) {
	    				    rc = fpga_pci_detach(ocl_bar_handle);
	    				    if (rc) {
								std::cout << "Failure while detaching from the fpga." << std::endl;
	    				    }
	    				}
						std::cout << "ocl peek failed!!!" << std::endl;
						return(-1);
					}
					//print_fifo_states(ocl_rd_data);

					//read from output fifo if not empty
					if(!FPGA::get_fifo_state(ocl_rd_data, RLWE_OUTPUT_FIFO_EMPTY)){
						//std::cout << "Reading RLWE " << fpga_read_idx << std::endl;
						v_ctext[(fpga_read_idx << 1) + 1] = std::move(FPGA::dma_read_RLWE(read_fd, &rc, read_buffer, OUTPUT_FIFO_ADDR));
						if(rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							if(write_buffer != NULL)
								free(write_buffer);	
							if(read_fd >= 0)
								close(read_fd);
							if(write_fd >= 0)
								close(write_fd);
	    					if (ocl_bar_handle >= 0) {
	    					    rc = fpga_pci_detach(ocl_bar_handle);
	    					    if (rc) {
									std::cout << "Failure while detaching from the fpga." << std::endl;
	    					    }
	    					}
							std::cout << "DMA read failed!!!" << std::endl;
							return(-1);
						}

						fpga_read_idx++;
					}
				}while(fpga_write_idx >= (packed_array_size / 2) && fpga_read_idx < (packed_array_size / 2));
			}
			auto af_mult = high_resolution_clock::now();
			cout << "mult takes " << duration_cast<microseconds>(af_mult - bf_mult).count() << " us" << endl;

			//compute all addition 
			auto bf_add = high_resolution_clock::now();
			for(uint16_t j = 0; j < packed_array_size; j += 2){
				v_ctext[j/2] = RLWE::RLWE_addition(v_ctext[j], v_ctext[j + 1]);
			}
			auto af_add = high_resolution_clock::now();
			cout << "addition takes " << duration_cast<microseconds>(af_add - bf_add).count() << " us" << endl;

			packed_array_size >>= 1;
		}

		//RLWE::RLWE_plaintext p_selected = RLWE::RLWE_decrypt(sk, v_ctext[0], 2);

		//cout << "selected ciphertext decrypted" << endl;
		//p_selected.display();

		cout << "blind rotate" << endl;
		//std::vector<RLWE::RGSW_ciphertext> rotate_bits(expanded_RGSW->begin(), expanded_RGSW->begin() + digitN);
		//if(rotate_bits.size() != (uint32_t)digitN){
		//	cout << "rotate bits not the same size" << endl;
		//	exit(1);
		//}
		
		//blind rotate
		//manually rotate multiple copies of the input RGSW vector for better parallelism 	
		auto before_blind_rotate = high_resolution_clock::now();
		for(uint16_t i = 0; i < num_rotate_poly; i++){
			std::cout << "in loop " << i << std::endl;
			//rotate
			auto bf_rotate = high_resolution_clock::now();
			RLWE::RLWE_ciphertext tmp = RLWE_rotate_freq(v_ctext[0], i, false);
			auto af_rotate = high_resolution_clock::now();
			cout << "rotate takes " << duration_cast<microseconds>(af_rotate - bf_rotate).count() << " us" << endl;

			//manual CMUX, with multiple copy of the same operation to amortize the time	
			//subtraction 
			tmp = RLWE::RLWE_subtraction(tmp, v_ctext[0]);

			//mult
			int fpga_write_idx = 0;
			int fpga_read_idx = 0;
			ddr_addr = (1ULL << 31) + i * RGSW_size;

			RLWE::RLWE_ciphertext mult;
			auto bf_mult = high_resolution_clock::now();
			//this is repeated to test continuously streamed performanced 
			while(fpga_read_idx < 1){
				//check if input fifo is full
				rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
				if(rc != 0){
					if(read_buffer != NULL)
						free(read_buffer);
					if(write_buffer != NULL)
						free(write_buffer);	
					if(read_fd >= 0)
						close(read_fd);
					if(write_fd >= 0)
						close(write_fd);
	    			if (ocl_bar_handle >= 0) {
	    			    rc = fpga_pci_detach(ocl_bar_handle);
	    			    if (rc) {
							std::cout << "Failure while detaching from the fpga." << std::endl;
	    			    }
	    			}
					std::cout << "ocl peek failed!!!" << std::endl;
					return(-1);
				}

				//write new input if not full	
				while(fpga_write_idx < 1 && 
					!FPGA::get_fifo_state(ocl_rd_data, RLWE_INPUT_FIFO_FULL) && 
					!FPGA::get_fifo_state(ocl_rd_data, ROB_FULL) && 
					!FPGA::get_fifo_state(ocl_rd_data, KEY_LOAD_FIFO_FULL)){
					//std::cout << "Writing RLWE " << fpga_write_idx << std::endl;
					//write RLWE
					rc = FPGA::dma_write_RLWE(write_fd, tmp, write_buffer, INPUT_FIFO_ADDR);
					if(rc != 0){
						if(read_buffer != NULL)
							free(read_buffer);
						if(write_buffer != NULL)
							free(write_buffer);	
						if(read_fd >= 0)
							close(read_fd);
						if(write_fd >= 0)
							close(write_fd);
	    				if (ocl_bar_handle >= 0) {
	    				    rc = fpga_pci_detach(ocl_bar_handle);
	    				    if (rc) {
								std::cout << "Failure while detaching from the fpga." << std::endl;
	    				    }
	    				}
						std::cout << "DMA write RLWE failed!!!" << std::endl;
						return(-1);
					}
					//write instruction
	    			rc = fpga_pci_poke(ocl_bar_handle, ADDR_INST_IN, FPGA::form_instruction(RLWE_MULT_RGSW, 0, 0, 0, (uint32_t)(ddr_addr >> 14)));
					if(rc != 0){
						if(read_buffer != NULL)
							free(read_buffer);
						if(write_buffer != NULL)
							free(write_buffer);	
						if(read_fd >= 0)
							close(read_fd);
						if(write_fd >= 0)
							close(write_fd);
	    				if (ocl_bar_handle >= 0) {
	    				    rc = fpga_pci_detach(ocl_bar_handle);
	    				    if (rc) {
								std::cout << "Failure while detaching from the fpga." << std::endl;
	    				    }
	    				}
						std::cout << "ocl poke failed!!!" << std::endl;
						return(-1);
					}

					fpga_write_idx++;
					//check fifo state
					rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
					if(rc != 0){
						if(read_buffer != NULL)
							free(read_buffer);
						if(write_buffer != NULL)
							free(write_buffer);	
						if(read_fd >= 0)
							close(read_fd);
						if(write_fd >= 0)
							close(write_fd);
	    				if (ocl_bar_handle >= 0) {
	    				    rc = fpga_pci_detach(ocl_bar_handle);
	    				    if (rc) {
								std::cout << "Failure while detaching from the fpga." << std::endl;
	    				    }
	    				}
						std::cout << "ocl peek failed!!!" << std::endl;
						return(-1);
					}
					//print_fifo_states(ocl_rd_data);
				}
				do{
					//check if output fifo is not empty
					rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
					if(rc != 0){
						if(read_buffer != NULL)
							free(read_buffer);
						if(write_buffer != NULL)
							free(write_buffer);	
						if(read_fd >= 0)
							close(read_fd);
						if(write_fd >= 0)
							close(write_fd);
	    				if (ocl_bar_handle >= 0) {
	    				    rc = fpga_pci_detach(ocl_bar_handle);
	    				    if (rc) {
								std::cout << "Failure while detaching from the fpga." << std::endl;
	    				    }
	    				}
						std::cout << "ocl peek failed!!!" << std::endl;
						return(-1);
					}
					//print_fifo_states(ocl_rd_data);

					//read from output fifo if not empty
					if(!FPGA::get_fifo_state(ocl_rd_data, RLWE_OUTPUT_FIFO_EMPTY)){
						//std::cout << "Reading RLWE " << fpga_read_idx << std::endl;
						mult = std::move(FPGA::dma_read_RLWE(read_fd, &rc, read_buffer, OUTPUT_FIFO_ADDR));
						if(rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							if(write_buffer != NULL)
								free(write_buffer);	
							if(read_fd >= 0)
								close(read_fd);
							if(write_fd >= 0)
								close(write_fd);
	    					if (ocl_bar_handle >= 0) {
	    					    rc = fpga_pci_detach(ocl_bar_handle);
	    					    if (rc) {
									std::cout << "Failure while detaching from the fpga." << std::endl;
	    					    }
	    					}
							std::cout << "DMA read failed!!!" << std::endl;
							return(-1);
						}

						fpga_read_idx++;
					}
				}while(fpga_write_idx >= 1 && fpga_read_idx < 1);
			}
			auto af_mult = high_resolution_clock::now();
			cout << "blind mult takes " << duration_cast<microseconds>(af_mult - bf_mult).count() << " us" << endl;
			
			v_ctext[0] = RLWE::RLWE_addition(v_ctext[0], mult);
		}


		auto after_blind_rotate = high_resolution_clock::now();
		cout << "blind rotate takes " << duration_cast<milliseconds>(after_blind_rotate - before_blind_rotate).count() << " ms" << endl;
	
		RLWE::RLWE_ciphertext c_rotated = v_ctext[0];
		RLWE::RLWE_plaintext p_rotated = RLWE::RLWE_decrypt(sk, c_rotated, 2);
		cout << "final plaintext" << endl;
		//p_rotated.display();
		cout << "final plaintext[0]" << p_rotated.m[0] << endl;

		if(read_buffer != NULL)
			free(read_buffer);
		if(write_buffer != NULL)
			free(write_buffer);	
		if(read_fd >= 0)
			close(read_fd);
		if(write_fd >= 0)
			close(write_fd);
		if (ocl_bar_handle >= 0) {
		    rc = fpga_pci_detach(ocl_bar_handle);
		    if (rc) {
				std::cout << "Failure while detaching from the fpga." << std::endl;
		    }
		}
		return(0);

	}

	int fpga_RLWE_subs_test(RNG_uniform &uni_dist, RNG_norm &norm_dist, const RLWE::RLWE_secretkey &sk, int slot_id){
		int pf_id = FPGA_APP_PF;
		int bar_id = APP_PF_BAR0;
	    int rc;
	   	int	read_fd = -1;
		int write_fd = -1;

		cout << "generating the substitution key" << endl;
		auto before_subs_key = high_resolution_clock::now();
		application::substitute_key subs_key(sk, uni_dist, norm_dist);
		auto after_subs_key = high_resolution_clock::now();

		auto time_subs_key = duration_cast<milliseconds>(after_subs_key - before_subs_key);
		cout << "subs key gen takes " << time_subs_key.count() << " ms" << endl;

		//transfer subskey
		rc = FPGA::dma_write_subs_key(slot_id, subs_key);
		if(rc != 0){
			std::cout << "subskey transfer failed!!!" << std::endl;
			return(-1);
		}

		//read and compare subskey
		rc = FPGA::dma_read_compare_subs_key(slot_id, subs_key);
		if(rc != 0){
			std::cout << "subskey read and compare failed!!!" << std::endl;
			return(-1);
		}

	    pci_bar_handle_t ocl_bar_handle = PCI_BAR_HANDLE_INIT;

	    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &ocl_bar_handle);
		if(rc != 0){
			std::cout << "Unable to attach to the AFI" << std::endl;
			return(-1);
		}
		
	    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ true);
	    write_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ false);
		if(read_fd < 0 || write_fd < 0){
			std::cout << "unable to open read/write dma queue" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if(write_fd >= 0){
				close(write_fd);
			}
	    	if (ocl_bar_handle >= 0) {
	    	    rc = fpga_pci_detach(ocl_bar_handle);
	    	    if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    	    }
	    	}
			return(-1);	
		}

		//prepare two RLWE plaintexts for RLWE expansion function
		std::vector<ciphertext_t> poly_0(N);
		std::vector<ciphertext_t> poly_1(N);
		ciphertext_t Q2 = Q/2;
		cout << "Q2*iN = " << mod_general((long_ciphertext_t)Q2 * (long_ciphertext_t)iN, Q) << endl;;
		for(int i = 0; i < N; i++){
			poly_0[i] = mod_general((long_ciphertext_t)Q2 * (long_ciphertext_t)iN, Q);
			if(i % 2 == 0){
				poly_1[i] = mod_general(0 * (long_ciphertext_t)iN, Q);
			} else {
				poly_1[i] = mod_general((long_ciphertext_t)Q2 * (long_ciphertext_t)iN, Q);
			}
		}
			
		cout << "before encrypt" << endl;
		RLWE::RLWE_plaintext p0(poly_0, false);	//all one
		RLWE::RLWE_plaintext p1(poly_1, false);	//even index negQ8, odd index Q8

		//prepare two RLWE ciphertexts for RLWE expansion function
		cout << "encrypting" << endl;
		RLWE::RLWE_ciphertext c0 = RLWE::RLWE_encrypt(sk, p0, uni_dist, norm_dist);
		RLWE::RLWE_ciphertext c1 = RLWE::RLWE_encrypt(sk, p1, uni_dist, norm_dist);
		

		ciphertext_t max_noise = 0;	
		//start expansion 
		cout << "expanding ciphertext 0" << endl;
		auto before_expand = high_resolution_clock::now();
		std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> expanded_RLWE_0 = FPGA::fpga_RLWE_subs_test(c0, sk, subs_key, ocl_bar_handle, &rc, read_fd, write_fd);
		auto after_expand = high_resolution_clock::now();

		auto time_expand = duration_cast<milliseconds>(after_expand - before_expand);
		cout << "RLWE expansion takes " << time_expand.count() << " ms" << endl;
	
		if(rc != 0){
			std::cout << "Error while expanding RLWE with fpga" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if(write_fd >= 0){
				close(write_fd);
			}
	    	if (ocl_bar_handle >= 0) {
	    	    rc = fpga_pci_detach(ocl_bar_handle);
	    	    if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    	    }
	    	}
			return(-1);	
		}

		cout << "verifying expansion 0 result" << endl;
		for(int i = 0; i < N; i++){
			RLWE::RLWE_plaintext p_tmp = RLWE::RLWE_decrypt(sk, (*expanded_RLWE_0)[i], 2);
			max_noise = max_noise > p_tmp.max_noise ? max_noise : p_tmp.max_noise;
			if(p_tmp.m[0] != 1){
				cout << "expansion failed!!!" << endl;
				if(read_fd >= 0){
					close(read_fd);
				}
				if(write_fd >= 0){
					close(write_fd);
				}
	    		if (ocl_bar_handle >= 0) {
	    		    rc = fpga_pci_detach(ocl_bar_handle);
	    		    if (rc) {
						std::cout << "Failure while detaching from the fpga." << std::endl;
	    		    }
	    		}
				return(-1);
			}
		}

		cout << "expanded poly 0 successfully" << endl;
		cout << "max noise = " << max_noise << endl;

		max_noise = 0;	
		cout << "expanding ciphertext 1" << endl;
		std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> expanded_RLWE_1 = FPGA::fpga_RLWE_subs_test(c1, sk, subs_key, ocl_bar_handle, &rc, read_fd, write_fd);	
		if(rc != 0){
			std::cout << "Error while expanding RLWE with fpga" << std::endl;
			if(read_fd >= 0){
				close(read_fd);
			}
			if(write_fd >= 0){
				close(write_fd);
			}
	    	if (ocl_bar_handle >= 0) {
	    	    rc = fpga_pci_detach(ocl_bar_handle);
	    	    if (rc) {
					std::cout << "Failure while detaching from the fpga." << std::endl;
	    	    }
	    	}
			return(-1);	
		}

		cout << "verifying expansion 1 result" << endl;
		for(int i = 0; i < N; i++){
			RLWE::RLWE_plaintext p_tmp = RLWE::RLWE_decrypt(sk, (*expanded_RLWE_1)[i], 2);
			max_noise = max_noise > p_tmp.max_noise ? max_noise : p_tmp.max_noise;
			if(i % 2 == 1){
				if(p_tmp.m[0] != 1){
					cout << "expansion failed!!!" << endl;
					if(read_fd >= 0){
						close(read_fd);
					}
					if(write_fd >= 0){
						close(write_fd);
					}
	    			if (ocl_bar_handle >= 0) {
	    			    rc = fpga_pci_detach(ocl_bar_handle);
	    			    if (rc) {
							std::cout << "Failure while detaching from the fpga." << std::endl;
	    			    }
	    			}
					return(-1);
				}
			} else{
				if(p_tmp.m[0] != 0){
					cout << "expansion failed!!!" << endl;
					if(read_fd >= 0){
						close(read_fd);
					}
					if(write_fd >= 0){
						close(write_fd);
					}
	    			if (ocl_bar_handle >= 0) {
	    			    rc = fpga_pci_detach(ocl_bar_handle);
	    			    if (rc) {
							std::cout << "Failure while detaching from the fpga." << std::endl;
	    			    }
	    			}
					return(-1);
				}
			}
		}
		cout << "expanded poly 1 successfully" << endl;
		cout << "max noise = " << max_noise << endl;

		if(read_fd >= 0){
			close(read_fd);
		}
		if(write_fd >= 0){
			close(write_fd);
		}
	    if (ocl_bar_handle >= 0) {
	        rc = fpga_pci_detach(ocl_bar_handle);
	        if (rc) {
				std::cout << "Failure while detaching from the fpga." << std::endl;
				return(-1);	
	        }
	    }
		return(0);
	}


}
