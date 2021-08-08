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
using namespace FPGA;

/* use the stdout logger for printing debug information  */
const struct logger *logger = &logger_stdout;

int main(int argc, char **argv){

    int slot_id = 0;
    int rc = 0;


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
	N = 2048; // it is required that q devides 2N to embed q/2 into N
	//N = 1024; // it is required that q devides 2N to embed q/2 into N
	
	N2 = N/2+1;
	
	digitN = (int)std::log2((double)N);
	
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
	nbit = 54;
	//nbit = 27;
	
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
	//BARRETT_M 		= (1ULL << (BARRETT_K2)) / Q;
	BARRETT_M 		= 0x0040000000012FFF ;
  	LOG2_RLWE_LEN	= (uint32_t)std::log2((double)N);
 	EMBED_FACTOR 	= N * 2 / q ;
 	TOP_FIFO_MODE	= RLWEMODE;
	
////////////////////////////////////////////////////
//
// End set global variables 
//
///////////////////////////////////////////////////


	cout << "Set up the parameters" << endl;
	cout << "q = \t" << q << endl;
	cout << "Q = \t" << Q << endl; 
	cout << "N = \t" << N << endl; 
	cout << "iN = \t" << iN << endl;
	cout << "ROU = \t" << ROU << endl;
	
	//build the ROU table 	
	root_of_unity_table(ROU, Q, N, ROU_table, iROU_table);
	
	//build the rotation vectors
	rotate_poly_forward = rotate_vector_gen(true);
	rotate_poly_backward = rotate_vector_gen(false);
	
	cout << "Set up LWE context" << endl;
	// create LWE context 
	RNG_uniform LWE_uni_dist(q);						// uniform dist for a
	RNG_uniform LWE_uni_dist_key(3);					// uniform dist for sk, use a short sk
	RNG_norm LWE_norm_dist(LWE_mean, LWE_stddev);		// normal dist for noise e
	LWE::LWE_secretkey LWE_sk(LWE_uni_dist_key);		// secret key LWE_sk

	cout << "Set up RLWE context" << endl;
	// creat RLWE context
	RNG_uniform RLWE_uni_dist(Q);							// uniform dist for a 
	RNG_uniform RLWE_uni_dist_key(3);						// uniform dist for sk, use a short sk
	RNG_norm RLWE_norm_dist(RLWE_mean, RLWE_stddev);		// normal dist for noise e
	RLWE::RLWE_secretkey RLWE_sk(RLWE_uni_dist_key);		// secret key RLWE_sk



////////////////////////////////////////////////
//
// FPGA config, default slot id = 0 
//
//////////////////////////////////////////////

    /* setup logging to print to stdout */
    rc = log_init("test_bootstrap_w_fpga");
	if(rc != 0){
		std::cout << "Unable to initialize the log." << std::endl;
		if(ROU_table != NULL)
			free(ROU_table);
		if(iROU_table != NULL)
			free(iROU_table);
    	return -1;

	}
    rc = log_attach(logger, NULL, 0);
	if(rc != 0){
		std::cout << "Unable to attach to the log." << std::endl;
		if(ROU_table != NULL)
			free(ROU_table);
		if(iROU_table != NULL)
			free(iROU_table);
    	return -1;

	}

    /* initialize the fpga_mgmt library */
    rc = fpga_mgmt_init();
	if(rc != 0){
		std::cout << "Unable to initialize the fpga_mgmt library." << std::endl;
		if(ROU_table != NULL)
			free(ROU_table);
		if(iROU_table != NULL)
			free(iROU_table);
    	return -1;
	}

    /* check that the AFI is loaded */
    log_info("Checking to see if the right AFI is loaded...");
    rc = check_slot_config(slot_id);
	if(rc != 0){
		std::cout << "slot config is not correct." << std::endl;
		if(ROU_table != NULL)
			free(ROU_table);
		if(iROU_table != NULL)
			free(iROU_table);
    	return -1;
	}
////////////////////////////////////////////////////////
//
// FPGA config finish, no need to change above 
//
//////////////////////////////////////////////////////


	cout << "-------------------test::rlwe_expand----------------" << endl;
    printf("\n===== OCL config write/read =====\n");
	rc = FPGA::OCL_config_wr_rd(slot_id);
	if(rc != 0){
		std::cout << "OCL config write/read failed" << std::endl;
		if(ROU_table != NULL)
			free(ROU_table);
		if(iROU_table != NULL)
			free(iROU_table);
    	return -1;
	}
	
    printf("\n===== BAR1 ROU/iROU write 1k =====\n");
	rc = FPGA::BAR1_ROU_table_2k_wr(slot_id);
	if(rc != 0){
		std::cout << "BAR1 ROU/iROU write 1k failed" << std::endl;
		if(ROU_table != NULL)
			free(ROU_table);
		if(iROU_table != NULL)
			free(iROU_table);
    	return -1;
	}
	

	rc = FPGA::rlwesubs_dual_test(slot_id);

	if(rc != 0){
		std::cout << "Stand alone rlwesubs dual test failed" << std::endl;
		if(ROU_table != NULL)
			free(ROU_table);
		if(iROU_table != NULL)
			free(iROU_table);
    	return -1;
	}


	if(ROU_table != NULL)
		free(ROU_table);
	if(iROU_table != NULL)
		free(iROU_table);
	if(rc != 0)
    	return -1;
	else 
		return 0;
}

