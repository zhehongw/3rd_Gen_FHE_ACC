#include "fhe_acc.h"

static const uint16_t AMZ_PCI_VENDOR_ID = 0x1D0F; /* Amazon PCI Vendor ID */
static const uint16_t PCI_DEVICE_ID = 0xF001;

#ifdef SV_TEST
static uint8_t *send_rdbuf_to_c_read_buffer = NULL;
static size_t send_rdbuf_to_c_buffer_size = 0;

void setup_send_rdbuf_to_c(uint8_t *read_buffer, size_t buffer_size)
{
    send_rdbuf_to_c_read_buffer = read_buffer;
    send_rdbuf_to_c_buffer_size = buffer_size;
}

int send_rdbuf_to_c(char* rd_buf)
{
#ifndef VIVADO_SIM
    /* Vivado does not support svGetScopeFromName */
    svScope scope;
    scope = svGetScopeFromName("tb");
    svSetScope(scope);
#endif
    int i;

    /* For Questa simulator the first 8 bytes are not transmitted correctly, so
     * the buffer is transferred with 8 extra bytes and those bytes are removed
     * here. Made this default for all the simulators. */
    for (i = 0; i < send_rdbuf_to_c_buffer_size; ++i) {
        send_rdbuf_to_c_read_buffer[i] = rd_buf[i+8];
    }

    /* end of line character is not transferered correctly. So assign that
     * here. */
    /*send_rdbuf_to_c_read_buffer[send_rdbuf_to_c_buffer_size - 1] = '\0';*/

    return 0;
}
#endif


#ifndef SV_TEST

int check_afi_ready(int slot_id) {
   struct fpga_mgmt_image_info info = {0}; 
   int rc;

   /* get local image description, contains status, vendor id, and device id. */
   rc = fpga_mgmt_describe_local_image(slot_id, &info,0);
   fail_on(rc, out, "Unable to get AFI information from slot %d. Are you running as root?",slot_id);

   /* check to see if the slot is ready */
   if (info.status != FPGA_STATUS_LOADED) {
     rc = 1;
     fail_on(rc, out, "AFI in Slot %d is not in READY state !", slot_id);
   }

   printf("AFI PCI  Vendor ID: 0x%x, Device ID 0x%x\n",
          info.spec.map[FPGA_APP_PF].vendor_id,
          info.spec.map[FPGA_APP_PF].device_id);

   /* confirm that the AFI that we expect is in fact loaded */
   if (info.spec.map[FPGA_APP_PF].vendor_id != AMZ_PCI_VENDOR_ID ||
       info.spec.map[FPGA_APP_PF].device_id != PCI_DEVICE_ID) {
     printf("AFI does not show expected PCI vendor id and device ID. If the AFI "
            "was just loaded, it might need a rescan. Rescanning now.\n");

     rc = fpga_pci_rescan_slot_app_pfs(slot_id);
     fail_on(rc, out, "Unable to update PF for slot %d",slot_id);
     /* get local image description, contains status, vendor id, and device id. */
     rc = fpga_mgmt_describe_local_image(slot_id, &info, 0);
     fail_on(rc, out, "Unable to get AFI information from slot %d",slot_id);

     printf("AFI PCI  Vendor ID: 0x%x, Device ID 0x%x\n",
            info.spec.map[FPGA_APP_PF].vendor_id,
            info.spec.map[FPGA_APP_PF].device_id);

     /* confirm that the AFI that we expect is in fact loaded after rescan */
     if (info.spec.map[FPGA_APP_PF].vendor_id != AMZ_PCI_VENDOR_ID ||
         info.spec.map[FPGA_APP_PF].device_id != PCI_DEVICE_ID ) {
       rc = 1;
       fail_on(rc, out, "The PCI vendor id and device of the loaded AFI are not "
               "the expected values.");
     }
   }
    
   return rc;
 out:
   return 1;
}

int check_slot_config(int slot_id)
{
    int rc;
    struct fpga_mgmt_image_info info = {0};

    /* get local image description, contains status, vendor id, and device id */
    rc = fpga_mgmt_describe_local_image(slot_id, &info, 0);
    fail_on(rc, out, "Unable to get local image information. Are you running "
        "as root?");

    /* check to see if the slot is ready */
    if (info.status != FPGA_STATUS_LOADED) {
        rc = 1;
        fail_on(rc, out, "Slot %d is not ready", slot_id);
    }

    /* confirm that the AFI that we expect is in fact loaded */
    if (info.spec.map[FPGA_APP_PF].vendor_id != AMZ_PCI_VENDOR_ID ||
        info.spec.map[FPGA_APP_PF].device_id != PCI_DEVICE_ID)
    {
        rc = 1;
        char sdk_path_buf[512];
        char *sdk_env_var;
        sdk_env_var = getenv("SDK_DIR");
        snprintf(sdk_path_buf, sizeof(sdk_path_buf), "%s",
            (sdk_env_var != NULL) ? sdk_env_var : "<aws-fpga>");
        log_error(
            "...\n"
            "  The slot appears loaded, but the pci vendor or device ID doesn't match the\n"
            "  expected values. You may need to rescan the fpga with \n"
            "    fpga-describe-local-image -S %i -R\n"
            "  Note that rescanning can change which device file in /dev/ a FPGA will map to.\n",
            slot_id);
        log_error(
            "...\n"
            "  To remove and re-add your xdma driver and reset the device file mappings, run\n"
            "    sudo rmmod xdma && sudo insmod \"%s/sdk/linux_kernel_drivers/xdma/xdma.ko\"\n",
            sdk_path_buf);
        fail_on(rc, out, "The PCI vendor id and device of the loaded image are "
                         "not the expected values.");
    }

    char dbdf[16];
    snprintf(dbdf,
                  sizeof(dbdf),
                  PCI_DEV_FMT,
                  info.spec.map[FPGA_APP_PF].domain,
                  info.spec.map[FPGA_APP_PF].bus,
                  info.spec.map[FPGA_APP_PF].dev,
                  info.spec.map[FPGA_APP_PF].func);
    log_info("Operating on slot %d with id: %s", slot_id, dbdf);

out:
    return rc;
}

//void usage(char* program_name) {
//    printf("usage: %s [--slot <slot-id>][<poke-value>]\n", program_name);
//}

#endif


uint64_t buffer_compare(uint8_t *bufa, uint8_t *bufb, size_t buffer_size)
{
	size_t i;
	uint64_t differ = 0;
	for (i = 0; i < buffer_size; ++i) {
		if (bufa[i] != bufb[i]) {
			differ += 1;
		}
	}

	return differ;
}




//////////////////////////
//no need to change above
//////////////////////////

int OCL_config_wr_rd(int slot_id) {
	int pf_id = FPGA_APP_PF;
	int bar_id = APP_PF_BAR0;
    int rc;
	uint32_t rd_data_hi, rd_data_lo;
	uint64_t rd_data;
    /* pci_bar_handle_t is a handler for an address space exposed by one PCI BAR on one of the PCI PFs of the FPGA */

    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

    
    /* attach to the fpga, with a pci_bar_handle out param
     * To attach to multiple slots or BARs, call this function multiple times,
     * saving the pci_bar_handle to specify which address space to interact with in
     * other API calls.
     * This function accepts the slot_id, physical function, and bar number
     */
#ifndef SV_TEST
    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);
    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);
