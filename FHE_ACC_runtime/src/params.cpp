#include "params.h"

//const int digitN = (int)std::log2((double)N);

//const ciphertext_t Q = previous_prime(first_prime(nbit, N), N);

//const long_ciphertext_t mu_factor = find_mu(Q);

//const ciphertext_t iN = inverse_mod(N, Q);

//const ciphertext_t ROU = root_of_unity(N, Q);

//ciphertext_t ROU_table[N];	
//ciphertext_t iROU_table[N];	

//const ciphertext_t BGbits = (ciphertext_t)std::log2(BG);
//const ciphertext_t Bks_R_bits = (ciphertext_t)std::log2(Bks_R);

//const ciphertext_t digitG = (ciphertext_t)std::ceil(std::log2((double)Q) / std::log2((double)BG));
//const ciphertext_t digitG2 = 2 * digitG;

//const ciphertext_t digitR = (ciphertext_t)std::ceil(std::log2((double)q) / std::log2((double)Br));

//const ciphertext_t digitKS = (ciphertext_t)std::ceil(std::log2((double)Q) / std::log2((double)Bks));

//const ciphertext_t digitKS_R = (ciphertext_t)std::ceil(std::log2((double)Q) / std::log2((double)Bks_R));


//define all LWE parameters
//deine the dimensin of LWE ciphtertext
int n;

//define LWE plaintext modulus
uint16_t t;

//define the LWE ciphertext modulus
ciphertext_t q;

ciphertext_t q2;

//define the noise bound of LWE ciphertext
ciphertext_t E;

//define secret key sample range for LWE
ciphertext_t LWE_sk_range;

//define mean and stddev of normal distribution of the LWE
ciphertext_t LWE_mean;
double LWE_stddev;

//define all RLWE/RGSW parameters
//define the order of RLWE/RGSW cyclotomic polynomial, 
//order of the 2Nth cyclotomic polynomial is N, with N being a power of 2
int N;

int N2;

uint16_t digitN;

//define secret key sample range for RLWE
ciphertext_t RLWE_sk_range;

//define mean and stddev of normal distribution of the RLWE
ciphertext_t RLWE_mean;
double RLWE_stddev;

//define the noise bound of the RLWE, it seems E_rlwe = omega(\sqrt(log(n)))
//which in this case is around 3, so for now just put an arbitrary small number
//need verification
ciphertext_t E_rlwe;

//define the RLWE/RGSW plaintext modulus
//support STD128 bit security

//as will see, the coefficients of the plaintext polynomial 
//are in the set {0, 1, -1}, so two bit plaintext modulus
int t_rlwe;

//define number of bit of RLWE modulo Q
uint16_t nbit;

//define the RLWE/RGSW ciphertext modulus, a prime
ciphertext_t Q;

//define the barrett reduction mu factor
//extern const long_ciphertext_t mu_factor;

// the inverse of N mod Q, with N * iN = 1 mod Q 
ciphertext_t iN;	

//primitive 2Nth root of unity
ciphertext_t ROU;

//twiddle factor table for NTT, in bit reverse order, dynamically allocated 
ciphertext_t *ROU_table;	//need to find a way to make these constant
//twiddle factor table for iNTT, in bit reverse order
ciphertext_t *iROU_table;	//need to find a way to make these constant

//define the decompse base of the RGSW ciphertext
//const ciphertext_t BG = 1 << 11;
ciphertext_t BG;
ciphertext_t BGbits;			// number of bits of BG, used for division
ciphertext_t BG_mask;		// a mask with lower 9 bits all one 

//define the size of the RGSW scheme, it is defined as digitG = logBG(Q) 
ciphertext_t digitG;
ciphertext_t digitG2;

//define the refresh base for homomorphically evaluate the decryption 
//const ciphertext_t Br = 2;
ciphertext_t Br;
ciphertext_t digitR;

//define the key switch base for RLWE-to-LWE key switching, note that it's with respect to Q not q
ciphertext_t Bks;
//const ciphertext_t Bks = 2;
ciphertext_t digitKS;

