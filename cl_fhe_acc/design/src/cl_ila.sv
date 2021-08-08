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

module cl_ila #(
    parameter STAGES = $clog2(`MAX_LEN)
)(
	input aclk,
	
	input drck,
	input shift,
	input tdi,
	input update,
	input sel,
	output logic tdo,
	input tms,
	input tck,
	input runtest,
	input reset,
	input capture,
	input bscanid_en,

	//debug ports to ila
	input [2:0] 			lcl_sh_cl_ddr_is_ready,
	ROU_config_if 			rou_wr_port [0 : STAGES - 1],
	ROU_config_if 			irou_wr_port,
	axi_bus_if				sh_cl_dma_pcis_q,
	axi_bus_if 				lcl_cl_sh_ddrb_q3,
	axi_bus_if 				lcl_cl_sh_RLWE_input_FIFO_q3,
	axi_bus_if 				lcl_cl_sh_RLWE_output_FIFO_q3,
	axi_bus_if 				fhe_core_ddr_master_bus_q2
);

//---------------------------- 
// Debug bridge
//---------------------------- 
 cl_debug_bridge CL_DEBUG_BRIDGE (
	.clk(aclk),
	.S_BSCAN_drck(drck),
	.S_BSCAN_shift(shift),
	.S_BSCAN_tdi(tdi),
	.S_BSCAN_update(update),
	.S_BSCAN_sel(sel),
	.S_BSCAN_tdo(tdo),
	.S_BSCAN_tms(tms),
	.S_BSCAN_tck(tck),
	.S_BSCAN_runtest(runtest),
	.S_BSCAN_reset(reset),
	.S_BSCAN_capture(capture),
	.S_BSCAN_bscanid_en(bscanid_en)
);

//---------------------------- 
// Debug Core ILA for dmm pcis AXI4 interface 
//---------------------------- 
ila_1 CL_DMA_ILA_0 (
	.clk    (aclk),
	.probe0 (sh_cl_dma_pcis_q.awvalid),
	.probe1 (sh_cl_dma_pcis_q.awaddr),
	.probe2 (2'b0),
	.probe3 (sh_cl_dma_pcis_q.awready),
	.probe4 (sh_cl_dma_pcis_q.wvalid),
	.probe5 (sh_cl_dma_pcis_q.wstrb),
	.probe6 (sh_cl_dma_pcis_q.wlast),
	.probe7 (sh_cl_dma_pcis_q.wready),
	.probe8 (1'b0),
	.probe9 (1'b0),
	.probe10 (sh_cl_dma_pcis_q.wdata),
	.probe11 (1'b0),
	.probe12 (sh_cl_dma_pcis_q.arready),
	.probe13 (2'b0),
	.probe14 (sh_cl_dma_pcis_q.rdata),
	.probe15 (sh_cl_dma_pcis_q.araddr),
	.probe16 (sh_cl_dma_pcis_q.arvalid),
	.probe17 (3'b0),
	.probe18 (3'b0),
	.probe19 (sh_cl_dma_pcis_q.awid),
	.probe20 (sh_cl_dma_pcis_q.arid),
	.probe21 (sh_cl_dma_pcis_q.awlen),
	.probe22 (sh_cl_dma_pcis_q.rlast),
	.probe23 (3'b0), 
	.probe24 (sh_cl_dma_pcis_q.rresp),
	.probe25 (sh_cl_dma_pcis_q.rid),
	.probe26 (sh_cl_dma_pcis_q.rvalid),
	.probe27 (sh_cl_dma_pcis_q.arlen),
	.probe28 (3'b0),
	.probe29 (sh_cl_dma_pcis_q.bresp),
	.probe30 (sh_cl_dma_pcis_q.rready),
	.probe31 (4'b0),
	.probe32 (4'b0),
	.probe33 (4'b0),
	.probe34 (4'b0),
	.probe35 (sh_cl_dma_pcis_q.bvalid),
	.probe36 (4'b0),
	.probe37 (4'b0),
	.probe38 (sh_cl_dma_pcis_q.bid),
	.probe39 (sh_cl_dma_pcis_q.bready),
	.probe40 (1'b0),
	.probe41 (1'b0),
	.probe42 (1'b0),
	.probe43 (1'b0)
);

//---------------------------- 
// Debug Core ILA for DDRB AXI4 interface monitoring 
//---------------------------- 
ila_1 CL_DDRB_ILA_0 (
	.clk    (aclk),
	.probe0 (lcl_cl_sh_ddrb_q3.awvalid),
	.probe1 (lcl_cl_sh_ddrb_q3.awaddr),
	.probe2 (2'b0),
	.probe3 (lcl_cl_sh_ddrb_q3.awready),
	.probe4 (lcl_cl_sh_ddrb_q3.wvalid),
	.probe5 (lcl_cl_sh_ddrb_q3.wstrb),
	.probe6 (lcl_cl_sh_ddrb_q3.wlast),
	.probe7 (lcl_cl_sh_ddrb_q3.wready),
	.probe8 (1'b0),
	.probe9 (1'b0),
	.probe10 (lcl_cl_sh_ddrb_q3.wdata),
	.probe11 (1'b0),
	.probe12 (lcl_cl_sh_ddrb_q3.arready),
	.probe13 (2'b0),
	.probe14 (lcl_cl_sh_ddrb_q3.rdata),
	.probe15 (lcl_cl_sh_ddrb_q3.araddr),
	.probe16 (lcl_cl_sh_ddrb_q3.arvalid),
	.probe17 (3'b0),
	.probe18 (3'b0),
	.probe19 (lcl_cl_sh_ddrb_q3.awid[6:0]),
	.probe20 (lcl_cl_sh_ddrb_q3.arid[6:0]),
	.probe21 (lcl_cl_sh_ddrb_q3.awlen),
	.probe22 (lcl_cl_sh_ddrb_q3.rlast),
	.probe23 (3'b0), 
	.probe24 (lcl_cl_sh_ddrb_q3.rresp),
	.probe25 (lcl_cl_sh_ddrb_q3.rid[6:0]),
	.probe26 (lcl_cl_sh_ddrb_q3.rvalid),
	.probe27 (lcl_cl_sh_ddrb_q3.arlen),
	.probe28 (3'b0),
	.probe29 (lcl_cl_sh_ddrb_q3.bresp),
	.probe30 (lcl_cl_sh_ddrb_q3.rready),
	.probe31 (4'b0),
	.probe32 (4'b0),
	.probe33 (4'b0),
	.probe34 (4'b0),
	.probe35 (lcl_cl_sh_ddrb_q3.bvalid),
	.probe36 (4'b0),
	.probe37 (4'b0),
	.probe38 (lcl_cl_sh_ddrb_q3.bid[6:0]),
	.probe39 (lcl_cl_sh_ddrb_q3.bready),
	.probe40 (1'b0),
	.probe41 (1'b0),
	.probe42 (1'b0),
	.probe43 (1'b0)
);

//---------------------------- 
// Debug Core ILA for RLWE input fifo AXI4 interface monitoring 
//---------------------------- 
ila_1 CL_INPUT_FIFO_ILA_0 (
	.clk    (aclk),
	.probe0 (lcl_cl_sh_RLWE_input_FIFO_q3.awvalid),
	.probe1 (lcl_cl_sh_RLWE_input_FIFO_q3.awaddr),
	.probe2 (2'b0),
	.probe3 (lcl_cl_sh_RLWE_input_FIFO_q3.awready),
	.probe4 (lcl_cl_sh_RLWE_input_FIFO_q3.wvalid),
	.probe5 (lcl_cl_sh_RLWE_input_FIFO_q3.wstrb),
	.probe6 (lcl_cl_sh_RLWE_input_FIFO_q3.wlast),
	.probe7 (lcl_cl_sh_RLWE_input_FIFO_q3.wready),
	.probe8 (1'b0),
	.probe9 (1'b0),
	.probe10 (lcl_cl_sh_RLWE_input_FIFO_q3.wdata),
	.probe11 (1'b0),
	.probe12 (lcl_cl_sh_RLWE_input_FIFO_q3.arready),
	.probe13 (2'b0),
	.probe14 (lcl_cl_sh_RLWE_input_FIFO_q3.rdata),
	.probe15 (lcl_cl_sh_RLWE_input_FIFO_q3.araddr),
	.probe16 (lcl_cl_sh_RLWE_input_FIFO_q3.arvalid),
	.probe17 (3'b0),
	.probe18 (3'b0),
	.probe19 (lcl_cl_sh_RLWE_input_FIFO_q3.awid[6:0]),
	.probe20 (lcl_cl_sh_RLWE_input_FIFO_q3.arid[6:0]),
	.probe21 (lcl_cl_sh_RLWE_input_FIFO_q3.awlen),
	.probe22 (lcl_cl_sh_RLWE_input_FIFO_q3.rlast),
	.probe23 (3'b0), 
	.probe24 (lcl_cl_sh_RLWE_input_FIFO_q3.rresp),
	.probe25 (lcl_cl_sh_RLWE_input_FIFO_q3.rid[6:0]),
	.probe26 (lcl_cl_sh_RLWE_input_FIFO_q3.rvalid),
	.probe27 (lcl_cl_sh_RLWE_input_FIFO_q3.arlen),
	.probe28 (3'b0),
	.probe29 (lcl_cl_sh_RLWE_input_FIFO_q3.bresp),
	.probe30 (lcl_cl_sh_RLWE_input_FIFO_q3.rready),
	.probe31 (4'b0),
	.probe32 (4'b0),
	.probe33 (4'b0),
	.probe34 (4'b0),
	.probe35 (lcl_cl_sh_RLWE_input_FIFO_q3.bvalid),
	.probe36 (4'b0),
	.probe37 (4'b0),
	.probe38 (lcl_cl_sh_RLWE_input_FIFO_q3.bid[6:0]),
	.probe39 (lcl_cl_sh_RLWE_input_FIFO_q3.bready),
	.probe40 (1'b0),
	.probe41 (1'b0),
	.probe42 (1'b0),
	.probe43 (1'b0)
);

//---------------------------- 
// Debug Core ILA for RLWE output fifo AXI4 interface monitoring 
//---------------------------- 
ila_1 CL_OUTPUT_FIFO_ILA_0 (
	.clk    (aclk),
	.probe0 (lcl_cl_sh_RLWE_output_FIFO_q3.awvalid),
	.probe1 (lcl_cl_sh_RLWE_output_FIFO_q3.awaddr),
	.probe2 (2'b0),
	.probe3 (lcl_cl_sh_RLWE_output_FIFO_q3.awready),
	.probe4 (lcl_cl_sh_RLWE_output_FIFO_q3.wvalid),
	.probe5 (lcl_cl_sh_RLWE_output_FIFO_q3.wstrb),
	.probe6 (lcl_cl_sh_RLWE_output_FIFO_q3.wlast),
	.probe7 (lcl_cl_sh_RLWE_output_FIFO_q3.wready),
	.probe8 (1'b0),
	.probe9 (1'b0),
	.probe10 (lcl_cl_sh_RLWE_output_FIFO_q3.wdata),
	.probe11 (1'b0),
	.probe12 (lcl_cl_sh_RLWE_output_FIFO_q3.arready),
	.probe13 (2'b0),
	.probe14 (lcl_cl_sh_RLWE_output_FIFO_q3.rdata),
	.probe15 (lcl_cl_sh_RLWE_output_FIFO_q3.araddr),
	.probe16 (lcl_cl_sh_RLWE_output_FIFO_q3.arvalid),
	.probe17 (3'b0),
	.probe18 (3'b0),
	.probe19 (lcl_cl_sh_RLWE_output_FIFO_q3.awid[6:0]),
	.probe20 (lcl_cl_sh_RLWE_output_FIFO_q3.arid[6:0]),
	.probe21 (lcl_cl_sh_RLWE_output_FIFO_q3.awlen),
	.probe22 (lcl_cl_sh_RLWE_output_FIFO_q3.rlast),
	.probe23 (3'b0), 
	.probe24 (lcl_cl_sh_RLWE_output_FIFO_q3.rresp),
	.probe25 (lcl_cl_sh_RLWE_output_FIFO_q3.rid[6:0]),
	.probe26 (lcl_cl_sh_RLWE_output_FIFO_q3.rvalid),
	.probe27 (lcl_cl_sh_RLWE_output_FIFO_q3.arlen),
	.probe28 (3'b0),
	.probe29 (lcl_cl_sh_RLWE_output_FIFO_q3.bresp),
	.probe30 (lcl_cl_sh_RLWE_output_FIFO_q3.rready),
	.probe31 (4'b0),
	.probe32 (4'b0),
	.probe33 (4'b0),
	.probe34 (4'b0),
	.probe35 (lcl_cl_sh_RLWE_output_FIFO_q3.bvalid),
	.probe36 (4'b0),
	.probe37 (4'b0),
	.probe38 (lcl_cl_sh_RLWE_output_FIFO_q3.bid[6:0]),
	.probe39 (lcl_cl_sh_RLWE_output_FIFO_q3.bready),
	.probe40 (1'b0),
	.probe41 (1'b0),
	.probe42 (1'b0),
	.probe43 (1'b0)
);

//---------------------------- 
// Debug Core ILA for key loading fifo AXI4 interface monitoring 
//---------------------------- 
ila_1 CL_KEY_FIFO_ILA_0 (
	.clk    (aclk),
	.probe0 (fhe_core_ddr_master_bus_q2.awvalid),
	.probe1 (fhe_core_ddr_master_bus_q2.awaddr),
	.probe2 (2'b0),
	.probe3 (fhe_core_ddr_master_bus_q2.awready),
	.probe4 (fhe_core_ddr_master_bus_q2.wvalid),
	.probe5 (fhe_core_ddr_master_bus_q2.wstrb),
	.probe6 (fhe_core_ddr_master_bus_q2.wlast),
	.probe7 (fhe_core_ddr_master_bus_q2.wready),
	.probe8 (1'b0),
	.probe9 (1'b0),
	.probe10 (fhe_core_ddr_master_bus_q2.wdata),
	.probe11 (1'b0),
	.probe12 (fhe_core_ddr_master_bus_q2.arready),
	.probe13 (2'b0),
	.probe14 (fhe_core_ddr_master_bus_q2.rdata),
	.probe15 (fhe_core_ddr_master_bus_q2.araddr),
	.probe16 (fhe_core_ddr_master_bus_q2.arvalid),
	.probe17 (3'b0),
	.probe18 (3'b0),
	.probe19 (fhe_core_ddr_master_bus_q2.awid[5:0]),
	.probe20 (fhe_core_ddr_master_bus_q2.arid[5:0]),
	.probe21 (fhe_core_ddr_master_bus_q2.awlen),
	.probe22 (fhe_core_ddr_master_bus_q2.rlast),
	.probe23 (3'b0), 
	.probe24 (fhe_core_ddr_master_bus_q2.rresp),
	.probe25 (fhe_core_ddr_master_bus_q2.rid[5:0]),
	.probe26 (fhe_core_ddr_master_bus_q2.rvalid),
	.probe27 (fhe_core_ddr_master_bus_q2.arlen),
	.probe28 (3'b0),
	.probe29 (fhe_core_ddr_master_bus_q2.bresp),
	.probe30 (fhe_core_ddr_master_bus_q2.rready),
	.probe31 (4'b0),
	.probe32 (4'b0),
	.probe33 (4'b0),
	.probe34 (4'b0),
	.probe35 (fhe_core_ddr_master_bus_q2.bvalid),
	.probe36 (4'b0),
	.probe37 (4'b0),
	.probe38 (fhe_core_ddr_master_bus_q2.bid[5:0]),
	.probe39 (fhe_core_ddr_master_bus_q2.bready),
	.probe40 (1'b0),
	.probe41 (1'b0),
	.probe42 (1'b0),
	.probe43 (1'b0)
);

//---------------------------- 
// Debug Core ILA for bar1 rou/irou write port fifo AXI4 interface monitoring 
//---------------------------- 
ila_1 CL_BAR1_ILA_0 (
	.clk    (aclk),
	.probe0 (rou_wr_port[10].we),
	.probe1 (rou_wr_port[10].addr),
	.probe2 (rou_wr_port[10].din),
	.probe3 (rou_wr_port[9].we),
	.probe4 (rou_wr_port[9].addr),
	.probe5 (rou_wr_port[9].din),
	.probe6 (rou_wr_port[8].we),
	.probe7 (rou_wr_port[8].addr),
	.probe8 (rou_wr_port[8].din),
	.probe9 (rou_wr_port[7].we),
	.probe10 (rou_wr_port[7].addr),
	.probe11 (rou_wr_port[7].din),
	.probe12 (rou_wr_port[6].we),
	.probe13 (rou_wr_port[6].addr),
	.probe14 (rou_wr_port[6].din),
	.probe15 (rou_wr_port[5].we),
	.probe16 (rou_wr_port[5].addr),
	.probe17 (rou_wr_port[5].din),
	.probe18 (rou_wr_port[4].we),
	.probe19 (rou_wr_port[4].addr),
	.probe20 (rou_wr_port[4].din),
	.probe21 (rou_wr_port[3].we),
	.probe22 (rou_wr_port[3].addr),
	.probe23 (rou_wr_port[3].din), 
	.probe24 (rou_wr_port[2].we),
	.probe25 (rou_wr_port[2].addr),
	.probe26 (rou_wr_port[2].din),
	.probe27 (rou_wr_port[1].we),
	.probe28 (rou_wr_port[1].addr),
	.probe29 (rou_wr_port[1].din),
	.probe30 (rou_wr_port[0].we),
	.probe31 (rou_wr_port[0].addr),
	.probe32 (rou_wr_port[0].din),
	.probe33 (irou_wr_port.we),
	.probe34 (irou_wr_port.addr),
	.probe35 (irou_wr_port.din),
	.probe36 (lcl_sh_cl_ddr_is_ready),
	.probe37 (1'b0),
	.probe38 (1'b0),
	.probe39 (1'b0),
	.probe40 (1'b0),
	.probe41 (1'b0),
	.probe42 (1'b0),
	.probe43 (1'b0)
);

endmodule

