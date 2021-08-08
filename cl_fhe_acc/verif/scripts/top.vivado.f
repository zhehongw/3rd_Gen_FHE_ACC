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

--define VIVADO_SIM

--sourcelibext .v
--sourcelibext .sv
--sourcelibext .svh
--sourcelibext .vh

--sourcelibdir ${CL_ROOT}/design/src
--sourcelibdir ${CL_ROOT}/design/src_aws_top
--sourcelibdir ${SH_LIB_DIR}
--sourcelibdir ${SH_INF_DIR}
--sourcelibdir ${HDK_SHELL_DESIGN_DIR}/sh_ddr/sim

--include ${CL_ROOT}/../common/design
--include ${CL_ROOT}/design/src
--include ${CL_ROOT}/design/src_aws_top
#--include ${CL_ROOT}/verif/test/aws_tests
--include ${CL_ROOT}/verif/test/mem_init_content/bk
--include ${CL_ROOT}/verif/test/mem_init_content/top_verify/rlwesubs/bk
--include ${CL_ROOT}/verif/test/mem_init_content/top_verify/bootstrap/bk

--include ${SH_LIB_DIR}
--include ${SH_INF_DIR}
--include ${HDK_COMMON_DIR}/verif/include
--include ${HDK_SHELL_DESIGN_DIR}/ip/cl_debug_bridge/bd_0/ip/ip_0/sim
--include ${HDK_SHELL_DESIGN_DIR}/ip/cl_debug_bridge/bd_0/ip/ip_0/hdl/verilog
--include ${HDK_SHELL_DESIGN_DIR}/ip/axi_register_slice/hdl
--include ${HDK_SHELL_DESIGN_DIR}/ip/axi_register_slice_light/hdl
--include ${CL_ROOT}/design/src/my_dma_axi_xbar/sim
--include ${HDK_SHELL_DESIGN_DIR}/ip/cl_axi_interconnect/ipshared/7e3a/hdl
--include ${HDK_SHELL_DESIGN_DIR}/sh_ddr/sim

-f ${HDK_COMMON_DIR}/verif/tb/filelists/tb.${SIMULATOR}.f
${TEST_NAME}

${CL_ROOT}/design/src_aws_top/cl_aws_top_defines.vh
${CL_ROOT}/design/src/common.vh
${CL_ROOT}/design/src_aws_top/cl_id_defines.vh

${HDK_SHELL_DESIGN_DIR}/ip/axi_clock_converter_0/sim/axi_clock_converter_0.v
${HDK_SHELL_DESIGN_DIR}/ip/dest_register_slice/sim/dest_register_slice.v
${HDK_SHELL_DESIGN_DIR}/ip/src_register_slice/sim/src_register_slice.v
${HDK_SHELL_DESIGN_DIR}/ip/axi_register_slice/sim/axi_register_slice.v
${HDK_SHELL_DESIGN_DIR}/ip/axi_register_slice_light/sim/axi_register_slice_light.v