#endif
    
	//write the config regs	
    printf("Writing RLWE_Q\n");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_RLWE_Q, LOW_32b(RLWE_Q));
    fail_on(rc, out, "Unable to write to the fpga !");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_RLWE_Q + 4, HIGH_32b(RLWE_Q));
    fail_on(rc, out, "Unable to write to the fpga !");

    printf("Writing BARRETT_M\n");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_BARRETT_M, LOW_32b(BARRETT_M));
    fail_on(rc, out, "Unable to write to the fpga !");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_BARRETT_M + 4, HIGH_32b(BARRETT_M));
    fail_on(rc, out, "Unable to write to the fpga !");

    printf("Writing RLWE_ILEN\n");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_RLWE_ILEN, LOW_32b(RLWE_ILENGTH));
    fail_on(rc, out, "Unable to write to the fpga !");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_RLWE_ILEN + 4, HIGH_32b(RLWE_ILENGTH));
    fail_on(rc, out, "Unable to write to the fpga !");

    printf("Writing BG_MASK\n");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_BG_MASK, LOW_32b(BG_MASK));
    fail_on(rc, out, "Unable to write to the fpga !");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_BG_MASK + 4, HIGH_32b(BG_MASK));
    fail_on(rc, out, "Unable to write to the fpga !");

    printf("Writing BARRETT_K2\n");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_BARRETT_K2, BARRETT_K2);
    fail_on(rc, out, "Unable to write to the fpga !");

    printf("Writing RLWE_LEN\n");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_RLWE_LEN, RLWE_LENGTH);
    fail_on(rc, out, "Unable to write to the fpga !");

    printf("Writing LOG2_RLWE_LEN\n");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_LOG2_RLWE_LEN, LOG2_RLWE_LEN);
    fail_on(rc, out, "Unable to write to the fpga !");

    printf("Writing DIGITG\n");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_DIGITG, DIGITG);
    fail_on(rc, out, "Unable to write to the fpga !");

    printf("Writing BG_WIDTH\n");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_BG_WIDTH, BG_WIDTH);
    fail_on(rc, out, "Unable to write to the fpga !");

    printf("Writing LWE_Q_MASK\n");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_LWE_Q_MASK, LWE_Q - 1);
    fail_on(rc, out, "Unable to write to the fpga !");

    printf("Writing EMBED_FACTOR\n");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_EMBED_FACTOR, EMBED_FACTOR);
    fail_on(rc, out, "Unable to write to the fpga !");

    printf("Writing TOP_FIFO_MODE\n");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_TOP_FIFO_MODE, TOP_FIFO_MODE);
    fail_on(rc, out, "Unable to write to the fpga !");

    printf("Writing OR_BOUND1\n");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_OR_BOUND1, gate_constant[0]);
    fail_on(rc, out, "Unable to write to the fpga !");

    printf("Writing AND_BOUND1\n");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_AND_BOUND1, gate_constant[1]);
    fail_on(rc, out, "Unable to write to the fpga !");

    printf("Writing NOR_BOUND1\n");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_NOR_BOUND1, gate_constant[2]);
    fail_on(rc, out, "Unable to write to the fpga !");

    printf("Writing NAND_BOUND1\n");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_NAND_BOUND1, gate_constant[3]);
    fail_on(rc, out, "Unable to write to the fpga !");

    printf("Writing XOR_BOUND1\n");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_XOR_BOUND1, gate_constant[4]);
    fail_on(rc, out, "Unable to write to the fpga !");

    printf("Writing XNOR_BOUND1\n");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_XNOR_BOUND1, gate_constant[5]);
    fail_on(rc, out, "Unable to write to the fpga !");

	//wait for the write to complete
	usleep(2);

	//read the config regs
    printf("Reading RLWE_Q\n");
    rc = fpga_pci_peek(pci_bar_handle, ADDR_RLWE_Q, &rd_data_lo);
    fail_on(rc, out, "Unable to read from the fpga !");
    rc = fpga_pci_peek(pci_bar_handle, ADDR_RLWE_Q + 4, &rd_data_hi);
    fail_on(rc, out, "Unable to read from the fpga !");
	rd_data = rd_data_hi;
	rd_data = (rd_data << 32) + rd_data_lo;
    printf("Read RLWE_Q = 0x%lx\n", rd_data);

    printf("Reading BARRETT_M\n");
    rc = fpga_pci_peek(pci_bar_handle, ADDR_BARRETT_M, &rd_data_lo);
    fail_on(rc, out, "Unable to read from the fpga !");
    rc = fpga_pci_peek(pci_bar_handle, ADDR_BARRETT_M + 4, &rd_data_hi);
    fail_on(rc, out, "Unable to read from the fpga !");
	rd_data = rd_data_hi;
	rd_data = (rd_data << 32) + rd_data_lo;
    printf("Read BARRETT_M = 0x%lx\n", rd_data);

    printf("Reading RLWE_ILEN\n");
    rc = fpga_pci_peek(pci_bar_handle, ADDR_RLWE_ILEN, &rd_data_lo);
    fail_on(rc, out, "Unable to read from the fpga !");
    rc = fpga_pci_peek(pci_bar_handle, ADDR_RLWE_ILEN + 4, &rd_data_hi);
    fail_on(rc, out, "Unable to read from the fpga !");
	rd_data = rd_data_hi;
	rd_data = (rd_data << 32) + rd_data_lo;
    printf("Read RLWE_ILEN = 0x%lx\n", rd_data);

    printf("Reading BG_MASK\n");
    rc = fpga_pci_peek(pci_bar_handle, ADDR_BG_MASK, &rd_data_lo);
    fail_on(rc, out, "Unable to read from the fpga !");
    rc = fpga_pci_peek(pci_bar_handle, ADDR_BG_MASK + 4, &rd_data_hi);
    fail_on(rc, out, "Unable to read from the fpga !");
	rd_data = rd_data_hi;
	rd_data = (rd_data << 32) + rd_data_lo;
    printf("Read BG_MASK = 0x%lx\n", rd_data);

    printf("Reading BARRETT_K2\n");
    rc = fpga_pci_peek(pci_bar_handle, ADDR_BARRETT_K2, &rd_data_lo);
    fail_on(rc, out, "Unable to read from the fpga !");
    printf("Read BARRETT_K2 = 0x%x\n", rd_data_lo);

    printf("Reading RLWE_LEN\n");
    rc = fpga_pci_peek(pci_bar_handle, ADDR_RLWE_LEN, &rd_data_lo);
    fail_on(rc, out, "Unable to read from the fpga !");
    printf("Read RLWE_LEN = 0x%x\n", rd_data_lo);

    printf("Reading LOG2_RLWE_LEN\n");
    rc = fpga_pci_peek(pci_bar_handle, ADDR_LOG2_RLWE_LEN, &rd_data_lo);
    fail_on(rc, out, "Unable to read from the fpga !");
    printf("Read LOG2_RLWE_LEN = 0x%x\n", rd_data_lo);

    printf("Reading DIGITG\n");
    rc = fpga_pci_peek(pci_bar_handle, ADDR_DIGITG, &rd_data_lo);
    fail_on(rc, out, "Unable to read from the fpga !");
    printf("Read DIGITG = 0x%x\n", rd_data_lo);

    printf("Reading BG_WIDTH\n");
    rc = fpga_pci_peek(pci_bar_handle, ADDR_BG_WIDTH, &rd_data_lo);
    fail_on(rc, out, "Unable to read from the fpga !");
    printf("Read BG_WIDTH = 0x%x\n", rd_data_lo);

    printf("Reading LWE_Q_MASK\n");
    rc = fpga_pci_peek(pci_bar_handle, ADDR_LWE_Q_MASK, &rd_data_lo);
    fail_on(rc, out, "Unable to read from the fpga !");
    printf("Read LWE_Q_MASK = 0x%x\n", rd_data_lo);

    printf("Reading EMBED_FACTOR\n");
    rc = fpga_pci_peek(pci_bar_handle, ADDR_EMBED_FACTOR, &rd_data_lo);
    fail_on(rc, out, "Unable to read from the fpga !");
    printf("Read EMBED_FACTOR = 0x%x\n", rd_data_lo);

    printf("Reading TOP_FIFO_MODE\n");
    rc = fpga_pci_peek(pci_bar_handle, ADDR_TOP_FIFO_MODE, &rd_data_lo);
    fail_on(rc, out, "Unable to read from the fpga !");
    printf("Read TOP_FIFO_MODE = 0x%x\n", rd_data_lo);

    printf("Reading OR_BOUND1\n");
    rc = fpga_pci_peek(pci_bar_handle, ADDR_OR_BOUND1, &rd_data_lo);
    fail_on(rc, out, "Unable to read from the fpga !");
    printf("Read ADDR_OR_BOUND1 = 0x%x\n", rd_data_lo);

    printf("Reading AND_BOUND1\n");
    rc = fpga_pci_peek(pci_bar_handle, ADDR_AND_BOUND1, &rd_data_lo);
    fail_on(rc, out, "Unable to read from the fpga !");
    printf("Read ADDR_AND_BOUND1 = 0x%x\n", rd_data_lo);

    printf("Reading NOR_BOUND1\n");
    rc = fpga_pci_peek(pci_bar_handle, ADDR_NOR_BOUND1, &rd_data_lo);
    fail_on(rc, out, "Unable to read from the fpga !");
    printf("Read ADDR_NOR_BOUND1 = 0x%x\n", rd_data_lo);

    printf("Reading NAND_BOUND1\n");
    rc = fpga_pci_peek(pci_bar_handle, ADDR_NAND_BOUND1, &rd_data_lo);
    fail_on(rc, out, "Unable to read from the fpga !");
    printf("Read ADDR_NAND_BOUND1 = 0x%x\n", rd_data_lo);

    printf("Reading XOR_BOUND1\n");
    rc = fpga_pci_peek(pci_bar_handle, ADDR_XOR_BOUND1, &rd_data_lo);
    fail_on(rc, out, "Unable to read from the fpga !");
    printf("Read ADDR_XOR_BOUND1 = 0x%x\n", rd_data_lo);

    printf("Reading XNOR_BOUND1\n");
    rc = fpga_pci_peek(pci_bar_handle, ADDR_XNOR_BOUND1, &rd_data_lo);
    fail_on(rc, out, "Unable to read from the fpga !");
    printf("Read ADDR_XNOR_BOUND1 = 0x%x\n", rd_data_lo);

out:
    /* clean up */
    if (pci_bar_handle >= 0) {
        rc = fpga_pci_detach(pci_bar_handle);
        if (rc) {
            printf("Failure while detaching from the fpga.\n");
        }
    }

    /* if there is an error code, exit with status 1 */
    return (rc != 0 ? 1 : 0);
}

int OCL_config_wr_one_addr(int slot_id, uint64_t ocl_addr, uint32_t data) {
	int pf_id = FPGA_APP_PF;
	int bar_id = APP_PF_BAR0;
    int rc;

    /* pci_bar_handle_t is a handler for an address space exposed by one PCI BAR on one of the PCI PFs of the FPGA */
    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

    
    /* attach to the fpga, with a pci_bar_handle out param
     * To attach to multiple slots or BARs, call this function multiple times,
     * saving the pci_bar_handle to specify which address space to interact with in
     * other API calls.
     * This function accepts the slot_id, physical function, and bar number
     */
#ifndef SV_TEST
    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);
    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);
#endif
    
	//write the config regs	
    rc = fpga_pci_poke(pci_bar_handle, ocl_addr, data);
    fail_on(rc, out, "Unable to write to the fpga !");

out:
    /* clean up */
    if (pci_bar_handle >= 0) {
        rc = fpga_pci_detach(pci_bar_handle);
        if (rc) {
            printf("Failure while detaching from the fpga.\n");
        }
    }

    /* if there is an error code, exit with status 1 */
    return (rc != 0 ? 1 : 0);
}

int OCL_config_rd_one_addr(int slot_id, uint64_t ocl_addr, uint32_t* data) {
	int pf_id = FPGA_APP_PF;
	int bar_id = APP_PF_BAR0;
    int rc;
    /* pci_bar_handle_t is a handler for an address space exposed by one PCI BAR on one of the PCI PFs of the FPGA */

    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

    
    /* attach to the fpga, with a pci_bar_handle out param
     * To attach to multiple slots or BARs, call this function multiple times,
     * saving the pci_bar_handle to specify which address space to interact with in
     * other API calls.
     * This function accepts the slot_id, physical function, and bar number
     */
#ifndef SV_TEST
    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);
    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);
#endif
    
	//read the config regs
    rc = fpga_pci_peek(pci_bar_handle, ocl_addr, data);
    fail_on(rc, out, "Unable to read from the fpga !");

out:
    /* clean up */
    if (pci_bar_handle >= 0) {
        rc = fpga_pci_detach(pci_bar_handle);
        if (rc) {
            printf("Failure while detaching from the fpga.\n");
        }
    }

    /* if there is an error code, exit with status 1 */
    return (rc != 0 ? 1 : 0);
}


int BAR1_ROU_table_2k_wr(int slot_id) {
	int pf_id = FPGA_APP_PF;
	int bar_id = APP_PF_BAR1;
    int rc;
    char* cl_dir;
	char file_path[256];	//max file path 255 char
	FILE* fptr;
	struct timespec ts;		//specify time to sleep
	/* pci_bar_handle_t is a handler for an address space exposed by one PCI BAR on one of the PCI PFs of the FPGA */

    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

    
    /* attach to the fpga, with a pci_bar_handle out param
     * To attach to multiple slots or BARs, call this function multiple times,
     * saving the pci_bar_handle to specify which address space to interact with in
     * other API calls.
     * This function accepts the slot_id, physical function, and bar number
     */
#ifndef SV_TEST
    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);
    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);
