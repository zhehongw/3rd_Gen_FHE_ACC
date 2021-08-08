#include "nbt.h"

//uint64_t barrett_mod(const big_int &in, const uint64_t &modulo, const big_int &mu){
//	
//}

ciphertext_t reverse_bit(const ciphertext_t order, const ciphertext_t input){
//helper function to find the reversed bit number of the input
//order: defines how many bits the input is by log2(order), only support power of two
//input: number to be reversed 
//return: the reversed number of input
	int num_bit = std::log2(order);
	ciphertext_t m = input;
	ciphertext_t reverse = input & 1;

	m >>= 1;
	num_bit--;
	while(m){
		reverse <<= 1;
		reverse |= (m & 1);
		m >>= 1;
		num_bit--;
	}
	reverse <<= num_bit;
	return(reverse);
}

ciphertext_t power_mod(const ciphertext_t base, const ciphertext_t exp, const ciphertext_t modulo){
//helper function that calculates power of input mod modulo
//the reason not to use std::pow directly is to do overflow check
//base: the base of the power
//exp: the exponent of the power
//modulo: the desired modulo
//return: the result
	ciphertext_t b = base % modulo; // mod to reduce the size of b
	long_ciphertext_t result = 1;
	ciphertext_t power = exp;
	while(power > 0){
		if((power & 1) == 1){
			result *= (long_ciphertext_t)b;
			result %= (long_ciphertext_t)modulo;
		}
		b = ((long_ciphertext_t)b * (long_ciphertext_t)b) % (long_ciphertext_t)modulo;
		power = power >> 1;
	}
	return((ciphertext_t)result);
}

ciphertext_t GCD(const ciphertext_t a, const ciphertext_t b){
//helper funtion to find the greatest common divisor of a and b
//a: one integer 
//b: another integer
//return: the GCD of a and b
	//GCD is not defined when input are both zero
	//so input cannot be both zero
	//if one is zero, the GCD is simply the other input
	if(a == 0)
		return(b);
	if(b == 0)
		return(a);

	ciphertext_t m_a = a;
	ciphertext_t m_b = b;
	ciphertext_t m_t = 0;
	while(m_b != 0){
		m_t = m_b;
		m_b = m_a % m_b;
		m_a = m_t;
	}
	return(m_a);
}

ciphertext_t inverse_mod(const ciphertext_t input, const ciphertext_t modulo){
//helper function to get the inverse of input mod modulo, only support prime modulo
//when modulo is prime, the inverse of input is simply input^(modulo - 2)
//since from the Fermat's little theorem, a^(p-1) = 1 mod p, p is a prime
//input: the number to be inversed 
//modulo: the modulo that defines the inverse, a prime
//return: the inverse of input mod modulo

	return(power_mod(input, modulo - 2, modulo));
	
	//long_ciphertext_t inverse = 1;
	//ciphertext_t modm2 = modulo - 2;
	//for(ciphertext_t i = 0; i < modm2; i++){
	//	inverse *= (long_ciphertext_t)input;
	//	inverse %= (long_ciphertext_t)modulo;
	//}
	//return((ciphertext_t)inverse);
}

ciphertext_t pollar_rho_factorization(const ciphertext_t input){
//helper function to find a factor of input 
//input: a integer to be factorized
//return: a factor of input, not necessarily prime
	std::random_device device;
	std::default_random_engine engine = std::default_random_engine(device());
	std::uniform_int_distribution<uint64_t> uniform_generator = std::uniform_int_distribution<uint64_t>(0, input);

	ciphertext_t factor = 1;
	long_ciphertext_t c = uniform_generator(engine);
	long_ciphertext_t x = uniform_generator(engine);
	long_ciphertext_t xx = x;

	if(input % 2 == 0)
		return ((ciphertext_t)2);
	do{
		x = (x * x + c) % (long_ciphertext_t)input;
		xx = (xx * xx + c) % (long_ciphertext_t)input;
		xx = (xx * xx + c) % (long_ciphertext_t)input;
		
		factor = GCD((ciphertext_t)((x >= xx) ? x - xx : xx - x), input);

	}while(factor == 1);

	return(factor);
}

