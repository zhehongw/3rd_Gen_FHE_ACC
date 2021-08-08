# Amazon FPGA Hardware Development Kit
#
# Copyright 2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License"). You may not use
# this file except in compliance with the License. A copy of the License is
# located at
#
#    http://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file. This file is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
# implied. See the License for the specific language governing permissions and
# limitations under the License.

INCLUDES = -I $(SDK_DIR)/userspace/include

CC = gcc
CFLAGS = -DCONFIG_LOGLEVEL=4 -std=gnu11 -g -Wall -Werror $(INCLUDES)

LDLIBS = -lfpga_mgmt -lm

#SRC = test_dram_dma_common.c test_dram_dma_retention.c test_dram_dma.c test_dram_dma_hwsw_cosim.c
SRC = fhe_acc.c test_fhe_acc_bootstrap_init.c test_fhe_acc_rlwesubs.c test_fhe_acc_ocl_read.c test_fhe_acc_combined.c test_fhe_acc_rlwe_mult_rgsw.c test_fhe_acc_bootstrap.c

OBJ = $(SRC:.c=.o)


#all: test_dram_dma check_env retention cosim $(BIN)
all: test_fhe_acc_bootstrap_init test_fhe_acc_rlwesubs test_fhe_acc_ocl_read test_fhe_acc_combined test_fhe_acc_bootstrap test_fhe_acc_rlwe_mult_rgsw $(BIN)

#test_dram_dma: $(OBJ)
#	$(CC) $(CFLAGS) -o test_dram_dma test_dram_dma.o test_dram_dma_common.o  $(LDFLAGS) $(LDLIBS)

test_fhe_acc_bootstrap_init: $(OBJ)
	#$(CC) $(CFLAGS) -o test_fhe_acc $(OBJ) $(LDFLAGS) $(LDLIBS)
	$(CC) $(CFLAGS) -o test_fhe_acc_bootstrap_init fhe_acc.o test_fhe_acc_bootstrap_init.o $(LDFLAGS) $(LDLIBS)

test_fhe_acc_bootstrap: $(OBJ)
	#$(CC) $(CFLAGS) -o test_fhe_acc $(OBJ) $(LDFLAGS) $(LDLIBS)
	$(CC) $(CFLAGS) -o test_fhe_acc_bootstrap fhe_acc.o test_fhe_acc_bootstrap.o $(LDFLAGS) $(LDLIBS)

test_fhe_acc_rlwesubs: $(OBJ)
	#$(CC) $(CFLAGS) -o test_fhe_acc $(OBJ) $(LDFLAGS) $(LDLIBS)
	$(CC) $(CFLAGS) -o test_fhe_acc_rlwesubs fhe_acc.o test_fhe_acc_rlwesubs.o $(LDFLAGS) $(LDLIBS)

test_fhe_acc_rlwe_mult_rgsw: $(OBJ)
	#$(CC) $(CFLAGS) -o test_fhe_acc $(OBJ) $(LDFLAGS) $(LDLIBS)
	$(CC) $(CFLAGS) -o test_fhe_acc_rlwe_mult_rgsw fhe_acc.o test_fhe_acc_rlwe_mult_rgsw.o $(LDFLAGS) $(LDLIBS)

test_fhe_acc_ocl_read: $(OBJ)
	#$(CC) $(CFLAGS) -o test_fhe_acc $(OBJ) $(LDFLAGS) $(LDLIBS)
	$(CC) $(CFLAGS) -o test_fhe_acc_ocl_read fhe_acc.o test_fhe_acc_ocl_read.o $(LDFLAGS) $(LDLIBS)

test_fhe_acc_combined: $(OBJ)
	#$(CC) $(CFLAGS) -o test_fhe_acc $(OBJ) $(LDFLAGS) $(LDLIBS)
	$(CC) $(CFLAGS) -o test_fhe_acc_combined fhe_acc.o test_fhe_acc_combined.o $(LDFLAGS) $(LDLIBS)


clean:
	#rm -f *.o test_dram_dma_retention test_dram_dma test_dram_dma_hwsw_cosim
	rm -f *.o test_fhe_acc_bootstrap_init test_fhe_acc_rlwesubs test_fhe_acc_ocl_read test_fhe_acc_combined
	rm -f test_fhe_acc_bootstrap_init 
	rm -f test_fhe_acc_bootstrap 
	rm -f test_fhe_acc_rlwesubs 
	rm -f test_fhe_acc_rlwe_mult_rgsw
	rm -f test_fhe_acc_ocl_read 
	rm -f test_fhe_acc_combined

check_env:
ifndef SDK_DIR
    $(error SDK_DIR is undefined. Try "source sdk_setup.sh" to set the software environment)
endif
