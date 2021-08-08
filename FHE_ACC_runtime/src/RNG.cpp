#include "RNG.h"
//random number are all signed number, so after reference, need to apply a modulo operation
RNG_uniform::RNG_uniform(int range){
	// standard way to generate random number in C++11
	std::random_device device; // set up a random device that resort to hardware or os for random numbers, but relaying on this alone would be slow and insecure, since the random number pool will soon be depeleted if invoked many times 
	engine = std::default_random_engine(device()); // use the random devive as a seed to a PRNG engine, and use the engine as a generator for random numbers
	if (range % 2 == 1)
		uniform_generator = std::uniform_int_distribution<signed_ciphertext_t>(-range / 2, range / 2); // set what kind of distribution to be generated from
	else 
		uniform_generator = std::uniform_int_distribution<signed_ciphertext_t>(-range / 2, range / 2 - 1); // set what kind of distribution to be generated from

}


signed_ciphertext_t RNG_uniform::generate_uniform(){
	return uniform_generator(engine);
}

RNG_norm::RNG_norm(int mean_in, double stddev_in){ // the default value of the function only needs to be defined in the function declaration 
	std::random_device device;
	engine = std::default_random_engine(device());
	norm_generator = std::normal_distribution<double>(mean_in, stddev_in);
	mean = mean_in;
	stddev = stddev_in;
}

signed_ciphertext_t RNG_norm::generate_norm(ciphertext_t bound){
	signed_ciphertext_t temp;
	//do{
	//	//implicitly cast double to ciphertext_t
	//	temp = norm_generator(engine);
	//}while(std::abs(temp) >= bound);
	temp = (signed_ciphertext_t)norm_generator(engine);
	temp %= (signed_ciphertext_t)bound;
	return temp;
}