void prime_factoritzation(const ciphertext_t input, std::set<ciphertext_t> &prime_factors){
//helper function to find all prime factor of the input number
//input: a integer to be factorized
//prime_factors: a set that hold the factorization result
	ciphertext_t n = input;
	if(n == 0 || n == 1)
		return;
	if(MR_primality(n, 40)){
		prime_factors.insert(n);
		return;
	}
	ciphertext_t factor = pollar_rho_factorization(n);

	prime_factoritzation(factor, prime_factors);

	n /= factor;

	prime_factoritzation(n, prime_factors);
}

void find_totient_list(const ciphertext_t input, std::vector<ciphertext_t> &totient_list){
//helper funtion to find the totient list of the input
//input: the number to be investigated
//totient_list: the vector that hold the totient list
	ciphertext_t n = input;
	ciphertext_t factor = 0;
	for(ciphertext_t i = 0; i < n; i++){
		factor = GCD(i, n);
		if(factor == 1)
			totient_list.push_back(i);
	}
}

bool witness_funciton(const ciphertext_t a, const ciphertext_t r, const ciphertext_t d, const ciphertext_t input){
//witness function invoked in the primality test
//a: a random number from interval [2, input-2]
//r and d: from the equation input - 1 = (2^r) * d, where d is odd
//input: the number to be tested
//return: whether it is a composite
	
	//std::cout << "witnessing " << input << std::endl;
	//std::cout << "a = " << a << " r = " << r << " d = " << d << std::endl;
	long_ciphertext_t tmp = (long_ciphertext_t)power_mod(a, d, input);
	//std::cout << "a^d = " << (ciphertext_t)tmp << std::endl;
	if (tmp == 1 || tmp == input - 1)
		return false;
	for(uint32_t i = 1; i < r; i++){
		tmp = (tmp * tmp) % (long_ciphertext_t)input;
		if(tmp == input - 1)
	   		return false;	   
	}
	return true;
}

bool MR_primality(const ciphertext_t input, const int round){
//Miller-Rabin primality test
//input: the number to be tested
//round: the number of rounds to be tested
//return: whether it is a prime

	//std::cout << "testing " << input << std::endl;
	//primary test
	if(input < 2 || (input !=2 && input % 2 == 0))
		return(false);
	if(input == 2 || input  == 3 || input == 5)
		return(true);
	
	//MR test
	std::random_device device;
	std::default_random_engine engine = std::default_random_engine(device());
	std::uniform_int_distribution<ciphertext_t> uniform_generator = std::uniform_int_distribution<ciphertext_t>(2, input - 2);
	//get d and s
	ciphertext_t d = input - 1;
	ciphertext_t s = 0;
	while(d % 2 == 0){
		d = d / 2;
		s++;
	}
	// witness loop
	ciphertext_t a = 0;
	bool composite = true;
	for(int i = 0; i < round; i++){
		a = uniform_generator(engine);
		composite = witness_funciton(a, s, d, input);
		if (composite)
			break;
	}
	return(!composite);
}