#endif
    
	
    printf("Read in ROU table\n");
	cl_dir = getenv("CL_DIR");
	//printf("%s", cl_dir);	
	
	char* rou_path = "/verif/tests/mem_init_content/bk/ROU_table_2k_complete.mem";
	snprintf(file_path, sizeof(file_path), "%s%s", cl_dir, rou_path);
	//printf("%s\n", file_path);	
	
	fptr = fopen(file_path, "r");
	if(fptr == NULL){
		fail_on(1, out, "Unable to open ROU file");
	}
	

	uint64_t rou;
	fscanf(fptr, "%lx\n", &rou);	//read the first one out, no need to program the first one
    printf("Program ROU table\n");
	for(int i = 8; i < RLWE_LENGTH * 8; i += 8){
		fscanf(fptr, "%lx\n", &rou);		//64 bit number should use %lx to read in, or it only reads in 32 bit from the file
#ifndef SV_TEST
 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)i, LOW_32b(rou));
#else
 		rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)i, LOW_32b(rou));
		//////////////////////////////////////////////////////////////////////////
		//
		// the original AWS HDK does not support accessing bars other than ocl in simulation, 
		// this function is added by me with hacked HDK files. Check the README.txt.
		//
		/////////////////////////////////////////////////////////////////////////////
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
#ifndef SV_TEST
    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(i + 4), LOW_32b(rou >> 27));
#else
    	rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(i + 4), LOW_32b(rou >> 27));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
	}
	//wait 1000ns	
	ts.tv_sec = 0;
	ts.tv_nsec = 1000;
	nanosleep(&ts, NULL);

	printf("Read in iROU table\n");
	char* irou_path = "/verif/tests/mem_init_content/bk/iROU_table_2k.mem";
	snprintf(file_path, sizeof(file_path), "%s%s", cl_dir, irou_path);
	//printf("%s\n", file_path);	
	
	fptr = fopen(file_path, "r");
	if(fptr == NULL){
		fail_on(1, out, "Unable to open iROU file");
	}
	

	uint64_t irou;
    printf("Program iROU table\n");
	for(int i = 0; i < RLWE_LENGTH * 8; i += 8){
		fscanf(fptr, "%lx\n", &irou);
#ifndef SV_TEST
 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(i + IROU_BASE_ADDR), LOW_32b(irou));
#else
 		rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(i + IROU_BASE_ADDR), LOW_32b(irou));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
#ifndef SV_TEST
    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(i + 4 + IROU_BASE_ADDR), LOW_32b(irou >> 27));
#else
    	rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(i + 4 + IROU_BASE_ADDR), LOW_32b(irou >> 27));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
	}
	//wait 1000ns	
	ts.tv_sec = 0;
	ts.tv_nsec = 1000;
	nanosleep(&ts, NULL);


out:
    /* clean up */
    if (pci_bar_handle >= 0) {
        rc = fpga_pci_detach(pci_bar_handle);
        if (rc) {
            printf("Failure while detaching from the fpga.\n");
        }
    }

    /* if there is an error code, exit with status 1 */
    return (rc != 0 ? 1 : 0);
}

int BAR1_ROU_table_1k_wr(int slot_id) {
	int pf_id = FPGA_APP_PF;
	int bar_id = APP_PF_BAR1;
    int rc;
    char* cl_dir;
	char file_path[256];	//max file path 255 char
	FILE* fptr;
	struct timespec ts;		//specify time to sleep
	/* pci_bar_handle_t is a handler for an address space exposed by one PCI BAR on one of the PCI PFs of the FPGA */

    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

    
    /* attach to the fpga, with a pci_bar_handle out param
     * To attach to multiple slots or BARs, call this function multiple times,
     * saving the pci_bar_handle to specify which address space to interact with in
     * other API calls.
     * This function accepts the slot_id, physical function, and bar number
     */
#ifndef SV_TEST
    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);
    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);
#endif
    
	
    printf("Read in ROU table\n");
	cl_dir = getenv("CL_DIR");
	//printf("%s", cl_dir);	
	
	char* rou_path = "/verif/tests/mem_init_content/bk/ROU_table_1k_complete.mem";
	snprintf(file_path, sizeof(file_path), "%s%s", cl_dir, rou_path);
	//printf("%s\n", file_path);	
	
	fptr = fopen(file_path, "r");
	if(fptr == NULL){
		fail_on(1, out, "Unable to open ROU file");
	}
	

	uint64_t rou;
	fscanf(fptr, "%lx\n", &rou);	//read the first one out, no need to program the first one
    printf("Program ROU table\n");
	for(int i = 0; i < 1; i++){
		fscanf(fptr, "%lx\n", &rou);
#ifndef SV_TEST
 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE9_BASE_ADDR + i * 8), LOW_32b(rou));
#else
 		rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(ROU_STAGE9_BASE_ADDR + i * 8), LOW_32b(rou));		
		//////////////////////////////////////////////////////////////////////////
		//
		// the original AWS HDK does not support accessing bars other than ocl in simulation, 
		// this function is added by me with hacked HDK files. Check the README.txt.
		//
		/////////////////////////////////////////////////////////////////////////////
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
#ifndef SV_TEST
    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE9_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
#else
    	rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(ROU_STAGE9_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
	}

	for(int i = 0; i < 2; i++){
		fscanf(fptr, "%lx\n", &rou);
#ifndef SV_TEST
 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE8_BASE_ADDR + i * 8), LOW_32b(rou));
#else
 		rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(ROU_STAGE8_BASE_ADDR + i * 8), LOW_32b(rou));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
#ifndef SV_TEST
    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE8_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
#else
    	rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(ROU_STAGE8_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
	}

	for(int i = 0; i < 4; i++){
		fscanf(fptr, "%lx\n", &rou);
#ifndef SV_TEST
 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE7_BASE_ADDR + i * 8), LOW_32b(rou));
#else
 		rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(ROU_STAGE7_BASE_ADDR + i * 8), LOW_32b(rou));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
#ifndef SV_TEST
    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE7_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
#else
    	rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(ROU_STAGE7_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
	}

	for(int i = 0; i < 8; i++){
		fscanf(fptr, "%lx\n", &rou);
#ifndef SV_TEST
 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE6_BASE_ADDR + i * 8), LOW_32b(rou));
#else
 		rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(ROU_STAGE6_BASE_ADDR + i * 8), LOW_32b(rou));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
#ifndef SV_TEST
    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE6_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
#else
    	rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(ROU_STAGE6_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
	}

	for(int i = 0; i < 16; i++){
		fscanf(fptr, "%lx\n", &rou);
#ifndef SV_TEST
 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE5_BASE_ADDR + i * 8), LOW_32b(rou));
#else
 		rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(ROU_STAGE5_BASE_ADDR + i * 8), LOW_32b(rou));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
#ifndef SV_TEST
    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE5_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
#else
    	rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(ROU_STAGE5_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
	}

	for(int i = 0; i < 32; i++){
		fscanf(fptr, "%lx\n", &rou);
#ifndef SV_TEST
 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE4_BASE_ADDR + i * 8), LOW_32b(rou));
#else
 		rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(ROU_STAGE4_BASE_ADDR + i * 8), LOW_32b(rou));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
#ifndef SV_TEST
    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE4_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
#else
    	rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(ROU_STAGE4_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
	}

	for(int i = 0; i < 64; i++){
		fscanf(fptr, "%lx\n", &rou);
#ifndef SV_TEST
 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE3_BASE_ADDR + i * 8), LOW_32b(rou));
#else
 		rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(ROU_STAGE3_BASE_ADDR + i * 8), LOW_32b(rou));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
#ifndef SV_TEST
    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE3_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
#else
    	rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(ROU_STAGE3_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
	}

	for(int i = 0; i < 128; i++){
		fscanf(fptr, "%lx\n", &rou);
#ifndef SV_TEST
 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE2_BASE_ADDR + i * 8), LOW_32b(rou));
#else
 		rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(ROU_STAGE2_BASE_ADDR + i * 8), LOW_32b(rou));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
#ifndef SV_TEST
    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE2_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
#else
    	rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(ROU_STAGE2_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
	}

	for(int i = 0; i < 256; i++){
		fscanf(fptr, "%lx\n", &rou);
#ifndef SV_TEST
 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE1_BASE_ADDR + i * 8), LOW_32b(rou));
#else
 		rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(ROU_STAGE1_BASE_ADDR + i * 8), LOW_32b(rou));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
#ifndef SV_TEST
    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE1_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
#else
    	rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(ROU_STAGE1_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
	}

	for(int i = 0; i < 512; i++){
		fscanf(fptr, "%lx\n", &rou);
#ifndef SV_TEST
 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE0_BASE_ADDR + i * 8), LOW_32b(rou));
#else
 		rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(ROU_STAGE0_BASE_ADDR + i * 8), LOW_32b(rou));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
#ifndef SV_TEST
    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE0_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
#else
    	rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(ROU_STAGE0_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
	}

	fclose(fptr);
	//wait 1000ns	
	ts.tv_sec = 0;
	ts.tv_nsec = 1000;
	nanosleep(&ts, NULL);

	printf("Read in iROU table\n");
	char* irou_path = "/verif/tests/mem_init_content/bk/iROU_table_1k.mem";
	snprintf(file_path, sizeof(file_path), "%s%s", cl_dir, irou_path);
	//printf("%s\n", file_path);	
	
	fptr = fopen(file_path, "r");
	if(fptr == NULL){
		fail_on(1, out, "Unable to open iROU file");
	}
	

	uint64_t irou;
    printf("Program iROU table\n");
	for(int i = 0; i < RLWE_LENGTH * 8; i += 8){
		fscanf(fptr, "%lx\n", &irou);
#ifndef SV_TEST
 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(i + IROU_BASE_ADDR), LOW_32b(irou));
#else
 		rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(i + IROU_BASE_ADDR), LOW_32b(irou));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
#ifndef SV_TEST
    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(i + 4 + IROU_BASE_ADDR), LOW_32b(irou >> 27));
#else
    	rc = fpga_pci_poke_bar1(pci_bar_handle, (uint64_t)(i + 4 + IROU_BASE_ADDR), LOW_32b(irou >> 27));
#endif
    	fail_on(rc, out, "Unable to write to the fpga !");
	}

	fclose(fptr);
	//wait 1000ns	
	ts.tv_sec = 0;
	ts.tv_nsec = 1000;
	nanosleep(&ts, NULL);