#my axi xbar
${CL_ROOT}/design/src/my_dma_axi_xbar/ipshared/276e/hdl/fifo_generator_v13_2_rfs.v 
${CL_ROOT}/design/src/my_dma_axi_xbar/ipshared/2ef9/hdl/axi_register_slice_v2_1_vl_rfs.v
${CL_ROOT}/design/src/my_dma_axi_xbar/ipshared/47c9/hdl/axi_data_fifo_v2_1_vl_rfs.v
${CL_ROOT}/design/src/my_dma_axi_xbar/ipshared/b68e/hdl/axi_crossbar_v2_1_vl_rfs.v
${CL_ROOT}/design/src/my_dma_axi_xbar/ip/my_dma_axi_xbar_m00_regslice_0/sim/my_dma_axi_xbar_m00_regslice_0.v
${CL_ROOT}/design/src/my_dma_axi_xbar/ip/my_dma_axi_xbar_m01_regslice_0/sim/my_dma_axi_xbar_m01_regslice_0.v
${CL_ROOT}/design/src/my_dma_axi_xbar/ip/my_dma_axi_xbar_m02_regslice_0/sim/my_dma_axi_xbar_m02_regslice_0.v
${CL_ROOT}/design/src/my_dma_axi_xbar/ip/my_dma_axi_xbar_s00_regslice_0/sim/my_dma_axi_xbar_s00_regslice_0.v
${CL_ROOT}/design/src/my_dma_axi_xbar/ip/my_dma_axi_xbar_s01_regslice_0/sim/my_dma_axi_xbar_s01_regslice_0.v
${CL_ROOT}/design/src/my_dma_axi_xbar/ip/my_dma_axi_xbar_xbar_0/sim/my_dma_axi_xbar_xbar_0.v
${CL_ROOT}/design/src/my_dma_axi_xbar/sim/my_dma_axi_xbar.v

${HDK_SHELL_DESIGN_DIR}/ip/cl_axi_interconnect/ipshared/9909/hdl/axi_data_fifo_v2_1_vl_rfs.v
${HDK_SHELL_DESIGN_DIR}/ip/cl_axi_interconnect/ipshared/c631/hdl/axi_crossbar_v2_1_vl_rfs.v
${HDK_SHELL_DESIGN_DIR}/ip/cl_axi_interconnect/ip/cl_axi_interconnect_xbar_0/sim/cl_axi_interconnect_xbar_0.v
${HDK_SHELL_DESIGN_DIR}/ip/cl_axi_interconnect/ip/cl_axi_interconnect_s00_regslice_0/sim/cl_axi_interconnect_s00_regslice_0.v
${HDK_SHELL_DESIGN_DIR}/ip/cl_axi_interconnect/ip/cl_axi_interconnect_s01_regslice_0/sim/cl_axi_interconnect_s01_regslice_0.v
${HDK_SHELL_DESIGN_DIR}/ip/cl_axi_interconnect/ip/cl_axi_interconnect_m00_regslice_0/sim/cl_axi_interconnect_m00_regslice_0.v
${HDK_SHELL_DESIGN_DIR}/ip/cl_axi_interconnect/ip/cl_axi_interconnect_m01_regslice_0/sim/cl_axi_interconnect_m01_regslice_0.v
${HDK_SHELL_DESIGN_DIR}/ip/cl_axi_interconnect/ip/cl_axi_interconnect_m02_regslice_0/sim/cl_axi_interconnect_m02_regslice_0.v
${HDK_SHELL_DESIGN_DIR}/ip/cl_axi_interconnect/ip/cl_axi_interconnect_m03_regslice_0/sim/cl_axi_interconnect_m03_regslice_0.v
${HDK_SHELL_DESIGN_DIR}/ip/cl_axi_interconnect/sim/cl_axi_interconnect.v
${HDK_SHELL_DESIGN_DIR}/ip/dest_register_slice/hdl/axi_register_slice_v2_1_vl_rfs.v
${HDK_SHELL_DESIGN_DIR}/ip/axi_clock_converter_0/hdl/axi_clock_converter_v2_1_vl_rfs.v
${HDK_SHELL_DESIGN_DIR}/ip/axi_clock_converter_0/hdl/fifo_generator_v13_2_rfs.v