ciphertext_t first_prime(const int nbit, const int order){
//find the first prime Q that is less than 32-bit and satisfies Q = 1 mod 2*order 
//nbit: number of bits that the Q is required to be, no more than 32
//order: the cyclotomic polynomial order, which is the order of the (2*order)th cyclotomic polynomial 
//output: a prime that satisfies the above requirement
	//std::cout << "nbit = " << nbit << std::endl;
	ciphertext_t m = 2 * order;
	ciphertext_t r = (1ULL << (ciphertext_t)nbit) % m;
	ciphertext_t cand = 1ULL << (ciphertext_t)nbit;
	
	//std::cout << "Looking for Q" << std::endl;
	//overflow check
	if(cand == 0){
		std::cerr << "Target Q is too large. Overflow!!!" << std::endl;
		return (0);
	}
	
	ciphertext_t tmp = cand + m - r + 1; //make sure Q = 1 mod 2*order
	if(tmp < cand){
		std::cerr << "Target Q is too large. Overflow!!!" << std::endl;
		return (0);
	}
	cand = tmp;
	while(!MR_primality(cand, 20)){
		//std::cout << "candidate " << cand << " is not prime" << std::endl;
		tmp = cand + m;
		//std::cout << "tmp = " << tmp << std::endl;
		if(tmp < cand){
			std::cerr << "Target Q is too large. Overflow!!!" << std::endl;
			return (0);
		}
		cand = tmp;
		//std::cout << "cand = " << cand << std::endl;

	}
	return(cand);
}

ciphertext_t previous_prime(const ciphertext_t prime, const int order){
//not sure why this is required
//find the previous prime of the input prime that meets Q = 1 mod 2*order
//prime: a input prime 
//output: a prime is less than input prime
	int m = 2 * order;
	ciphertext_t cand= prime - m;
	ciphertext_t tmp;
	//std::cout << "Looking for prime previous Q" << std::endl;
	while(!MR_primality(cand, 20)){
		tmp = cand - m;
		if(tmp > cand){
			std::cerr << "Target Q is too small. Underflow!!!" << std::endl;
			return (0);
		}
		cand = tmp;
	}
	//std::cout << "found a prime" << std::endl;
	return cand;
}

ciphertext_t find_generator(const ciphertext_t prime){
//to fina a generator of the multiplicative group Z/pZ*, where p is a prime
//prime: the input prime that defines the field
//return: a generator of the field
	std::set<ciphertext_t> prime_factors;
	ciphertext_t pm1 = prime - 1;

	std::random_device device;
	std::default_random_engine engine = std::default_random_engine(device());
	std::uniform_int_distribution<ciphertext_t> uniform_generator = std::uniform_int_distribution<ciphertext_t>(2, pm1);
	
	prime_factoritzation(pm1, prime_factors);

	bool found = false;
	ciphertext_t generator;
	while(!found){
		ciphertext_t count = 0;

		generator = uniform_generator(engine);

		for(auto it = prime_factors.begin(); it != prime_factors.end(); it++){
			if(power_mod(generator, pm1/(*it), prime) == 1)
				break;
			else
				count++;
		}
		if(count == prime_factors.size())
			found = true;
	}
	return(generator);
}

ciphertext_t root_of_unity(const int order, const ciphertext_t modulo){
//find the smallest primitive (2*order)th root of unity mod modulo, where order is a power of 2
//order: the cyclotomic polynomial order, which is the order of the (2*order)th cyclotomic polynomial
//modulo: a prime works a the modulo of the polynomial ring 
//output: the smallest root of unity
	ciphertext_t m = 2 * order;
	ciphertext_t modm1 = modulo - 1;
	if((modm1 % m) != 0){
		std::cerr << "Q != 1 mod 2 * order. Change Q!!!" << std::endl;
		return (0);
	}
	//find a candidate of ROU
	ciphertext_t generator = find_generator(modulo);
	ciphertext_t ROU = power_mod(generator, modm1 / m, modulo);
	while(ROU == 1){
		//if ROU is a trivial solution, loop to get a new one
		ROU = root_of_unity(order, modulo);
	}

	//The ROU candidate is not necessarily the smallest
	//to gaurantee a deterministic output with the same order and modulo
	//cycle through the list of the primitive root of unity to get 
	//the smallest one
	//
	//To do this, raise the ROU to all the powers that are co-prime to
	//the cyclotomic order (2*order).
	
	std::vector<ciphertext_t> totient_list;
	find_totient_list(m, totient_list);
	//std::cout << "totient list of 2N content:" << std::endl;
	//for(auto it = totient_list.begin(); it != totient_list.end(); it++){
	//	std::cout << *it << " ";
	//}
	//std::cout << std::endl;
	//std::cout << "totient list size = " << totient_list.size() << std::endl;
	ciphertext_t prepow = 0;
	ciphertext_t minROU = ROU;
	long_ciphertext_t tmp = 1;
	for(auto it = totient_list.begin(); it != totient_list.end(); it++){
		ciphertext_t powdiff = *it - prepow;
		tmp = (tmp * power_mod(ROU, powdiff, modulo)) % modulo;
		if(tmp < minROU && tmp != 1)
			minROU = tmp;
		prepow = *it;
	}
	return minROU;
}