//define the key switch base for RLWE-to-RLWE key switching, note that it's with respect to Q 
ciphertext_t Bks_R;			//for now set this the same as BG, and also other parameters related to it
ciphertext_t Bks_R_bits;	//number bits of Bks_R, used for division 
ciphertext_t digitKS_R;
ciphertext_t Bks_R_mask;

//define the mapping range constant of each type of gates
ciphertext_t gate_constant[6];

//define a forward ploynomial rotation polynomials in NTT form
//which are vectors of form V[j] = X^(2^j), where 2^j is the rotation factor
std::vector<std::vector<ciphertext_t>> rotate_poly_forward;

//define a backward ploynomial rotation polynomials in NTT form
//which are vectors of form V[j] = -X^(2^j) = (Q-1)X^(2^j), where 2^j is the rotation factor
std::vector<std::vector<ciphertext_t>> rotate_poly_backward;

///////////////////////////////////////////////////
//
// Parameters for FPGA
// 
///////////////////////////////////////////////////
uint32_t 	BARRETT_K;
uint64_t 	BARRETT_M;
uint32_t 	BARRETT_K2;
uint32_t  	LOG2_RLWE_LEN;
uint32_t 	EMBED_FACTOR;
uint32_t 	TOP_FIFO_MODE;


void root_of_unity_table(const ciphertext_t &ROU, const ciphertext_t &modulo, const int order, ciphertext_t *ROU_table, ciphertext_t *iROU_table){
//generate the calculated table of power of the ROU and iROU, in bit reverse order
//ROU: the input root of unity
//modulo: the target modulo, prime
//order: the order of the polynomial, i.e. the size of the table
//ROU_table: a preset array to hold the ROU table
//iROU_table: a preset array to hold the iROU table
//get inverse of ROU mod modulo
	
	ciphertext_t iROU = inverse_mod(ROU, modulo);
	ciphertext_t prod = mod_general((long_ciphertext_t)ROU * (long_ciphertext_t)iROU, modulo);
	if(prod != 1){
		std::cout << "ROU*iROU != 1, = " << prod << std::endl;
		exit(1);
	}	
	
	ROU_table[0] = 1;
	iROU_table[0] = 1;
	ciphertext_t tmp = 1;
	ciphertext_t itmp = 1;
	for(uint32_t i = 1; i < (uint32_t)order; i++){
		tmp = mod_general((long_ciphertext_t)tmp * (long_ciphertext_t)ROU, modulo);
		itmp = mod_general((long_ciphertext_t)itmp * (long_ciphertext_t)iROU, modulo);
		ROU_table[reverse_bit(order, i)] = tmp;
		iROU_table[reverse_bit(order, i)] = itmp;
	}
}

std::vector<std::vector<ciphertext_t>> rotate_vector_gen(const bool forward){
// this is a helper function that generates the vector of rotation polynomials in NTT form
// it uses malloc, so remember to free the allocated memory when main finishes
// forward: whether it generates forward rotate poly or backward rotate poly
// return: a vector of rotate poly
	std::vector<std::vector<ciphertext_t>> v(num_rotate_poly);
	int pow_2 = 1;
	if(forward){
		for(uint16_t i = 0; i < num_rotate_poly; i++){
			std::vector<ciphertext_t> poly(N);
			for(int j = 0; j < N; j++){
				poly[j] = 0;
			}
			poly[pow_2] = 1;

			NTT(poly.data(), N, Q, ROU_table);
			v[i] = std::move(poly);
			pow_2 *= 2;
		}
	}else{
		for(uint16_t i = 0; i < num_rotate_poly; i++){
			std::vector<ciphertext_t> poly(N);
			for(int j = 0; j < N; j++){
				poly[j] = 0;
			}
			poly[N-pow_2] = Q-1;
			NTT(poly.data(), N, Q, ROU_table);

			v[i] = std::move(poly);
			pow_2 *= 2;
		}
	}
	return(v);
}