out:
    /* clean up */
    if (pci_bar_handle >= 0) {
        rc = fpga_pci_detach(pci_bar_handle);
        if (rc) {
            printf("Failure while detaching from the fpga.\n");
        }
    }

    /* if there is an error code, exit with status 1 */
    return (rc != 0 ? 1 : 0);
}


int dma_test(int slot_id)
{
    int write_fd, read_fd, rc;
	size_t buffer_size = 32 * 1024;
	struct timespec ts;		//specify time to sleep

	long sz = sysconf(_SC_PAGESIZE);

    write_fd = -1;
    read_fd = -1;

    uint64_t *write_buffer = aligned_alloc(sz, buffer_size * 4);	//try aligned address, if the buffer is page aligned than the dma awlen = 0x07, arlen = 0x3f
    uint64_t *read_buffer = aligned_alloc(sz, buffer_size * 4);
    if (write_buffer == NULL || read_buffer == NULL) {
        rc = -ENOMEM;
        goto out;
    }

    printf("Memory has been allocated, initializing DMA and filling the buffer...\n");

#ifndef SV_TEST
    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ true);
    fail_on((rc = (read_fd < 0) ? -1 : 0), out, "unable to open read dma queue");

    write_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ false);
    fail_on((rc = (write_fd < 0) ? -1 : 0), out, "unable to open write dma queue");
#else
    setup_send_rdbuf_to_c((uint8_t*)read_buffer, buffer_size);
    printf("Starting DDR init...\n");
    init_ddr();
    printf("Done DDR init...\n");
#endif
	
    printf("filling buffer with sequential data...\n") ;
	for(int i = 0; i < buffer_size / 8 * 4; i++) {
		*(write_buffer + i) = 0x003FFFFFFFFED001 - i;
		//printf("write_buffer[%4d] = %lx\n", i, *(write_buffer + i));
	}
	
	printf("Now performing the DMA transactions to ddr...\n");
	//rc = do_dma_write(write_fd, (uint8_t*)write_buffer, 16, DDR_ADDR, 0, slot_id);
	rc = do_dma_write(write_fd, (uint8_t*)write_buffer, buffer_size, DDR_ADDR, 0, slot_id);
	fail_on(rc, out, "DMA write failed on channel: %d", 0);
	
    printf("Now performing the DMA transactions from ddr...\n");
    //rc = do_dma_read(read_fd, (uint8_t*)read_buffer, 16, DDR_ADDR, 0, slot_id);
    rc = do_dma_read(read_fd, (uint8_t*)read_buffer, buffer_size, DDR_ADDR, 0, slot_id);
    fail_on(rc, out, "DMA read failed on channel: %d", 0);

    //printf("Print ddr read buffer data\n") ;
	////for(int i = 0; i < 2; i++) {
	//for(int i = 0; i < buffer_size / 8; i++) {
	//	printf("read_buffer[%4d] = %lx\n", i, *(read_buffer + i));
	//}

    uint64_t differ = buffer_compare((uint8_t*)read_buffer, (uint8_t*)write_buffer, buffer_size);
    if (differ != 0) {
        log_error("DDR wr/rd failed with %lu bytes which differ", differ);
    	rc = 1;
    } else {
        log_info("DDR wr/rd passed!");
    	rc = 0;
    }
	
	//reset read buffer
	for(int i = 0; i < buffer_size / 8; i++){
		*(read_buffer + i) = 0;
	}
		
	printf("Set the mode to RLWEMODE to write input fifo...\n");
	OCL_config_wr_one_addr(slot_id, ADDR_TOP_FIFO_MODE, RLWEMODE);

	ts.tv_sec = 0;
	ts.tv_nsec = 1000;
	nanosleep(&ts, NULL);
	for(int i = 0; i < 4; i++){	
    	printf("Now performing the DMA transactions to input fifo...\n");
    	rc = do_dma_write(write_fd, ((uint8_t*)write_buffer) + i * buffer_size , buffer_size, INPUT_FIFO_ADDR, 0, slot_id);
    	fail_on(rc, out, "DMA write failed on channel: %d", 0);
	}

	printf("Set the mode to BTMODE to read input fifo...\n");
	OCL_config_wr_one_addr(slot_id, ADDR_TOP_FIFO_MODE, BTMODE);

	ts.tv_sec = 0;
	ts.tv_nsec = 1000;
	nanosleep(&ts, NULL);

	for(int i = 0; i < 4; i++) {
		printf("Now performing the DMA transactions from input fifo...\n");
		rc = do_dma_read(read_fd, ((uint8_t*)read_buffer) + i * buffer_size, buffer_size, INPUT_FIFO_ADDR, 0, slot_id);
		fail_on(rc, out, "DMA read failed on channel: %d", 0);
	}

    //printf("Print input fifo read buffer data\n") ;
	//for(int i = 0; i < buffer_size / 8 * 4; i++) {
	//	printf("read_buffer[%5d] = %lx\n", i, *(read_buffer + i));
	//}

    differ = buffer_compare((uint8_t*)read_buffer, (uint8_t*)write_buffer, buffer_size);
    if (differ != 0) {
        log_error("Input fifo wr/rd failed with %lu bytes which differ", differ);
    	rc = 1;
    } else {
        log_info("Input fifo wr/rd passed!");
    	rc = 0;
    }
out:
    if (write_buffer != NULL) {
        free(write_buffer);
    }
    if (read_buffer != NULL) {
        free(read_buffer);
    }
#if !defined(SV_TEST)
    if (write_fd >= 0) {
        close(write_fd);
    }
    if (read_fd >= 0) {
        close(read_fd);
    }
#endif
    /* if there is an error code, exit with status 1 */
    return (rc != 0 ? 1 : 0);
}


int rlwesubs_dual_test(int slot_id){
	int pf_id = FPGA_APP_PF;
	int bar_id = APP_PF_BAR0;
    int write_fd = -1;
   	int	read_fd = -1;
	int rc;

	size_t buffer_size = 32 * 1024;
	struct timespec ts;		//specify time to sleep
    char *cl_dir;
	char file_path[512];	//max file path 511 char
	FILE *fptr_a, *fptr_b;
	uint64_t ddr_addr = DDR_ADDR;	//addr to FPGA ddr

	long sz = sysconf(_SC_PAGESIZE);
	
	uint32_t ocl_rd_data;


	//setup to BAR0/OCL
    /* pci_bar_handle_t is a handler for an address space exposed by one PCI BAR on one of the PCI PFs of the FPGA */
    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

    
    /* attach to the fpga, with a pci_bar_handle out param
     * To attach to multiple slots or BARs, call this function multiple times,
     * saving the pci_bar_handle to specify which address space to interact with in
     * other API calls.
     * This function accepts the slot_id, physical function, and bar number
     */
#ifndef SV_TEST
    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);
    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);
#endif

	//allocate buffer
    uint64_t *write_buffer = aligned_alloc(sz, buffer_size);	//try aligned address, if the buffer is page aligned than the dma awlen = 0x07, arlen = 0x3f
    uint64_t *read_buffer = aligned_alloc(sz, buffer_size);
    uint64_t *input_buffer0 = aligned_alloc(sz, buffer_size);
    uint64_t *input_buffer1 = aligned_alloc(sz, buffer_size);
    uint64_t *output_buffer0 = aligned_alloc(sz, buffer_size);
    uint64_t *output_buffer1 = aligned_alloc(sz, buffer_size);
    if (write_buffer == NULL || read_buffer == NULL || input_buffer0 == NULL || input_buffer1 == NULL || output_buffer0 == NULL || output_buffer1 == NULL) {
        rc = -ENOMEM;
        goto out;
    }

    printf("Memory has been allocated, initializing DMA and filling the buffer...\n");

#ifndef SV_TEST
    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ true);
    fail_on((rc = (read_fd < 0) ? -1 : 0), out, "unable to open read dma queue");

    write_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ false);
    fail_on((rc = (write_fd < 0) ? -1 : 0), out, "unable to open write dma queue");
#else
    setup_send_rdbuf_to_c((uint8_t*)read_buffer, buffer_size);
    printf("Starting DDR init...\n");
    init_ddr();
    printf("Done DDR init...\n");