//long_ciphertext_t find_mu(const uint64_t modulo){
//
//}


void NTT(const ciphertext_t *a, const int length, const ciphertext_t modulo, const ciphertext_t *ROU_table_in, ciphertext_t *NTT_out){
//number theory transform for power of 2 length sequence with FFT technique(Cooley-Tukey)
//a: the sequence to be transformed, in normal order
//length: the length of the transform, power of two
//modulo: the modulo of the NTT, prime
//ROU_table_in: the power of root of unity in bit reverse order 
//NTT_out: the sequence holds the transform result, in bit reverse order 
//"Speeding up the Number Theoretic Transform for Faster Ideal Lattice-Based Cryptography"
//Patrick Longa and Michael Naehrig, Microsoft Research, USA

	//not in place version, copy the input sequence first
	for(int i = 0; i < length; i++){
		NTT_out[i] = a[i];
	}
	//start NTT
	int t = length;
	for(int m = 1; m < length; m *= 2){
		t = t / 2;
		for(int i = 0; i < m; i++){
			int j1 = 2 * i * t;
			int j2 = j1 + t;
			ciphertext_t S = ROU_table_in[m + i];
			for(int j = j1; j < j2; j++){
				ciphertext_t U = NTT_out[j];
				ciphertext_t V = mod_general((long_ciphertext_t)NTT_out[j + t] * (long_ciphertext_t)S, modulo); // it has be done like this
				NTT_out[j] = mod_general((long_ciphertext_t)U + (long_ciphertext_t)V, modulo);
				NTT_out[j + t] = mod_general((signed_long_ciphertext_t)U - (signed_long_ciphertext_t)V, modulo);
			}
		}	
	}
}

void iNTT(const ciphertext_t *NTT_in, const int length, const ciphertext_t modulo, const ciphertext_t *iROU_table_in, const ciphertext_t ilength, ciphertext_t *a){
//inverse number theory transform for power of 2 length sequence with FFT technique
//NTT_in: the NTT sequence to be inversely transformed, in freq decimated order
//length: the lenth of the sequence, power of two
//modulo: the modulo of the NTT, prime
//iROU_table_in: the power of the inverse of the root of unity in bit reverse order
//ilength: the inverse of length mod modulo 
//a: the sequence holds the inverse transform result, in normal order
//"Speeding up the Number Theoretic Transform for Faster Ideal Lattice-Based Cryptography"
//Patrick Longa and Michael Naehrig, Microsoft Research, USA

	//not in place version, copy the sequence first;
	for(int i = 0; i < length; i++){
		a[i] = NTT_in[i];
	}
	//start NTT
	int  t = 1;
	for(int m = length / 2; m >= 1; m /= 2){
		int j1 = 0;
		for(int i = 0; i < m; i++){
			int j2 = j1 + t;
			ciphertext_t S = iROU_table_in[m + i];
			for(int j = j1; j < j2; j++){
				ciphertext_t U = a[j];
				ciphertext_t V = a[j + t];
				a[j] = mod_general((long_ciphertext_t)U + (long_ciphertext_t)V, modulo);
				a[j + t] = mod_general(((signed_long_ciphertext_t)U - (signed_long_ciphertext_t)V) * (signed_long_ciphertext_t)S, modulo);
			}
			j1 += (2 * t);
		}
		t *= 2;
	}
	for(int i = 0; i < length; i++){
		a[i] = mod_general((long_ciphertext_t)a[i] * (long_ciphertext_t)ilength,  modulo);
	}
}