${HDK_COMMON_DIR}/verif/models/ddr4_rdimm_wrapper/ddr4_bi_delay.sv
${HDK_COMMON_DIR}/verif/models/ddr4_rdimm_wrapper/ddr4_db_delay_model.sv
${HDK_COMMON_DIR}/verif/models/ddr4_rdimm_wrapper/ddr4_db_dly_dir.sv
${HDK_COMMON_DIR}/verif/models/ddr4_rdimm_wrapper/ddr4_dir_detect.sv
${HDK_COMMON_DIR}/verif/models/ddr4_rdimm_wrapper/ddr4_rcd_model.sv
${HDK_COMMON_DIR}/verif/models/ddr4_rdimm_wrapper/ddr4_rank.sv
${HDK_COMMON_DIR}/verif/models/ddr4_rdimm_wrapper/ddr4_dimm.sv
${HDK_COMMON_DIR}/verif/models/ddr4_rdimm_wrapper/ddr4_rdimm_wrapper.sv 
${SH_LIB_DIR}/bram_2rw.sv
${SH_LIB_DIR}/flop_fifo.sv
${SH_LIB_DIR}/lib_pipe.sv
${HDK_SHELL_DESIGN_DIR}/sh_ddr/sim/mgt_gen_axl.sv
${HDK_SHELL_DESIGN_DIR}/sh_ddr/sim/ccf_ctl.v
${HDK_SHELL_DESIGN_DIR}/sh_ddr/sim/mgt_acc_axl.sv
${HDK_SHELL_DESIGN_DIR}/sh_ddr/sim/sync.v
${HDK_SHELL_DESIGN_DIR}/sh_ddr/sim/flop_ccf.sv
${HDK_SHELL_DESIGN_DIR}/sh_ddr/sim/sh_ddr.sv


--define DISABLE_VJTAG_DEBUG
${CL_ROOT}/design/src/interface_defines.sv
${CL_ROOT}/design/src/pipeline.sv
${CL_ROOT}/design/src/mod_add.sv
${CL_ROOT}/design/src/mod_mult.sv
${CL_ROOT}/design/src/mod_sub.sv
${CL_ROOT}/design/src/cl_ila.sv
${CL_ROOT}/design/src/barrel_shifter.sv
${CL_ROOT}/design/src/poly_ram_block_byte_en.sv
${CL_ROOT}/design/src/poly_ram_block.sv
${CL_ROOT}/design/src/myFIFO_global_poly_input.sv
${CL_ROOT}/design/src/myFIFO_global_poly_output.sv
${CL_ROOT}/design/src/myFIFO_iNTT.sv
${CL_ROOT}/design/src/myFIFO_key_loading.sv
${CL_ROOT}/design/src/myFIFO_NTT.sv
${CL_ROOT}/design/src/myFIFO_subs.sv
${CL_ROOT}/design/src/iROU_buffer.sv
${CL_ROOT}/design/src/ROU_buffer.sv
${CL_ROOT}/design/src/accumulator.sv
${CL_ROOT}/design/src/axil_bar1_slave.sv
${CL_ROOT}/design/src/axil_ocl_slave.sv
${CL_ROOT}/design/src/cl_dma_pcis_slv.sv
${CL_ROOT}/design/src/CT_butterfly.sv
${CL_ROOT}/design/src/DMA_AXI_to_input_poly_FIFO.sv
${CL_ROOT}/design/src/DMA_AXI_to_output_poly_FIFO.sv
${CL_ROOT}/design/src/GS_butterfly.sv
${CL_ROOT}/design/src/iNTT_module.sv
${CL_ROOT}/design/src/key_load_module.sv
${CL_ROOT}/design/src/NTT_leading_stage.sv
${CL_ROOT}/design/src/NTT_stage.sv
${CL_ROOT}/design/src/poly_mult_RLWE.sv
${CL_ROOT}/design/src/RLWE_input_FIFO.sv
${CL_ROOT}/design/src/RLWE_output_FIFO.sv
${CL_ROOT}/design/src/ROB.sv
${CL_ROOT}/design/src/subs_module.sv

${CL_ROOT}/design/src/NTT_top.sv
${CL_ROOT}/design/src/compute_chain_top.sv
${CL_ROOT}/design/src/acc_top.sv
${CL_ROOT}/design/src/fhe_acc_top.sv
${CL_ROOT}/design/src_aws_top/cl_fhe_acc_top.sv
