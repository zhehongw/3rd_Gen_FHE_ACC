#ifndef NBT_H
#define NBT_H
//#include "params.h"
#include <random>
#include <cmath>
#include <iostream>
#include <set>
#include <vector>
#include <array>
#include <limits>
#include <iomanip>

//define plaintext message type
//in hardware implementation, if the bitwidth of the plaintext 
//is exactly the same as the one defined by the plaintext modulus, 
//then it doesn't matter whether it's defined as unsigned or signed. 
//for example, if the plaintext modulus is 4, and the plaintext bitwidth is 
//exactly defined as 2 bit,  then it does not matter whether 11 is taken as 3 
//or -1, because when adding 1, 0 is get in both cases.
//Similarly, can be applied to ciphtertext
//And by some trick, this also apply to software implementation
//define every number in as unsigned, only convert to signed when necessary
typedef uint64_t message_t;

//define ciphettext number type
typedef uint64_t ciphertext_t;

typedef int64_t signed_ciphertext_t;

//define the 128 bit number type
typedef unsigned __int128 long_ciphertext_t;
typedef __int128 signed_long_ciphertext_t;


//uint64_t barrett_mod(const big_int &in, const uint64_t &modulo, const big_int &mu);

inline ciphertext_t mod_pow2(const ciphertext_t &a, const int &modulo){
//helper function to calculate the mod 2^n, this is faster than the general mod
//a: the number to be mod, note that the number must be type casted to unsigned first if it is signed
//modulo: a power of two modulo
//return: the unsigned result that encode the negative number within the range [q/2, q-1]
//to convert it into signed: (resuethod) The pencil-and-paper method for multiplying x = 9274 and y = 847 would appear aslt >= modulo/2) ? (signed int)result - modulo : (signed int)result
	//to be explicit, for q = 512, the mapping I used here is 
	//mapping 256 to -256, not zero. So the negative number inlcudes
	//-256 ~ -1
	return (a % (ciphertext_t)modulo);
}

inline ciphertext_t mod_pow2(const signed_ciphertext_t &a, const int &modulo){
//helper function to calculate the mod 2^n, this is faster than the general mod
//a: the number to be mod, note that the number must be type casted to unsigned first if it is signed
//modulo: a power of two modulo
//return: the unsigned result that encode the negative number within the range [q/2, q-1]
//to convert it into signed: (result >= modulo/2) ? (signed int)result - modulo : (signed int)result

	return ((ciphertext_t)a % (ciphertext_t)modulo);
}

inline ciphertext_t mod_general(const signed_long_ciphertext_t &a, const ciphertext_t &modulo){
//helper function to calculate the mod arbitrary number, a odd prime to be specific. 
//if the modulo is power of two, the above one should be used for speed
//a: the number to be mod, note that the number needs to be convert to signed first if it is unsigned,
//with the following statement (input > modulo/2) ? (signed int)input - modulo : (signed int)input;
//note the difference between here ">" and the ">=" above
//the reason that necessates this function is that the mod operation is defined differently in math and in 
//the computer. In math, -1 mod Q is defined to be Q-1, while in the computer -1 mod Q is defined as -1
//modulo: a odd prime modulo
//return: the unsigned result that encode the negative number within the range (q/2, q-1]

	ciphertext_t result = (ciphertext_t)(((a % (signed_long_ciphertext_t)modulo) + (signed_long_ciphertext_t)modulo) % (signed_long_ciphertext_t)modulo);
	return(result);
}

inline ciphertext_t mod_general(const long_ciphertext_t &a, const ciphertext_t &modulo){
// if the input is known to be a positive number, like already from moduloused number, 
// then this can be used to save some operations

	ciphertext_t result = (ciphertext_t)(a % (long_ciphertext_t)modulo);
	return(result);
}

inline ciphertext_t mod_general(const signed_ciphertext_t &a, const ciphertext_t &modulo){
//helper function to calculate the mod arbitrary number, a odd prime to be specific. 
//if the modulo is power of two, the above one should be used for speed
//a: the number to be mod, note that the number needs to be convert to signed first (I have second thought about this) if it is unsigned,
//with the following statement (input > modulo/2) ? (signed int)input - modulo : (signed int)input;
//note the difference between here ">" and the ">=" above
//modulo: a odd prime modulo
//return: the unsigned result that encode the negative number within the range (q/2, q-1]

	ciphertext_t result = ((a % (signed_ciphertext_t)modulo) + (signed_ciphertext_t)modulo) % (signed_ciphertext_t)modulo;
	return(result);
}

inline ciphertext_t mod_general(const ciphertext_t &a, const ciphertext_t &modulo){
// if the input is known to be a positive number, like already from moduloused number, 
// then this can be used to save some operations

	ciphertext_t result = a % modulo;
	return(result);
}


ciphertext_t reverse_bit(const ciphertext_t order, const ciphertext_t input);
//helper function to find the reversed bit number of the input
//order: defines how many bits the input is by log2(order), only support power of two
//input: number to be reversed 
//return: the reversed number of input