void NTT(ciphertext_t *a, const int length, const ciphertext_t modulo, const ciphertext_t *ROU_table_in){
//number theory transform for power of 2 length sequence with FFT technique(Cooley-Tukey)
//a: the sequence to be transformed, in normal order
//length: the length of the transform, power of two
//modulo: the modulo of the NTT, prime
//ROU_table_in: the power of root of unity in bit reverse order 
//NTT_out: the sequence holds the transform result, in bit reverse order 
//"Speeding up the Number Theoretic Transform for Faster Ideal Lattice-Based Cryptography"
//Patrick Longa and Michael Naehrig, Microsoft Research, USA

	//start NTT
	int t = length;
	for(int m = 1; m < length; m *= 2){
		t = t / 2;
		for(int i = 0; i < m; i++){
			int j1 = 2 * i * t;
			int j2 = j1 + t;
			ciphertext_t S = ROU_table_in[m + i];
			for(int j = j1; j < j2; j++){
				ciphertext_t U = a[j];
				ciphertext_t V = mod_general((long_ciphertext_t)a[j + t] * (long_ciphertext_t)S, modulo); // it has be done like this
				a[j] = mod_general((long_ciphertext_t)U + (long_ciphertext_t)V, modulo);
				a[j + t] = mod_general((signed_long_ciphertext_t)U - (signed_long_ciphertext_t)V, modulo);
			}
		}	
		//std::cout << "NTT loop " << m << std::endl;
		//for(int i = 0; i < length; i++){
		//	std::cout << std::hex << std::uppercase << std::setw(14) << std::setfill('0') << a[i] << std::endl;
		//}

	}
}

void iNTT(ciphertext_t *NTT_in, const int length, const ciphertext_t modulo, const ciphertext_t *iROU_table_in, const ciphertext_t ilength){
//inverse number theory transform for power of 2 length sequence with FFT technique
//NTT_in: the NTT sequence to be inversely transformed, in freq decimated order
//length: the lenth of the sequence, power of two
//modulo: the modulo of the NTT, prime
//iROU_table_in: the power of the inverse of the root of unity in bit reverse order
//ilength: the inverse of length mod modulo 
//a: the sequence holds the inverse transform result, in normal order
//"Speeding up the Number Theoretic Transform for Faster Ideal Lattice-Based Cryptography"
//Patrick Longa and Michael Naehrig, Microsoft Research, USA

	//start NTT
	int  t = 1;
	for(int m = length / 2; m >= 1; m /= 2){
		int j1 = 0;
		for(int i = 0; i < m; i++){
			int j2 = j1 + t;
			ciphertext_t S = iROU_table_in[m + i];
			for(int j = j1; j < j2; j++){
				ciphertext_t U = NTT_in[j];
				ciphertext_t V = NTT_in[j + t];
				NTT_in[j] = mod_general((long_ciphertext_t)U + (long_ciphertext_t)V, modulo);
				NTT_in[j + t] = mod_general(((signed_long_ciphertext_t)U - (signed_long_ciphertext_t)V) * (signed_long_ciphertext_t)S, modulo);
			}
			j1 += (2 * t);
		}
		t *= 2;
		//std::cout << "iNTT loop " << m << std::endl;
		//for(int i = 0; i < length; i++){
		//	std::cout << std::hex << std::uppercase << std::setw(14) << std::setfill('0') << NTT_in[i] << std::endl;
		//}
	}
	for(int i = 0; i < length; i++){
		NTT_in[i] = mod_general((long_ciphertext_t)NTT_in[i] * (long_ciphertext_t)ilength,  modulo);
	}
}

