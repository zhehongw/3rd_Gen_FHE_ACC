# This contains the CL specific constraints for synthesis at the CL level


set_property MAX_FANOUT 50 [get_nets -of_objects [get_pins SH_DDR/ddr_cores.DDR4_0/inst/div_clk_rst_r1_reg/Q]]
#set_property MAX_FANOUT 50 [get_nets -of_objects [get_pins CL_PCIM_MSTR/CL_TST_PCI/sync_rst_n_reg/Q]]

#for synth
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/q_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/m_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/k2_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/length_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/ilength_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/log2_len_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/BG_mask_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/digitG_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/BG_width_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/lwe_q_mask_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/embed_factor_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/top_fifo_mode_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/or_bound1_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/and_bound1_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/nor_bound1_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/nand_bound1_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/xor_bound1_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/xnor_bound1_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/or_bound2_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/and_bound2_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/nor_bound2_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/nand_bound2_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/xor_bound2_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/xnor_bound2_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0

#set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/ROB_full.* -filter {DIRECTION == IN}]
#set_false_path -through $_xlnx_shared_i0
#set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/ROB_empty.* -filter {DIRECTION == IN}]
#set_false_path -through $_xlnx_shared_i0
#set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/key_load_fifo_full.* -filter {DIRECTION == IN}]
#set_false_path -through $_xlnx_shared_i0
#set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/key_load_fifo_empty.* -filter {DIRECTION == IN}]
#set_false_path -through $_xlnx_shared_i0
#set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/RLWE_input_FIFO_full.* -filter {DIRECTION == IN}]
#set_false_path -through $_xlnx_shared_i0
#set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/RLWE_input_FIFO_empty.* -filter {DIRECTION == IN}]
#set_false_path -through $_xlnx_shared_i0
#set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/RLWE_output_FIFO_full.* -filter {DIRECTION == IN}]
#set_false_path -through $_xlnx_shared_i0
#set _xlnx_shared_i0 [get_pins -regexp .*FHE_ACC_TOP/AXIL_OCL_SLV/RLWE_output_FIFO_empty.* -filter {DIRECTION == IN}]
#set_false_path -through $_xlnx_shared_i0

#set _xlnx_shared_i0 [get_nets -hierarchical -regexp .*FHE_ACC_TOP/config_signals.*]
#set_false_path -through $_xlnx_shared_i0
#for impl
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/q_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/m_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/k2_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/length_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/ilength_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/log2_len_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/BG_mask_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/digitG_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/BG_width_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/lwe_q_mask_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/embed_factor_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/top_fifo_mode_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/or_bound1_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/and_bound1_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/nor_bound1_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/nand_bound1_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/xor_bound1_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/xnor_bound1_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/or_bound2_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/and_bound2_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/nor_bound2_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/nand_bound2_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/xor_bound2_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0
set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/xnor_bound2_out.* -filter {DIRECTION == OUT}]
set_false_path -through $_xlnx_shared_i0

#set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/ROB_full.* -filter {DIRECTION == IN}]
#set_false_path -through $_xlnx_shared_i0
#set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/ROB_empty.* -filter {DIRECTION == IN}]
#set_false_path -through $_xlnx_shared_i0
#set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/key_load_fifo_full.* -filter {DIRECTION == IN}]
#set_false_path -through $_xlnx_shared_i0
#set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/key_load_fifo_empty.* -filter {DIRECTION == IN}]
#set_false_path -through $_xlnx_shared_i0
#set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/RLWE_input_FIFO_full.* -filter {DIRECTION == IN}]
#set_false_path -through $_xlnx_shared_i0
#set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/RLWE_input_FIFO_empty.* -filter {DIRECTION == IN}]
#set_false_path -through $_xlnx_shared_i0
#set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/RLWE_output_FIFO_full.* -filter {DIRECTION == IN}]
#set_false_path -through $_xlnx_shared_i0
#set _xlnx_shared_i0 [get_pins -regexp WRAPPER_INST/CL/FHE_ACC_TOP/AXIL_OCL_SLV/RLWE_output_FIFO_empty.* -filter {DIRECTION == IN}]
#set_false_path -through $_xlnx_shared_i0