ciphertext_t power_mod(const ciphertext_t base, const uint32_t exp, const ciphertext_t modulo);
//helper function that calculates power of input mod modulo
//only support non-negative exponent
//the reason not to use std::pow directly is to do overflow check
//base: the base of the power
//exp: the exponent of the power
//modulo: the desired modulo
//return: the result

ciphertext_t GCD(const ciphertext_t a, const ciphertext_t b);
//helper funtion to find the greatest common divisor of a and b
//a: one integer 
//b: another integer
//return: the GCD of a and b

ciphertext_t inverse_mod(const ciphertext_t input, const ciphertext_t modulo);
//helper function to get the inverse of input mod modulo, only support prime modulo
//when modulo is prime, the inverse of input is simply input^(modulo - 2)
//since from the Fermat's little theorem, a^(p-1) = 1 mod p, p is a prime
//input: the number to be inversed 
//modulo: the modulo that defines the inverse, a prime
//return: the inverse of input mod modulo

ciphertext_t pollar_rho_factorization(const ciphertext_t input);
//helper function to find a factor of input 
//input: a integer to be factorized
//return: a factor of input, not necessarily prime

void prime_factoritzation(const ciphertext_t input, std::set<ciphertext_t> &prime_factors);
//helper function to find all prime factor of the input number
//input: a integer to be factorized
//prime_factors: a set that hold the factorization result

void find_totient_list(const ciphertext_t input, std::vector<ciphertext_t> &totient_list);
//helper funtion to find the totient list of the input
//input: the number to be investigated
//totient_list: the vector that hold the totient list

bool witness_funciton(const ciphertext_t a, const ciphertext_t r, const ciphertext_t d, const ciphertext_t input);
//witness function invoked in the primality test
//a: a random number from interval [2, input-2]
//r and d: from the equation input - 1 = (2^r) * d, where d is odd
//input: the number to be tested
//return: whether it is a composite

bool MR_primality(const ciphertext_t input, const int round);
//Miller-Rabin primality test
//input: the number to be tested
//round: the number of rounds to be tested
//return: whether it is a prime

ciphertext_t first_prime(const int nbit, const int order);
//find the first prime Q that is less than 32-bit and satisfies Q = 1 mod 2*order 
//nbit: number of bits that the Q is required to be, no more than 32
//order: the cyclotomic polynomial order, which is the order of the (2*order)th cyclotomic polynomial 
//output: a prime that satisfies the above requirement

ciphertext_t previous_prime(const ciphertext_t prime, int order);
//not sure why this is required
//find the previous prime of the input prime that meets Q = 1 mod 2*order
//prime: a input prime 
//output: a prime is less than input prime

ciphertext_t find_generator(const ciphertext_t prime);
//to fina a generator of the multiplicative group Z/pZ*, where p is a prime
//prime: the input prime that defines the field
//return: a generator of the field

ciphertext_t root_of_unity(const int order, const ciphertext_t modulo);
//find the smallest primitive (2*order)th root of unity mod modulo
//order: the cyclotomic polynomial order, which is the order of the (2*order)th cyclotomic polynomial
//modulo: a prime works as a the modulo of the polynomail ring 
//output: the smallest root of unity

//long_ciphertext_t find_mu(const uint64_t modulo);

void NTT(const ciphertext_t *a, const int length, const ciphertext_t modulo, const ciphertext_t *ROU_table_in, ciphertext_t *NTT_out);	
//number theory transform for power of 2 length sequence with FFT technique(Cooley-Tukey)
//a: the sequence to be transformed, in normal order
//length: the length of the transform, power of two
//modulo: the modulo of the NTT, prime
//ROU_table_in: the power of root of unity in bit reverse order 
//NTT_out: the sequence holds the transform result, in bit reverse order 

void iNTT(const ciphertext_t *NTT_in, const int length, const ciphertext_t modulo, const ciphertext_t *iROU_table_in, const ciphertext_t ilength, ciphertext_t *a);	
//inverse number theory transform for power of 2 length sequence with FFT technique
//NTT_in: the NTT sequence to be inversely transformed, in freq decimated order
//length: the lenth of the sequence, power of two
//modulo: the modulo of the NTT, prime
//iROU_table_in: the power of the inverse of the root of unity in bit reverse order
//ilength: the inverse of length mod modulo 
//a: the sequence holds the inverse transform result, in normal order

void NTT(ciphertext_t *a, const int length, const ciphertext_t modulo, const ciphertext_t *ROU_table_in);	
//number theory transform for power of 2 length sequence with FFT technique(Cooley-Tukey)
//in place version, overwrite the original input
//a: the sequence to be transformed, in normal order
//length: the length of the transform, power of two
//modulo: the modulo of the NTT, prime
//ROU_table_in: the power of root of unity in bit reverse order 

void iNTT(ciphertext_t *NTT_in, const int length, const ciphertext_t modulo, const ciphertext_t *iROU_table_in, const ciphertext_t ilength);	
//inverse number theory transform for power of 2 length sequence with FFT technique
//in place version, overwrite the original input
//NTT_in: the NTT sequence to be inversely transformed, in freq decimated order
//length: the lenth of the sequence, power of two
//modulo: the modulo of the NTT, prime
//iROU_table_in: the power of the inverse of the root of unity in bit reverse order
//ilength: the inverse of length mod modulo 


#endif
