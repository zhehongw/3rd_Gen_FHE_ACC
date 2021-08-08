#ifndef RNG_H
#define RNG_H
#include <random>
#include "params.h"
#include <cstdlib>
//random number are all signed number, so after reference, need to apply a modulo operation
class RNG_uniform{
//uniform number generator class
	public:
	RNG_uniform(int range);//constructor needs to be public to be initialized 
	// construct a uniform RNG generator
	// range: the number range of the distribution 
	signed_ciphertext_t generate_uniform();
	// generate a uniformly distributed random number 
	private:
	std::uniform_int_distribution<signed_ciphertext_t> uniform_generator;
	std::default_random_engine engine;
};

class RNG_norm{
//discrete gaussian generator
	public:
	RNG_norm(int mean_in = 0, double stddev_in = 1);
	// construct a nomal RNG generator
	// mean: mean of the distribution
	// stddev: standard diviation of the distribution  
	signed_ciphertext_t generate_norm(ciphertext_t bound);
	// generate a normally distributed random number within the bound
	// bound: the maximum number returned by the generator
	private:
	std::normal_distribution<double> norm_generator;
	std::default_random_engine engine;
	int mean;
	double stddev;
};

#endif

