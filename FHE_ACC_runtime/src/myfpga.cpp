#include "myfpga.h"
using namespace std;

namespace FPGA{
	static const uint16_t AMZ_PCI_VENDOR_ID = 0x1D0F; /* Amazon PCI Vendor ID */
	static const uint16_t PCI_DEVICE_ID = 0xF001;
	
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
	
//////////////////////////
//no need to change above
//////////////////////////
	
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
	    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);
	    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);
	    
		//write the config regs	
	    printf("Writing RLWE_Q\n");
	    rc = fpga_pci_poke(pci_bar_handle, ADDR_RLWE_Q, LOW_32b(Q));
	    fail_on(rc, out, "Unable to write to the fpga !");
	    rc = fpga_pci_poke(pci_bar_handle, ADDR_RLWE_Q + 4, HIGH_32b(Q));
	    fail_on(rc, out, "Unable to write to the fpga !");
	
	    printf("Writing BARRETT_M\n");
	    rc = fpga_pci_poke(pci_bar_handle, ADDR_BARRETT_M, LOW_32b(BARRETT_M));
	    fail_on(rc, out, "Unable to write to the fpga !");
	    rc = fpga_pci_poke(pci_bar_handle, ADDR_BARRETT_M + 4, HIGH_32b(BARRETT_M));
	    fail_on(rc, out, "Unable to write to the fpga !");
	
	    printf("Writing RLWE_ILEN\n");
	    rc = fpga_pci_poke(pci_bar_handle, ADDR_RLWE_ILEN, LOW_32b(iN));
	    fail_on(rc, out, "Unable to write to the fpga !");
	    rc = fpga_pci_poke(pci_bar_handle, ADDR_RLWE_ILEN + 4, HIGH_32b(iN));
	    fail_on(rc, out, "Unable to write to the fpga !");
		
		if(TOP_FIFO_MODE == BTMODE){	
	    	printf("Writing BG_MASK\n");
	    	rc = fpga_pci_poke(pci_bar_handle, ADDR_BG_MASK, LOW_32b(BG_mask));
	    	fail_on(rc, out, "Unable to write to the fpga !");
	    	rc = fpga_pci_poke(pci_bar_handle, ADDR_BG_MASK + 4, HIGH_32b(BG_mask));
	    	fail_on(rc, out, "Unable to write to the fpga !");
		} else if(TOP_FIFO_MODE == RLWEMODE) {
	    	printf("Writing Bks_R_mask\n");
	    	rc = fpga_pci_poke(pci_bar_handle, ADDR_BG_MASK, LOW_32b(Bks_R_mask));
	    	fail_on(rc, out, "Unable to write to the fpga !");
	    	rc = fpga_pci_poke(pci_bar_handle, ADDR_BG_MASK + 4, HIGH_32b(Bks_R_mask));
	    	fail_on(rc, out, "Unable to write to the fpga !");
		} else {
	    	fail_on(-1, out, "TOP_FIFO_MODE is not set!!!");
		}
	
	    printf("Writing BARRETT_K2\n");
	    rc = fpga_pci_poke(pci_bar_handle, ADDR_BARRETT_K2, BARRETT_K2);
	    fail_on(rc, out, "Unable to write to the fpga !");
	
	    printf("Writing RLWE_LEN\n");
	    rc = fpga_pci_poke(pci_bar_handle, ADDR_RLWE_LEN, (uint32_t)N);
	    fail_on(rc, out, "Unable to write to the fpga !");
	
	    printf("Writing LOG2_RLWE_LEN\n");
	    rc = fpga_pci_poke(pci_bar_handle, ADDR_LOG2_RLWE_LEN, LOG2_RLWE_LEN);
	    fail_on(rc, out, "Unable to write to the fpga !");
		
		if(TOP_FIFO_MODE == BTMODE){	
	    	printf("Writing DIGITG\n");
	    	rc = fpga_pci_poke(pci_bar_handle, ADDR_DIGITG, (uint32_t)digitG);
	    	fail_on(rc, out, "Unable to write to the fpga !");
	
	    	printf("Writing BG_WIDTH\n");
	    	rc = fpga_pci_poke(pci_bar_handle, ADDR_BG_WIDTH, (uint32_t)BGbits);
	    	fail_on(rc, out, "Unable to write to the fpga !");
		} else if(TOP_FIFO_MODE == RLWEMODE){
	    	printf("Writing DIGITG\n");
	    	rc = fpga_pci_poke(pci_bar_handle, ADDR_DIGITG, (uint32_t)digitKS_R);
	    	fail_on(rc, out, "Unable to write to the fpga !");
	
	    	printf("Writing BG_WIDTH\n");
	    	rc = fpga_pci_poke(pci_bar_handle, ADDR_BG_WIDTH, (uint32_t)Bks_R_bits);
	    	fail_on(rc, out, "Unable to write to the fpga !");
		} else {
	    	fail_on(-1, out, "TOP_FIFO_MODE is not set!!!");
		}
	
	    printf("Writing LWE_Q_MASK\n");
	    rc = fpga_pci_poke(pci_bar_handle, ADDR_LWE_Q_MASK, q - 1);
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
		rd_data = (rd_data << 32) | rd_data_lo;
	    printf("Read RLWE_Q = 0x%lx\n", rd_data);
	
	    printf("Reading BARRETT_M\n");
	    rc = fpga_pci_peek(pci_bar_handle, ADDR_BARRETT_M, &rd_data_lo);
	    fail_on(rc, out, "Unable to read from the fpga !");
	    rc = fpga_pci_peek(pci_bar_handle, ADDR_BARRETT_M + 4, &rd_data_hi);
	    fail_on(rc, out, "Unable to read from the fpga !");
		rd_data = rd_data_hi;
		rd_data = (rd_data << 32) | rd_data_lo;
	    printf("Read BARRETT_M = 0x%lx\n", rd_data);
	
	    printf("Reading RLWE_ILEN\n");
	    rc = fpga_pci_peek(pci_bar_handle, ADDR_RLWE_ILEN, &rd_data_lo);
	    fail_on(rc, out, "Unable to read from the fpga !");
	    rc = fpga_pci_peek(pci_bar_handle, ADDR_RLWE_ILEN + 4, &rd_data_hi);
	    fail_on(rc, out, "Unable to read from the fpga !");
		rd_data = rd_data_hi;
		rd_data = (rd_data << 32) | rd_data_lo;
	    printf("Read RLWE_ILEN = 0x%lx\n", rd_data);
	
	    printf("Reading BG_MASK\n");
	    rc = fpga_pci_peek(pci_bar_handle, ADDR_BG_MASK, &rd_data_lo);
	    fail_on(rc, out, "Unable to read from the fpga !");
	    rc = fpga_pci_peek(pci_bar_handle, ADDR_BG_MASK + 4, &rd_data_hi);
	    fail_on(rc, out, "Unable to read from the fpga !");
		rd_data = rd_data_hi;
		rd_data = (rd_data << 32) | rd_data_lo;
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
	    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);
	    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);
	    
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
	    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);
	    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);
	    
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
		struct timespec ts;		//specify time to sleep
		/* pci_bar_handle_t is a handler for an address space exposed by one PCI BAR on one of the PCI PFs of the FPGA */
	
	    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;
	
	    
	    /* attach to the fpga, with a pci_bar_handle out param
	     * To attach to multiple slots or BARs, call this function multiple times,
	     * saving the pci_bar_handle to specify which address space to interact with in
	     * other API calls.
	     * This function accepts the slot_id, physical function, and bar number
	     */
	    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);
	    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);
	    
		
		uint64_t rou;
	    printf("Program ROU table\n");
		for(int i = 8; i < N * 8; i += 8){
			rou = ROU_table[i / 8];
	 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)i, LOW_32b(rou));
	    	fail_on(rc, out, "Unable to write to the fpga !");
	    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(i + 4), LOW_32b(rou >> 27));
	    	fail_on(rc, out, "Unable to write to the fpga !");
		}
		//wait 1000ns	
		ts.tv_sec = 0;
		ts.tv_nsec = 1000;
		nanosleep(&ts, NULL);
	
		uint64_t irou;
	    printf("Program iROU table\n");
		for(int i = 0; i < N * 8; i += 8){
			irou = iROU_table[i / 8];
	 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(i + IROU_BASE_ADDR), LOW_32b(irou));
	    	fail_on(rc, out, "Unable to write to the fpga !");
	    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(i + 4 + IROU_BASE_ADDR), LOW_32b(irou >> 27));
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
		struct timespec ts;		//specify time to sleep
		/* pci_bar_handle_t is a handler for an address space exposed by one PCI BAR on one of the PCI PFs of the FPGA */
	
	    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;
	
	    
	    /* attach to the fpga, with a pci_bar_handle out param
	     * To attach to multiple slots or BARs, call this function multiple times,
	     * saving the pci_bar_handle to specify which address space to interact with in
	     * other API calls.
	     * This function accepts the slot_id, physical function, and bar number
	     */
	    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);
	    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);
	    
		
		uint64_t rou;
	    printf("Program ROU table\n");
		for(int i = 0; i < 1; i++){
			rou = ROU_table[i + 1];
	 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE9_BASE_ADDR + i * 8), LOW_32b(rou));
	    	fail_on(rc, out, "Unable to write to the fpga !");
	    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE9_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
	    	fail_on(rc, out, "Unable to write to the fpga !");
		}
	
		for(int i = 0; i < 2; i++){
			rou = ROU_table[i + 2];
	 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE8_BASE_ADDR + i * 8), LOW_32b(rou));
	    	fail_on(rc, out, "Unable to write to the fpga !");
	    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE8_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
	    	fail_on(rc, out, "Unable to write to the fpga !");
		}
	
		for(int i = 0; i < 4; i++){
			rou = ROU_table[i + 4];
	 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE7_BASE_ADDR + i * 8), LOW_32b(rou));
	    	fail_on(rc, out, "Unable to write to the fpga !");
	    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE7_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
	    	fail_on(rc, out, "Unable to write to the fpga !");
		}
	
		for(int i = 0; i < 8; i++){
			rou = ROU_table[i + 8];
	 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE6_BASE_ADDR + i * 8), LOW_32b(rou));
	    	fail_on(rc, out, "Unable to write to the fpga !");
	    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE6_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
	    	fail_on(rc, out, "Unable to write to the fpga !");
		}
	
		for(int i = 0; i < 16; i++){
			rou = ROU_table[i + 16];
	 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE5_BASE_ADDR + i * 8), LOW_32b(rou));
	    	fail_on(rc, out, "Unable to write to the fpga !");
	    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE5_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
	    	fail_on(rc, out, "Unable to write to the fpga !");
		}
	
		for(int i = 0; i < 32; i++){
			rou = ROU_table[i + 32];
	 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE4_BASE_ADDR + i * 8), LOW_32b(rou));
	    	fail_on(rc, out, "Unable to write to the fpga !");
	    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE4_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
	    	fail_on(rc, out, "Unable to write to the fpga !");
		}
	
		for(int i = 0; i < 64; i++){
			rou = ROU_table[i + 64];
	 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE3_BASE_ADDR + i * 8), LOW_32b(rou));
	    	fail_on(rc, out, "Unable to write to the fpga !");
	    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE3_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
	    	fail_on(rc, out, "Unable to write to the fpga !");
		}
	
		for(int i = 0; i < 128; i++){
			rou = ROU_table[i + 128];
	 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE2_BASE_ADDR + i * 8), LOW_32b(rou));
	    	fail_on(rc, out, "Unable to write to the fpga !");
	    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE2_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
	    	fail_on(rc, out, "Unable to write to the fpga !");
		}
	
		for(int i = 0; i < 256; i++){
			rou = ROU_table[i + 256];
	 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE1_BASE_ADDR + i * 8), LOW_32b(rou));
	    	fail_on(rc, out, "Unable to write to the fpga !");
	    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE1_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
	    	fail_on(rc, out, "Unable to write to the fpga !");
		}
	
		for(int i = 0; i < 512; i++){
			rou = ROU_table[i + 512];
	 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE0_BASE_ADDR + i * 8), LOW_32b(rou));
	    	fail_on(rc, out, "Unable to write to the fpga !");
	    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(ROU_STAGE0_BASE_ADDR + i * 8 + 4), LOW_32b(rou >> 27));
	    	fail_on(rc, out, "Unable to write to the fpga !");
		}
	
		//wait 1000ns	
		ts.tv_sec = 0;
		ts.tv_nsec = 1000;
		nanosleep(&ts, NULL);
	
		uint64_t irou;
	    printf("Program iROU table\n");
		for(int i = 0; i < N * 8; i += 8){
			irou = iROU_table[i / 8];
	 		rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(i + IROU_BASE_ADDR), LOW_32b(irou));
	    	fail_on(rc, out, "Unable to write to the fpga !");
	    	rc = fpga_pci_poke(pci_bar_handle, (uint64_t)(i + 4 + IROU_BASE_ADDR), LOW_32b(irou >> 27));
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

	int dma_write_bootstrap_key(const int slot_id, const RLWE::bootstrap_key &bt_key){
	    int write_fd = -1;
		int rc = 0;
	
		size_t buffer_size = N * 2 * 8;	//buffer size 
		uint64_t ddr_addr = DDR_ADDR;	//addr to FPGA ddr
	
		long sz = sysconf(_SC_PAGESIZE);

		//allocate buffer
	    uint64_t *write_buffer = (uint64_t *)aligned_alloc(sz, buffer_size);	//try aligned address, if the buffer is page aligned than the dma awlen = 0x07, arlen = 0x3f
	    if (write_buffer == NULL) {
			std::cout << "not enough memory to allocate write dma buffer" << std::endl; 
			return(-ENOMEM);
	    }
	
	    printf("Memory has been allocated, initializing DMA and filling the buffer...\n");
	
	    write_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ false);
		if(write_fd < 0){
			if(write_buffer != NULL)
				free(write_buffer);
			std::cout << "unable to open write dma queue" << std::endl;
			return(-1);	
		}
	
		std::cout << "Transferring bootstrap key to DDR" << std::endl;

		for(int i = 0; i < n; i++){
			for(uint16_t j = 0; j < digitR; j++){
				for(uint16_t k = 0; k < Br; k++){
					for(uint16_t g = 0; g < 2; g++){
						for(uint16_t h = 0; h < digitG; h++){
							//std::cout << "ddr_addr = " << ddr_addr << std::endl;
							rc = dma_write_RLWE(write_fd, bt_key.btkey[k][j][i].c_text[h][g], write_buffer, ddr_addr);
							if(rc != 0){
								std::cout << "dma write to ddr fail at i=" << i << ", j=" << j << ", k=" << k << ", g=" << g << ", h=" << h << std::endl;
								if(write_buffer != NULL){
									free(write_buffer);
								}
	    						if (write_fd >= 0) {
	    						    close(write_fd);
	    						}
								return(-1);
							}
							ddr_addr += buffer_size;
						}
					}
				}
			}
		}
		
	    if (write_buffer != NULL) {
	        free(write_buffer);
	    }
	    if (write_fd >= 0) {
	        close(write_fd);
	    }
	    /* if there is an error code, exit with status 1 */
	    return (0);
	}

	int dma_write_subs_key(const int slot_id, const application::substitute_key &subs_key){
	    int write_fd = -1;
		int rc = 0;
	
		size_t buffer_size = N * 2 * 8;	//buffer size 
		uint64_t ddr_addr = DDR_ADDR;	//addr to FPGA ddr
	
		long sz = sysconf(_SC_PAGESIZE);

		//allocate buffer
	    uint64_t *write_buffer = (uint64_t *)aligned_alloc(sz, buffer_size);	//try aligned address, if the buffer is page aligned than the dma awlen = 0x07, arlen = 0x3f
	    if (write_buffer == NULL) {
			std::cout << "not enough memory to allocate write dma buffer" << std::endl; 
			return(-ENOMEM);
	    }
	
	    printf("Memory has been allocated, initializing DMA and filling the buffer...\n");
	
	    write_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ false);
		if(write_fd < 0){
			if(write_buffer != NULL)
				free(write_buffer);
			std::cout << "unable to open write dma queue" << std::endl;
			return(-1);	
		}
	
		std::cout << "Transferring RLWE substitute key to DDR" << std::endl;

		for(uint16_t i = 0; i < digitN; i++){
			for(uint16_t j = 0; j < digitKS_R; j++){
				//std::cout << "ddr_addr = " << ddr_addr << std::endl;
				rc = dma_write_RLWE(write_fd, subs_key.subs_key[i].RLWE_kskey[j], write_buffer, ddr_addr);
				if(rc != 0){
					std::cout << "dma write to ddr fail at i=" << i << ", j=" << j << std::endl;
					if(write_buffer != NULL){
						free(write_buffer);
					}
					if (write_fd >= 0) {
					    close(write_fd);
					}
					return(-1);
				}
				ddr_addr += buffer_size;
			}
		}
		
	    if (write_buffer != NULL) {
	        free(write_buffer);
	    }
	    if (write_fd >= 0) {
	        close(write_fd);
	    }
	    /* if there is an error code, exit with status 1 */
	    return (0);
	}

	int dma_write_RGSW_enc_sk(const int slot_id, const RLWE::RGSW_ciphertext &enc_sec){
	    int write_fd = -1;
		int rc = 0;
	
		size_t buffer_size = N * 2 * 8;	//buffer size 
		uint64_t ddr_addr = RGSW_ENC_SK_ADDR;	//addr to FPGA ddr
	
		long sz = sysconf(_SC_PAGESIZE);

		//allocate buffer
	    uint64_t *write_buffer = (uint64_t *)aligned_alloc(sz, buffer_size);	//try aligned address, if the buffer is page aligned than the dma awlen = 0x07, arlen = 0x3f
	    if (write_buffer == NULL) {
			std::cout << "not enough memory to allocate write dma buffer" << std::endl; 
			return(-ENOMEM);
	    }
	
	    printf("Memory has been allocated, initializing DMA and filling the buffer...\n");
	
	    write_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ false);
		if(write_fd < 0){
			if(write_buffer != NULL)
				free(write_buffer);
			std::cout << "unable to open write dma queue" << std::endl;
			return(-1);	
		}
	
		std::cout << "Transferring RGSW encrypted secret key to DDR" << std::endl;

		for(uint16_t i = 0; i < 2; i++){
			for(uint16_t j = 0; j < digitG; j++){
				//std::cout << "ddr_addr = " << ddr_addr << std::endl;
				rc = dma_write_RLWE(write_fd, enc_sec.c_text[j][i], write_buffer, ddr_addr);
				if(rc != 0){
					std::cout << "dma write to ddr fail at i=" << i << ", j=" << j << std::endl;
					if(write_buffer != NULL){
						free(write_buffer);
					}
					if (write_fd >= 0) {
					    close(write_fd);
					}
					return(-1);
				}
				ddr_addr += buffer_size;
			}
		}
		
	    if (write_buffer != NULL) {
	        free(write_buffer);
	    }
	    if (write_fd >= 0) {
	        close(write_fd);
	    }
	    /* if there is an error code, exit with status 1 */
	    return (0);
	}



	int dma_read_compare_bootstrap_key(const int slot_id, const RLWE::bootstrap_key &bt_key){
	   	int	read_fd = -1;
		int rc;
	
		size_t buffer_size = N * 2 * 8;
		//struct timespec ts;		//specify time to sleep

		uint64_t ddr_addr = DDR_ADDR;	//addr to FPGA ddr
	
		long sz = sysconf(_SC_PAGESIZE);

		//allocate buffer
	    uint64_t *read_buffer = (uint64_t *) aligned_alloc(sz, buffer_size);
	    if (read_buffer == NULL) {
			std::cout << "not enough memory to allocate read dma buffer" << std::endl; 
			return(-ENOMEM);
	    }
	
	    printf("Memory has been allocated, initializing DMA and filling the buffer...\n");
	
	    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ true);
		if(read_fd < 0){
	    	if (read_buffer != NULL) {
	    		free(read_buffer);
			}
			std::cout << "unable to open read dma queue" << std::endl;
			return(-1);	
		}

		std::cout << "Transferring bootstrap key from DDR" << std::endl;

		for(int i = 0; i < n; i++){
			for(uint16_t j = 0; j < digitR; j++){
				for(uint16_t k = 0; k < Br; k++){
					for(uint16_t g = 0; g < 2; g++){
						for(uint16_t h = 0; h < digitG; h++){
							RLWE::RLWE_ciphertext temp_c;
							//std::cout << "ddr_addr = " << ddr_addr << std::endl;

							temp_c = dma_read_RLWE(read_fd, &rc, read_buffer, ddr_addr);
							if(rc != 0){
								std::cout << "dma read from ddr fail at i=" << i << ", j=" << j << ", k=" << k << ", g=" << g << ", h=" << h << std::endl;
								if(read_buffer != NULL){
									free(read_buffer);
								}
	    						if (read_fd >= 0) {
	    						    close(read_fd);
	    						}
								return(-1);
							}

							uint64_t diffs;
						   	diffs	= buffer_compare((uint8_t*)temp_c.a.data(), (uint8_t*)bt_key.btkey[k][j][i].c_text[h][g].a.data(), (size_t)(N * 8));
						   	diffs	+= buffer_compare((uint8_t*)temp_c.b.data(), (uint8_t*)bt_key.btkey[k][j][i].c_text[h][g].b.data(), (size_t)(N * 8));
							if(diffs != 0){
								std::cout << "bootstrap key read back not equal to ground truth at i=" << i << ", j=" << j << ", k=" << k << ", g=" << g << ", h=" << h << std::endl;
								if(read_buffer != NULL){
									free(read_buffer);
								}
	    						if (read_fd >= 0) {
	    						    close(read_fd);
	    						}
								return(-1);
							}
							ddr_addr += buffer_size;
						}
					}
				}
			}
		}
		
	    if (read_buffer != NULL) {
	        free(read_buffer);
	    }
	    if (read_fd >= 0) {
	        close(read_fd);
	    }
	    return (0);
	}


	int dma_read_compare_subs_key(const int slot_id, const application::substitute_key &subs_key){
	   	int	read_fd = -1;
		int rc;
	
		size_t buffer_size = N * 2 * 8;
		//struct timespec ts;		//specify time to sleep

		uint64_t ddr_addr = DDR_ADDR;	//addr to FPGA ddr
	
		long sz = sysconf(_SC_PAGESIZE);

		//allocate buffer
	    uint64_t *read_buffer = (uint64_t *) aligned_alloc(sz, buffer_size);
	    if (read_buffer == NULL) {
			std::cout << "not enough memory to allocate read dma buffer" << std::endl; 
			return(-ENOMEM);
	    }
	
	    printf("Memory has been allocated, initializing DMA and filling the buffer...\n");
	
	    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ true);
		if(read_fd < 0){
			if(read_buffer != NULL)
				free(read_buffer);
			std::cout << "unable to open read dma queue" << std::endl;
			return(-1);	
		}

		std::cout << "Transferring RLWE substitute key from DDR" << std::endl;

		for(uint16_t i = 0; i < digitN; i++){
			for(uint16_t j = 0; j < digitKS_R; j++){
				RLWE::RLWE_ciphertext temp_c;
				//std::cout << "ddr_addr = " << ddr_addr << std::endl;

				temp_c = dma_read_RLWE(read_fd, &rc, read_buffer, ddr_addr);
				if(rc != 0){
					std::cout << "dma read from ddr fail at i=" << i << ", j=" << j << std::endl;
					if(read_buffer != NULL){
						free(read_buffer);
					}
	    			if (read_fd >= 0) {
	    			    close(read_fd);
	    			}
					return(-1);
				}

				uint64_t diffs;
				diffs	= buffer_compare((uint8_t*)temp_c.a.data(), (uint8_t*)subs_key.subs_key[i].RLWE_kskey[j].a.data(), (size_t)(N * 8));
				diffs	+= buffer_compare((uint8_t*)temp_c.b.data(), (uint8_t*)subs_key.subs_key[i].RLWE_kskey[j].b.data(), (size_t)(N * 8));
				if(diffs != 0){
					std::cout << "bootstrap key read back not equal to ground truth at i=" << i << ", j=" << j << std::endl;
					if(read_buffer != NULL){
						free(read_buffer);
					}
	    			if (read_fd >= 0) {
	    			    close(read_fd);
	    			}
					return(-1);
				}
				ddr_addr += buffer_size;
			}
		}
		
	    if (read_buffer != NULL) {
	        free(read_buffer);
	    }
	    if (read_fd >= 0) {
	        close(read_fd);
	    }
	    /* if there is an error code, exit with status 1 */
	    return (0);
	}


	int dma_read_compare_RGSW_enc_sk(const int slot_id, const RLWE::RGSW_ciphertext &enc_sec){
	   	int	read_fd = -1;
		int rc;
	
		size_t buffer_size = N * 2 * 8;
		//struct timespec ts;		//specify time to sleep

		uint64_t ddr_addr = RGSW_ENC_SK_ADDR;	//addr to FPGA ddr
	
		long sz = sysconf(_SC_PAGESIZE);

		//allocate buffer
	    uint64_t *read_buffer = (uint64_t *) aligned_alloc(sz, buffer_size);
	    if (read_buffer == NULL) {
			std::cout << "not enough memory to allocate read dma buffer" << std::endl; 
			return(-ENOMEM);
	    }
	
	    printf("Memory has been allocated, initializing DMA and filling the buffer...\n");
	
	    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ true);
		if(read_fd < 0){
			if(read_buffer != NULL)
				free(read_buffer);
			std::cout << "unable to open read dma queue" << std::endl;
			return(-1);	
		}

		std::cout << "Transferring RGSW enc sk from DDR" << std::endl;

		for(uint16_t g = 0; g < 2; g++){
			for(uint16_t h = 0; h < digitG; h++){
				RLWE::RLWE_ciphertext temp_c;
				//std::cout << "ddr_addr = " << ddr_addr << std::endl;

				temp_c = dma_read_RLWE(read_fd, &rc, read_buffer, ddr_addr);
				if(rc != 0){
					std::cout << "dma read from ddr fail at" << " g=" << g << ", h=" << h << std::endl;
					if(read_buffer != NULL){
						free(read_buffer);
					}
	    			if (read_fd >= 0) {
	    			    close(read_fd);
	    			}
					return(-1);
				}

				uint64_t diffs;
			   	diffs	= buffer_compare((uint8_t*)temp_c.a.data(), (uint8_t*)enc_sec.c_text[h][g].a.data(), (size_t)(N * 8));
			   	diffs	+= buffer_compare((uint8_t*)temp_c.b.data(), (uint8_t*)enc_sec.c_text[h][g].b.data(), (size_t)(N * 8));
				if(diffs != 0){
					std::cout << "RGSW ENC SK read back not equal to ground truth at" << " g=" << g << ", h=" << h << std::endl;
					if(read_buffer != NULL){
						free(read_buffer);
					}
	    			if (read_fd >= 0) {
	    			    close(read_fd);
	    			}
					return(-1);
				}
				ddr_addr += buffer_size;
			}
		}
		
	    if (read_buffer != NULL) {
	        free(read_buffer);
	    }
	    if (read_fd >= 0) {
	        close(read_fd);
	    }
	    /* if there is an error code, exit with status 1 */
	    return (0);
	}


	LWE::LWE_ciphertext fpga_eval_bootstrap_x1(const LWE::LWE_ciphertext &c1, const LWE::LWE_ciphertext &c2, const LWE::keyswitch_key &kskey, const GATES gate, const pci_bar_handle_t ocl_bar_handle, int *rc, int read_fd){

		uint64_t ddr_addr = DDR_ADDR;
		uint64_t RGSW_size = 2 * digitG * N * 2 * 8;
		uint32_t ocl_rd_data;
		long sz = sysconf(_SC_PAGESIZE);
		uint64_t buffer_size = N * 2 * 8;
		uint64_t *read_buffer = (uint64_t * ) aligned_alloc(sz, buffer_size);
	    if (read_buffer == NULL) {
			std::cout << "not enough memory to allocate read dma buffer" << std::endl; 
			*rc = -ENOMEM;
			return(LWE::LWE_ciphertext());
	    }
		if(c1 == c2){
			cout << "Please only use independent ciphertexts!!!" << endl;
			if(read_buffer != NULL)
				free(read_buffer);
			*rc = -1;
			return(LWE::LWE_ciphertext());
		}
		//evaluate the NAND 
		//auto start = std::chrono::high_resolution_clock::now();
		LWE::LWE_ciphertext c_text = LWE::LWE_evaluate(c1, c2, gate);	// hold the evaluation
	
		//auto after_eval = std::chrono::high_resolution_clock::now();
		//std::cout << "evaluate takes: " << std::chrono::duration_cast<std::chrono::milliseconds>(after_eval - start).count() << " ms" << endl;
		
		//start bootstrapping
		//1. accumulate
		for(int64_t i = 0; i < n; i++){
			ciphertext_t nega = (q - c_text.a[i]) % q;	//addtive inverse of "a" equals to modulo - a
			for(uint64_t j = 0; j < digitR; j++){
				ciphertext_t residu = nega % Br;
					//std::cout << "at index " << i << " Br powr " << j << " Br " << residu<< std::endl;
					if(i == 0 && j == 0){
						ddr_addr = (((uint64_t)i * (uint64_t)digitR + (uint64_t)j) * (uint64_t)Br + (uint64_t)residu) * (uint64_t)RGSW_size;
						ddr_addr = ddr_addr & ((1ULL << 31) - 1);
	    				*rc = fpga_pci_poke(ocl_bar_handle, ADDR_INST_IN, form_instruction(BOOTSTRAP_INIT, (uint32_t)gate, c_text.b, 0, (uint32_t)(ddr_addr >> 14)));
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							std::cout << "ocl poke failed!!!" << std::endl;
							return(LWE::LWE_ciphertext());
						}
					} else {
						if(residu > 0){	//actually != 0 is good enough
							ddr_addr = (((uint64_t)i * (uint64_t)digitR + (uint64_t)j) * (uint64_t)Br + (uint64_t)residu) * (uint64_t)RGSW_size;
							ddr_addr = ddr_addr & ((1ULL << 34) - 1);
	    					*rc = fpga_pci_poke(ocl_bar_handle, ADDR_INST_IN, form_instruction(BOOTSTRAP, 0, 0, 0, (uint32_t)(ddr_addr >> 14)));
							if(*rc != 0){
								if(read_buffer != NULL)
									free(read_buffer);
								std::cout << "ocl poke failed!!!" << std::endl;
								return(LWE::LWE_ciphertext());
							}
						}
					}
					do{
						*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							std::cout << "ocl peek failed!!!" << std::endl;
							return(LWE::LWE_ciphertext());
						}
						//print_fifo_states(ocl_rd_data);
					}while(get_fifo_state(ocl_rd_data, ROB_FULL) || get_fifo_state(ocl_rd_data, KEY_LOAD_FIFO_FULL));
				nega /= Br;
			}
		}
		//wait for the ROB to be empty 
		//std::cout << "Wait for ROB empty" << std::endl;
		do{
			*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
			if(*rc != 0){
				if(read_buffer != NULL)
					free(read_buffer);
				std::cout << "ocl peek failed!!!" << std::endl;
				return(LWE::LWE_ciphertext());
			}
			//print_fifo_states(ocl_rd_data);
		}while(!get_fifo_state(ocl_rd_data, ROB_EMPTY));
		
		//wait for input fifo not empty
		//std::cout << "Wait for input fifo to be nonempty" << std::endl;
		do{
			*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
			if(*rc != 0){
				if(read_buffer != NULL)
					free(read_buffer);
				std::cout << "ocl peek failed!!!" << std::endl;
				return(LWE::LWE_ciphertext());
			}
			//print_fifo_states(ocl_rd_data);
		}while(get_fifo_state(ocl_rd_data, RLWE_INPUT_FIFO_EMPTY));

		
		RLWE::RLWE_ciphertext acc = dma_read_RLWE(read_fd, rc, read_buffer, INPUT_FIFO_ADDR);
		if(*rc != 0){
			if(read_buffer != NULL)
				free(read_buffer);
			std::cout << "DMA read failed!!!" << std::endl;
			return(LWE::LWE_ciphertext());
		}

		//auto after_acc = std::chrono::high_resolution_clock::now();
		//std::cout << "acc takes: " << std::chrono::duration_cast<std::chrono::milliseconds>(after_acc - after_init).count() << " ms" << endl;

		//2.transfer acc to LWE ciphertext_t, key switch
		//in the PALISADE, the Q/8 is added to the coefficient of acc.b[0]
		//I incorporate it into the key switch function
		LWE::LWE_ciphertext lwe_modQ = LWE::LWE_keyswitch(acc, kskey);

		//auto after_key_switch = std::chrono::high_resolution_clock::now();
		//std::cout << "key switch takes: " << std::chrono::duration_cast<std::chrono::milliseconds>(after_key_switch - after_acc).count() << " ms" << endl;

		//3.mod switch from mod Q to mod q
		LWE::LWE_ciphertext result = LWE::LWE_modswitch(lwe_modQ);

		//auto after_mod_switch = std::chrono::high_resolution_clock::now();
		//std::cout << "mod switch takes: " << std::chrono::duration_cast<std::chrono::milliseconds>(after_mod_switch - after_key_switch).count() << " ms" << endl;
		if(read_buffer != NULL)
			free(read_buffer);
		return(result);
	}


	std::vector<LWE::LWE_ciphertext> fpga_eval_bootstrap_x4(const std::vector<LWE::LWE_ciphertext> &c1, const std::vector<LWE::LWE_ciphertext> &c2, const LWE::keyswitch_key &kskey, const std::vector<GATES> gate, const pci_bar_handle_t ocl_bar_handle, int *rc, int read_fd){

		uint64_t ddr_addr = DDR_ADDR;
		uint64_t RGSW_size = 2 * digitG * N * 2 * 8;
		//struct timespec ts;	//specify time to sleep
		uint32_t ocl_rd_data;
		long sz = sysconf(_SC_PAGESIZE);
		uint64_t buffer_size = N * 2 * 8;
		std::vector<LWE::LWE_ciphertext> c_text(4);

		if(c1.size() != 4 || c2.size() != 4){
			cout << "Input vectors must be size of 4!!!" << endl;
			*rc = -1;
			return(c_text);
		}

		for(int i = 0; i < 4; i++){
			if(c1[i] == c2[i]){
				cout << "Please only use independent ciphertexts!!!" << endl;
				*rc = -1;
				return(c_text);
			}
		}

		uint64_t *read_buffer = (uint64_t * ) aligned_alloc(sz, buffer_size);
	    if (read_buffer == NULL) {
			std::cout << "not enough memory to allocate read dma buffer" << std::endl; 
			*rc = -ENOMEM;
			return(c_text);
	    }
		
		
		//evaluate the NAND 
		//auto start = std::chrono::high_resolution_clock::now();
		//std::cout << "LWE eval" << std::endl; 
		for(int i = 0; i < 4; i++){
			c_text[i] = LWE::LWE_evaluate(c1[i], c2[i], gate[i]);	// hold the evaluation
		}
	
		//auto after_eval = std::chrono::high_resolution_clock::now();
		//std::cout << "evaluate takes: " << std::chrono::duration_cast<std::chrono::milliseconds>(after_eval - start).count() << " ms" << endl;
		
		//start bootstrapping, initialization included 
		//1. accumulate
		uint64_t ddr_addr_p1;
		uint64_t ddr_addr_p2;
		std::vector<ciphertext_t> nega(4);
		auto bf_bootstrap = std::chrono::high_resolution_clock::now();
		for(int64_t i = 0; i < n; i++){
			//ciphertext_t nega = mod_pow2(-((signed_ciphertext_t)c_text.a[i]), q);
			for(int k = 0; k < 4; k++){
				nega[k] = (q - c_text[k].a[i]) % q;	//addtive inverse of "a" equals to modulo - a
			}
			ddr_addr_p1 = (uint64_t)i * (uint64_t)digitR;
			for(uint64_t j = 0; j < digitR; j++){
				ddr_addr_p2 = (ddr_addr_p1 + (uint64_t)j) * (uint64_t)Br;
				for(int k = 0; k < 4; k++){
					ciphertext_t residu = nega[k] % Br;
					//std::cout << "at index " << i << " Br powr " << j << " Br " << residu<< std::endl;

					if(i == 0 && j == 0){
						ddr_addr = (ddr_addr_p2 + (uint64_t)residu) * (uint64_t)RGSW_size;
						ddr_addr = ddr_addr & ((1ULL << 31) - 1);
	    				*rc = fpga_pci_poke(ocl_bar_handle, ADDR_INST_IN, form_instruction(BOOTSTRAP_INIT, (uint32_t)gate[k], c_text[k].b, 0, (uint32_t)(ddr_addr >> 14)));
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							std::cout << "ocl poke failed!!!" << std::endl;
							return(c_text);
						}
					} else {
						ddr_addr = (ddr_addr_p2 + (uint64_t)residu) * (uint64_t)RGSW_size;
						ddr_addr = ddr_addr & ((1ULL << 34) - 1);
	    				*rc = fpga_pci_poke(ocl_bar_handle, ADDR_INST_IN, form_instruction(BOOTSTRAP, 0, 0, 0, (uint32_t)(ddr_addr >> 14)));
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							std::cout << "ocl poke failed!!!" << std::endl;
							return(c_text);
						}
					}
					do{
						*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							std::cout << "ocl peek failed!!!" << std::endl;
							return(c_text);
						}
						//print_fifo_states(ocl_rd_data);
					}while(get_fifo_state(ocl_rd_data, ROB_FULL) || get_fifo_state(ocl_rd_data, KEY_LOAD_FIFO_FULL));
					nega[k] /= Br;
				}
			}
		}

		auto af_bootstrap = std::chrono::high_resolution_clock::now();
		std::cout << "bt takes: " << std::chrono::duration_cast<std::chrono::microseconds>(af_bootstrap - bf_bootstrap).count() << " us" << endl;
		//wait for input fifo not empty
		//std::cout << "Wait for input fifo not empty" << std::endl;
		do{
			*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
			if(*rc != 0){
				if(read_buffer != NULL)
					free(read_buffer);
				std::cout << "ocl peek failed!!!" << std::endl;
				return(c_text);
			}
			//print_fifo_states(ocl_rd_data);
		}while(get_fifo_state(ocl_rd_data, RLWE_INPUT_FIFO_EMPTY));

		
		std::vector<RLWE::RLWE_ciphertext> acc(4);

		auto bf_stream = std::chrono::high_resolution_clock::now();
		//std::cout << "Read from input fifo" << std::endl;
		for(int i = 0; i < 4; i++){
			//std::cout << "Read from input fifo " << i << std::endl;
			acc[i] = dma_read_RLWE(read_fd, rc, read_buffer, INPUT_FIFO_ADDR);
			if(*rc != 0){
				if(read_buffer != NULL)
					free(read_buffer);
				std::cout << "DMA read failed!!!" << std::endl;
				return(c_text);
			}
		}
		auto af_stream = std::chrono::high_resolution_clock::now();
		std::cout << "stream takes: " << std::chrono::duration_cast<std::chrono::microseconds>(af_stream - bf_stream).count() << " us" << endl;

		auto bf_postproc = std::chrono::high_resolution_clock::now();
		for(int i = 0; i < 4; i++){
			LWE::LWE_ciphertext lwe_modQ = LWE::LWE_keyswitch(acc[i], kskey);
			c_text[i] = LWE::LWE_modswitch(lwe_modQ);
		}
		auto af_postproc = std::chrono::high_resolution_clock::now();
		std::cout << "post process takes: " << std::chrono::duration_cast<std::chrono::microseconds>(af_postproc - bf_postproc).count() << " us" << endl;

		if(read_buffer != NULL)
			free(read_buffer);
		return(c_text);
	}


	std::vector<LWE::LWE_ciphertext> fpga_eval_bootstrap_x8(const std::vector<LWE::LWE_ciphertext> &c1, const std::vector<LWE::LWE_ciphertext> &c2, const LWE::keyswitch_key &kskey, const std::vector<GATES> gate, const pci_bar_handle_t ocl_bar_handle, int *rc, int read_fd){

		uint64_t ddr_addr = DDR_ADDR;
		uint64_t RGSW_size = 2 * digitG * N * 2 * 8;
		uint32_t ocl_rd_data;
		long sz = sysconf(_SC_PAGESIZE);
		uint64_t buffer_size = N * 2 * 8;
		std::vector<LWE::LWE_ciphertext> c_text(8);

		if(c1.size() != 8 || c2.size() != 8){
			cout << "Input vectors must be size of 4!!!" << endl;
			*rc = -1;
			return(c_text);
		}

		for(int i = 0; i < 8; i++){
			if(c1[i] == c2[i]){
				cout << "Please only use independent ciphertexts!!!" << endl;
				*rc = -1;
				return(c_text);
			}
		}

		uint64_t *read_buffer = (uint64_t * ) aligned_alloc(sz, buffer_size);
	    if (read_buffer == NULL) {
			std::cout << "not enough memory to allocate read dma buffer" << std::endl; 
			*rc = -ENOMEM;
			return(c_text);
	    }
		
		
		//evaluate the NAND 
		//auto start = std::chrono::high_resolution_clock::now();
		//std::cout << "LWE eval" << std::endl; 
		for(int i = 0; i < 8; i++){
			c_text[i] = LWE::LWE_evaluate(c1[i], c2[i], gate[i]);	// hold the evaluation
		}
	
		//auto after_eval = std::chrono::high_resolution_clock::now();
		//std::cout << "evaluate takes: " << std::chrono::duration_cast<std::chrono::milliseconds>(after_eval - start).count() << " ms" << endl;
		
		//start bootstrapping, initialization included 
		//1. accumulate
		uint64_t ddr_addr_p1;
		uint64_t ddr_addr_p2;
		std::vector<ciphertext_t> nega(8);
		auto bf_bootstrap = std::chrono::high_resolution_clock::now();
		for(int64_t i = 0; i < n; i++){
			//ciphertext_t nega = mod_pow2(-((signed_ciphertext_t)c_text.a[i]), q);
			for(int k = 0; k < 8; k++){
				nega[k] = (q - c_text[k].a[i]) % q;	//addtive inverse of "a" equals to modulo - a
			}
			ddr_addr_p1 = (uint64_t)i * (uint64_t)digitR;
			for(uint64_t j = 0; j < digitR; j++){
				ddr_addr_p2 = (ddr_addr_p1 + (uint64_t)j) * (uint64_t)Br;
				for(int k = 0; k < 8; k++){
					ciphertext_t residu = nega[k] % Br;
					//std::cout << "at index " << i << " Br powr " << j << " Br " << residu << " k " << k << std::endl;

					if(i == 0 && j == 0){
						ddr_addr = (ddr_addr_p2 + (uint64_t)residu) * (uint64_t)RGSW_size;
						//ddr_addr = ddr_addr & ((1ULL << 31) - 1);
	    				*rc = fpga_pci_poke(ocl_bar_handle, ADDR_INST_IN, form_instruction(BOOTSTRAP_INIT, (uint32_t)gate[k], c_text[k].b, 0, (uint32_t)(ddr_addr >> 14)));
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							std::cout << "ocl poke failed!!!" << std::endl;
							return(c_text);
						}
					} else {
						ddr_addr = (ddr_addr_p2 + (uint64_t)residu) * (uint64_t)RGSW_size;
						//ddr_addr = ddr_addr & ((1ULL << 34) - 1);
	    				*rc = fpga_pci_poke(ocl_bar_handle, ADDR_INST_IN, form_instruction(BOOTSTRAP, 0, 0, 0, (uint32_t)(ddr_addr >> 14)));
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							std::cout << "ocl poke failed!!!" << std::endl;
							return(c_text);
						}
					}

					do{
						*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							std::cout << "ocl peek failed!!!" << std::endl;
							return(c_text);
						}
						//print_fifo_states(ocl_rd_data);
					}while(get_fifo_state(ocl_rd_data, ROB_FULL) || get_fifo_state(ocl_rd_data, KEY_LOAD_FIFO_FULL));
					nega[k] /= Br;
				}
			}
		}
		auto af_bootstrap = std::chrono::high_resolution_clock::now();
		std::cout << "bt takes: " << std::chrono::duration_cast<std::chrono::microseconds>(af_bootstrap - bf_bootstrap).count() << " us" << endl;

		std::vector<RLWE::RLWE_ciphertext> acc(8);
		
		auto bf_stream = std::chrono::high_resolution_clock::now();
		//std::cout << "Read from input fifo" << std::endl;
		for(int i = 0; i < 8; i++){
			//std::cout << "Read from input fifo " << i << std::endl;
			acc[i] = dma_read_RLWE(read_fd, rc, read_buffer, INPUT_FIFO_ADDR);
			if(*rc != 0){
				if(read_buffer != NULL)
					free(read_buffer);
				std::cout << "DMA read failed!!!" << std::endl;
				return(c_text);
			}
		}

		auto af_stream = std::chrono::high_resolution_clock::now();
		std::cout << "stream takes: " << std::chrono::duration_cast<std::chrono::microseconds>(af_stream - bf_stream).count() << " us" << endl;
		
		for(int i = 0; i < 8; i++){
			LWE::LWE_ciphertext lwe_modQ = LWE::LWE_keyswitch(acc[i], kskey);
			c_text[i] = LWE::LWE_modswitch(lwe_modQ);
		}

		if(read_buffer != NULL)
			free(read_buffer);
		return(c_text);
	}

	std::vector<LWE::LWE_ciphertext> fpga_eval_bootstrap_x12(const std::vector<LWE::LWE_ciphertext> &c1, const std::vector<LWE::LWE_ciphertext> &c2, const LWE::keyswitch_key &kskey, const std::vector<GATES> gate, const pci_bar_handle_t ocl_bar_handle, int *rc, int read_fd){

		uint64_t ddr_addr = DDR_ADDR;
		uint64_t RGSW_size = 2 * digitG * N * 2 * 8;
		uint32_t ocl_rd_data;
		long sz = sysconf(_SC_PAGESIZE);
		uint64_t buffer_size = N * 2 * 8;
		std::vector<LWE::LWE_ciphertext> c_text(12);

		if(c1.size() != 12 || c2.size() != 12){
			cout << "Input vectors must be size of 12!!!" << endl;
			*rc = -1;
			return(c_text);
		}

		for(int i = 0; i < 12; i++){
			if(c1[i] == c2[i]){
				cout << "Please only use independent ciphertexts!!!" << endl;
				*rc = -1;
				return(c_text);
			}
		}

		uint64_t *read_buffer = (uint64_t * ) aligned_alloc(sz, buffer_size);
	    if (read_buffer == NULL) {
			std::cout << "not enough memory to allocate read dma buffer" << std::endl; 
			*rc = -ENOMEM;
			return(c_text);
	    }
		
		
		//evaluate the NAND 
		auto start = std::chrono::high_resolution_clock::now();
		//std::cout << "LWE eval" << std::endl; 
		for(int i = 0; i < 12; i++){
			c_text[i] = LWE::LWE_evaluate(c1[i], c2[i], gate[i]);	// hold the evaluation
		}
	
		auto after_eval = std::chrono::high_resolution_clock::now();
		std::cout << "evaluate takes: " << std::chrono::duration_cast<std::chrono::microseconds>(after_eval - start).count() << " us" << endl;
		
		//start bootstrapping, initialization included 
		//1. accumulate
		uint64_t ddr_addr_p1;
		uint64_t ddr_addr_p2;
		std::vector<ciphertext_t> nega(12);
		auto bf_bootstrap = std::chrono::high_resolution_clock::now();
		for(int64_t i = 0; i < n; i++){
			for(int k = 0; k < 12; k++){
				nega[k] = (q - c_text[k].a[i]) % q;	//addtive inverse of "a" equals to modulo - a
			}
			ddr_addr_p1 = (uint64_t)i * (uint64_t)digitR;
			for(uint64_t j = 0; j < digitR; j++){
				ddr_addr_p2 = (ddr_addr_p1 + (uint64_t)j) * (uint64_t)Br;
				for(int k = 0; k < 12; k++){
					ciphertext_t residu = nega[k] % Br;
					//std::cout << "at index " << i << " Br powr " << j << " Br " << residu << " k " << k << std::endl;

					if(i == 0 && j == 0){
						ddr_addr = (ddr_addr_p2 + (uint64_t)residu) * (uint64_t)RGSW_size;
						//ddr_addr = ddr_addr & ((1ULL << 31) - 1);
	    				*rc = fpga_pci_poke(ocl_bar_handle, ADDR_INST_IN, form_instruction(BOOTSTRAP_INIT, (uint32_t)gate[k], c_text[k].b, 0, (uint32_t)(ddr_addr >> 14)));
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							std::cout << "ocl poke failed!!!" << std::endl;
							return(c_text);
						}
					} else {
						ddr_addr = (ddr_addr_p2 + (uint64_t)residu) * (uint64_t)RGSW_size;
						//ddr_addr = ddr_addr & ((1ULL << 34) - 1);
	    				*rc = fpga_pci_poke(ocl_bar_handle, ADDR_INST_IN, form_instruction(BOOTSTRAP, 0, 0, 0, (uint32_t)(ddr_addr >> 14)));
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							std::cout << "ocl poke failed!!!" << std::endl;
							return(c_text);
						}
					}

					do{
						*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							std::cout << "ocl peek failed!!!" << std::endl;
							return(c_text);
						}
						//print_fifo_states(ocl_rd_data);
					}while(get_fifo_state(ocl_rd_data, ROB_FULL) || get_fifo_state(ocl_rd_data, KEY_LOAD_FIFO_FULL));
					nega[k] /= Br;
				}
			}
		}

		auto af_bootstrap = std::chrono::high_resolution_clock::now();
		std::cout << "bt takes: " << std::chrono::duration_cast<std::chrono::microseconds>(af_bootstrap - bf_bootstrap).count() << " us" << endl;


		//seems that the input bandwidth is not fast enough, so there is no need to wait for the input FIFO to be not empty
		
		std::vector<RLWE::RLWE_ciphertext> acc(12);

		auto bf_stream = std::chrono::high_resolution_clock::now();
		//std::cout << "Read from input fifo" << std::endl;
		for(int i = 0; i < 12; i++){
			//std::cout << "Read from input fifo " << i << std::endl;
			acc[i] = dma_read_RLWE(read_fd, rc, read_buffer, INPUT_FIFO_ADDR);
			if(*rc != 0){
				if(read_buffer != NULL)
					free(read_buffer);
				std::cout << "DMA read failed!!!" << std::endl;
				return(c_text);
			}
		}

		auto af_stream = std::chrono::high_resolution_clock::now();
		std::cout << "stream takes: " << std::chrono::duration_cast<std::chrono::microseconds>(af_stream - bf_stream).count() << " us" << endl;

		// post process, key switch, mod switch
		auto bf_postproc = std::chrono::high_resolution_clock::now();
		for(int i = 0; i < 12; i++){
			LWE::LWE_ciphertext lwe_modQ = LWE::LWE_keyswitch(acc[i], kskey);
			c_text[i] = LWE::LWE_modswitch(lwe_modQ);
		}
		auto af_postproc = std::chrono::high_resolution_clock::now();
		std::cout << "post process takes: " << std::chrono::duration_cast<std::chrono::microseconds>(af_postproc - bf_postproc).count() << " us" << endl;

		if(read_buffer != NULL)
			free(read_buffer);
		return(c_text);
	}

	std::vector<LWE::LWE_ciphertext> fpga_eval_bootstrap_x16(const std::vector<LWE::LWE_ciphertext> &c1, const std::vector<LWE::LWE_ciphertext> &c2, const LWE::keyswitch_key &kskey, const std::vector<GATES> gate, const pci_bar_handle_t ocl_bar_handle, int *rc, int read_fd){
	//this is a general version of x12, it can do any number less than 16, but the max parallelism is 14, and 12 gives the best performance 
		uint64_t ddr_addr = DDR_ADDR;
		uint64_t RGSW_size = 2 * digitG * N * 2 * 8;
		uint32_t ocl_rd_data;
		long sz = sysconf(_SC_PAGESIZE);
		uint64_t buffer_size = N * 2 * 8;
		std::vector<LWE::LWE_ciphertext> c_text(10);

		if(c1.size() != 10 || c2.size() != 10){
			cout << "Input vectors must be size of 12!!!" << endl;
			*rc = -1;
			return(c_text);
		}

		for(int i = 0; i < 10; i++){
			if(c1[i] == c2[i]){
				cout << "Please only use independent ciphertexts!!!" << endl;
				*rc = -1;
				return(c_text);
			}
		}

		uint64_t *read_buffer = (uint64_t * ) aligned_alloc(sz, buffer_size);
	    if (read_buffer == NULL) {
			std::cout << "not enough memory to allocate read dma buffer" << std::endl; 
			*rc = -ENOMEM;
			return(c_text);
	    }
		
		
		//evaluate the NAND 
		auto start = std::chrono::high_resolution_clock::now();
		//std::cout << "LWE eval" << std::endl; 
		for(int i = 0; i < 10; i++){
			c_text[i] = LWE::LWE_evaluate(c1[i], c2[i], gate[i]);	// hold the evaluation
		}
	
		auto after_eval = std::chrono::high_resolution_clock::now();
		std::cout << "evaluate takes: " << std::chrono::duration_cast<std::chrono::microseconds>(after_eval - start).count() << " us" << endl;
		
		//start bootstrapping
		//1. accumulate
		uint64_t ddr_addr_p1;
		uint64_t ddr_addr_p2;
		std::vector<ciphertext_t> nega(10);
		auto bf_bootstrap = std::chrono::high_resolution_clock::now();
		for(int64_t i = 0; i < n; i++){
			for(int k = 0; k < 10; k++){
				nega[k] = (q - c_text[k].a[i]) % q;	//addtive inverse of "a" equals to modulo - a
			}
			ddr_addr_p1 = (uint64_t)i * (uint64_t)digitR;
			for(uint64_t j = 0; j < digitR; j++){
				ddr_addr_p2 = (ddr_addr_p1 + (uint64_t)j) * (uint64_t)Br;
				for(int k = 0; k < 10; k++){
					ciphertext_t residu = nega[k] % Br;
					//std::cout << "at index " << i << " Br powr " << j << " Br " << residu << " k " << k << std::endl;

					if(i == 0 && j == 0){
						ddr_addr = (ddr_addr_p2 + (uint64_t)residu) * (uint64_t)RGSW_size;
						//ddr_addr = ddr_addr & ((1ULL << 31) - 1);
	    				*rc = fpga_pci_poke(ocl_bar_handle, ADDR_INST_IN, form_instruction(BOOTSTRAP_INIT, (uint32_t)gate[k], c_text[k].b, 0, (uint32_t)(ddr_addr >> 14)));
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							std::cout << "ocl poke failed!!!" << std::endl;
							return(c_text);
						}
					} else {
						ddr_addr = (ddr_addr_p2 + (uint64_t)residu) * (uint64_t)RGSW_size;
						//ddr_addr = ddr_addr & ((1ULL << 34) - 1);
	    				*rc = fpga_pci_poke(ocl_bar_handle, ADDR_INST_IN, form_instruction(BOOTSTRAP, 0, 0, 0, (uint32_t)(ddr_addr >> 14)));
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							std::cout << "ocl poke failed!!!" << std::endl;
							return(c_text);
						}
					}

					do{
						*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							std::cout << "ocl peek failed!!!" << std::endl;
							return(c_text);
						}
						//print_fifo_states(ocl_rd_data);
					}while(get_fifo_state(ocl_rd_data, ROB_FULL) || get_fifo_state(ocl_rd_data, KEY_LOAD_FIFO_FULL));
					nega[k] /= Br;
				}
			}
		}

		auto af_bootstrap = std::chrono::high_resolution_clock::now();
		std::cout << "bt takes: " << std::chrono::duration_cast<std::chrono::microseconds>(af_bootstrap - bf_bootstrap).count() << " us" << endl;

		std::vector<RLWE::RLWE_ciphertext> acc(10);

		auto bf_stream = std::chrono::high_resolution_clock::now();
		//std::cout << "Read from input fifo" << std::endl;
		for(int i = 0; i < 10; i++){
			//std::cout << "Read from input fifo " << i << std::endl;
			acc[i] = dma_read_RLWE(read_fd, rc, read_buffer, INPUT_FIFO_ADDR);
			if(*rc != 0){
				if(read_buffer != NULL)
					free(read_buffer);
				std::cout << "DMA read failed!!!" << std::endl;
				return(c_text);
			}
		}

		auto af_stream = std::chrono::high_resolution_clock::now();
		std::cout << "stream takes: " << std::chrono::duration_cast<std::chrono::microseconds>(af_stream - bf_stream).count() << " us" << endl;


		auto bf_postproc = std::chrono::high_resolution_clock::now();
		for(int i = 0; i < 10; i++){
			LWE::LWE_ciphertext lwe_modQ = LWE::LWE_keyswitch(acc[i], kskey);
			c_text[i] = LWE::LWE_modswitch(lwe_modQ);
		}
		auto af_postproc = std::chrono::high_resolution_clock::now();
		std::cout << "post process takes: " << std::chrono::duration_cast<std::chrono::microseconds>(af_postproc - bf_postproc).count() << " us" << endl;

		if(read_buffer != NULL)
			free(read_buffer);
		return(c_text);
	}

	std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> fpga_expand_RLWE(const RLWE::RLWE_ciphertext &c1, const pci_bar_handle_t ocl_bar_handle, int *rc, int read_fd, int write_fd){
		uint64_t ddr_addr = DDR_ADDR;
		uint64_t RLWE_kskey_size = digitKS_R * N * 2 * 8;
		uint32_t ocl_rd_data;
		long sz = sysconf(_SC_PAGESIZE);
		
		uint64_t buffer_size 	= N * 2 * 8;
		uint64_t *read_buffer 	= (uint64_t * ) aligned_alloc(sz, buffer_size);
		uint64_t *write_buffer 	= (uint64_t * ) aligned_alloc(sz, buffer_size);

	    if (read_buffer == NULL || write_buffer == NULL) {
			if(read_buffer != NULL)
				free(read_buffer);
			if(write_buffer != NULL)
				free(write_buffer);	

			std::cout << "not enough memory to allocate read dma buffer" << std::endl; 
			*rc = -ENOMEM;
			return(NULL);
	    }

		std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> result = std::make_unique<std::vector<RLWE::RLWE_ciphertext>>(N);
		(*result)[0] = c1;
		int inner_loop = 1; 	//2 to the power of i

		for(uint16_t i = 0; i < digitN; i++){
			std::vector<RLWE::RLWE_ciphertext> subs(inner_loop);
			int fpga_write_idx 	= 0;
			int fpga_read_idx 	= 0;

			//std::cout << "In outer loop " << i << std::endl;
			//auto bf_subs = std::chrono::high_resolution_clock::now();
			while(fpga_read_idx < inner_loop){
				//check if input fifo is full
				*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
				if(*rc != 0){
					if(read_buffer != NULL)
						free(read_buffer);
					if(write_buffer != NULL)
						free(write_buffer);	
					std::cout << "ocl peek failed!!!" << std::endl;
					return(NULL);
				}
				//print_fifo_states(ocl_rd_data);

				//write new input if not full	
				while(fpga_write_idx < inner_loop && !get_fifo_state(ocl_rd_data, RLWE_INPUT_FIFO_FULL) && !get_fifo_state(ocl_rd_data, ROB_FULL) && !get_fifo_state(ocl_rd_data, KEY_LOAD_FIFO_FULL)){
					//std::cout << "Writing RLWE " << fpga_write_idx << std::endl;
					//write RLWE
					*rc = dma_write_RLWE(write_fd, (*(result))[fpga_write_idx], write_buffer, INPUT_FIFO_ADDR);
					if(*rc != 0){
						if(read_buffer != NULL)
							free(read_buffer);
						if(write_buffer != NULL)
							free(write_buffer);	
						std::cout << "DMA write RLWE failed!!!" << std::endl;
						return(NULL);
					}
					//write instruction
					ddr_addr = i * RLWE_kskey_size;
					ddr_addr = ddr_addr & ((1ULL << 34) - 1);
	    			*rc = fpga_pci_poke(ocl_bar_handle, ADDR_INST_IN, form_instruction(RLWESUBS, 0, 0, (uint32_t)i, (uint32_t)(ddr_addr >> 14)));
					if(*rc != 0){
						if(read_buffer != NULL)
							free(read_buffer);
						if(write_buffer != NULL)
							free(write_buffer);	
						std::cout << "ocl poke failed!!!" << std::endl;
						return(NULL);
					}

					fpga_write_idx++;
					//check fifo state
					*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
					if(*rc != 0){
						if(read_buffer != NULL)
							free(read_buffer);
						if(write_buffer != NULL)
							free(write_buffer);	
						std::cout << "ocl peek failed!!!" << std::endl;
						return(NULL);
					}
					//print_fifo_states(ocl_rd_data);
				}
				
				do{
					//check if output fifo is not empty
					*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
					if(*rc != 0){
						if(read_buffer != NULL)
							free(read_buffer);
						if(write_buffer != NULL)
							free(write_buffer);	
						std::cout << "ocl peek failed!!!" << std::endl;
						return(NULL);
					}
					//print_fifo_states(ocl_rd_data);

					//read from output fifo if not empty
					if(!get_fifo_state(ocl_rd_data, RLWE_OUTPUT_FIFO_EMPTY)){
						//std::cout << "Reading RLWE " << fpga_read_idx << std::endl;
						subs[fpga_read_idx] = std::move(dma_read_RLWE(read_fd, rc, read_buffer, OUTPUT_FIFO_ADDR));
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							if(write_buffer != NULL)
								free(write_buffer);	
							std::cout << "DMA read failed!!!" << std::endl;
							return(NULL);
						}
						fpga_read_idx++;	
					}
				}while(fpga_write_idx >= inner_loop && fpga_read_idx < inner_loop);
			}
			//auto af_subs = std::chrono::high_resolution_clock::now();
			//std::cout << "subs takes: " << std::chrono::duration_cast<std::chrono::microseconds>(af_subs - bf_subs).count() << " us" << endl;
			
			//auto bf_subs_post = std::chrono::high_resolution_clock::now();
			//post process of the substituted RLWEs
			for(int j = 0; j < inner_loop; j++){
				RLWE::RLWE_ciphertext tmp 	= (*result)[j];
				(*result)[j] 				= RLWE::RLWE_addition(tmp, subs[j]);
				(*result)[j + inner_loop] 	= RLWE::RLWE_rotate_freq(RLWE::RLWE_subtraction(tmp, subs[j]), i, false);
			}
			//auto af_subs_post = std::chrono::high_resolution_clock::now();
			//std::cout << "subs post takes: " << std::chrono::duration_cast<std::chrono::microseconds>(af_subs_post - bf_subs_post).count() << " us" << endl;
			inner_loop *= 2;
		}
		if(read_buffer != NULL)
			free(read_buffer);
		if(write_buffer != NULL)
			free(write_buffer);	
		return(result);
	}

	std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> fpga_expand_RLWE_cont_rd_wr(const RLWE::RLWE_ciphertext &c1, const pci_bar_handle_t ocl_bar_handle, int *rc, int read_fd, int write_fd){
		uint64_t ddr_addr = DDR_ADDR;
		uint64_t RLWE_kskey_size = digitKS_R * N * 2 * 8;
		//struct timespec ts;	//specify time to sleep
		uint32_t ocl_rd_data;
		//uint32_t ocl_rd_data_q;
		long sz = sysconf(_SC_PAGESIZE);
		
		uint64_t buffer_size 	= N * 2 * 8;
		uint64_t *read_buffer 	= (uint64_t * ) aligned_alloc(sz, buffer_size);
		uint64_t *write_buffer 	= (uint64_t * ) aligned_alloc(sz, buffer_size);

	    if (read_buffer == NULL || write_buffer == NULL) {
			if(read_buffer != NULL)
				free(read_buffer);
			if(write_buffer != NULL)
				free(write_buffer);	

			std::cout << "not enough memory to allocate read dma buffer" << std::endl; 
			*rc = -ENOMEM;
			return(NULL);
	    }

		std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> result = std::make_unique<std::vector<RLWE::RLWE_ciphertext>>(N);
		(*result)[0] = c1;
		int inner_loop = 1; 	//2 to the power of i

		for(uint16_t i = 0; i < digitN; i++){
			std::vector<RLWE::RLWE_ciphertext> subs(inner_loop);
			int fpga_write_idx 	= 0;
			int fpga_read_idx 	= 0;

			std::cout << "In outer loop " << i << std::endl;
			while(fpga_read_idx < inner_loop){
				//check if input fifo is full
				//ts.tv_sec = 0;
				//ts.tv_nsec = 20000;
				//nanosleep(&ts, NULL);
				*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
				if(*rc != 0){
					if(read_buffer != NULL)
						free(read_buffer);
					if(write_buffer != NULL)
						free(write_buffer);	
					std::cout << "ocl peek failed!!!" << std::endl;
					return(NULL);
				}
				//print_fifo_states(ocl_rd_data);
				int wr_count = 0;
				//write new input if not full	
				while(wr_count < 12 && fpga_write_idx < inner_loop && !get_fifo_state(ocl_rd_data, RLWE_INPUT_FIFO_FULL) && !get_fifo_state(ocl_rd_data, ROB_FULL) && !get_fifo_state(ocl_rd_data, KEY_LOAD_FIFO_FULL)){
					std::cout << "Writing RLWE " << fpga_write_idx << std::endl;
					//write RLWE
					*rc = dma_write_RLWE(write_fd, (*(result))[fpga_write_idx], write_buffer, INPUT_FIFO_ADDR);
					if(*rc != 0){
						if(read_buffer != NULL)
							free(read_buffer);
						if(write_buffer != NULL)
							free(write_buffer);	
						std::cout << "DMA write RLWE failed!!!" << std::endl;
						return(NULL);
					}
					//write instruction
					ddr_addr = i * RLWE_kskey_size;
					ddr_addr = ddr_addr & ((1ULL << 34) - 1);
	    			*rc = fpga_pci_poke(ocl_bar_handle, ADDR_INST_IN, form_instruction(RLWESUBS, 0, 0, (uint32_t)i, (uint32_t)(ddr_addr >> 14)));
					if(*rc != 0){
						if(read_buffer != NULL)
							free(read_buffer);
						if(write_buffer != NULL)
							free(write_buffer);	
						std::cout << "ocl poke failed!!!" << std::endl;
						return(NULL);
					}

					fpga_write_idx++;
					wr_count++;
					//check fifo state
					//ts.tv_sec = 0;
					//ts.tv_nsec = 20000;
					//nanosleep(&ts, NULL);
					*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
					if(*rc != 0){
						if(read_buffer != NULL)
							free(read_buffer);
						if(write_buffer != NULL)
							free(write_buffer);	
						std::cout << "ocl peek failed!!!" << std::endl;
						return(NULL);
					}
					//print_fifo_states(ocl_rd_data);
				}
				
				std::cout << "Wait for output FIFO, wr_count = " << wr_count << std::endl;
				while(get_fifo_state(ocl_rd_data, RLWE_OUTPUT_FIFO_EMPTY)){
					//check if output fifo is not empty
					//ts.tv_sec = 0;
					//ts.tv_nsec = 20000;
					//nanosleep(&ts, NULL);
					*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
					if(*rc != 0){
						if(read_buffer != NULL)
							free(read_buffer);
						if(write_buffer != NULL)
							free(write_buffer);	
						std::cout << "ocl peek failed!!!" << std::endl;
						return(NULL);
					}
					//print_fifo_states(ocl_rd_data);
				}
				int rd_count = 0;
				//while(fpga_read_idx < inner_loop && rd_count < wr_count){
				while(rd_count < wr_count && fpga_read_idx < inner_loop && !get_fifo_state(ocl_rd_data, RLWE_OUTPUT_FIFO_EMPTY)){
					std::cout << "Reading RLWE " << fpga_read_idx << std::endl;
					//read from output fifo if not empty
					if(!get_fifo_state(ocl_rd_data, RLWE_OUTPUT_FIFO_EMPTY)){
						subs[fpga_read_idx] = std::move(dma_read_RLWE(read_fd, rc, read_buffer, OUTPUT_FIFO_ADDR));
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							if(write_buffer != NULL)
								free(write_buffer);	
							std::cout << "DMA read failed!!!" << std::endl;
							return(NULL);
						}
						fpga_read_idx++;	
						rd_count++;
					}
					//check if output fifo is not empty
					//ts.tv_sec = 0;
					//ts.tv_nsec = 20000;
					//nanosleep(&ts, NULL);
					//*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
					//if(*rc != 0){
					//	if(read_buffer != NULL)
					//		free(read_buffer);
					//	if(write_buffer != NULL)
					//		free(write_buffer);	
					//	std::cout << "ocl peek failed!!!" << std::endl;
					//	return(NULL);
					//}
					//print_fifo_states(ocl_rd_data);
				}

			}
			
			//post process of the substituted RLWEs
			for(int j = 0; j < inner_loop; j++){
				RLWE::RLWE_ciphertext tmp 	= (*result)[j];
				(*result)[j] 				= RLWE::RLWE_addition(tmp, subs[j]);
				(*result)[j + inner_loop] 	= RLWE::RLWE_rotate_freq(RLWE::RLWE_subtraction(tmp, subs[j]), i, false);
			}
			inner_loop *= 2;
		}
		if(read_buffer != NULL)
			free(read_buffer);
		if(write_buffer != NULL)
			free(write_buffer);	
		return(result);
	}


	std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> fpga_expand_RLWE_batch_rd_wr(const RLWE::RLWE_ciphertext &c1, const pci_bar_handle_t ocl_bar_handle, int *rc, int read_fd, int write_fd){
		uint64_t ddr_addr = DDR_ADDR;
		uint64_t RLWE_kskey_size = digitKS_R * N * 2 * 8;
		//struct timespec ts;	//specify time to sleep
		uint32_t ocl_rd_data;
		//uint32_t ocl_rd_data_q;
		long sz = sysconf(_SC_PAGESIZE);
		
		uint64_t buffer_size 	= N * 2 * 8;
		uint64_t *read_buffer 	= (uint64_t * ) aligned_alloc(sz, buffer_size);
		uint64_t *write_buffer 	= (uint64_t * ) aligned_alloc(sz, buffer_size);

	    if (read_buffer == NULL || write_buffer == NULL) {
			if(read_buffer != NULL)
				free(read_buffer);
			if(write_buffer != NULL)
				free(write_buffer);	

			std::cout << "not enough memory to allocate read dma buffer" << std::endl; 
			*rc = -ENOMEM;
			return(NULL);
	    }

		std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> result = std::make_unique<std::vector<RLWE::RLWE_ciphertext>>(N);
		(*result)[0] = c1;
		int inner_loop = 1; 	//2 to the power of i

		for(uint16_t i = 0; i < digitN; i++){
			std::vector<RLWE::RLWE_ciphertext> subs(inner_loop);
			int fpga_write_idx 	= 0;
			int fpga_read_idx 	= 0;

			std::cout << "In outer loop " << i << std::endl;
			while(fpga_read_idx < inner_loop){
				//check if input fifo is full
				//ts.tv_sec = 0;
				//ts.tv_nsec = 20000;
				//nanosleep(&ts, NULL);
				*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
				if(*rc != 0){
					if(read_buffer != NULL)
						free(read_buffer);
					if(write_buffer != NULL)
						free(write_buffer);	
					std::cout << "ocl peek failed!!!" << std::endl;
					return(NULL);
				}
				//print_fifo_states(ocl_rd_data);
				//write new input if not full	
				int wr_count = 0;
				while(fpga_write_idx < inner_loop && !get_fifo_state(ocl_rd_data, RLWE_INPUT_FIFO_FULL) && !get_fifo_state(ocl_rd_data, ROB_FULL) && !get_fifo_state(ocl_rd_data, KEY_LOAD_FIFO_FULL)){
					if(inner_loop == 1) {
						std::cout << "Writing RLWE " << fpga_write_idx << std::endl;
						//write RLWE
						*rc = dma_write_RLWE(write_fd, (*(result))[fpga_write_idx], write_buffer, INPUT_FIFO_ADDR);
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							if(write_buffer != NULL)
								free(write_buffer);	
							std::cout << "DMA write RLWE failed!!!" << std::endl;
							return(NULL);
						}
						fpga_write_idx++;
						wr_count++;
						//write instruction
						ddr_addr = i * RLWE_kskey_size;
						ddr_addr = ddr_addr & ((1ULL << 34) - 1);
	    				*rc = fpga_pci_poke(ocl_bar_handle, ADDR_INST_IN, form_instruction(RLWESUBS, 0, 0, (uint32_t)i, (uint32_t)(ddr_addr >> 14)));
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							if(write_buffer != NULL)
								free(write_buffer);	
							std::cout << "ocl poke failed!!!" << std::endl;
							return(NULL);
						}
						//check fifo state
						//ts.tv_sec = 0;
						//ts.tv_nsec = 20000;
						//nanosleep(&ts, NULL);
						*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							if(write_buffer != NULL)
								free(write_buffer);	
							std::cout << "ocl peek failed!!!" << std::endl;
							return(NULL);
						}
						//print_fifo_states(ocl_rd_data);
					} else if (inner_loop == 2) {
						for(int j = 0; j < 2; j++){
							std::cout << "Writing RLWE " << fpga_write_idx << std::endl;
							//write RLWE
							*rc = dma_write_RLWE(write_fd, (*(result))[fpga_write_idx], write_buffer, INPUT_FIFO_ADDR);
							if(*rc != 0){
								if(read_buffer != NULL)
									free(read_buffer);
								if(write_buffer != NULL)
									free(write_buffer);	
								std::cout << "DMA write RLWE failed!!!" << std::endl;
								return(NULL);
							}
							fpga_write_idx++;
							wr_count++;
						}
						for(int j = 0; j < 2; j++){
							//write instruction
							ddr_addr = i * RLWE_kskey_size;
							ddr_addr = ddr_addr & ((1ULL << 34) - 1);
	    					*rc = fpga_pci_poke(ocl_bar_handle, ADDR_INST_IN, form_instruction(RLWESUBS, 0, 0, (uint32_t)i, (uint32_t)(ddr_addr >> 14)));
							if(*rc != 0){
								if(read_buffer != NULL)
									free(read_buffer);
								if(write_buffer != NULL)
									free(write_buffer);	
								std::cout << "ocl poke failed!!!" << std::endl;
								return(NULL);
							}
						}
						//check fifo state
						//ts.tv_sec = 0;
						//ts.tv_nsec = 20000;
						//nanosleep(&ts, NULL);
						*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							if(write_buffer != NULL)
								free(write_buffer);	
							std::cout << "ocl peek failed!!!" << std::endl;
							return(NULL);
						}
						//print_fifo_states(ocl_rd_data);
					} else {
					//} else if (inner_loop == 4) {
						for(int j = 0; j < 4; j++){
							std::cout << "Writing RLWE " << fpga_write_idx << std::endl;
							//write RLWE
							*rc = dma_write_RLWE(write_fd, (*(result))[fpga_write_idx], write_buffer, INPUT_FIFO_ADDR);
							if(*rc != 0){
								if(read_buffer != NULL)
									free(read_buffer);
								if(write_buffer != NULL)
									free(write_buffer);	
								std::cout << "DMA write RLWE failed!!!" << std::endl;
								return(NULL);
							}
							fpga_write_idx++;
							wr_count++;
						}
						for(int j = 0; j < 4; j++){
							//write instruction
							ddr_addr = i * RLWE_kskey_size;
							ddr_addr = ddr_addr & ((1ULL << 34) - 1);
	    					*rc = fpga_pci_poke(ocl_bar_handle, ADDR_INST_IN, form_instruction(RLWESUBS, 0, 0, (uint32_t)i, (uint32_t)(ddr_addr >> 14)));
							if(*rc != 0){
								if(read_buffer != NULL)
									free(read_buffer);
								if(write_buffer != NULL)
									free(write_buffer);	
								std::cout << "ocl poke failed!!!" << std::endl;
								return(NULL);
							}
						}
						//check fifo state
						//ts.tv_sec = 0;
						//ts.tv_nsec = 40000;
						//nanosleep(&ts, NULL);
						*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							if(write_buffer != NULL)
								free(write_buffer);	
							std::cout << "ocl peek failed!!!" << std::endl;
							return(NULL);
						}
						//print_fifo_states(ocl_rd_data);
					}
					break;
				}

				if(inner_loop == 1){	
					std::cout << "Wait for output FIFO, wr_count = " << wr_count << std::endl;
					while(get_fifo_state(ocl_rd_data, RLWE_OUTPUT_FIFO_EMPTY)){
						//check if output fifo is not empty
						//ts.tv_sec = 0;
						//ts.tv_nsec = 20000;
						//nanosleep(&ts, NULL);
						*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							if(write_buffer != NULL)
								free(write_buffer);	
							std::cout << "ocl peek failed!!!" << std::endl;
							return(NULL);
						}
						//print_fifo_states(ocl_rd_data);
					}
					std::cout << "Reading RLWE " << fpga_read_idx << std::endl;
					//read from output fifo if not empty
					if(!get_fifo_state(ocl_rd_data, RLWE_OUTPUT_FIFO_EMPTY)){
						subs[fpga_read_idx] = std::move(dma_read_RLWE(read_fd, rc, read_buffer, OUTPUT_FIFO_ADDR));
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							if(write_buffer != NULL)
								free(write_buffer);	
							std::cout << "DMA read failed!!!" << std::endl;
							return(NULL);
						}
						fpga_read_idx++;	
					}
					//check if output fifo is not empty
					//ts.tv_sec = 0;
					//ts.tv_nsec = 20000;
					//nanosleep(&ts, NULL);
					//*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
					//if(*rc != 0){
					//	if(read_buffer != NULL)
					//		free(read_buffer);
					//	if(write_buffer != NULL)
					//		free(write_buffer);	
					//	std::cout << "ocl peek failed!!!" << std::endl;
					//	return(NULL);
					//}
					//print_fifo_states(ocl_rd_data);
				} else {
					std::cout << "Wait for output FIFO to be full, wr_count = " << wr_count << std::endl;
					while(!get_fifo_state(ocl_rd_data, RLWE_OUTPUT_FIFO_FULL)){
						//check if output fifo is not empty
						//ts.tv_sec = 0;
						//ts.tv_nsec = 20000;
						//nanosleep(&ts, NULL);
						*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							if(write_buffer != NULL)
								free(write_buffer);	
							std::cout << "ocl peek failed!!!" << std::endl;
							return(NULL);
						}
						//print_fifo_states(ocl_rd_data);
					}
					//while(fpga_read_idx < inner_loop && rd_count < wr_count){
					int rd_count = 0;
					do{
						for(int j = 0; j < 2; j++){
							std::cout << "Reading RLWE " << fpga_read_idx << std::endl;
							//read from output fifo if not empty
							subs[fpga_read_idx] = std::move(dma_read_RLWE(read_fd, rc, read_buffer, OUTPUT_FIFO_ADDR));
							if(*rc != 0){
								if(read_buffer != NULL)
									free(read_buffer);
								if(write_buffer != NULL)
									free(write_buffer);	
								std::cout << "DMA read failed!!!" << std::endl;
								return(NULL);
							}
							fpga_read_idx++;	
							rd_count++;
						}
						//check if output fifo is not empty
						do{
							//ts.tv_sec = 0;
							//ts.tv_nsec = 20000;
							//nanosleep(&ts, NULL);
							*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
							if(*rc != 0){
								if(read_buffer != NULL)
									free(read_buffer);
								if(write_buffer != NULL)
									free(write_buffer);	
								std::cout << "ocl peek failed!!!" << std::endl;
								return(NULL);
							}
							//print_fifo_states(ocl_rd_data);
						}while(rd_count < wr_count && !get_fifo_state(ocl_rd_data, RLWE_OUTPUT_FIFO_FULL));
						//do{
						//	ts.tv_sec = 0;
						//	ts.tv_nsec = 20000;
						//	nanosleep(&ts, NULL);
						//	*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
						//	if(*rc != 0){
						//		if(read_buffer != NULL)
						//			free(read_buffer);
						//		if(write_buffer != NULL)
						//			free(write_buffer);	
						//		std::cout << "ocl peek failed!!!" << std::endl;
						//		return(NULL);
						//	}
						//	//print_fifo_states(ocl_rd_data);
						//}while(rd_count < wr_count && !get_fifo_state(ocl_rd_data, RLWE_OUTPUT_FIFO_FULL));
					}while(rd_count < wr_count);

				}
			}
			
			//post process of the substituted RLWEs
			for(int j = 0; j < inner_loop; j++){
				RLWE::RLWE_ciphertext tmp 	= (*result)[j];
				(*result)[j] 				= RLWE::RLWE_addition(tmp, subs[j]);
				(*result)[j + inner_loop] 	= RLWE::RLWE_rotate_freq(RLWE::RLWE_subtraction(tmp, subs[j]), i, false);
			}
			inner_loop *= 2;
		}
		if(read_buffer != NULL)
			free(read_buffer);
		if(write_buffer != NULL)
			free(write_buffer);	
		return(result);
	}



	std::shared_ptr<std::vector<RLWE::RGSW_ciphertext>> fpga_homo_expand(const std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> &packed_bits, const pci_bar_handle_t ocl_bar_handle, int *rc, int read_fd, int write_fd){
		uint64_t ddr_addr = RGSW_ENC_SK_ADDR;		//only this addr is used in this function
		ddr_addr = ddr_addr & ((1ULL << 34) - 1);

		//uint64_t RLWE_kskey_size = digitKS_R * N * 2 * 8;
		struct timespec ts;	//specify time to sleep
		uint32_t ocl_rd_data;
		long sz = sysconf(_SC_PAGESIZE);
		
		uint64_t buffer_size 	= N * 2 * 8;
		uint64_t *read_buffer 	= (uint64_t * ) aligned_alloc(sz, buffer_size);
		uint64_t *write_buffer 	= (uint64_t * ) aligned_alloc(sz, buffer_size);

	    if (read_buffer == NULL || write_buffer == NULL) {
			if(read_buffer != NULL)
				free(read_buffer);
			if(write_buffer != NULL)
				free(write_buffer);	

			std::cout << "not enough memory to allocate read dma buffer" << std::endl; 
			*rc = -ENOMEM;
			return(NULL);
	    }

		auto result = std::make_shared<std::vector<RLWE::RGSW_ciphertext>>(N);
		//std::cout << (*result)[0]. c_text.size() << std::endl;	
		//std::cout << (*result)[0]. c_text[0][0].a.size() << std::endl;	

		//get the unpacked bits in RLWE
		std::vector<std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>>> unpacked_bits(digitG);
		for(uint16_t i = 0; i < digitG; i++){
			std::cout << "expand RLWE " << i << std::endl;
			//unpacked_bits[i] = fpga_expand_RLWE_cont_rd_wr((*packed_bits)[i], ocl_bar_handle, rc, read_fd, write_fd);
			unpacked_bits[i] = fpga_expand_RLWE((*packed_bits)[i], ocl_bar_handle, rc, read_fd, write_fd);
			if(*rc != 0){
				if(read_buffer != NULL)
					free(read_buffer);
				if(write_buffer != NULL)
					free(write_buffer);	
				std::cout << "Error occured while expanding RLWE " << i << std::endl;
				return(NULL);
			}
			ts.tv_sec = 0;
			ts.tv_nsec = 1000;
			nanosleep(&ts, NULL);
		}
		

		std::cout << "expand RLWE finishes" << std::endl;
		//get the unpacked bits in RGSW
		//fill up the first column of all the RGSW ciphertexts
		uint16_t fpga_write_idx_i = 0;
		uint16_t fpga_write_idx_j = 0;
		uint16_t fpga_read_idx_i = 0;
		uint16_t fpga_read_idx_j = 0;
		auto bf_rlwe_mult = std::chrono::high_resolution_clock::now();
		while(fpga_read_idx_i < N){
			//check input fifo status
			//ts.tv_sec = 0;
			//ts.tv_nsec = 30000;
			//nanosleep(&ts, NULL);
			*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
			if(*rc != 0){
				if(read_buffer != NULL)
					free(read_buffer);
				if(write_buffer != NULL)
					free(write_buffer);	
				std::cout << "ocl peek failed!!!" << std::endl;
				return(NULL);
			}
			//print_fifo_states(ocl_rd_data);
			
			//write new input if not full
			while(fpga_write_idx_i < N && !get_fifo_state(ocl_rd_data, RLWE_INPUT_FIFO_FULL) && !get_fifo_state(ocl_rd_data, ROB_FULL) && !get_fifo_state(ocl_rd_data, KEY_LOAD_FIFO_FULL)){
				//std::cout << "writing RLWE i " << fpga_write_idx_i << " j " << fpga_write_idx_j << std::endl;
				//write RLWE
				//auto bf_dma_write = std::chrono::high_resolution_clock::now();
				*rc = dma_write_RLWE(write_fd, (*(unpacked_bits[fpga_write_idx_j]))[fpga_write_idx_i], write_buffer, INPUT_FIFO_ADDR);
				//auto af_dma_write = std::chrono::high_resolution_clock::now();
				//std::cout << "dma write takes: " << std::chrono::duration_cast<std::chrono::microseconds>(af_dma_write - bf_dma_write).count() << " us" << endl;
				if(*rc != 0){
					if(read_buffer != NULL)
						free(read_buffer);
					if(write_buffer != NULL)
						free(write_buffer);	
					std::cout << "DMA write RLWE failed!!!" << std::endl;
					return(NULL);
				}
				
				//write instruction
				//auto bf_inst_write = std::chrono::high_resolution_clock::now();
	    		*rc = fpga_pci_poke(ocl_bar_handle, ADDR_INST_IN, form_instruction(RLWE_MULT_RGSW, 0, 0, 0, (uint32_t)(ddr_addr >> 14)));
				//auto af_inst_write = std::chrono::high_resolution_clock::now();
				//std::cout << "inst write takes: " << std::chrono::duration_cast<std::chrono::nanoseconds>(af_inst_write - bf_inst_write).count() << " ns" << endl;
				if(*rc != 0){
					if(read_buffer != NULL)
						free(read_buffer);
					if(write_buffer != NULL)
						free(write_buffer);	
					std::cout << "ocl poke failed!!!" << std::endl;
					return(NULL);
				}

				fpga_write_idx_j++;
				if(fpga_write_idx_j >= digitG){
					fpga_write_idx_i++;
					fpga_write_idx_j = 0;
				}
				//check the fifo status
				//auto bf_state_rd = std::chrono::high_resolution_clock::now();
				*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
				//auto af_state_rd = std::chrono::high_resolution_clock::now();
				//std::cout << "inst read takes: " << std::chrono::duration_cast<std::chrono::nanoseconds>(af_state_rd - bf_state_rd).count() << " ns" << endl;
				if(*rc != 0){
					if(read_buffer != NULL)
						free(read_buffer);
					if(write_buffer != NULL)
						free(write_buffer);	
					std::cout << "ocl peek failed!!!" << std::endl;
					return(NULL);
				}
				//print_fifo_states(ocl_rd_data);
			}

			do{
				*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
				if(*rc != 0){
					if(read_buffer != NULL)
						free(read_buffer);
					if(write_buffer != NULL)
						free(write_buffer);	
					std::cout << "ocl peek failed!!!" << std::endl;
					return(NULL);
				}
				//print_fifo_states(ocl_rd_data);

				//read from output fifo if not empty
				if(!get_fifo_state(ocl_rd_data, RLWE_OUTPUT_FIFO_EMPTY)){
					//std::cout << "Reading RLWE i " << fpga_read_idx_i << " j " << fpga_read_idx_j << std::endl;
					//auto bf_dma_read = std::chrono::high_resolution_clock::now();
					(*result)[fpga_read_idx_i].c_text[fpga_read_idx_j][0] = std::move(dma_read_RLWE(read_fd, rc, read_buffer, OUTPUT_FIFO_ADDR));
					//auto af_dma_read = std::chrono::high_resolution_clock::now();
					//std::cout << "dma read takes: " << std::chrono::duration_cast<std::chrono::microseconds>(af_dma_read - bf_dma_read).count() << " us" << endl;
					if(*rc != 0){
						if(read_buffer != NULL)
							free(read_buffer);
						if(write_buffer != NULL)
							free(write_buffer);	
						std::cout << "DMA read failed!!!" << std::endl;
						return(NULL);
					}
					fpga_read_idx_j++;
					if(fpga_read_idx_j >= digitG){
						fpga_read_idx_i++;
						fpga_read_idx_j = 0;
					}	
				}
			}while(fpga_write_idx_i >= N && fpga_read_idx_i < N);
		}
		auto af_rlwe_mult = std::chrono::high_resolution_clock::now();
		std::cout << "rlwe_mult takes: " << std::chrono::duration_cast<std::chrono::microseconds>(af_rlwe_mult - bf_rlwe_mult).count() << " us" << endl;

		auto bf_move = std::chrono::high_resolution_clock::now();
		//fill up the second column of all the RGSW ciphertexts	
		for(uint16_t i = 0; i < N; i++){
			for(uint16_t j = 0; j < digitG; j++){
				(*result)[i].c_text[j][1] = std::move((*(unpacked_bits[j]))[i]);
			}
		}
		auto af_move = std::chrono::high_resolution_clock::now();
		std::cout << "move takes: " << std::chrono::duration_cast<std::chrono::microseconds>(af_move - bf_move).count() << " us" << endl;
		return(result);
	}