#endif


	cl_dir = getenv("CL_DIR");
	//printf("%s", cl_dir);	
	
    printf("Transferring subs key to DDR\n");
	for(int test_case = 0; test_case < 2; test_case++){
		for(int i = 0; i < DIGITG; i++){

			char* path_shared = "/verif/tests/mem_init_content/top_verify/rlwesubs/bk";
			//open poly a file
			snprintf(file_path, sizeof(file_path), "%s%s/RLWESUBS_keyinput_2k_rlwe_%0d_a%0d.mem", cl_dir, path_shared, i, test_case);
			//printf("%s\n", file_path);	
			
			fptr_a = fopen(file_path, "r");
			if(fptr_a == NULL){
				fail_on(1, out, "Unable to open key poly a file, %0d, %0d", i, test_case);
			}

			//open poly b file
			snprintf(file_path, sizeof(file_path), "%s%s/RLWESUBS_keyinput_2k_rlwe_%0d_b%0d.mem", cl_dir, path_shared, i, test_case);
			//printf("%s\n", file_path);	
			
			fptr_b = fopen(file_path, "r");
			if(fptr_b == NULL){
				fail_on(1, out, "Unable to open key poly b file, %0d, %0d", i, test_case);
			}
			
			//fill the buffer with data read from files
			uint64_t* buffer_addr_temp = write_buffer;
			for(int k = 0; k < RLWE_LENGTH / 4; k++){
				for(int j = 0; j < 4; j++){
					fscanf(fptr_a, "%lx\n", buffer_addr_temp);
					buffer_addr_temp++;
				}
				for(int j = 0; j < 4; j++){
					fscanf(fptr_b, "%lx\n", buffer_addr_temp);
					buffer_addr_temp++;
				}
			}
				
			//dma to ddr
			rc = do_dma_write(write_fd, (uint8_t*)write_buffer, buffer_size, ddr_addr, 0, slot_id);
			fail_on(rc, out, "DMA write failed on channel: %d", 0);
			ddr_addr += buffer_size;
			fclose(fptr_a);
			fclose(fptr_b);
		}
	}

    printf("Finish transferring subs key to DDR\n");
	for(int loop_counter = 0; loop_counter < 1000; loop_counter++){
    	printf("In loop %d\n", loop_counter);
    	printf("Reading in input RLWE\n");
		for(int test_case = 0; test_case < 2; test_case++){
			char* path_shared = "/verif/tests/mem_init_content/top_verify/rlwesubs/bk";
			//open poly a file
			snprintf(file_path, sizeof(file_path), "%s%s/RLWESUBS_inputrlwe_2k_a%0d.mem", cl_dir, path_shared, test_case);
			//printf("%s\n", file_path);	
			
			fptr_a = fopen(file_path, "r");
			if(fptr_a == NULL){
				fail_on(1, out, "Unable to open input rlwe poly a file, %0d", test_case);
			}

			//open poly b file
			snprintf(file_path, sizeof(file_path), "%s%s/RLWESUBS_inputrlwe_2k_b%0d.mem", cl_dir, path_shared, test_case);
			//printf("%s\n", file_path);	
			
			fptr_b = fopen(file_path, "r");
			if(fptr_b == NULL){
				fail_on(1, out, "Unable to open input rlwe poly b file, %0d", test_case);
			}
			
			//fill the buffer with data read from files
			uint64_t* buffer_addr_temp;
			if(test_case == 0)
				buffer_addr_temp = input_buffer0;
			else 
				buffer_addr_temp = input_buffer1;

			for(int k = 0; k < RLWE_LENGTH / 4; k++){
				for(int j = 0; j < 4; j++){
					fscanf(fptr_a, "%lx\n", buffer_addr_temp);
					buffer_addr_temp++;
				}
				for(int j = 0; j < 4; j++){
					fscanf(fptr_b, "%lx\n", buffer_addr_temp);
					buffer_addr_temp++;
				}
			}
				
			fclose(fptr_a);
			fclose(fptr_b);
		}
    	printf("Finish reading in input RLWE\n");


    	printf("Transferring input RLWE to CL\n");
		for(int rlwe_loop_counter = 0; rlwe_loop_counter < 2; rlwe_loop_counter++){
			for(int test_case = 0; test_case < 2; test_case++){
				rc = fpga_pci_peek(pci_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
				fail_on(rc, out, "Unable to read from the fpga !");
				print_fifo_states(ocl_rd_data);
				if(test_case == 0){		
					//dma to ddr
					rc = do_dma_write(write_fd, (uint8_t*)input_buffer0, buffer_size, INPUT_FIFO_ADDR, 0, slot_id);
					fail_on(rc, out, "DMA write failed on channel: %d", 0);
				} else {
					//dma to ddr
					rc = do_dma_write(write_fd, (uint8_t*)input_buffer1, buffer_size, INPUT_FIFO_ADDR, 0, slot_id);
					fail_on(rc, out, "DMA write failed on channel: %d", 0);
				}	
			}
		}
    	printf("Finish Transferring input RLWE to CL\n");


    	printf("Writing four instructions to CL\n");
		for(int rlwe_loop_counter = 0; rlwe_loop_counter < 2; rlwe_loop_counter++){
			for(int test_case = 0; test_case < 2; test_case++){
				rc = fpga_pci_peek(pci_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
				fail_on(rc, out, "Unable to read from the fpga !");
				print_fifo_states(ocl_rd_data);

				ddr_addr = DDR_ADDR + test_case * 32 * 1024 * DIGITG;
				ddr_addr = ddr_addr & ((1ULL << 34) - 1);
    			rc = fpga_pci_poke(pci_bar_handle, ADDR_INST_IN, form_instruction(RLWESUBS, 0, 0, 0, (uint32_t)(ddr_addr >> 14)));
    			fail_on(rc, out, "Unable to write to the fpga !");
			}
		}
    	printf("Finish writing four instructions to CL, waiting for the input RLWE to be not full\n");

    	printf("Transferring 4 extra input RLWE to CL\n");
		for(int rlwe_loop_counter = 0; rlwe_loop_counter < 2; rlwe_loop_counter++){
			for(int test_case = 0; test_case < 2; test_case++){
				do{
					rc = fpga_pci_peek(pci_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
					fail_on(rc, out, "Unable to read from the fpga !");
					print_fifo_states(ocl_rd_data);
					ts.tv_sec = 0;
					ts.tv_nsec = 1000;
					nanosleep(&ts, NULL);
				}while(get_fifo_state(ocl_rd_data, RLWE_INPUT_FIFO_FULL));

				if(test_case == 0){		
					//dma to ddr
					rc = do_dma_write(write_fd, (uint8_t*)input_buffer0, buffer_size, INPUT_FIFO_ADDR, 0, slot_id);
					fail_on(rc, out, "DMA write failed on channel: %d", 0);
				} else {
					//dma to ddr
					rc = do_dma_write(write_fd, (uint8_t*)input_buffer1, buffer_size, INPUT_FIFO_ADDR, 0, slot_id);
					fail_on(rc, out, "DMA write failed on channel: %d", 0);
				}	
			}
		}
    	printf("Finish Transferring 4 extra input RLWE to CL\n");

    	printf("Writing four instructions to CL\n");
		for(int rlwe_loop_counter = 0; rlwe_loop_counter < 2; rlwe_loop_counter++){
			for(int test_case = 0; test_case < 2; test_case++){
				rc = fpga_pci_peek(pci_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
				fail_on(rc, out, "Unable to read from the fpga !");
				print_fifo_states(ocl_rd_data);

				ddr_addr = DDR_ADDR + test_case * 32 * 1024 * DIGITG;
				ddr_addr = ddr_addr & ((1ULL << 34) - 1);
    			rc = fpga_pci_poke(pci_bar_handle, ADDR_INST_IN, form_instruction(RLWESUBS, 0, 0, 0, (uint32_t)(ddr_addr >> 14)));
    			fail_on(rc, out, "Unable to write to the fpga !");
			}
		}
    	printf("Finish writing four instructions to CL, waiting for the output RLWE to be nonempty\n");

    	printf("Reading in output RLWE ground truth\n");
		for(int test_case = 0; test_case < 2; test_case++){
			char* path_shared = "/verif/tests/mem_init_content/top_verify/rlwesubs/bk";
			//open poly a file
			snprintf(file_path, sizeof(file_path), "%s%s/RLWESUBS_outputrlwe_2k_a%0d.mem", cl_dir, path_shared, test_case);
			//printf("%s\n", file_path);	
			
			fptr_a = fopen(file_path, "r");
			if(fptr_a == NULL){
				fail_on(1, out, "Unable to open input rlwe poly a file, %0d", test_case);
			}

			//open poly b file
			snprintf(file_path, sizeof(file_path), "%s%s/RLWESUBS_outputrlwe_2k_b%0d.mem", cl_dir, path_shared, test_case);
			//printf("%s\n", file_path);	
			
			fptr_b = fopen(file_path, "r");
			if(fptr_b == NULL){
				fail_on(1, out, "Unable to open input rlwe poly b file, %0d", test_case);
			}
			
			//fill the buffer with data read from files
			uint64_t* buffer_addr_temp;
			if(test_case == 0)
				buffer_addr_temp = output_buffer0;
			else 
				buffer_addr_temp = output_buffer1;

			//printf("ground truth\n");
			for(int k = 0; k < RLWE_LENGTH / 4; k++){
				for(int j = 0; j < 4; j++){
					fscanf(fptr_a, "%lx\n", buffer_addr_temp);
					//printf("%16lx\n", *buffer_addr_temp);
					buffer_addr_temp++;
				}
				for(int j = 0; j < 4; j++){
					fscanf(fptr_b, "%lx\n", buffer_addr_temp);
					//printf("%16lx\n", *buffer_addr_temp);
					buffer_addr_temp++;
				}
			}

			fclose(fptr_a);
			fclose(fptr_b);
		}
    	printf("Finish reading in output RLWE ground truth\n");

    	rc = 0;
    	printf("Transferring output RLWE from CL and compare to ground truth\n");
		for(int rlwe_loop_counter = 0; rlwe_loop_counter < 4; rlwe_loop_counter++){
			for(int test_case = 0; test_case < 2; test_case++){
				do{
					ts.tv_sec = 0;
					ts.tv_nsec = 1000;
					nanosleep(&ts, NULL);
					rc = fpga_pci_peek(pci_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
					fail_on(rc, out, "Unable to read from the fpga !");
					print_fifo_states(ocl_rd_data);
				}while(get_fifo_state(ocl_rd_data, RLWE_OUTPUT_FIFO_EMPTY));
				//dma to ddr
				rc = do_dma_read(read_fd, (uint8_t*)read_buffer, buffer_size, OUTPUT_FIFO_ADDR, 0, slot_id);
				fail_on(rc, out, "DMA read failed on channel: %d", 0);

				//printf("read out %d, %d\n", rlwe_loop_counter, test_case);
				//for(int k = 0; k < RLWE_LENGTH * 2; k++){
				//	printf("%16lx\n", *(read_buffer + k));
				//}
				uint64_t differ;
				if(test_case == 0) 
					differ = buffer_compare((uint8_t*)read_buffer, (uint8_t*)output_buffer0, buffer_size);
				else 
					differ = buffer_compare((uint8_t*)read_buffer, (uint8_t*)output_buffer1, buffer_size);

    			if (differ != 0) {
    			    log_error("rlwesubs failed at loop: %d, test_case: %d, with %lu bytes which differ", rlwe_loop_counter, test_case, differ);
    				rc = 1;
    			} else {
    			    log_info("rlwesubs passed at loop:  %d, test_case: %d!", rlwe_loop_counter, test_case);
    			}
			}
		}
    	printf("Finish Transferring output RLWE from CL and comparing\n");
	}
		
out:
    /* clean up */
    if (pci_bar_handle >= 0) {
        rc = fpga_pci_detach(pci_bar_handle);
        if (rc) {
            printf("Failure while detaching from the fpga.\n");
        }
    }

    if (write_buffer != NULL) {
        free(write_buffer);
    }
    if (read_buffer != NULL) {
        free(read_buffer);
    }
    if (input_buffer0 != NULL) {
        free(input_buffer0);
    }
    if (input_buffer1 != NULL) {
        free(input_buffer1);
    }
    if (output_buffer0 != NULL) {
        free(output_buffer0);
    }
    if (output_buffer1 != NULL) {
        free(output_buffer1);
    }
#if !defined(SV_TEST)
    if (write_fd >= 0) {
        close(write_fd);
    }
    if (read_fd >= 0) {
        close(read_fd);
    }
#endif
	if(rc != 0) 
		printf("rlwesubs case failed!\n");
	else
		printf("rlwesubs case passed!\n");
    /* if there is an error code, exit with status 1 */
    return (rc != 0 ? 1 : 0);
}

int bootstrap_init_test(int slot_id){
	int pf_id = FPGA_APP_PF;
	int bar_id = APP_PF_BAR0;
    int write_fd = -1;
   	int	read_fd = -1;
	int rc;

	size_t buffer_size = 16 * 1024;
	struct timespec ts;		//specify time to sleep
    char *cl_dir;
	char file_path[512];	//max file path 511 char
	FILE *fptr_a, *fptr_b;
	uint64_t ddr_addr = DDR_ADDR;	//addr to FPGA ddr

	long sz = sysconf(_SC_PAGESIZE);
	
	uint32_t ocl_rd_data;


	//setup to BAR0/OCL
    /* pci_bar_handle_t is a handler for an address space exposed by one PCI BAR on one of the PCI PFs of the FPGA */
    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

    
    /* attach to the fpga, with a pci_bar_handle out param
     * To attach to multiple slots or BARs, call this function multiple times,
     * saving the pci_bar_handle to specify which address space to interact with in
     * other API calls.
     * This function accepts the slot_id, physical function, and bar number
     */
#ifndef SV_TEST
    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);
    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);
#endif

	//allocate buffer
    uint64_t *write_buffer = aligned_alloc(sz, buffer_size);	//try aligned address, if the buffer is page aligned than the dma awlen = 0x07, arlen = 0x3f
    uint64_t *read_buffer = aligned_alloc(sz, buffer_size);
    uint64_t *output_buffer = aligned_alloc(sz, buffer_size);
    if (write_buffer == NULL || read_buffer == NULL || output_buffer == NULL) {
        rc = -ENOMEM;
        goto out;
    }

    printf("Memory has been allocated, initializing DMA and filling the buffer...\n");

#ifndef SV_TEST
    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ true);
    fail_on((rc = (read_fd < 0) ? -1 : 0), out, "unable to open read dma queue");

    write_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ false);
    fail_on((rc = (write_fd < 0) ? -1 : 0), out, "unable to open write dma queue");
#else
    setup_send_rdbuf_to_c((uint8_t*)read_buffer, buffer_size);
    printf("Starting DDR init...\n");
    init_ddr();
    printf("Done DDR init...\n");
#endif


	cl_dir = getenv("CL_DIR");
	//printf("%s", cl_dir);	
	
    printf("Transferring bootstrap key to DDR\n");
	for(int h = 0; h < 2; h++){
		for(int i = 0; i < DIGITG; i++){

			char* path_shared = "/verif/tests/mem_init_content/top_verify/bootstrap/bk";
			//open poly a file
			snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_inputrgsw_1k_rlwe_%0d_%0d_a.mem", cl_dir, path_shared, i, h);
			//printf("%s\n", file_path);	
			
			fptr_a = fopen(file_path, "r");
			if(fptr_a == NULL){
				fail_on(1, out, "Unable to open key poly a file, %0d, %0d", i, h);
			}

			//open poly b file
			snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_inputrgsw_1k_rlwe_%0d_%0d_b.mem", cl_dir, path_shared, i, h);
			//printf("%s\n", file_path);	
			
			fptr_b = fopen(file_path, "r");
			if(fptr_b == NULL){
				fail_on(1, out, "Unable to open key poly b file, %0d, %0d", i, h);
			}
			
			//fill the buffer with data read from files
			uint64_t* buffer_addr_temp = write_buffer;
			for(int k = 0; k < RLWE_LENGTH / 4; k++){
				for(int j = 0; j < 4; j++){
					fscanf(fptr_a, "%lx\n", buffer_addr_temp);
					buffer_addr_temp++;
				}
				for(int j = 0; j < 4; j++){
					fscanf(fptr_b, "%lx\n", buffer_addr_temp);
					buffer_addr_temp++;
				}
			}
				
			//dma to ddr
			rc = do_dma_write(write_fd, (uint8_t*)write_buffer, buffer_size, ddr_addr, 0, slot_id);
			fail_on(rc, out, "DMA write failed on channel: %d", 0);
			ddr_addr += buffer_size;
			fclose(fptr_a);
			fclose(fptr_b);
		}
	}

    printf("Finish transferring bootstrap key to DDR\n");

    printf("Writing eight instructions to CL\n");
	for(int rlwe_loop_counter = 0; rlwe_loop_counter < 8; rlwe_loop_counter++){
		rc = fpga_pci_peek(pci_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
		fail_on(rc, out, "Unable to read from the fpga !");
		print_fifo_states(ocl_rd_data);

		ddr_addr = DDR_ADDR;
		ddr_addr = ddr_addr & ((1ULL << 31) - 1);
    	rc = fpga_pci_poke(pci_bar_handle, ADDR_INST_IN, form_instruction(BOOTSTRAP_INIT, 3, 0, 0, (uint32_t)(ddr_addr >> 14)));
    	fail_on(rc, out, "Unable to write to the fpga !");
	}
    printf("Finish writing four instructions to CL, waiting for the output RLWE to be nonempty\n");

    printf("Reading in output RLWE ground truth\n");
	char* path_shared = "/verif/tests/mem_init_content/top_verify/bootstrap/bk";
	//open poly a file
	snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_outputrlwe_1k_a.mem", cl_dir, path_shared);
	//printf("%s\n", file_path);	
	
	fptr_a = fopen(file_path, "r");
	if(fptr_a == NULL){
		fail_on(1, out, "Unable to open output rlwe poly a file");
	}

	//open poly b file
	snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_outputrlwe_1k_b.mem", cl_dir, path_shared);
	//printf("%s\n", file_path);	
	
	fptr_b = fopen(file_path, "r");
	if(fptr_b == NULL){
		fail_on(1, out, "Unable to open output rlwe poly b file");
	}
	
	//fill the buffer with data read from files
	uint64_t* buffer_addr_temp;
	buffer_addr_temp = output_buffer;
	//printf("ground truth\n");
	for(int k = 0; k < RLWE_LENGTH / 4; k++){
		for(int j = 0; j < 4; j++){
			fscanf(fptr_a, "%lx\n", buffer_addr_temp);
			//printf("%16lx\n", *buffer_addr_temp);
			buffer_addr_temp++;
		}
		for(int j = 0; j < 4; j++){
			fscanf(fptr_b, "%lx\n", buffer_addr_temp);
			//printf("%16lx\n", *buffer_addr_temp);
			buffer_addr_temp++;
		}
	}

	fclose(fptr_a);
	fclose(fptr_b);
    printf("Finish reading in output RLWE ground truth\n");

    rc = 0;
    printf("Transferring output RLWE from CL and compare to ground truth\n");
	for(int rlwe_loop_counter = 0; rlwe_loop_counter < 8; rlwe_loop_counter++){
		do{
			ts.tv_sec = 0;
			ts.tv_nsec = 1000;
			nanosleep(&ts, NULL);
			rc = fpga_pci_peek(pci_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
			fail_on(rc, out, "Unable to read from the fpga !");
			print_fifo_states(ocl_rd_data);
		}while(get_fifo_state(ocl_rd_data, RLWE_INPUT_FIFO_EMPTY));
		//dma to ddr
		rc = do_dma_read(read_fd, (uint8_t*)read_buffer, buffer_size, INPUT_FIFO_ADDR, 0, slot_id);
		fail_on(rc, out, "DMA read failed on channel: %d", 0);
		//printf("read out\n");
		//for(int k = 0; k < RLWE_LENGTH * 2; k++){
		//	printf("%16lx\n", *(read_buffer + k));
		//}
		uint64_t differ;
		differ = buffer_compare((uint8_t*)read_buffer, (uint8_t*)output_buffer, buffer_size);
    	if (differ != 0) {
    	    log_error("bootstrap_init failed at loop: %d, with %lu bytes which differ", rlwe_loop_counter, differ);
    		rc = 1;
    	} else {
    	    log_info("bootstrap_init passed at loop:  %d!", rlwe_loop_counter);
    	}
	}
    printf("Finish Transferring output RLWE from CL and comparing\n");
		
out:
    /* clean up */
    if (pci_bar_handle >= 0) {
        rc = fpga_pci_detach(pci_bar_handle);
        if (rc) {
            printf("Failure while detaching from the fpga.\n");
        }
    }

    if (write_buffer != NULL) {
        free(write_buffer);
    }
    if (read_buffer != NULL) {
        free(read_buffer);
    }
    if (output_buffer != NULL) {
        free(output_buffer);
    }
#if !defined(SV_TEST)
    if (write_fd >= 0) {
        close(write_fd);
    }
    if (read_fd >= 0) {
        close(read_fd);
    }
#endif
	if(rc != 0) 
		printf("bootstrap case failed!\n");
	else
		printf("bootstrap case passed!\n");
    /* if there is an error code, exit with status 1 */
    return (rc != 0 ? 1 : 0);
}

int bootstrap_test(int slot_id){
	int pf_id = FPGA_APP_PF;
	int bar_id = APP_PF_BAR0;
    int write_fd = -1;
   	int	read_fd = -1;
	int rc;

	size_t buffer_size = 16 * 1024;
	struct timespec ts;		//specify time to sleep
    char *cl_dir;
	char file_path[512];	//max file path 511 char
	FILE *fptr_a, *fptr_b;
	uint64_t ddr_addr = DDR_ADDR;	//addr to FPGA ddr

	long sz = sysconf(_SC_PAGESIZE);
	
	uint32_t ocl_rd_data;


	//setup to BAR0/OCL
    /* pci_bar_handle_t is a handler for an address space exposed by one PCI BAR on one of the PCI PFs of the FPGA */
    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

    
    /* attach to the fpga, with a pci_bar_handle out param
     * To attach to multiple slots or BARs, call this function multiple times,
     * saving the pci_bar_handle to specify which address space to interact with in
     * other API calls.
     * This function accepts the slot_id, physical function, and bar number
     */
#ifndef SV_TEST
    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);
    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);
#endif

	//allocate buffer
    uint64_t *write_buffer = aligned_alloc(sz, buffer_size);	//try aligned address, if the buffer is page aligned than the dma awlen = 0x07, arlen = 0x3f
    uint64_t *read_buffer = aligned_alloc(sz, buffer_size);
    uint64_t *output_buffer = aligned_alloc(sz, buffer_size);
    if (write_buffer == NULL || read_buffer == NULL || output_buffer == NULL) {
        rc = -ENOMEM;
        goto out;
    }

    printf("Memory has been allocated, initializing DMA and filling the buffer...\n");

#ifndef SV_TEST
    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ true);
    fail_on((rc = (read_fd < 0) ? -1 : 0), out, "unable to open read dma queue");

    write_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ false);
    fail_on((rc = (write_fd < 0) ? -1 : 0), out, "unable to open write dma queue");
