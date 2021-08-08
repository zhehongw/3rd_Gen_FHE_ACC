// Amazon FPGA Hardware Development Kit
//
// Copyright 2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Amazon Software License (the "License"). You may not use
// this file except in compliance with the License. A copy of the License is
// located at
//
//    http://aws.amazon.com/asl/
//
// or in the "license" file accompanying this file. This file is distributed on
// an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
// implied. See the License for the specific language governing permissions and
// limitations under the License.
#include "fhe_acc.h"

////////////////////////////////////////
// Do not modify from here 
///////////////////////////////////////
/* use the stdout logger for printing debug information  */
#ifndef SV_TEST
const struct logger *logger = &logger_stdout;
/*
 * pci_vendor_id and pci_device_id values below are Amazon's and avaliable to use for a given FPGA slot. 
 * Users may replace these with their own if allocated to them by PCI SIG
 */
//static uint16_t pci_vendor_id = 0x1D0F; /* Amazon PCI Vendor ID */
//static uint16_t pci_device_id = 0xF000; /* PCI Device ID preassigned by Amazon for F1 applications */
#endif


#ifdef SV_TEST
//For cadence and questa simulators the main has to return some value
# ifdef INT_MAIN
int test_main(uint32_t *exit_code)
# else 
void test_main(uint32_t *exit_code)
# endif 
#else 
int main(int argc, char **argv)
#endif
{
    //The statements within SCOPE ifdef below are needed for HW/SW co-simulation with VCS
    #ifdef SCOPE
      svScope scope;
      scope = svGetScopeFromName("tb");
      svSetScope(scope);
    #endif
	
	uint32_t value = 0xefbeadde;
    int slot_id = 0;
    int rc;
    
#ifndef SV_TEST
    // Process command line args
    {
        int i;
        int value_set = 0;
        for (i = 1; i < argc; i++) {
            if (!strcmp(argv[i], "--slot")) {
                i++;
                if (i >= argc) {
                    printf("error: missing slot-id\n");
                    //usage(argv[0]);
    				printf("usage: %s [--slot <slot-id>][<poke-value>]\n", argv[0]);
                    return 1;
                }
                sscanf(argv[i], "%d", &slot_id);
            } else if (!value_set) {
                sscanf(argv[i], "%x", &value);
                value_set = 1;
            } else {
                printf("error: Invalid arg: %s", argv[i]);
                //usage(argv[0]);
    			printf("usage: %s [--slot <slot-id>][<poke-value>]\n", argv[0]);
                return 1;
            }
        }
    }
#endif


#ifndef SV_TEST
	printf("not define SV_TEST, slot_id=%d\n", slot_id);
    /* setup logging to print to stdout */
    rc = log_init("test_fhe_acc_main");
    fail_on(rc, out, "Unable to initialize the log.");
    rc = log_attach(logger, NULL, 0);
    fail_on(rc, out, "%s", "Unable to attach to the log.");

    /* initialize the fpga_mgmt library */
    rc = fpga_mgmt_init();
    fail_on(rc, out, "Unable to initialize the fpga_mgmt library");
    /* check that the AFI is loaded */
    //log_info("Checking to see if the right AFI is loaded...");
    //rc = check_afi_ready(slot_id);
    //fail_on(rc, out, "AFI not ready");
    rc = check_slot_config(slot_id);
    fail_on(rc, out, "slot config is not correct");
#endif

////////////////////////////////////////
// Do not modify until here 
///////////////////////////////////////

//////////////////////////////////////
//global constants of config regs
//////////////////////////////////////
	BG 				= 512; 
	RLWE_Q 			= 0x003FFFFFFFFED001;
	BARRETT_K 		= BIT_WIDTH;
	BARRETT_M 		= 0x0040000000012FFF;
	RLWE_ILENGTH 	= 0x003FF7FFFFFED027;
	BG_MASK 		= BG - 1;
	RLWE_LENGTH 	= 2048;
	BARRETT_K2 		= BARRETT_K * 2;
	
	LOG2_RLWE_LEN 	= (uint32_t)log2(RLWE_LENGTH);
	
	DIGITG 			= 6;
	DIGITG2 		= DIGITG * 2;
	
	BG_WIDTH 		= (uint32_t)log2(BG);
	
	LWE_Q 			= 512;
	EMBED_FACTOR 	= RLWE_LENGTH * 2 / LWE_Q;
	TOP_FIFO_MODE 	= RLWEMODE;

//currently other Bases are not included here, like Bks, etc.
	gate_constant[0] = (uint32_t)(5 * (LWE_Q >> 3)); //OR
	gate_constant[1] = (uint32_t)(7 * (LWE_Q >> 3)); //AND
	gate_constant[2] = (uint32_t)(1 * (LWE_Q >> 3)); //NOR
	gate_constant[3] = (uint32_t)(3 * (LWE_Q >> 3)); //NAND
	gate_constant[4] = (uint32_t)(5 * (LWE_Q >> 3)); //XOR
	gate_constant[5] = (uint32_t)(1 * (LWE_Q >> 3)); //XNOR


//////////////////////////////////////
//global constants of config regs
//////////////////////////////////////

///////////////////////////////////////////////
// The test functions start here
//////////////////////////////////////////////


	//switch to 1k length set up
	BG 				= 512; 
	RLWE_Q 			= 0x0000000007FFF801;
	BARRETT_K 		= BIT_WIDTH / 2;
	BARRETT_M 		= (1ULL << (BARRETT_K * 2)) / RLWE_Q;
	RLWE_ILENGTH 	= 0x0000000007FDF803;
	BG_MASK 		= BG - 1;
	RLWE_LENGTH 	= 1024;
	BARRETT_K2 		= BARRETT_K * 2;
	
	LOG2_RLWE_LEN 	= (uint32_t)log2(RLWE_LENGTH);
	
	DIGITG 			= 3;
	DIGITG2 		= DIGITG * 2;
	
	BG_WIDTH 		= (uint32_t)log2(BG);
	
	LWE_Q 			= 512;
	EMBED_FACTOR 	= RLWE_LENGTH * 2 / LWE_Q;
	TOP_FIFO_MODE 	= BTMODE;

    printf("\n===== OCL config write/read =====\n");
	rc = OCL_config_wr_rd(slot_id);
    fail_on(rc, out, "OCL config write/read failed");
	
    printf("\n===== BAR1 ROU/iROU write 1k =====\n");
	rc = BAR1_ROU_table_1k_wr(slot_id);
    fail_on(rc, out, "BAR1 ROU/iROU write 1k failed");
	
	printf("\n===== BOOTSTRAP test =====\n");
	rc = bootstrap_test(slot_id);
	fail_on(rc, out, "BOOTSTRAP test failed");


    //printf("\n===== DMA DDR/input fifo write/read =====\n");
	//rc = dma_test(slot_id);
    //fail_on(rc, out, "DMA DDR/input fifo write/read failed");
///////////////////////////////////////////////
// The test functions end here
//////////////////////////////////////////////



#ifndef SV_TEST
    return rc;
    
out:
    return 1;
#else
    if (rc != 0) {
        printf("TEST FAILED \n");
    }
    else {
        printf("TEST PASSED \n");
    }
out:
   #ifdef INT_MAIN
   *exit_code = 0;
   return 0;
   #else 
   *exit_code = 0;
   #endif
#endif
}

/* As HW simulation test is not run on a AFI, the below function is not valid */

//#ifdef SV_TEST
///*This function is used transfer string buffer from SV to C.
//  This function currently returns 0 but can be used to update a buffer on the 'C' side.*/
//int send_rdbuf_to_c(char* rd_buf)
//{
//   return 0;
//}
//
//#endif