//debug code
	std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> fpga_RLWE_subs_test(const RLWE::RLWE_ciphertext &c1, const RLWE::RLWE_secretkey &sk, const application::substitute_key &subs_key, const pci_bar_handle_t ocl_bar_handle, int *rc, int read_fd, int write_fd){
		uint64_t ddr_addr = DDR_ADDR;
		uint64_t RLWE_kskey_size = digitKS_R * N * 2 * 8;
		//struct timespec ts;	//specify time to sleep
		uint32_t ocl_rd_data;
		long sz = sysconf(_SC_PAGESIZE);
		
		uint64_t buffer_size 	= N * 2 * 8;
		uint64_t *read_buffer 	= (uint64_t * ) aligned_alloc(sz, buffer_size);
		uint64_t *write_buffer 	= (uint64_t * ) aligned_alloc(sz, buffer_size);

	    if (read_buffer == NULL || write_buffer == NULL) {
			if(read_buffer != NULL)
				free(read_buffer);
			if(write_buffer != NULL)
				free(write_buffer);	

			std::cout << "not enough memory to allocate read dma buffer" << std::endl; 
			*rc = -ENOMEM;
			return(NULL);
	    }

		std::unique_ptr<std::vector<RLWE::RLWE_ciphertext>> result = std::make_unique<std::vector<RLWE::RLWE_ciphertext>>(N);
		(*result)[0] = c1;
		int inner_loop = 1; 	//2 to the power of i

		for(uint16_t i = 0; i < digitN; i++){
			std::vector<RLWE::RLWE_ciphertext> subs(inner_loop);
			int fpga_write_idx 	= 0;
			int fpga_read_idx 	= 0;

			std::cout << "In outer loop " << i << std::endl;
			while(fpga_read_idx < inner_loop){
				//check if input fifo is full
				//ts.tv_sec = 0;
				//ts.tv_nsec = 128;
				//nanosleep(&ts, NULL);
				*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
				if(*rc != 0){
					if(read_buffer != NULL)
						free(read_buffer);
					if(write_buffer != NULL)
						free(write_buffer);	
					std::cout << "ocl peek failed!!!" << std::endl;
					return(NULL);
				}
				//print_fifo_states(ocl_rd_data);

				//std::cout << "In write RLWE loop " << std::endl;
				//write new input if not full	
				while(fpga_write_idx < inner_loop && !get_fifo_state(ocl_rd_data, RLWE_INPUT_FIFO_FULL) && !get_fifo_state(ocl_rd_data, ROB_FULL) && !get_fifo_state(ocl_rd_data, KEY_LOAD_FIFO_FULL)){
					std::cout << "transferring write_index " << fpga_write_idx << std::endl;
					//write RLWE
					*rc = dma_write_RLWE(write_fd, (*(result))[fpga_write_idx], write_buffer, INPUT_FIFO_ADDR);
					if(*rc != 0){
						if(read_buffer != NULL)
							free(read_buffer);
						if(write_buffer != NULL)
							free(write_buffer);	
						std::cout << "DMA write RLWE failed!!!" << std::endl;
						return(NULL);
					}
					//write instruction
					ddr_addr = i * RLWE_kskey_size;
					//std::cout << "ddr_addr = " << ddr_addr << std::endl;
					ddr_addr = ddr_addr & ((1ULL << 34) - 1);
	    			*rc = fpga_pci_poke(ocl_bar_handle, ADDR_INST_IN, form_instruction(RLWESUBS, 0, 0, (uint32_t)i, (uint32_t)(ddr_addr >> 14)));
					if(*rc != 0){
						if(read_buffer != NULL)
							free(read_buffer);
						if(write_buffer != NULL)
							free(write_buffer);	
						std::cout << "ocl poke failed!!!" << std::endl;
						return(NULL);
					}

					fpga_write_idx++;
					//check fifo state
					//ts.tv_sec = 0;
					//ts.tv_nsec = 128;
					//nanosleep(&ts, NULL);
					*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
					if(*rc != 0){
						if(read_buffer != NULL)
							free(read_buffer);
						if(write_buffer != NULL)
							free(write_buffer);	
						std::cout << "ocl peek failed!!!" << std::endl;
						return(NULL);
					}
					//print_fifo_states(ocl_rd_data);
				}
				
				//std::cout << "In read RLWE loop " << std::endl;
				do{
					//check if output fifo is not empty
					//ts.tv_sec = 0;
					//ts.tv_nsec = 128;
					//nanosleep(&ts, NULL);
					*rc = fpga_pci_peek(ocl_bar_handle, ADDR_FIFO_STATE, &ocl_rd_data);
					if(*rc != 0){
						if(read_buffer != NULL)
							free(read_buffer);
						if(write_buffer != NULL)
							free(write_buffer);	
						std::cout << "ocl peek failed!!!" << std::endl;
						return(NULL);
					}
					//print_fifo_states(ocl_rd_data);

					//read from output fifo if not empty
					if(!get_fifo_state(ocl_rd_data, RLWE_OUTPUT_FIFO_EMPTY)){
						std::cout << "Read RLWE " << fpga_read_idx << std::endl;
						subs[fpga_read_idx] = std::move(dma_read_RLWE(read_fd, rc, read_buffer, OUTPUT_FIFO_ADDR));
						if(*rc != 0){
							if(read_buffer != NULL)
								free(read_buffer);
							if(write_buffer != NULL)
								free(write_buffer);	
							std::cout << "DMA read failed!!!" << std::endl;
							return(NULL);
						}
						fpga_read_idx++;	
					}
				}while(fpga_write_idx >= inner_loop && fpga_read_idx < inner_loop);
			}
			
			//if(i == 0){
			//	RLWE::RLWE_ciphertext subs_soft = RLWE::RLWE_keyswitch(RLWE::RLWE_substitute((*result)[0], i), subs_key.subs_key[i]);
			//	//for(uint16_t k = 0; k < digitKS_R; k++){
			//	//	std::cout << "subs key 0 : " << k << " poly a" << std::endl;
			//	//	for(int l = 0; l < N; l++){
			//	//		std::cout << std::hex << uppercase << setw(16) << setfill('0') << subs_key.subs_key[i].RLWE_kskey[k].a[l] << endl;
			//	//	}
			//	//	std::cout << "subs key 0 : " << k << " poly b" << std::endl;
			//	//	for(int l = 0; l < N; l++){
			//	//		std::cout << std::hex << uppercase << setw(16) << setfill('0') << subs_key.subs_key[i].RLWE_kskey[k].b[l] << endl;
			//	//	}
			//	//}
			//	std::cout << "subs software" << std::endl;
			//	subs_soft.display();
			//	std::cout << "subs hardware" << std::endl;
			//	subs[0].display();
			//}

			//post process of the substituted RLWEs
			for(int j = 0; j < inner_loop; j++){
				RLWE::RLWE_ciphertext tmp 	= (*result)[j];
				(*result)[j] 				= RLWE::RLWE_addition(tmp, subs[j]);
				(*result)[j + inner_loop] 	= RLWE::RLWE_rotate_freq(RLWE::RLWE_subtraction(tmp, subs[j]), i, false);
			}
			
			//if(i == 0){
			//	for(int j = 0; j < inner_loop; j++){
			//		std::cout << "decrypt RLWE after expand " << i << "at " << j << std::endl;
			//		RLWE::RLWE_plaintext p_tmp1 = RLWE::RLWE_decrypt(sk, (*result)[j], 2);
			//		p_tmp1.display();
			//		std::cout << "decrypt RLWE after expand " << i << "at " << (j + inner_loop) << std::endl;
			//		RLWE::RLWE_plaintext p_tmp2 = RLWE::RLWE_decrypt(sk, (*result)[j + inner_loop], 2);
			//		p_tmp2.display();
			//	}
			//}

			inner_loop *= 2;
		}
		if(read_buffer != NULL)
			free(read_buffer);
		if(write_buffer != NULL)
			free(write_buffer);	
		return(result);
	}