#else
    setup_send_rdbuf_to_c((uint8_t*)read_buffer, buffer_size);
    printf("Starting DDR init...\n");
    init_ddr();
    printf("Done DDR init...\n");
#endif


	cl_dir = getenv("CL_DIR");
	//printf("%s", cl_dir);	

	printf("Transferring bootstrap key to DDR\n");
	for(int h = 0; h < 2; h++){
		for(int i = 0; i < DIGITG; i++){

			char* path_shared = "/verif/tests/mem_init_content/top_verify/bootstrap/bk";
			//open poly a file
			snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_inputrgsw_1k_rlwe_%0d_%0d_a.mem", cl_dir, path_shared, i, h);
			//printf("%s\n", file_path);	
			
			fptr_a = fopen(file_path, "r");
			if(fptr_a == NULL){
				fail_on(1, out, "Unable to open key poly a file, %0d, %0d", i, h);
			}

			//open poly b file
			snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_inputrgsw_1k_rlwe_%0d_%0d_b.mem", cl_dir, path_shared, i, h);
			//printf("%s\n", file_path);	
			
			fptr_b = fopen(file_path, "r");
			if(fptr_b == NULL){
				fail_on(1, out, "Unable to open key poly b file, %0d, %0d", i, h);
			}
			
			//fill the buffer with data read from files
			uint64_t* buffer_addr_temp = write_buffer;
			for(int k = 0; k < RLWE_LENGTH / 4; k++){
				for(int j = 0; j < 4; j++){
					fscanf(fptr_a, "%lx\n", buffer_addr_temp);
					buffer_addr_temp++;
				}
				for(int j = 0; j < 4; j++){
					fscanf(fptr_b, "%lx\n", buffer_addr_temp);
					buffer_addr_temp++;
				}
			}
				
			//dma to ddr
			rc = do_dma_write(write_fd, (uint8_t*)write_buffer, buffer_size, ddr_addr, 0, slot_id);
			fail_on(rc, out, "DMA write failed on channel: %d", 0);
			ddr_addr += buffer_size;
			fclose(fptr_a);
			fclose(fptr_b);
		}
	}

    printf("Finish transferring bootstrap key to DDR\n");


    printf("Reading in input RLWE\n");
	char* path_shared = "/verif/tests/mem_init_content/top_verify/bootstrap/bk";
	//open poly a file
	snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_inputrlwe_1k_a.mem", cl_dir, path_shared);
	//printf("%s\n", file_path);	
	
	fptr_a = fopen(file_path, "r");
	if(fptr_a == NULL){
		fail_on(1, out, "Unable to open input rlwe poly a file");
	}

	//open poly b file
	snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_inputrlwe_1k_b.mem", cl_dir, path_shared);
	//printf("%s\n", file_path);	
	
	fptr_b = fopen(file_path, "r");
	if(fptr_b == NULL){
		fail_on(1, out, "Unable to open input rlwe poly b file");
	}
	
	//fill the buffer with data read from files
	uint64_t* buffer_addr_temp = write_buffer;

	for(int k = 0; k < RLWE_LENGTH / 4; k++){
		for(int j = 0; j < 4; j++){
			fscanf(fptr_a, "%lx\n", buffer_addr_temp);
			buffer_addr_temp++;
		}
		for(int j = 0; j < 4; j++){
			fscanf(fptr_b, "%lx\n", buffer_addr_temp);
			buffer_addr_temp++;
		}
	}
		
	fclose(fptr_a);
	fclose(fptr_b);
    printf("Finish reading in input RLWE\n");

	
    printf("Change input FIFO mode to RLWEMODE to transfer input\n");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_TOP_FIFO_MODE, (uint32_t)RLWEMODE);
    fail_on(rc, out, "Unable to write to the fpga !");
	ts.tv_sec = 0;
	ts.tv_nsec = 1000;
	nanosleep(&ts, NULL);

    printf("Transferring input RLWE to CL\n");
	for(int rlwe_loop_counter = 0; rlwe_loop_counter < 4; rlwe_loop_counter++){
		//dma to ddr
		rc = do_dma_write(write_fd, (uint8_t*)write_buffer, buffer_size, INPUT_FIFO_ADDR, 0, slot_id);
		fail_on(rc, out, "DMA write failed on channel: %d", 0);
	}
    printf("Finish Transferring input RLWE to CL\n");

    printf("Change input FIFO mode to BTMODE to compute\n");
    rc = fpga_pci_poke(pci_bar_handle, ADDR_TOP_FIFO_MODE, (uint32_t)BTMODE);
    fail_on(rc, out, "Unable to write to the fpga !");
	ts.tv_sec = 0;
	ts.tv_nsec = 1000;
	nanosleep(&ts, NULL);
	rc = fpga_pci_peek(pci_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
	fail_on(rc, out, "Unable to read from the fpga !");
	print_fifo_states(ocl_rd_data);

    printf("Writing four instructions to CL\n");
	for(int rlwe_loop_counter = 0; rlwe_loop_counter < 4; rlwe_loop_counter++){
		ddr_addr = DDR_ADDR;
		ddr_addr = ddr_addr & ((1ULL << 34) - 1);
    	rc = fpga_pci_poke(pci_bar_handle, ADDR_INST_IN, form_instruction(BOOTSTRAP, 0, 0, 0, (uint32_t)(ddr_addr >> 14)));
    	fail_on(rc, out, "Unable to write to the fpga !");
	}
    printf("Finish writing four instructions to CL\n");

    printf("Waiting for the output\n");
	ts.tv_sec = 2;
	ts.tv_nsec = 0;
	nanosleep(&ts, NULL);
	rc = fpga_pci_peek(pci_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
	fail_on(rc, out, "Unable to read from the fpga !");
	print_fifo_states(ocl_rd_data);

    printf("Reading in output RLWE ground truth\n");
	path_shared = "/verif/tests/mem_init_content/top_verify/bootstrap/bk";
	//open poly a file
	snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_outputrlwe_1k_a.mem", cl_dir, path_shared);
	//printf("%s\n", file_path);	
	
	fptr_a = fopen(file_path, "r");
	if(fptr_a == NULL){
		fail_on(1, out, "Unable to open output rlwe poly a file");
	}

	//open poly b file
	snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_outputrlwe_1k_b.mem", cl_dir, path_shared);
	//printf("%s\n", file_path);	
	
	fptr_b = fopen(file_path, "r");
	if(fptr_b == NULL){
		fail_on(1, out, "Unable to open output rlwe poly b file");
	}

	//fill the buffer with data read from files
	buffer_addr_temp = output_buffer;
	for(int k = 0; k < RLWE_LENGTH / 4; k++){
		for(int j = 0; j < 4; j++){
			fscanf(fptr_a, "%lx\n", buffer_addr_temp);
			buffer_addr_temp++;
		}
		for(int j = 0; j < 4; j++){
			fscanf(fptr_b, "%lx\n", buffer_addr_temp);
			buffer_addr_temp++;
		}
	}

	fclose(fptr_a);
	fclose(fptr_b);
    printf("Finish reading in output RLWE ground truth\n");

    rc = 0;
    printf("Transferring output RLWE from CL and compare to ground truth\n");
	for(int rlwe_loop_counter = 0; rlwe_loop_counter < 4; rlwe_loop_counter++){
		do{
			ts.tv_sec = 0;
			ts.tv_nsec = 1000;
			nanosleep(&ts, NULL);
			rc = fpga_pci_peek(pci_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
			fail_on(rc, out, "Unable to read from the fpga !");
			print_fifo_states(ocl_rd_data);
		}while(get_fifo_state(ocl_rd_data, RLWE_INPUT_FIFO_EMPTY));
		//dma to ddr
		rc = do_dma_read(read_fd, (uint8_t*)read_buffer, buffer_size, INPUT_FIFO_ADDR, 0, slot_id);
		fail_on(rc, out, "DMA read failed on channel: %d", 0);
		uint64_t differ;
		differ = buffer_compare((uint8_t*)read_buffer, (uint8_t*)output_buffer, buffer_size);

    	if (differ != 0) {
    	    log_error("bootstrap failed at loop: %d, with %lu bytes which differ", rlwe_loop_counter, differ);
    		rc = 1;
    	} else {
    	    log_info("bootstrap passed at loop:  %d!", rlwe_loop_counter);
    	}
	}
    printf("Finish Transferring output RLWE from CL and comparing\n");
		
out:
    /* clean up */
    if (pci_bar_handle >= 0) {
        rc = fpga_pci_detach(pci_bar_handle);
        if (rc) {
            printf("Failure while detaching from the fpga.\n");
        }
    }

    if (write_buffer != NULL) {
        free(write_buffer);
    }
    if (read_buffer != NULL) {
        free(read_buffer);
    }
    if (output_buffer != NULL) {
        free(output_buffer);
    }
#if !defined(SV_TEST)
    if (write_fd >= 0) {
        close(write_fd);
    }
    if (read_fd >= 0) {
        close(read_fd);
    }
#endif
	if(rc != 0) 
		printf("bootstrap case failed!\n");
	else
		printf("bootstrap case passed!\n");
    /* if there is an error code, exit with status 1 */
    return (rc != 0 ? 1 : 0);
}

int rlwe_mult_rgsw_test(int slot_id){
	int pf_id = FPGA_APP_PF;
	int bar_id = APP_PF_BAR0;
    int write_fd = -1;
   	int	read_fd = -1;
	int rc;

	size_t buffer_size = 16 * 1024;
	struct timespec ts;		//specify time to sleep
    char *cl_dir;
	char file_path[512];	//max file path 511 char
	FILE *fptr_a, *fptr_b;
	uint64_t ddr_addr = DDR_ADDR;	//addr to FPGA ddr

	long sz = sysconf(_SC_PAGESIZE);
	
	uint32_t ocl_rd_data;


	//setup to BAR0/OCL
    /* pci_bar_handle_t is a handler for an address space exposed by one PCI BAR on one of the PCI PFs of the FPGA */
    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

    
    /* attach to the fpga, with a pci_bar_handle out param
     * To attach to multiple slots or BARs, call this function multiple times,
     * saving the pci_bar_handle to specify which address space to interact with in
     * other API calls.
     * This function accepts the slot_id, physical function, and bar number
     */
#ifndef SV_TEST
    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);
    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);
#endif

	//allocate buffer
    uint64_t *write_buffer = aligned_alloc(sz, buffer_size);	//try aligned address, if the buffer is page aligned than the dma awlen = 0x07, arlen = 0x3f
    uint64_t *read_buffer = aligned_alloc(sz, buffer_size);
    uint64_t *output_buffer = aligned_alloc(sz, buffer_size);
    if (write_buffer == NULL || read_buffer == NULL || output_buffer == NULL) {
        rc = -ENOMEM;
        goto out;
    }

    printf("Memory has been allocated, initializing DMA and filling the buffer...\n");

#ifndef SV_TEST
    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ true);
    fail_on((rc = (read_fd < 0) ? -1 : 0), out, "unable to open read dma queue");

    write_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ false);
    fail_on((rc = (write_fd < 0) ? -1 : 0), out, "unable to open write dma queue");
