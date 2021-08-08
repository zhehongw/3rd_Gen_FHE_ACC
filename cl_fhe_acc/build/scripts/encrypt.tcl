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

# TODO:
# Add check if CL_DIR and HDK_SHELL_DIR directories exist
# Add check if /build and /build/src_port_encryption directories exist
# Add check if the vivado_keyfile exist

set HDK_SHELL_DIR $::env(HDK_SHELL_DIR)
set HDK_SHELL_DESIGN_DIR $::env(HDK_SHELL_DESIGN_DIR)
set CL_DIR $::env(CL_DIR)

set TARGET_DIR $CL_DIR/build/src_post_encryption
set UNUSED_TEMPLATES_DIR $HDK_SHELL_DESIGN_DIR/interfaces


# Remove any previously encrypted files, that may no longer be used
if {[llength [glob -nocomplain -dir $TARGET_DIR *]] != 0} {
  eval file delete -force [glob $TARGET_DIR/*]
}

#---- Developr would replace this section with design files ----

## Change file names and paths below to reflect your CL area.  DO NOT include AWS RTL files.
file copy -force $CL_DIR/design/src_aws_top/cl_aws_top_defines.vh 	$TARGET_DIR
file copy -force $CL_DIR/design/src/common.vh	$TARGET_DIR
file copy -force $CL_DIR/design/src_aws_top/cl_id_defines.vh       	$TARGET_DIR
file copy -force $UNUSED_TEMPLATES_DIR/unused_ddr_c_template.inc 	$TARGET_DIR
file copy -force $UNUSED_TEMPLATES_DIR/unused_pcim_template.inc 	$TARGET_DIR
file copy -force $UNUSED_TEMPLATES_DIR/unused_cl_sda_template.inc 	$TARGET_DIR
file copy -force $UNUSED_TEMPLATES_DIR/unused_apppf_irq_template.inc $TARGET_DIR

#file copy -force $CL_DIR/design/src_4_iNTT_5_mult_pipe_stage/my_dma_axi_xbar/ip/my_dma_axi_xbar_m00_regslice_0/synth/my_dma_axi_xbar_m00_regslice_0.v	$TARGET_DIR
#file copy -force $CL_DIR/design/src_4_iNTT_5_mult_pipe_stage/my_dma_axi_xbar/ip/my_dma_axi_xbar_m01_regslice_0/synth/my_dma_axi_xbar_m01_regslice_0.v	$TARGET_DIR
#file copy -force $CL_DIR/design/src_4_iNTT_5_mult_pipe_stage/my_dma_axi_xbar/ip/my_dma_axi_xbar_m02_regslice_0/synth/my_dma_axi_xbar_m02_regslice_0.v	$TARGET_DIR
#file copy -force $CL_DIR/design/src_4_iNTT_5_mult_pipe_stage/my_dma_axi_xbar/ip/my_dma_axi_xbar_s00_regslice_0/synth/my_dma_axi_xbar_s00_regslice_0.v	$TARGET_DIR
#file copy -force $CL_DIR/design/src_4_iNTT_5_mult_pipe_stage/my_dma_axi_xbar/ip/my_dma_axi_xbar_s01_regslice_0/synth/my_dma_axi_xbar_s01_regslice_0.v	$TARGET_DIR
#file copy -force $CL_DIR/design/src_4_iNTT_5_mult_pipe_stage/my_dma_axi_xbar/ip/my_dma_axi_xbar_xbar_0/synth/my_dma_axi_xbar_xbar_0.v	$TARGET_DIR

#file copy -force $CL_DIR/design/src_4_iNTT_5_mult_pipe_stage/my_dma_axi_xbar/synth/my_dma_axi_xbar.v 	$TARGET_DIR
file copy -force $CL_DIR/design/src/interface_defines.sv		   	$TARGET_DIR
file copy -force $CL_DIR/design/src/pipeline.sv						$TARGET_DIR
file copy -force $CL_DIR/design/src/mod_add.sv						$TARGET_DIR
file copy -force $CL_DIR/design/src/mod_mult.sv						$TARGET_DIR
file copy -force $CL_DIR/design/src/mod_sub.sv						$TARGET_DIR
file copy -force $CL_DIR/design/src/barrel_shifter.sv				$TARGET_DIR
file copy -force $CL_DIR/design/src/poly_ram_block_byte_en.sv		$TARGET_DIR
file copy -force $CL_DIR/design/src/poly_ram_block.sv				$TARGET_DIR
file copy -force $CL_DIR/design/src/myFIFO_global_poly_input.sv		$TARGET_DIR
file copy -force $CL_DIR/design/src/myFIFO_global_poly_output.sv	$TARGET_DIR
file copy -force $CL_DIR/design/src/myFIFO_iNTT.sv					$TARGET_DIR
file copy -force $CL_DIR/design/src/myFIFO_key_loading.sv			$TARGET_DIR
file copy -force $CL_DIR/design/src/myFIFO_NTT.sv					$TARGET_DIR
file copy -force $CL_DIR/design/src/myFIFO_subs.sv					$TARGET_DIR
file copy -force $CL_DIR/design/src/iROU_buffer.sv					$TARGET_DIR
file copy -force $CL_DIR/design/src/ROU_buffer.sv					$TARGET_DIR
file copy -force $CL_DIR/design/src/accumulator.sv					$TARGET_DIR
file copy -force $CL_DIR/design/src/axil_bar1_slave.sv				$TARGET_DIR
file copy -force $CL_DIR/design/src/axil_ocl_slave.sv				$TARGET_DIR
file copy -force $CL_DIR/design/src/cl_dma_pcis_slv.sv				$TARGET_DIR
file copy -force $CL_DIR/design/src/CT_butterfly.sv					$TARGET_DIR
file copy -force $CL_DIR/design/src/DMA_AXI_to_input_poly_FIFO.sv	$TARGET_DIR
file copy -force $CL_DIR/design/src/DMA_AXI_to_output_poly_FIFO.sv	$TARGET_DIR
file copy -force $CL_DIR/design/src/GS_butterfly.sv					$TARGET_DIR
file copy -force $CL_DIR/design/src/iNTT_module.sv					$TARGET_DIR
file copy -force $CL_DIR/design/src/key_load_module.sv				$TARGET_DIR
file copy -force $CL_DIR/design/src/NTT_leading_stage.sv			$TARGET_DIR
file copy -force $CL_DIR/design/src/NTT_stage.sv					$TARGET_DIR
file copy -force $CL_DIR/design/src/poly_mult_RLWE.sv				$TARGET_DIR
file copy -force $CL_DIR/design/src/RLWE_input_FIFO.sv				$TARGET_DIR
file copy -force $CL_DIR/design/src/RLWE_output_FIFO.sv				$TARGET_DIR
file copy -force $CL_DIR/design/src/ROB.sv							$TARGET_DIR
file copy -force $CL_DIR/design/src/subs_module.sv					$TARGET_DIR

file copy -force $CL_DIR/design/src/NTT_top.sv						$TARGET_DIR
file copy -force $CL_DIR/design/src/acc_top.sv						$TARGET_DIR
file copy -force $CL_DIR/design/src/compute_chain_top.sv			$TARGET_DIR
file copy -force $CL_DIR/design/src/fhe_acc_top.sv					$TARGET_DIR
file copy -force $CL_DIR/design/src/cl_ila.sv						$TARGET_DIR
file copy -force $CL_DIR/design/src_aws_top/cl_fhe_acc_top.sv		$TARGET_DIR

#---- End of section replaced by Developer ---



# Make sure files have write permissions for the encryption

exec chmod +w {*}[glob $TARGET_DIR/*]

set TOOL_VERSION $::env(VIVADO_TOOL_VERSION)
set vivado_version [string range [version -short] 0 5]
puts "AWS FPGA: VIVADO_TOOL_VERSION $TOOL_VERSION"
puts "vivado_version $vivado_version"

# encrypt .v/.sv/.vh/inc as verilog files
#encrypt -k $HDK_SHELL_DIR/build/scripts/vivado_keyfile_2017_4.txt -lang verilog  [glob -nocomplain -- $TARGET_DIR/*.{v,sv}] [glob -nocomplain -- $TARGET_DIR/*.vh] [glob -nocomplain -- $TARGET_DIR/*.inc]
encrypt -k $HDK_SHELL_DIR/build/scripts/vivado_keyfile_2017_4.txt -lang verilog  [glob -nocomplain -- $TARGET_DIR/*.{v,sv}] [glob -nocomplain -- $TARGET_DIR/*.vh] 
# encrypt *vhdl files
#encrypt -k $HDK_SHELL_DIR/build/scripts/vivado_vhdl_keyfile_2017_4.txt -lang vhdl -quiet [ glob -nocomplain -- $TARGET_DIR/*.vhd? ]