////////////////////////////////////////////////////////////
//
// Below are standalone tests that do not directly connect to 
// other parts of the code
//
///////////////////////////////////////////////////////////

	int dma_test(int slot_id){
	    int write_fd, read_fd, rc;
		size_t buffer_size = 32 * 1024;
		struct timespec ts;		//specify time to sleep
		uint64_t differ;	
		long sz = sysconf(_SC_PAGESIZE);
	
	    write_fd = -1;
	    read_fd = -1;
	
	    uint64_t *write_buffer = (uint64_t *)aligned_alloc(sz, buffer_size * 4);	//try aligned address, if the buffer is page aligned than the dma awlen = 0x07, arlen = 0x3f
	    uint64_t *read_buffer = (uint64_t *)aligned_alloc(sz, buffer_size * 4);
	    if (write_buffer == NULL || read_buffer == NULL) {
	        rc = -ENOMEM;
	        goto out;
	    }
	
	    printf("Memory has been allocated, initializing DMA and filling the buffer...\n");
	
	    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ true);
	    fail_on((rc = (read_fd < 0) ? -1 : 0), out, "unable to open read dma queue");
	
	    write_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ false);
	    fail_on((rc = (write_fd < 0) ? -1 : 0), out, "unable to open write dma queue");
		
	    printf("filling buffer with sequential data...\n") ;
		for(uint32_t i = 0; i < buffer_size / 8 * 4; i++) {
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
	
	    differ = buffer_compare((uint8_t*)read_buffer, (uint8_t*)write_buffer, buffer_size);
	    if (differ != 0) {
	        log_error("DDR wr/rd failed with %lu bytes which differ", differ);
	    	rc = 1;
	    } else {
	        log_info("DDR wr/rd passed!");
	    	rc = 0;
	    }
		
		//reset read buffer
		for(uint32_t i = 0; i < buffer_size / 8; i++){
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
	    if (write_fd >= 0) {
	        close(write_fd);
	    }
	    if (read_fd >= 0) {
	        close(read_fd);
	    }
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
	
		int unused_return = 0;

		//setup to BAR0/OCL
	    /* pci_bar_handle_t is a handler for an address space exposed by one PCI BAR on one of the PCI PFs of the FPGA */
	    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

		//allocate buffer
	    uint64_t *write_buffer = (uint64_t *) aligned_alloc(sz, buffer_size);	//try aligned address, if the buffer is page aligned than the dma awlen = 0x07, arlen = 0x3f
	    uint64_t *read_buffer = (uint64_t *) aligned_alloc(sz, buffer_size);
	    uint64_t *input_buffer0 = (uint64_t *) aligned_alloc(sz, buffer_size);
	    uint64_t *input_buffer1 = (uint64_t *) aligned_alloc(sz, buffer_size);
	    uint64_t *output_buffer0 = (uint64_t *) aligned_alloc(sz, buffer_size);
	    uint64_t *output_buffer1 = (uint64_t *) aligned_alloc(sz, buffer_size);
	    if (write_buffer == NULL || read_buffer == NULL || input_buffer0 == NULL || input_buffer1 == NULL || output_buffer0 == NULL || output_buffer1 == NULL) {
	        rc = -ENOMEM;
	        goto out;
	    }
	
	    printf("Memory has been allocated, initializing DMA and filling the buffer...\n");
	
	    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ true);
	    fail_on((rc = (read_fd < 0) ? -1 : 0), out, "unable to open read dma queue");
	
	    write_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ false);
	    fail_on((rc = (write_fd < 0) ? -1 : 0), out, "unable to open write dma queue");

	    /* attach to the fpga, with a pci_bar_handle out param
	     * To attach to multiple slots or BARs, call this function multiple times,
	     * saving the pci_bar_handle to specify which address space to interact with in
	     * other API calls.
	     * This function accepts the slot_id, physical function, and bar number
	     */
	    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);
	    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);
	
		cl_dir = getenv("CL_DIR");
		//printf("%s", cl_dir);	
		
	    printf("Transferring subs key to DDR\n");
		for(int test_case = 0; test_case < 2; test_case++){
			for(int i = 0; i < (int)digitKS_R; i++){
	
				string path_shared = "/verif/tests/mem_init_content/top_verify/rlwesubs/bk";
				//open poly a file
				snprintf(file_path, sizeof(file_path), "%s%s/RLWESUBS_keyinput_2k_rlwe_%0d_a%0d.mem", cl_dir, path_shared.c_str(), i, test_case);
				//printf("%s\n", file_path);	
				
				fptr_a = fopen(file_path, "r");
				if(fptr_a == NULL){
					fail_on(1, out, "Unable to open key poly a file, %0d, %0d", i, test_case);
				}
	
				//open poly b file
				snprintf(file_path, sizeof(file_path), "%s%s/RLWESUBS_keyinput_2k_rlwe_%0d_b%0d.mem", cl_dir, path_shared.c_str(), i, test_case);
				//printf("%s\n", file_path);	
				
				fptr_b = fopen(file_path, "r");
				if(fptr_b == NULL){
					fail_on(1, out, "Unable to open key poly b file, %0d, %0d", i, test_case);
				}
				
				//fill the buffer with data read from files
				uint64_t* buffer_addr_temp = write_buffer;
				for(int k = 0; k < N / 4; k++){
					for(int j = 0; j < 4; j++){
						unused_return = fscanf(fptr_a, "%lx\n", buffer_addr_temp);
						buffer_addr_temp++;
					}
					for(int j = 0; j < 4; j++){
						unused_return = fscanf(fptr_b, "%lx\n", buffer_addr_temp);
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
	
	    printf("Reading in input RLWE\n");
		for(int test_case = 0; test_case < 2; test_case++){
			string path_shared = "/verif/tests/mem_init_content/top_verify/rlwesubs/bk";
			//open poly a file
			snprintf(file_path, sizeof(file_path), "%s%s/RLWESUBS_inputrlwe_2k_a%0d.mem", cl_dir, path_shared.c_str(), test_case);
			//printf("%s\n", file_path);	
			
			fptr_a = fopen(file_path, "r");
			if(fptr_a == NULL){
				fail_on(1, out, "Unable to open input rlwe poly a file, %0d", test_case);
			}
	
			//open poly b file
			snprintf(file_path, sizeof(file_path), "%s%s/RLWESUBS_inputrlwe_2k_b%0d.mem", cl_dir, path_shared.c_str(), test_case);
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
	
			for(int k = 0; k < N / 4; k++){
				for(int j = 0; j < 4; j++){
					unused_return = fscanf(fptr_a, "%lx\n", buffer_addr_temp);
					buffer_addr_temp++;
				}
				for(int j = 0; j < 4; j++){
					unused_return = fscanf(fptr_b, "%lx\n", buffer_addr_temp);
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
	
				ddr_addr = DDR_ADDR + test_case * 32 * 1024 * digitG;
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
	
				ddr_addr = DDR_ADDR + test_case * 32 * 1024 * digitG;
				ddr_addr = ddr_addr & ((1ULL << 34) - 1);
	    		rc = fpga_pci_poke(pci_bar_handle, ADDR_INST_IN, form_instruction(RLWESUBS, 0, 0, 0, (uint32_t)(ddr_addr >> 14)));
	    		fail_on(rc, out, "Unable to write to the fpga !");
			}
		}
	    printf("Finish writing four instructions to CL, waiting for the output RLWE to be nonempty\n");
	
	    printf("Reading in output RLWE ground truth\n");
		for(int test_case = 0; test_case < 2; test_case++){
			string path_shared = "/verif/tests/mem_init_content/top_verify/rlwesubs/bk";
			//open poly a file
			snprintf(file_path, sizeof(file_path), "%s%s/RLWESUBS_outputrlwe_2k_a%0d.mem", cl_dir, path_shared.c_str(), test_case);
			//printf("%s\n", file_path);	
			
			fptr_a = fopen(file_path, "r");
			if(fptr_a == NULL){
				fail_on(1, out, "Unable to open input rlwe poly a file, %0d", test_case);
			}
	
			//open poly b file
			snprintf(file_path, sizeof(file_path), "%s%s/RLWESUBS_outputrlwe_2k_b%0d.mem", cl_dir, path_shared.c_str(), test_case);
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
			for(int k = 0; k < N / 4; k++){
				for(int j = 0; j < 4; j++){
					unused_return = fscanf(fptr_a, "%lx\n", buffer_addr_temp);
					//printf("%16lx\n", *buffer_addr_temp);
					buffer_addr_temp++;
				}
				for(int j = 0; j < 4; j++){
					unused_return = fscanf(fptr_b, "%lx\n", buffer_addr_temp);
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
				//for(int k = 0; k < N * 2; k++){
				//	printf("%16lx\n", *(read_buffer + k));
				//}
				
				uint64_t differ;
				if(test_case == 0) 
					differ = buffer_compare((uint8_t*)read_buffer, (uint8_t*)output_buffer0, buffer_size);
				else 
					differ = buffer_compare((uint8_t*)read_buffer, (uint8_t*)output_buffer1, buffer_size);
	
	    		if (differ != 0) {
	    		    log_error("rlwesubs failed at loop: %d, test_case: %d, with %lu bytes which differ", rlwe_loop_counter, test_case, differ);
	    		    std::cout << "rlwesubs failed at loop: " << rlwe_loop_counter << ", test_case: " << test_case << "!" << std::endl;
	    			rc = 1;
	    		} else {
	    		    log_info("rlwesubs passed at loop:  %d, test_case: %d!", rlwe_loop_counter, test_case);
	    		    std::cout << "rlwesubs passed at loop: " << rlwe_loop_counter << ", test_case: " << test_case << "!" << std::endl;
	    		}
			}
		}
	    printf("Finish Transferring output RLWE from CL and comparing\n");
			
	out:
		std::cout << unused_return << std::endl;
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
	    if (write_fd >= 0) {
	        close(write_fd);
	    }
	    if (read_fd >= 0) {
	        close(read_fd);
	    }
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
	
		string path_shared;
		
		int unused_return = 0; 

		//setup to BAR0/OCL
	    /* pci_bar_handle_t is a handler for an address space exposed by one PCI BAR on one of the PCI PFs of the FPGA */
	    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;
	
		//allocate buffer
	    uint64_t *write_buffer = (uint64_t *) aligned_alloc(sz, buffer_size);	//try aligned address, if the buffer is page aligned than the dma awlen = 0x07, arlen = 0x3f
	    uint64_t *read_buffer = (uint64_t *) aligned_alloc(sz, buffer_size);
	    uint64_t *output_buffer = (uint64_t *) aligned_alloc(sz, buffer_size);
	    if (write_buffer == NULL || read_buffer == NULL || output_buffer == NULL) {
	        rc = -ENOMEM;
	        goto out;
	    }
	
	    printf("Memory has been allocated, initializing DMA and filling the buffer...\n");
	
	    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ true);
	    fail_on((rc = (read_fd < 0) ? -1 : 0), out, "unable to open read dma queue");
	
	    write_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ false);
	    fail_on((rc = (write_fd < 0) ? -1 : 0), out, "unable to open write dma queue");
	
	    /* attach to the fpga, with a pci_bar_handle out param
	     * To attach to multiple slots or BARs, call this function multiple times,
	     * saving the pci_bar_handle to specify which address space to interact with in
	     * other API calls.
	     * This function accepts the slot_id, physical function, and bar number
	     */
	    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);
	    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);
	
		cl_dir = getenv("CL_DIR");
		//printf("%s", cl_dir);	
		
	    printf("Transferring bootstrap key to DDR\n");
		for(int h = 0; h < 2; h++){
			for(int i = 0; i < (int)digitG; i++){
	
				string path_shared = "/verif/tests/mem_init_content/top_verify/bootstrap/bk";
				//open poly a file
				snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_inputrgsw_1k_rlwe_%0d_%0d_a.mem", cl_dir, path_shared.c_str(), i, h);
				//printf("%s\n", file_path);	
				
				fptr_a = fopen(file_path, "r");
				if(fptr_a == NULL){
					fail_on(1, out, "Unable to open key poly a file, %0d, %0d", i, h);
				}
	
				//open poly b file
				snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_inputrgsw_1k_rlwe_%0d_%0d_b.mem", cl_dir, path_shared.c_str(), i, h);
				//printf("%s\n", file_path);	
				
				fptr_b = fopen(file_path, "r");
				if(fptr_b == NULL){
					fail_on(1, out, "Unable to open key poly b file, %0d, %0d", i, h);
				}
				
				//fill the buffer with data read from files
				uint64_t* buffer_addr_temp = write_buffer;
				for(int k = 0; k < N / 4; k++){
					for(int j = 0; j < 4; j++){
						unused_return = fscanf(fptr_a, "%lx\n", buffer_addr_temp);
						buffer_addr_temp++;
					}
					for(int j = 0; j < 4; j++){
						unused_return = fscanf(fptr_b, "%lx\n", buffer_addr_temp);
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
	
		path_shared = "/verif/tests/mem_init_content/top_verify/bootstrap/bk";
	    printf("Reading in output RLWE ground truth\n");
		//open poly a file
		snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_outputrlwe_1k_a.mem", cl_dir, path_shared.c_str());
		//printf("%s\n", file_path);	
		
		fptr_a = fopen(file_path, "r");
		if(fptr_a == NULL){
			fail_on(1, out, "Unable to open output rlwe poly a file");
		}
	
		//open poly b file
		snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_outputrlwe_1k_b.mem", cl_dir, path_shared.c_str());
		//printf("%s\n", file_path);	
		
		fptr_b = fopen(file_path, "r");
		if(fptr_b == NULL){
			fail_on(1, out, "Unable to open output rlwe poly b file");
		}
		
		//fill the buffer with data read from files
		uint64_t* buffer_addr_temp;
		buffer_addr_temp = output_buffer;
		//printf("ground truth\n");
		for(int k = 0; k < N / 4; k++){
			for(int j = 0; j < 4; j++){
				unused_return = fscanf(fptr_a, "%lx\n", buffer_addr_temp);
				//printf("%16lx\n", *buffer_addr_temp);
				buffer_addr_temp++;
			}
			for(int j = 0; j < 4; j++){
				unused_return = fscanf(fptr_b, "%lx\n", buffer_addr_temp);
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
			//for(int k = 0; k < N * 2; k++){
			//	printf("%16lx\n", *(read_buffer + k));
			//}
			uint64_t differ;
			differ = buffer_compare((uint8_t*)read_buffer, (uint8_t*)output_buffer, buffer_size);
	    	if (differ != 0) {
	    	    log_error("bootstrap_init failed at loop: %d, with %lu bytes which differ", rlwe_loop_counter, differ);
	    	    std::cout << "bootstrap_init failed at loop: " <<  rlwe_loop_counter << std::endl;
	    		rc = 1;
	    	} else {
	    	    log_info("bootstrap_init passed at loop:  %d!", rlwe_loop_counter);
	    	    std::cout << "bootstrap_init passed at loop: " <<  rlwe_loop_counter << std::endl;
	    	}
		}
	    printf("Finish Transferring output RLWE from CL and comparing\n");
			
	out:
		std::cout << unused_return << std::endl;
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
	    if (write_fd >= 0) {
	        close(write_fd);
	    }
	    if (read_fd >= 0) {
	        close(read_fd);
	    }
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
	
		string path_shared;
	
		uint64_t* buffer_addr_temp;

		int unused_return = 0; 

		//setup to BAR0/OCL
	    /* pci_bar_handle_t is a handler for an address space exposed by one PCI BAR on one of the PCI PFs of the FPGA */
	    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;
	
		//allocate buffer
	    uint64_t *write_buffer = (uint64_t *) aligned_alloc(sz, buffer_size);	//try aligned address, if the buffer is page aligned than the dma awlen = 0x07, arlen = 0x3f
	    uint64_t *read_buffer = (uint64_t *) aligned_alloc(sz, buffer_size);
	    uint64_t *output_buffer = (uint64_t *) aligned_alloc(sz, buffer_size);
	    if (write_buffer == NULL || read_buffer == NULL || output_buffer == NULL) {
	        rc = -ENOMEM;
	        goto out;
	    }
	
	    printf("Memory has been allocated, initializing DMA and filling the buffer...\n");
	
	    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ true);
	    fail_on((rc = (read_fd < 0) ? -1 : 0), out, "unable to open read dma queue");
	
	    write_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ false);
	    fail_on((rc = (write_fd < 0) ? -1 : 0), out, "unable to open write dma queue");
	
		    
	    /* attach to the fpga, with a pci_bar_handle out param
	     * To attach to multiple slots or BARs, call this function multiple times,
	     * saving the pci_bar_handle to specify which address space to interact with in
	     * other API calls.
	     * This function accepts the slot_id, physical function, and bar number
	     */
	    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);
	    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);

		cl_dir = getenv("CL_DIR");
		//printf("%s", cl_dir);	
	
		printf("Transferring bootstrap key to DDR\n");
		for(int h = 0; h < 2; h++){
			for(int i = 0; i < (int)digitG; i++){
	
				string path_shared = "/verif/tests/mem_init_content/top_verify/bootstrap/bk";
				//open poly a file
				snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_inputrgsw_1k_rlwe_%0d_%0d_a.mem", cl_dir, path_shared.c_str(), i, h);
				//printf("%s\n", file_path);	
				
				fptr_a = fopen(file_path, "r");
				if(fptr_a == NULL){
					fail_on(1, out, "Unable to open key poly a file, %0d, %0d", i, h);
				}
	
				//open poly b file
				snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_inputrgsw_1k_rlwe_%0d_%0d_b.mem", cl_dir, path_shared.c_str(), i, h);
				//printf("%s\n", file_path);	
				
				fptr_b = fopen(file_path, "r");
				if(fptr_b == NULL){
					fail_on(1, out, "Unable to open key poly b file, %0d, %0d", i, h);
				}
				
				//fill the buffer with data read from files
				uint64_t* buffer_addr_temp = write_buffer;
				for(int k = 0; k < N / 4; k++){
					for(int j = 0; j < 4; j++){
						unused_return = fscanf(fptr_a, "%lx\n", buffer_addr_temp);
						buffer_addr_temp++;
					}
					for(int j = 0; j < 4; j++){
						unused_return = fscanf(fptr_b, "%lx\n", buffer_addr_temp);
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
		path_shared = "/verif/tests/mem_init_content/top_verify/bootstrap/bk";
		//open poly a file
		snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_inputrlwe_1k_a.mem", cl_dir, path_shared.c_str());
		//printf("%s\n", file_path);	
		
		fptr_a = fopen(file_path, "r");
		if(fptr_a == NULL){
			fail_on(1, out, "Unable to open input rlwe poly a file");
		}
	
		//open poly b file
		snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_inputrlwe_1k_b.mem", cl_dir, path_shared.c_str());
		//printf("%s\n", file_path);	
		
		fptr_b = fopen(file_path, "r");
		if(fptr_b == NULL){
			fail_on(1, out, "Unable to open input rlwe poly b file");
		}
		
		//fill the buffer with data read from files
		buffer_addr_temp = write_buffer;
	
		for(int k = 0; k < N / 4; k++){
			for(int j = 0; j < 4; j++){
				unused_return = fscanf(fptr_a, "%lx\n", buffer_addr_temp);
				buffer_addr_temp++;
			}
			for(int j = 0; j < 4; j++){
				unused_return = fscanf(fptr_b, "%lx\n", buffer_addr_temp);
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
		snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_outputrlwe_1k_a.mem", cl_dir, path_shared.c_str());
		//printf("%s\n", file_path);	
		
		fptr_a = fopen(file_path, "r");
		if(fptr_a == NULL){
			fail_on(1, out, "Unable to open output rlwe poly a file");
		}
	
		//open poly b file
		snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_outputrlwe_1k_b.mem", cl_dir, path_shared.c_str());
		//printf("%s\n", file_path);	
		
		fptr_b = fopen(file_path, "r");
		if(fptr_b == NULL){
			fail_on(1, out, "Unable to open output rlwe poly b file");
		}
	
		//fill the buffer with data read from files
		buffer_addr_temp = output_buffer;
		for(int k = 0; k < N / 4; k++){
			for(int j = 0; j < 4; j++){
				unused_return = fscanf(fptr_a, "%lx\n", buffer_addr_temp);
				buffer_addr_temp++;
			}
			for(int j = 0; j < 4; j++){
				unused_return = fscanf(fptr_b, "%lx\n", buffer_addr_temp);
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
	    	    std::cout << "bootstrap failed at loop: " << rlwe_loop_counter << std::endl;
	    		rc = 1;
	    	} else {
	    	    log_info("bootstrap passed at loop:  %d!", rlwe_loop_counter);
	    	    std::cout << "bootstrap passed at loop: " << rlwe_loop_counter << std::endl;
	    	}
		}
	    printf("Finish Transferring output RLWE from CL and comparing\n");
			
	out:
		std::cout << unused_return << std::endl;
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
	    if (write_fd >= 0) {
	        close(write_fd);
	    }
	    if (read_fd >= 0) {
	        close(read_fd);
	    }
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
	
		string path_shared;

		uint64_t* buffer_addr_temp;

		int unused_return = 0;
		
		//setup to BAR0/OCL
	    /* pci_bar_handle_t is a handler for an address space exposed by one PCI BAR on one of the PCI PFs of the FPGA */
	    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;
	
		//allocate buffer
	    uint64_t *write_buffer = (uint64_t *) aligned_alloc(sz, buffer_size);	//try aligned address, if the buffer is page aligned than the dma awlen = 0x07, arlen = 0x3f
	    uint64_t *read_buffer = (uint64_t *) aligned_alloc(sz, buffer_size);
	    uint64_t *output_buffer = (uint64_t *) aligned_alloc(sz, buffer_size);
	    if (write_buffer == NULL || read_buffer == NULL || output_buffer == NULL) {
	        rc = -ENOMEM;
	        goto out;
	    }
	
	    printf("Memory has been allocated, initializing DMA and filling the buffer...\n");
	
	    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ true);
	    fail_on((rc = (read_fd < 0) ? -1 : 0), out, "unable to open read dma queue");
	
	    write_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id, /*channel*/ 0, /*is_read*/ false);
	    fail_on((rc = (write_fd < 0) ? -1 : 0), out, "unable to open write dma queue");
		    
	    /* attach to the fpga, with a pci_bar_handle out param
	     * To attach to multiple slots or BARs, call this function multiple times,
	     * saving the pci_bar_handle to specify which address space to interact with in
	     * other API calls.
	     * This function accepts the slot_id, physical function, and bar number
	     */
	    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);
	    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);
	
		cl_dir = getenv("CL_DIR");
		//printf("%s", cl_dir);	
	
		printf("Transferring bootstrap key to DDR\n");
		for(int h = 0; h < 2; h++){
			for(int i = 0; i < (int)digitG; i++){
	
				string path_shared = "/verif/tests/mem_init_content/top_verify/bootstrap/bk";
				//open poly a file
				snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_inputrgsw_1k_rlwe_%0d_%0d_a.mem", cl_dir, path_shared.c_str(), i, h);
				//printf("%s\n", file_path);	
				
				fptr_a = fopen(file_path, "r");
				if(fptr_a == NULL){
					fail_on(1, out, "Unable to open key poly a file, %0d, %0d", i, h);
				}
	
				//open poly b file
				snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_inputrgsw_1k_rlwe_%0d_%0d_b.mem", cl_dir, path_shared.c_str(), i, h);
				//printf("%s\n", file_path);	
				
				fptr_b = fopen(file_path, "r");
				if(fptr_b == NULL){
					fail_on(1, out, "Unable to open key poly b file, %0d, %0d", i, h);
				}
				
				//fill the buffer with data read from files
				uint64_t* buffer_addr_temp = write_buffer;
				for(int k = 0; k < N / 4; k++){
					for(int j = 0; j < 4; j++){
						unused_return = fscanf(fptr_a, "%lx\n", buffer_addr_temp);
						buffer_addr_temp++;
					}
					for(int j = 0; j < 4; j++){
						unused_return = fscanf(fptr_b, "%lx\n", buffer_addr_temp);
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
		path_shared = "/verif/tests/mem_init_content/top_verify/bootstrap/bk";
		//open poly a file
		snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_inputrlwe_1k_a.mem", cl_dir, path_shared.c_str());
		//printf("%s\n", file_path);	
		
		fptr_a = fopen(file_path, "r");
		if(fptr_a == NULL){
			fail_on(1, out, "Unable to open input rlwe poly a file");
		}
	
		//open poly b file
		snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_inputrlwe_1k_b.mem", cl_dir, path_shared.c_str());
		//printf("%s\n", file_path);	
		
		fptr_b = fopen(file_path, "r");
		if(fptr_b == NULL){
			fail_on(1, out, "Unable to open input rlwe poly b file");
		}
		
		//fill the buffer with data read from files
		buffer_addr_temp = write_buffer;
	
		for(int k = 0; k < N / 4; k++){
			for(int j = 0; j < 4; j++){
				unused_return = fscanf(fptr_a, "%lx\n", buffer_addr_temp);
				buffer_addr_temp++;
			}
			for(int j = 0; j < 4; j++){
				unused_return = fscanf(fptr_b, "%lx\n", buffer_addr_temp);
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
		snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_outputrlwe_1k_a.mem", cl_dir, path_shared.c_str());
		//printf("%s\n", file_path);	
		
		fptr_a = fopen(file_path, "r");
		if(fptr_a == NULL){
			fail_on(1, out, "Unable to open output rlwe poly a file");
		}
	
		//open poly b file
		snprintf(file_path, sizeof(file_path), "%s%s/RLWExRGSW_outputrlwe_1k_b.mem", cl_dir, path_shared.c_str());
		//printf("%s\n", file_path);	
		
		fptr_b = fopen(file_path, "r");
		if(fptr_b == NULL){
			fail_on(1, out, "Unable to open output rlwe poly b file");
		}
	
		//fill the buffer with data read from files
		buffer_addr_temp = output_buffer;
		for(int k = 0; k < N / 4; k++){
			for(int j = 0; j < 4; j++){
				unused_return = fscanf(fptr_a, "%lx\n", buffer_addr_temp);
				buffer_addr_temp++;
			}
			for(int j = 0; j < 4; j++){
				unused_return = fscanf(fptr_b, "%lx\n", buffer_addr_temp);
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
			//for(int k = 0; k < N * 2; k++){
			//	printf("%16lx\n", *(read_buffer + k));
			//}
			uint64_t differ;
			differ = buffer_compare((uint8_t*)read_buffer, (uint8_t*)output_buffer, buffer_size);
	
	    	if (differ != 0) {
	    	    log_error("rlwe mult rgsw failed at loop: %d, with %lu bytes which differ", rlwe_loop_counter, differ);
	    	    std::cout << "rlwe mult rgsw failed at loop: " << rlwe_loop_counter << std::endl;
	    		rc = 1;
	    	} else {
	    	    log_info("rlwe mult rgsw passed at loop:  %d!", rlwe_loop_counter);
	    	    std::cout << "rlwe mult rgsw passed at loop: " << rlwe_loop_counter << std::endl;
	    	}
		}
	    printf("Finish Transferring output RLWE from CL and comparing\n");
			
	out:
		std::cout << unused_return << std::endl;
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
	    if (write_fd >= 0) {
	        close(write_fd);
	    }
	    if (read_fd >= 0) {
	        close(read_fd);
	    }
		if(rc != 0) 
			printf("rlwe mult rgsw case failed!\n");
		else
			printf("rlwe mult rgsw case passed!\n");
	    /* if there is an error code, exit with status 1 */
	    return (rc != 0 ? 1 : 0);
	}
}
