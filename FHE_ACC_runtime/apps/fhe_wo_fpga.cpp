#include "RNG.h"
#include "test.h"
#include "params.h"
#include "LWE.h"
#include "RLWE.h"
#include "myfpga.h"

#include <iostream>
#include <string>
#include <vector>
#include <bitset>
#include <chrono>
#include <limits>
#include <ios>

using std::cin;
using std::cout;
using std::endl;
using std::bitset;
using std::numeric_limits;
using std::streamsize;
using namespace std::chrono;
using namespace LWE;
using namespace RLWE;

int main(){
//////////////////////////////////////////////////////
//
// Set global variables 
//
/////////////////////////////////////////////////////

	//define all LWE parameters
	//deine the dimensin of LWE ciphtertext
	n = 512;
	
	//define LWE plaintext modulus
	t = 4;
	
	//define the LWE ciphertext modulus
	q = 512;
	
	q2 = q/2;
	
	//define the noise bound of LWE ciphertext
	E = q/16;
	
	//define secret key sample range for LWE
	LWE_sk_range = 3;
	
	//define mean and stddev of normal distribution of the LWE
	LWE_mean = 0;
	LWE_stddev = 3.19;
	
	//define all RLWE/RGSW parameters
	//define the order of RLWE/RGSW cyclotomic polynomial, 
	//order of the 2Nth cyclotomic polynomial is N, with N being a power of 2
	//N = 2048; // it is required that q devides 2N to embed q/2 into N
	N = 1024; // it is required that q devides 2N to embed q/2 into N
	
	N2 = N/2+1;
	
	digitN = (uint16_t)std::log2((double)N);
	
	//define secret key sample range for RLWE
	RLWE_sk_range = 3;
	
	//define mean and stddev of normal distribution of the RLWE
	RLWE_mean = 0;
	RLWE_stddev = 3.19;
	
	//define the noise bound of the RLWE, it seems E_rlwe = omega(\sqrt(log(n)))
	//which in this case is around 3, so for now just put an arbitrary small number
	//need verification
	E_rlwe = 18;
	
	//define the RLWE/RGSW plaintext modulus
	//support STD128 bit security
	
	//as will see, the coefficients of the plaintext polynomial 
	//are in the set {0, 1, -1}, so two bit plaintext modulus
	t_rlwe = 8;
	
	//define number of bit of RLWE modulo Q
	//nbit = 54;
	nbit = 27;
	
	//define the RLWE/RGSW ciphertext modulus, a prime
	Q = previous_prime(first_prime(nbit, N), N);
	
	//define the barrett reduction mu factor
	//extern const long_ciphertext_t mu_factor;
	
	// the inverse of N mod Q, with N * iN = 1 mod Q 
	iN = inverse_mod(N, Q);
	
	//primitive 2Nth root of unity
	ROU = root_of_unity(N, Q);
	
	//twiddle factor table for NTT, in bit reverse order
	//build the ROU table 	
	ROU_table = (ciphertext_t *) malloc(N * sizeof(ciphertext_t));
	iROU_table = (ciphertext_t *) malloc(N * sizeof(ciphertext_t));
	if(ROU_table == NULL || iROU_table == NULL){
		if(ROU_table != NULL)
			free(ROU_table);
		if(iROU_table != NULL)
			free(iROU_table);
		std::cout << "malloc for ROU/iROU table failed" << std::endl;
		return(-ENOMEM);
	}
	
	root_of_unity_table(ROU, Q, N, ROU_table, iROU_table);
	
	//define the decompse base of the RGSW ciphertext
	//ciphertext_t BG = 1 << 11;
	BG = 1 << 9;
	BGbits = (ciphertext_t)std::log2(BG);
	BG_mask = BG - 1;		// a mask with lower 9 bits all one 
	
	//define the size of the RGSW scheme, it is defined as digitG = logBG(Q) 
	digitG = (ciphertext_t)std::ceil(std::log2((double)Q) / std::log2((double)BG));
	digitG2 = 2 * digitG;
	
	//define the refresh base for homomorphically evaluate the decryption 
	//Br = 2;
	Br = 23;
	digitR = (ciphertext_t)std::ceil(std::log2((double)q) / std::log2((double)Br));
	
	//define the key switch base for RLWE-to-LWE key switching, note that it's with respect to Q not q
	Bks = 25;
	//Bks = 2;
	digitKS = (ciphertext_t)std::ceil(std::log2((double)Q) / std::log2((double)Bks));
	
	//define the key switch base for RLWE-to-RLWE key switching, note that it's with respect to Q 
	Bks_R = 1 << 9;
	Bks_R_bits = (ciphertext_t)std::log2(Bks_R);
	digitKS_R = (ciphertext_t)std::ceil(std::log2((double)Q) / std::log2((double)Bks_R));
	Bks_R_mask = Bks_R - 1;

	gate_constant[0] = (ciphertext_t)(5 * (q >> 3)); //OR
	gate_constant[1] = (ciphertext_t)(7 * (q >> 3)); //AND
	gate_constant[2] = (ciphertext_t)(1 * (q >> 3)); //NOR
	gate_constant[3] = (ciphertext_t)(3 * (q >> 3)); //NAND
	gate_constant[4] = (ciphertext_t)(5 * (q >> 3)); //XOR
	gate_constant[5] = (ciphertext_t)(1 * (q >> 3)); //XNOR

	//define the number of rotate polynomials, so that rotation can be done 
	//in a binary decomposed fashion
	//num_rotate_poly = 11;
	
	//build the rotation vectors
	rotate_poly_forward = rotate_vector_gen(true);
	rotate_poly_backward = rotate_vector_gen(false);

 	BARRETT_K 		= nbit;
 	BARRETT_K2 		= BARRETT_K * 2;
	BARRETT_M 		= (1ULL << (BARRETT_K2)) / Q;
	//BARRETT_M 		= 0x0040000000012FFF ;
  	LOG2_RLWE_LEN	= (uint32_t)std::log2((double)N);
 	EMBED_FACTOR 	= N * 2 / q ;
 	TOP_FIFO_MODE	= BTMODE;
////////////////////////////////////////////////////
//
// End set global variables 
//
///////////////////////////////////////////////////

	#ifdef DEBUG
		cout << "in debug" << endl;
		cout << "n = " << n << endl;
		cout << "N = " << N << endl;
	#endif	
	cout << "Set up the parameters" << endl;
	cout << "q = \t" << q << endl;
	cout << "Q = \t" << Q << endl; 
	cout << "N = \t" << N << endl; 
	cout << "iN = \t" << iN << endl;
	cout << "ROU = \t" << ROU << endl;
	
	ciphertext_t prod = mod_general((long_ciphertext_t)N * (long_ciphertext_t)iN, Q);
	if(prod != 1){
		cout << "N*iN != 1, = " << prod << endl;
		exit(1);
	}
	
	cout << "Set up LWE context" << endl;
	// create LWE context 
	RNG_uniform LWE_uni_dist(q);						// uniform dist for a
	RNG_uniform LWE_uni_dist_key(3);					// uniform dist for sk, use a short sk
	RNG_norm LWE_norm_dist(LWE_mean, LWE_stddev);		// normal dist for noise e
	LWE::LWE_secretkey LWE_sk(LWE_uni_dist_key);				// secret key LWE_sk

	cout << "Set up RLWE context" << endl;
	// creat RLWE context
	RNG_uniform RLWE_uni_dist(Q);							// uniform dist for a 
	RNG_uniform RLWE_uni_dist_key(3);						// uniform dist for sk, use a short sk
	RNG_norm RLWE_norm_dist(RLWE_mean, RLWE_stddev);		// normal dist for noise e
	RLWE::RLWE_secretkey RLWE_sk(RLWE_uni_dist_key);				// secret key RLWE_sk


// below are the dedicated tests for different functions

	while(true){
		cout << "+---------------------------------------------------------+" << endl;
        cout << "| The following tests are dedicated to different          |" << endl;
        cout << "| functionalities of this implementation of FHEW+TFHE     |" << endl;
        cout << "| Functions of the tests are defined in test.cpp          |" << endl;
        cout << "+---------------------------------------------------------+" << endl;
        cout << "| tests                                                   |" << endl;
        cout << "+---------------------------------------------------------+" << endl;
        cout << "| 1.   LWE encrypt/decrypt                                |" << endl;
        cout << "| 2.   LWE NAND (no bootstrap)                            |" << endl;
        cout << "| 3.   Scale modulus of LWE                               |" << endl;
        cout << "| 4.   Primality test                                     |" << endl;
        cout << "| 5.   Inverse of N over Q                                |" << endl;
        cout << "| 6.   Verify Root of Unity                               |" << endl;
        cout << "| 7.   NTT test                                           |" << endl;
        cout << "| 8.   RLWE encrypt/decrypt                               |" << endl;
        cout << "| 9.   LWE modulus switch                                 |" << endl;
        cout << "| 10.  RLWE ciphertext transpose                          |" << endl;
        cout << "| 11.  RLWE to LWE ciphertext key switch                  |" << endl;
        cout << "| 12.  LWE binary gates (with bootstrap)                  |" << endl;
        cout << "| 13.  RLWE multiply RGSW (pass only with zero noise)     |" << endl;
        cout << "| 14.  Acc initialization                                 |" << endl;
        cout << "| 15.  RLWE decompose (pass only with zero noise)         |" << endl;
        cout << "| 16.  RLWE time domain VS freq domain decompose          |" << endl;
        cout << "| 17.  RLWE key switch                                    |" << endl;
        cout << "| 18.  CMUX test                                          |" << endl;
        cout << "| 19.  Blind rotate in time domain test                   |" << endl;
        cout << "| 20.  Blind rotate in freq domain test                   |" << endl;
        cout << "| 21.  Homomorphic RLWE to RLWE expansion test            |" << endl;
        cout << "| 22.  Homomorphic RLWE to RGSW expansion test            |" << endl;
        cout << "| 23.  Homomorphic RLWE substitute noise size test        |" << endl;
        cout << "| 24.  Poly substitute test                               |" << endl;
        cout << "| 25.  RGSW packing (not working)                         |" << endl;
        cout << "| 26.  RGSW expansion and binary tree selection           |" << endl;
        cout << "| 27.  RGSW packing and binary tree selection(not working)|" << endl;
        cout << "| 28.  Barrett reduction test                             |" << endl;
        cout << "+---------------------------------------------------------+" << endl;

		int num_of_tests = 28;
		int sel = 0;
		bool valid = true;
		do{
			cout << endl << "> Run example (1 ~ " << num_of_tests << ") or exit (0): ";
            if (!(cin >> sel)){
                valid = false;
            }else if (sel < 0 || sel > num_of_tests){
                valid = false;
            }else{
                valid = true;
            }
			if (!valid){
                cout << "  [Beep~~] valid option: type 0 ~ " << num_of_tests << endl;
                cin.clear();
                //cin.ignore(numeric_limits<streamsize>::max()0x7fffffffffffffff, '\n');
                cin.ignore(0x7fffffffffffffff, '\n');
            }

		}while(!valid);

        switch (sel){
        case 1:
        	cout << "-------------------test::LWE_en_decrypt----------------" << endl;
  			for (int i = 0; i < 1024; i++){
  				cout << "\nTrial No." << i << "--------------" << endl;
  				test::LWE_en_decrypt(LWE_uni_dist, LWE_norm_dist, LWE_sk);
  			}
            break;

        case 2:
            cout << "-------------------test::LWE_NAND----------------" << endl;
			for (int i = 0; i < 1024; i++){
				cout << "\nTrial No." << i << "--------------" << endl;
				test::LWE_NAND(LWE_uni_dist, LWE_norm_dist, LWE_sk);
			}
            break;

        case 3:
            cout << "-------------------test::scale_mod----------------" << endl;
			test::scale_mod();	
            break;

        case 4:
            cout << "-------------------test::prime_test----------------" << endl;
			test::prime();	
            break;

        case 5:
            cout << "-------------------test::verify_iN----------------" << endl;
			test::verify_iN();
            break;

        case 6:
            cout << "-------------------test::verify_ROU----------------" << endl;
			test::verify_ROU();
            break;

        case 7:
            cout << "-------------------test::NTT----------------" << endl;
			test::verify_NTT();
            break;
		
		case 8:
			cout << "-------------------test::RLWE_en_decrypt----------------" << endl;
			for(int i = 0; i < 1024; i++){
				cout << "\nTrial No." << i << "--------------" << endl;
				test::RLWE_en_decrypt(RLWE_uni_dist, RLWE_norm_dist, RLWE_sk);
			}
			break;

		case 9:
			cout << "-------------------test::modswitch----------------" << endl;
			for(int i = 0; i < 1024; i++){
				cout << "\nTrial No." << i << "--------------" << endl;
				test::modswitch();
			}
			break;

		case 10:
			cout << "-------------------test::RLWE_transpose----------------" << endl;
			for(int i = 0; i < 1024; i++){
				cout << "\nTrial No." << i << "--------------" << endl;
				test::RLWE_transpose(RLWE_uni_dist, RLWE_norm_dist, RLWE_sk);
			}
			break;

		case 11:
			{//need to have a scope to create new variables in "switch case"
				cout << "-------------------test::LWE_keyswitch----------------" << endl;
				cout << "Set up RLWE to LWE switching key" << endl;
				// creat keyswtich key, switch from RLWE to LWE
				auto start = high_resolution_clock::now();
				
				LWE::keyswitch_key ks_key(RLWE_sk, LWE_sk, RLWE_uni_dist, RLWE_norm_dist);	//LWE key switch key
				
				auto after_ks_gen = high_resolution_clock::now();
				cout << "LWE key switch gen takes: " << duration_cast<milliseconds>(after_ks_gen - start).count() << " ms" << endl;

				for(int i = 0; i < 1024; i++){
					cout << "\nTrial No." << i << "--------------" << endl;
					test::keyswitch(RLWE_uni_dist, RLWE_norm_dist, LWE_sk, RLWE_sk, ks_key);
				}
			}
			break;

		case 12:
			{
				cout << "-------------------test::bootstrapping----------------" << endl;
				cout << "Set up RLWE to LWE switching key" << endl;
				// creat keyswtich key, switch from RLWE to LWE
				auto start = high_resolution_clock::now();
				
				LWE::keyswitch_key ks_key(RLWE_sk, LWE_sk, RLWE_uni_dist, RLWE_norm_dist);	//LWE key switch key
				
				auto after_ks_gen = high_resolution_clock::now();
				cout << "LWE key switch gen takes: " << duration_cast<milliseconds>(after_ks_gen - start).count() << " ms" << endl;
				
				cout << "Set up bootstrapping key" << endl;
				// creat bootstrap key, refresh noise
				RLWE::bootstrap_key bt_key(LWE_sk, RLWE_sk, RLWE_uni_dist, RLWE_norm_dist);	//bootstraping key 
				
				auto after_bt_gen = high_resolution_clock::now();
				cout << "bootstrap key gen takes: " << duration_cast<seconds>(after_bt_gen - after_ks_gen).count() << " s" << endl;

				int count = 0;
				for(uint32_t i = 0; i < 1024; i++){
					cout << "\nTrial No." << i << "--------------" << endl;
					auto before_bs = high_resolution_clock::now();
					count += test::bootstrapping(LWE_uni_dist, LWE_norm_dist, LWE_sk, bt_key, ks_key);
					auto after_bs = high_resolution_clock::now();
					cout << "bootstrap takes: " << duration_cast<seconds>(after_bs - before_bs).count() << " s" << endl;
				
				}
				cout << "failed " << count << " times" << endl;
			}
			break;

		case 13:
			cout << "-------------------test::RLWE_mult_RGSW----------------" << endl;
			cout << "-----this test only passes when RLWE noise is zero----" << endl;
			for(int i = 0; i < 128; i++){
				cout << "\nTrial No." << i << "--------------" << endl;
			  	test::RLWE_mult_RGSW(RLWE_uni_dist, RLWE_norm_dist, RLWE_sk);
			}
			break;

		case 14:
			cout << "-------------------test::acc_initialize----------------" << endl;
			test::acc_initialize();
			break;

		case 15:
			cout << "-------------------test::RGSW_decompose----------------" << endl;
			cout << "-----this test only passes when RLWE noise is zero----" << endl;
			test::RGSW_decompose(RLWE_uni_dist, RLWE_norm_dist, RLWE_sk);
			break;

		case 16:
			cout << "-------------------test::digit_decompose----------------" << endl;
			test::digit_decompose();
			break;

		case 17:
			{
				cout << "-------------------test::RLWE_keyswitch----------------" << endl;

				cout << "Generate another new RLWE key\n" << endl;
				RLWE_secretkey RLWE_sk_new(RLWE_uni_dist_key);				// generate another secret key RLWE_sk_new
				
				cout << "Set up RLWE to RLWE switching key\n" << endl;
				// creat keyswtich key, switch from RLWE to RLWE
				auto start = high_resolution_clock::now();
				
				RLWE::keyswitch_key RLWE_ks_key(RLWE_sk, RLWE_sk_new, RLWE_uni_dist, RLWE_norm_dist);	//RLWE key switch key
				
				auto after_ks_gen = high_resolution_clock::now();
				cout << "RLWE key switch gen takes: " << duration_cast<milliseconds>(after_ks_gen - start).count() << " ms\n" << endl;

				cout << "Perform RLWE key switch\n" << endl;
				for(int i = 0; i < 1024; i++){
					cout << "\nTrial No." << i << "--------------" << endl;
					test::RLWE_keyswitch(RLWE_uni_dist, RLWE_norm_dist, RLWE_sk, RLWE_sk_new, RLWE_ks_key);
				}
			}
			break;

		case 18: 
			{
				cout << "-------------------test::CMUX----------------" << endl;
				for(int i = 0; i < 1024; i++){
					cout << "\nTrial No." << i << "--------------" << endl;
					test::CMUX(RLWE_uni_dist, RLWE_norm_dist, RLWE_sk);
				}
			
			}
			break;

		case 19:
			{
				cout << "-------------------test::blind_rotate_time----------------" << endl;
				for(int i = 0; i < 1; i++){
					cout << "\nTrial No." << i << "--------------" << endl;
					test::blind_rotate_time(RLWE_uni_dist, RLWE_norm_dist, RLWE_sk);
				}
				
			}
			break;
		case 20:
			{
				cout << "-------------------test::blind_rotate_freq----------------" << endl;
				for(int i = 0; i < 1; i++){
					cout << "\nTrial No." << i << "--------------" << endl;
					test::blind_rotate_freq(RLWE_uni_dist, RLWE_norm_dist, RLWE_sk);
				}
			}
			break;
		case 21:
			{
				cout << "-------------------test::RLWE_expansion----------------" << endl;
				test::RLWE_expansion(RLWE_uni_dist, RLWE_norm_dist, RLWE_sk);
			}
			break;
		case 22:
			{
				cout << "-------------------test::homo_expansion----------------" << endl;
				test::homo_expansion(RLWE_uni_dist, RLWE_norm_dist, RLWE_sk);
			}
			break;
		case 23:
			{
				cout << "-------------------test::substitue_RLWE_noise_increase----------------" << endl;
				test::substitue_RLWE_noise_increase(RLWE_uni_dist, RLWE_norm_dist, RLWE_sk);
			}
			break;
		case 24:
			{
				cout << "-------------------test::poly_substitute----------------" << endl;
				test::poly_substitute();
			}
			break;
		case 25:
			{
				cout << "-------------------test::RGSW_packing----------------" << endl;
				//test::RGSW_packing(RLWE_uni_dist, RLWE_norm_dist, RLWE_sk);
			}
			break;
		case 26:
			{
				cout << "-------------------test::homo_expansion_and_tree_selection----------------" << endl;
				test::homo_expansion_and_tree_selection(RLWE_uni_dist, RLWE_norm_dist, RLWE_sk);
			}
			break;
		case 27:
			{
				cout << "-------------------test::RGSW_packing_and_tree_selection----------------" << endl;
				//test::RGSW_packing_and_tree_selection(RLWE_uni_dist, RLWE_norm_dist, RLWE_sk);
			}
			break;
		case 28:
			{

				cout << "-------------------test::Barrett reduction test----------------" << endl;
				test::barrett_reduction();
			}
			break;
        case 0:
			if(ROU_table != NULL)
				free(ROU_table);
			if(iROU_table != NULL)
				free(iROU_table);
            return 0;
        }

	}

	return 0;
}