#else
    setup_send_rdbuf_to_c((uint8_t*)read_buffer, buffer_size);
    printf("Starting DDR init...\n");
    init_ddr();
    printf("Done DDR init...\n");
#endif


	cl_dir = getenv("CL_DIR");
	//printf("%s", cl_dir);	

	printf("Transferring bootstrap key to DDR\n");
	for(int h = 0; h < 2; h++){
		for(int i = 0; i < DIGITG; i++){

			char* path_shared = "/verif/tests/mem_init_content/top_verify/bootstrap/bk";
			//open poly a file
			snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_inputrgsw_1k_rlwe_%0d_%0d_a.mem", cl_dir, path_shared, i, h);
			//printf("%s\n", file_path);	
			
			fptr_a = fopen(file_path, "r");
			if(fptr_a == NULL){
				fail_on(1, out, "Unable to open key poly a file, %0d, %0d", i, h);
			}

			//open poly b file
			snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_inputrgsw_1k_rlwe_%0d_%0d_b.mem", cl_dir, path_shared, i, h);
			//printf("%s\n", file_path);	
			
			fptr_b = fopen(file_path, "r");
			if(fptr_b == NULL){
				fail_on(1, out, "Unable to open key poly b file, %0d, %0d", i, h);
			}
			
			//fill the buffer with data read from files
			uint64_t* buffer_addr_temp = write_buffer;
			for(int k = 0; k < RLWE_LENGTH / 4; k++){
				for(int j = 0; j < 4; j++){
					fscanf(fptr_a, "%lx\n", buffer_addr_temp);
					buffer_addr_temp++;
				}
				for(int j = 0; j < 4; j++){
					fscanf(fptr_b, "%lx\n", buffer_addr_temp);
					buffer_addr_temp++;
				}
			}
				
			//dma to ddr
			rc = do_dma_write(write_fd, (uint8_t*)write_buffer, buffer_size, ddr_addr, 0, slot_id);
			fail_on(rc, out, "DMA write failed on channel: %d", 0);
			ddr_addr += buffer_size;
			fclose(fptr_a);
			fclose(fptr_b);
		}
	}

    printf("Finish transferring bootstrap key to DDR\n");


    printf("Reading in input RLWE\n");
	char* path_shared = "/verif/tests/mem_init_content/top_verify/bootstrap/bk";
	//open poly a file
	snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_inputrlwe_1k_a.mem", cl_dir, path_shared);
	//printf("%s\n", file_path);	
	
	fptr_a = fopen(file_path, "r");
	if(fptr_a == NULL){
		fail_on(1, out, "Unable to open input rlwe poly a file");
	}

	//open poly b file
	snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_inputrlwe_1k_b.mem", cl_dir, path_shared);
	//printf("%s\n", file_path);	
	
	fptr_b = fopen(file_path, "r");
	if(fptr_b == NULL){
		fail_on(1, out, "Unable to open input rlwe poly b file");
	}
	
	//fill the buffer with data read from files
	uint64_t* buffer_addr_temp = write_buffer;

	for(int k = 0; k < RLWE_LENGTH / 4; k++){
		for(int j = 0; j < 4; j++){
			fscanf(fptr_a, "%lx\n", buffer_addr_temp);
			buffer_addr_temp++;
		}
		for(int j = 0; j < 4; j++){
			fscanf(fptr_b, "%lx\n", buffer_addr_temp);
			buffer_addr_temp++;
		}
	}
		
	fclose(fptr_a);
	fclose(fptr_b);
    printf("Finish reading in input RLWE\n");

    printf("Transferring input RLWE to CL\n");
	for(int rlwe_loop_counter = 0; rlwe_loop_counter < 4; rlwe_loop_counter++){
		//dma to ddr
		rc = do_dma_write(write_fd, (uint8_t*)write_buffer, buffer_size, INPUT_FIFO_ADDR, 0, slot_id);
		fail_on(rc, out, "DMA write failed on channel: %d", 0);
	}
    printf("Finish Transferring input RLWE to CL\n");


    printf("Writing four instructions to CL\n");
	for(int rlwe_loop_counter = 0; rlwe_loop_counter < 4; rlwe_loop_counter++){
		ddr_addr = DDR_ADDR;
		ddr_addr = ddr_addr & ((1ULL << 34) - 1);
    	rc = fpga_pci_poke(pci_bar_handle, ADDR_INST_IN, form_instruction(RLWE_MULT_RGSW, 0, 0, 0, (uint32_t)(ddr_addr >> 14)));
    	fail_on(rc, out, "Unable to write to the fpga !");
	}
    printf("Finish writing four instructions to CL, waiting for the input RLWE to be not full\n");

	printf("Transferring 4 extra input RLWE to CL\n");
	for(int rlwe_loop_counter = 0; rlwe_loop_counter < 4; rlwe_loop_counter++){
		do{
			ts.tv_sec = 0;
			ts.tv_nsec = 1000;
			nanosleep(&ts, NULL);
			rc = fpga_pci_peek(pci_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
			fail_on(rc, out, "Unable to read from the fpga !");
			print_fifo_states(ocl_rd_data);
		}while(get_fifo_state(ocl_rd_data, RLWE_INPUT_FIFO_FULL));
		//dma to ddr
		rc = do_dma_write(write_fd, (uint8_t*)write_buffer, buffer_size, INPUT_FIFO_ADDR, 0, slot_id);
		fail_on(rc, out, "DMA write failed on channel: %d", 0);
	}
	printf("Finish Transferring 4 extra input RLWE to CL\n");
	
	printf("Writing four instructions to CL\n");
	for(int rlwe_loop_counter = 0; rlwe_loop_counter < 4; rlwe_loop_counter++){
		ddr_addr = DDR_ADDR;
		ddr_addr = ddr_addr & ((1ULL << 34) - 1);
		rc = fpga_pci_poke(pci_bar_handle, ADDR_INST_IN, form_instruction(RLWE_MULT_RGSW, 0, 0, 0, (uint32_t)(ddr_addr >> 14)));
		fail_on(rc, out, "Unable to write to the fpga !");
	}
	printf("Finish writing four instructions to CL, waiting for the output RLWE to be nonempty\n");

    printf("Reading in output RLWE ground truth\n");
	path_shared = "/verif/tests/mem_init_content/top_verify/bootstrap/bk";
	//open poly a file
	snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_outputrlwe_1k_a.mem", cl_dir, path_shared);
	//printf("%s\n", file_path);	
	
	fptr_a = fopen(file_path, "r");
	if(fptr_a == NULL){
		fail_on(1, out, "Unable to open output rlwe poly a file");
	}

	//open poly b file
	snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_outputrlwe_1k_b.mem", cl_dir, path_shared);
	//printf("%s\n", file_path);	
	
	fptr_b = fopen(file_path, "r");
	if(fptr_b == NULL){
		fail_on(1, out, "Unable to open output rlwe poly b file");
	}

	//fill the buffer with data read from files
	buffer_addr_temp = output_buffer;
	for(int k = 0; k < RLWE_LENGTH / 4; k++){
		for(int j = 0; j < 4; j++){
			fscanf(fptr_a, "%lx\n", buffer_addr_temp);
			buffer_addr_temp++;
		}
		for(int j = 0; j < 4; j++){
			fscanf(fptr_b, "%lx\n", buffer_addr_temp);
			buffer_addr_temp++;
		}
	}

	fclose(fptr_a);
	fclose(fptr_b);
    printf("Finish reading in output RLWE ground truth\n");

    rc = 0;
    printf("Transferring output RLWE from CL and compare to ground truth\n");
	for(int rlwe_loop_counter = 0; rlwe_loop_counter < 8; rlwe_loop_counter++){
		do{
			ts.tv_sec = 0;
			ts.tv_nsec = 1000;
			nanosleep(&ts, NULL);
			rc = fpga_pci_peek(pci_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
			fail_on(rc, out, "Unable to read from the fpga !");
			print_fifo_states(ocl_rd_data);
		}while(get_fifo_state(ocl_rd_data, RLWE_OUTPUT_FIFO_EMPTY));
		//dma to ddr
		rc = do_dma_read(read_fd, (uint8_t*)read_buffer, buffer_size, OUTPUT_FIFO_ADDR, 0, slot_id);
		fail_on(rc, out, "DMA read failed on channel: %d", 0);
		//printf("read out\n");
		//for(int k = 0; k < RLWE_LENGTH * 2; k++){
		//	printf("%16lx\n", *(read_buffer + k));
		//}
		uint64_t differ;
		differ = buffer_compare((uint8_t*)read_buffer, (uint8_t*)output_buffer, buffer_size);

    	if (differ != 0) {
    	    log_error("rlwe mult rgsw failed at loop: %d, with %lu bytes which differ", rlwe_loop_counter, differ);
    		rc = 1;
    	} else {
    	    log_info("rlwe mult rgsw passed at loop:  %d!", rlwe_loop_counter);
    	}
	}
    printf("Finish Transferring output RLWE from CL and comparing\n");
		
out:
    /* clean up */
    if (pci_bar_handle >= 0) {
        rc = fpga_pci_detach(pci_bar_handle);
        if (rc) {
            printf("Failure while detaching from the fpga.\n");
        }
    }

    if (write_buffer != NULL) {
        free(write_buffer);
    }
    if (read_buffer != NULL) {
        free(read_buffer);
    }
    if (output_buffer != NULL) {
        free(output_buffer);
    }
#if !defined(SV_TEST)
    if (write_fd >= 0) {
        close(write_fd);
    }
    if (read_fd >= 0) {
        close(read_fd);
    }
#endif
	if(rc != 0) 
		printf("rlwe mult rgsw case failed!\n");
	else
		printf("rlwe mult rgsw case passed!\n");
    /* if there is an error code, exit with status 1 */
    return (rc != 0 ? 1 : 0);
}

