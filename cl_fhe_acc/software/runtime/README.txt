The AWS hdk can only access OCL in hw/sw cosim. The following three files should be hacked to include BAR1 or other BARs.

$HDK_DIR/common/verif/include/sh_dpi_tasks.svh
$HDK_DIR/common/software/include/fpga_pci_sv.h 
$HDK_DIR/common/software/src/fpga_pci_sv.c

