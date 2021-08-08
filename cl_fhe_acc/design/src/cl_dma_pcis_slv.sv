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
`include "common.vh"
module cl_dma_pcis_slv 
//module cl_dma_pcis_slv #(parameter SCRB_MAX_ADDR = 64'h3FFFFFFFF, parameter SCRB_BURST_LEN_MINUS1 = 15, parameter NO_SCRB_INST = 1)

(
    input aclk,
    input aresetn,

    axi_bus_if.to_master sh_cl_dma_pcis_bus,
    axi_bus_if.to_master fhe_core_ddr_master_bus,

    axi_bus_if.to_slave lcl_cl_sh_ddrb,
    axi_bus_if.to_slave lcl_cl_sh_RLWE_input_FIFO,
    axi_bus_if.to_slave lcl_cl_sh_RLWE_output_FIFO,

	//debug ports to ila
	axi_bus_if lcl_cl_sh_ddrb_q3,
	axi_bus_if lcl_cl_sh_RLWE_input_FIFO_q3,
	axi_bus_if lcl_cl_sh_RLWE_output_FIFO_q3,
	axi_bus_if fhe_core_ddr_master_bus_q2,
    axi_bus_if sh_cl_dma_pcis_q
);

//----------------------------
// Internal signals
//----------------------------
//axi_bus_if lcl_cl_sh_ddra_q();
//axi_bus_if lcl_cl_sh_ddra_q2();
//axi_bus_if lcl_cl_sh_ddra_q3();


//axi_bus_if lcl_cl_sh_ddrd_q();
//axi_bus_if lcl_cl_sh_ddrd_q2();
//axi_bus_if lcl_cl_sh_ddrd_q3();
axi_bus_if lcl_cl_sh_ddrb_q();
axi_bus_if lcl_cl_sh_ddrb_q2();
//axi_bus_if lcl_cl_sh_ddrb_q3();

//axi_bus_if cl_sh_ddr_q();

axi_bus_if lcl_cl_sh_RLWE_input_FIFO_q();
axi_bus_if lcl_cl_sh_RLWE_input_FIFO_q2();
//axi_bus_if lcl_cl_sh_RLWE_input_FIFO_q3();

axi_bus_if lcl_cl_sh_RLWE_output_FIFO_q();
axi_bus_if lcl_cl_sh_RLWE_output_FIFO_q2();
//axi_bus_if lcl_cl_sh_RLWE_output_FIFO_q3();

axi_bus_if fhe_core_ddr_master_bus_q();
//axi_bus_if fhe_core_ddr_master_bus_q2();

//----------------------------
// End Internal signals
//----------------------------


//reset synchronizers
(* dont_touch = "true" *) logic slr0_sync_aresetn;
(* dont_touch = "true" *) logic slr1_sync_aresetn;
(* dont_touch = "true" *) logic slr2_sync_aresetn;
pipeline #(.BIT_WIDTH(1), .STAGE_NUM(4)) SLR0_PIPE_RST_N (.clk(aclk), .rstn(1'b1), .pipe_in(aresetn), .pipe_out(slr0_sync_aresetn));
pipeline #(.BIT_WIDTH(1), .STAGE_NUM(4)) SLR1_PIPE_RST_N (.clk(aclk), .rstn(1'b1), .pipe_in(aresetn), .pipe_out(slr1_sync_aresetn));
pipeline #(.BIT_WIDTH(1), .STAGE_NUM(4)) SLR2_PIPE_RST_N (.clk(aclk), .rstn(1'b1), .pipe_in(aresetn), .pipe_out(slr2_sync_aresetn));

//----------------------------
// flop the dma_pcis interface input of CL
//----------------------------

// AXI4 Register Slice for dma_pcis interface
axi_register_slice PCI_AXL_REG_SLC (
    .aclk          (aclk),
    .aresetn       (slr0_sync_aresetn),
    .s_axi_awid    (sh_cl_dma_pcis_bus.awid),
    .s_axi_awaddr  (sh_cl_dma_pcis_bus.awaddr),
    .s_axi_awlen   (sh_cl_dma_pcis_bus.awlen),
    .s_axi_awvalid (sh_cl_dma_pcis_bus.awvalid),
    .s_axi_awsize  (sh_cl_dma_pcis_bus.awsize),
    .s_axi_awready (sh_cl_dma_pcis_bus.awready),
    .s_axi_wdata   (sh_cl_dma_pcis_bus.wdata),
    .s_axi_wstrb   (sh_cl_dma_pcis_bus.wstrb),
    .s_axi_wlast   (sh_cl_dma_pcis_bus.wlast),
    .s_axi_wvalid  (sh_cl_dma_pcis_bus.wvalid),
    .s_axi_wready  (sh_cl_dma_pcis_bus.wready),
    .s_axi_bid     (sh_cl_dma_pcis_bus.bid),
    .s_axi_bresp   (sh_cl_dma_pcis_bus.bresp),
    .s_axi_bvalid  (sh_cl_dma_pcis_bus.bvalid),
    .s_axi_bready  (sh_cl_dma_pcis_bus.bready),
    .s_axi_arid    (sh_cl_dma_pcis_bus.arid),
    .s_axi_araddr  (sh_cl_dma_pcis_bus.araddr),
    .s_axi_arlen   (sh_cl_dma_pcis_bus.arlen),
    .s_axi_arvalid (sh_cl_dma_pcis_bus.arvalid),
    .s_axi_arsize  (sh_cl_dma_pcis_bus.arsize),
    .s_axi_arready (sh_cl_dma_pcis_bus.arready),
    .s_axi_rid     (sh_cl_dma_pcis_bus.rid),
    .s_axi_rdata   (sh_cl_dma_pcis_bus.rdata),
    .s_axi_rresp   (sh_cl_dma_pcis_bus.rresp),
    .s_axi_rlast   (sh_cl_dma_pcis_bus.rlast),
    .s_axi_rvalid  (sh_cl_dma_pcis_bus.rvalid),
    .s_axi_rready  (sh_cl_dma_pcis_bus.rready),

    .m_axi_awid    (sh_cl_dma_pcis_q.awid),
    .m_axi_awaddr  (sh_cl_dma_pcis_q.awaddr),
    .m_axi_awlen   (sh_cl_dma_pcis_q.awlen),
    .m_axi_awvalid (sh_cl_dma_pcis_q.awvalid),
    .m_axi_awsize  (sh_cl_dma_pcis_q.awsize),
    .m_axi_awready (sh_cl_dma_pcis_q.awready),
    .m_axi_wdata   (sh_cl_dma_pcis_q.wdata),
    .m_axi_wstrb   (sh_cl_dma_pcis_q.wstrb),
    .m_axi_wvalid  (sh_cl_dma_pcis_q.wvalid),
    .m_axi_wlast   (sh_cl_dma_pcis_q.wlast),
    .m_axi_wready  (sh_cl_dma_pcis_q.wready),
    .m_axi_bresp   (sh_cl_dma_pcis_q.bresp),
    .m_axi_bvalid  (sh_cl_dma_pcis_q.bvalid),
    .m_axi_bid     (sh_cl_dma_pcis_q.bid),
    .m_axi_bready  (sh_cl_dma_pcis_q.bready),
    .m_axi_arid    (sh_cl_dma_pcis_q.arid),
    .m_axi_araddr  (sh_cl_dma_pcis_q.araddr),
    .m_axi_arlen   (sh_cl_dma_pcis_q.arlen),
    .m_axi_arsize  (sh_cl_dma_pcis_q.arsize),
    .m_axi_arvalid (sh_cl_dma_pcis_q.arvalid),
    .m_axi_arready (sh_cl_dma_pcis_q.arready),
    .m_axi_rid     (sh_cl_dma_pcis_q.rid),
    .m_axi_rdata   (sh_cl_dma_pcis_q.rdata),
    .m_axi_rresp   (sh_cl_dma_pcis_q.rresp),
    .m_axi_rlast   (sh_cl_dma_pcis_q.rlast),
    .m_axi_rvalid  (sh_cl_dma_pcis_q.rvalid),
    .m_axi_rready  (sh_cl_dma_pcis_q.rready)
);

//-----------------------------------------------------
//TIE-OFF unused signals to prevent critical warnings
//-----------------------------------------------------
assign sh_cl_dma_pcis_q.rid[15:6] = 10'b0;
assign sh_cl_dma_pcis_q.bid[15:6] = 10'b0;

//----------------------------
// flop the fhe_core_ddr_master_bus interface input of CL
//----------------------------
axi_register_slice FHE_CORE_DDR_REG_SLC_1 (
    .aclk          (aclk),
    .aresetn       (slr0_sync_aresetn),
    .s_axi_awid    (fhe_core_ddr_master_bus.awid),
    .s_axi_awaddr  (fhe_core_ddr_master_bus.awaddr),
    .s_axi_awlen   (fhe_core_ddr_master_bus.awlen),
    .s_axi_awvalid (fhe_core_ddr_master_bus.awvalid),
    .s_axi_awsize  (fhe_core_ddr_master_bus.awsize),
    .s_axi_awready (fhe_core_ddr_master_bus.awready),
    .s_axi_wdata   (fhe_core_ddr_master_bus.wdata),
    .s_axi_wstrb   (fhe_core_ddr_master_bus.wstrb),
    .s_axi_wlast   (fhe_core_ddr_master_bus.wlast),
    .s_axi_wvalid  (fhe_core_ddr_master_bus.wvalid),
    .s_axi_wready  (fhe_core_ddr_master_bus.wready),
    .s_axi_bid     (fhe_core_ddr_master_bus.bid),
    .s_axi_bresp   (fhe_core_ddr_master_bus.bresp),
    .s_axi_bvalid  (fhe_core_ddr_master_bus.bvalid),
    .s_axi_bready  (fhe_core_ddr_master_bus.bready),
    .s_axi_arid    (fhe_core_ddr_master_bus.arid),
    .s_axi_araddr  (fhe_core_ddr_master_bus.araddr),
    .s_axi_arlen   (fhe_core_ddr_master_bus.arlen),
    .s_axi_arvalid (fhe_core_ddr_master_bus.arvalid),
    .s_axi_arsize  (fhe_core_ddr_master_bus.arsize),
    .s_axi_arready (fhe_core_ddr_master_bus.arready),
    .s_axi_rid     (fhe_core_ddr_master_bus.rid),
    .s_axi_rdata   (fhe_core_ddr_master_bus.rdata),
    .s_axi_rresp   (fhe_core_ddr_master_bus.rresp),
    .s_axi_rlast   (fhe_core_ddr_master_bus.rlast),
    .s_axi_rvalid  (fhe_core_ddr_master_bus.rvalid),
    .s_axi_rready  (fhe_core_ddr_master_bus.rready),

    .m_axi_awid    (fhe_core_ddr_master_bus_q.awid),
    .m_axi_awaddr  (fhe_core_ddr_master_bus_q.awaddr),
    .m_axi_awlen   (fhe_core_ddr_master_bus_q.awlen),
    .m_axi_awvalid (fhe_core_ddr_master_bus_q.awvalid),
    .m_axi_awsize  (fhe_core_ddr_master_bus_q.awsize),
    .m_axi_awready (fhe_core_ddr_master_bus_q.awready),
    .m_axi_wdata   (fhe_core_ddr_master_bus_q.wdata),
    .m_axi_wstrb   (fhe_core_ddr_master_bus_q.wstrb),
    .m_axi_wvalid  (fhe_core_ddr_master_bus_q.wvalid),
    .m_axi_wlast   (fhe_core_ddr_master_bus_q.wlast),
    .m_axi_wready  (fhe_core_ddr_master_bus_q.wready),
    .m_axi_bresp   (fhe_core_ddr_master_bus_q.bresp),
    .m_axi_bvalid  (fhe_core_ddr_master_bus_q.bvalid),
    .m_axi_bid     (fhe_core_ddr_master_bus_q.bid),
    .m_axi_bready  (fhe_core_ddr_master_bus_q.bready),
    .m_axi_arid    (fhe_core_ddr_master_bus_q.arid),
    .m_axi_araddr  (fhe_core_ddr_master_bus_q.araddr),
    .m_axi_arlen   (fhe_core_ddr_master_bus_q.arlen),
    .m_axi_arsize  (fhe_core_ddr_master_bus_q.arsize),
    .m_axi_arvalid (fhe_core_ddr_master_bus_q.arvalid),
    .m_axi_arready (fhe_core_ddr_master_bus_q.arready),
    .m_axi_rid     (fhe_core_ddr_master_bus_q.rid),
    .m_axi_rdata   (fhe_core_ddr_master_bus_q.rdata),
    .m_axi_rresp   (fhe_core_ddr_master_bus_q.rresp),
    .m_axi_rlast   (fhe_core_ddr_master_bus_q.rlast),
    .m_axi_rvalid  (fhe_core_ddr_master_bus_q.rvalid),
    .m_axi_rready  (fhe_core_ddr_master_bus_q.rready)
);
axi_register_slice FHE_CORE_DDR_REG_SLC_2 (
    .aclk          (aclk),
    .aresetn       (slr0_sync_aresetn),
    .s_axi_awid    (fhe_core_ddr_master_bus_q.awid),
    .s_axi_awaddr  (fhe_core_ddr_master_bus_q.awaddr),
    .s_axi_awlen   (fhe_core_ddr_master_bus_q.awlen),
    .s_axi_awvalid (fhe_core_ddr_master_bus_q.awvalid),
    .s_axi_awsize  (fhe_core_ddr_master_bus_q.awsize),
    .s_axi_awready (fhe_core_ddr_master_bus_q.awready),
    .s_axi_wdata   (fhe_core_ddr_master_bus_q.wdata),
    .s_axi_wstrb   (fhe_core_ddr_master_bus_q.wstrb),
    .s_axi_wlast   (fhe_core_ddr_master_bus_q.wlast),
    .s_axi_wvalid  (fhe_core_ddr_master_bus_q.wvalid),
    .s_axi_wready  (fhe_core_ddr_master_bus_q.wready),
    .s_axi_bid     (fhe_core_ddr_master_bus_q.bid),
    .s_axi_bresp   (fhe_core_ddr_master_bus_q.bresp),
    .s_axi_bvalid  (fhe_core_ddr_master_bus_q.bvalid),
    .s_axi_bready  (fhe_core_ddr_master_bus_q.bready),
    .s_axi_arid    (fhe_core_ddr_master_bus_q.arid),
    .s_axi_araddr  (fhe_core_ddr_master_bus_q.araddr),
    .s_axi_arlen   (fhe_core_ddr_master_bus_q.arlen),
    .s_axi_arvalid (fhe_core_ddr_master_bus_q.arvalid),
    .s_axi_arsize  (fhe_core_ddr_master_bus_q.arsize),
    .s_axi_arready (fhe_core_ddr_master_bus_q.arready),
    .s_axi_rid     (fhe_core_ddr_master_bus_q.rid),
    .s_axi_rdata   (fhe_core_ddr_master_bus_q.rdata),
    .s_axi_rresp   (fhe_core_ddr_master_bus_q.rresp),
    .s_axi_rlast   (fhe_core_ddr_master_bus_q.rlast),
    .s_axi_rvalid  (fhe_core_ddr_master_bus_q.rvalid),
    .s_axi_rready  (fhe_core_ddr_master_bus_q.rready),

    .m_axi_awid    (fhe_core_ddr_master_bus_q2.awid),
    .m_axi_awaddr  (fhe_core_ddr_master_bus_q2.awaddr),
    .m_axi_awlen   (fhe_core_ddr_master_bus_q2.awlen),
    .m_axi_awvalid (fhe_core_ddr_master_bus_q2.awvalid),
    .m_axi_awsize  (fhe_core_ddr_master_bus_q2.awsize),
    .m_axi_awready (fhe_core_ddr_master_bus_q2.awready),
    .m_axi_wdata   (fhe_core_ddr_master_bus_q2.wdata),
    .m_axi_wstrb   (fhe_core_ddr_master_bus_q2.wstrb),
    .m_axi_wvalid  (fhe_core_ddr_master_bus_q2.wvalid),
    .m_axi_wlast   (fhe_core_ddr_master_bus_q2.wlast),
    .m_axi_wready  (fhe_core_ddr_master_bus_q2.wready),
    .m_axi_bresp   (fhe_core_ddr_master_bus_q2.bresp),
    .m_axi_bvalid  (fhe_core_ddr_master_bus_q2.bvalid),
    .m_axi_bid     (fhe_core_ddr_master_bus_q2.bid),
    .m_axi_bready  (fhe_core_ddr_master_bus_q2.bready),
    .m_axi_arid    (fhe_core_ddr_master_bus_q2.arid),
    .m_axi_araddr  (fhe_core_ddr_master_bus_q2.araddr),
    .m_axi_arlen   (fhe_core_ddr_master_bus_q2.arlen),
    .m_axi_arsize  (fhe_core_ddr_master_bus_q2.arsize),
    .m_axi_arvalid (fhe_core_ddr_master_bus_q2.arvalid),
    .m_axi_arready (fhe_core_ddr_master_bus_q2.arready),
    .m_axi_rid     (fhe_core_ddr_master_bus_q2.rid),
    .m_axi_rdata   (fhe_core_ddr_master_bus_q2.rdata),
    .m_axi_rresp   (fhe_core_ddr_master_bus_q2.rresp),
    .m_axi_rlast   (fhe_core_ddr_master_bus_q2.rlast),
    .m_axi_rvalid  (fhe_core_ddr_master_bus_q2.rvalid),
    .m_axi_rready  (fhe_core_ddr_master_bus_q2.rready)
);

//-----------------------------------------------------
//TIE-OFF unused signals to prevent critical warnings
//-----------------------------------------------------
assign fhe_core_ddr_master_bus_q2.rid[15:6] = 10'b0;
assign fhe_core_ddr_master_bus_q2.bid[15:6] = 10'b0;

//----------------------------
// axi interconnect for DDR address decodes
//----------------------------
(* dont_touch = "true" *) my_dma_axi_xbar AXI_CROSSBAR(
        .ACLK(aclk),
        .ARESETN(slr1_sync_aresetn),

        .M00_AXI_araddr(lcl_cl_sh_ddrb_q.araddr),
        .M00_AXI_arburst(),
        .M00_AXI_arcache(),
        .M00_AXI_arid(lcl_cl_sh_ddrb_q.arid[6:0]),
        .M00_AXI_arlen(lcl_cl_sh_ddrb_q.arlen),
        .M00_AXI_arlock(),
        .M00_AXI_arprot(),
        .M00_AXI_arqos(),
        .M00_AXI_arready(lcl_cl_sh_ddrb_q.arready),
        .M00_AXI_arregion(),
        .M00_AXI_arsize(lcl_cl_sh_ddrb_q.arsize),
        .M00_AXI_arvalid(lcl_cl_sh_ddrb_q.arvalid),
        .M00_AXI_awaddr(lcl_cl_sh_ddrb_q.awaddr),
        .M00_AXI_awburst(),
        .M00_AXI_awcache(),
        .M00_AXI_awid(lcl_cl_sh_ddrb_q.awid[6:0]),
        .M00_AXI_awlen(lcl_cl_sh_ddrb_q.awlen),
        .M00_AXI_awlock(),
        .M00_AXI_awprot(),
        .M00_AXI_awqos(),
        .M00_AXI_awready(lcl_cl_sh_ddrb_q.awready),
        .M00_AXI_awregion(),
        .M00_AXI_awsize(lcl_cl_sh_ddrb_q.awsize),
        .M00_AXI_awvalid(lcl_cl_sh_ddrb_q.awvalid),
        .M00_AXI_bid(lcl_cl_sh_ddrb_q.bid[6:0]),
        .M00_AXI_bready(lcl_cl_sh_ddrb_q.bready),
        .M00_AXI_bresp(lcl_cl_sh_ddrb_q.bresp),
        .M00_AXI_bvalid(lcl_cl_sh_ddrb_q.bvalid),
        .M00_AXI_rdata(lcl_cl_sh_ddrb_q.rdata),
        .M00_AXI_rid(lcl_cl_sh_ddrb_q.rid[6:0]),
        .M00_AXI_rlast(lcl_cl_sh_ddrb_q.rlast),
        .M00_AXI_rready(lcl_cl_sh_ddrb_q.rready),
        .M00_AXI_rresp(lcl_cl_sh_ddrb_q.rresp),
        .M00_AXI_rvalid(lcl_cl_sh_ddrb_q.rvalid),
        .M00_AXI_wdata(lcl_cl_sh_ddrb_q.wdata),
        .M00_AXI_wlast(lcl_cl_sh_ddrb_q.wlast),
        .M00_AXI_wready(lcl_cl_sh_ddrb_q.wready),
        .M00_AXI_wstrb(lcl_cl_sh_ddrb_q.wstrb),
        .M00_AXI_wvalid(lcl_cl_sh_ddrb_q.wvalid),

        .M01_AXI_araddr(lcl_cl_sh_RLWE_input_FIFO_q.araddr),
        .M01_AXI_arburst(),
        .M01_AXI_arcache(),
        .M01_AXI_arid(lcl_cl_sh_RLWE_input_FIFO_q.arid[6:0]),
        .M01_AXI_arlen(lcl_cl_sh_RLWE_input_FIFO_q.arlen),
        .M01_AXI_arlock(),
        .M01_AXI_arprot(),
        .M01_AXI_arqos(),
        .M01_AXI_arready(lcl_cl_sh_RLWE_input_FIFO_q.arready),
        .M01_AXI_arregion(),
        .M01_AXI_arsize(lcl_cl_sh_RLWE_input_FIFO_q.arsize),
        .M01_AXI_arvalid(lcl_cl_sh_RLWE_input_FIFO_q.arvalid),
        .M01_AXI_awaddr(lcl_cl_sh_RLWE_input_FIFO_q.awaddr),
        .M01_AXI_awburst(),
        .M01_AXI_awcache(),
        .M01_AXI_awid(lcl_cl_sh_RLWE_input_FIFO_q.awid[6:0]),
        .M01_AXI_awlen(lcl_cl_sh_RLWE_input_FIFO_q.awlen),
        .M01_AXI_awlock(),
        .M01_AXI_awprot(),
        .M01_AXI_awqos(),
        .M01_AXI_awready(lcl_cl_sh_RLWE_input_FIFO_q.awready),
        .M01_AXI_awregion(),
        .M01_AXI_awsize(lcl_cl_sh_RLWE_input_FIFO_q.awsize),
        .M01_AXI_awvalid(lcl_cl_sh_RLWE_input_FIFO_q.awvalid),
        .M01_AXI_bid(lcl_cl_sh_RLWE_input_FIFO_q.bid[6:0]),
        .M01_AXI_bready(lcl_cl_sh_RLWE_input_FIFO_q.bready),
        .M01_AXI_bresp(lcl_cl_sh_RLWE_input_FIFO_q.bresp),
        .M01_AXI_bvalid(lcl_cl_sh_RLWE_input_FIFO_q.bvalid),
        .M01_AXI_rdata(lcl_cl_sh_RLWE_input_FIFO_q.rdata),
        .M01_AXI_rid(lcl_cl_sh_RLWE_input_FIFO_q.rid[6:0]),
        .M01_AXI_rlast(lcl_cl_sh_RLWE_input_FIFO_q.rlast),
        .M01_AXI_rready(lcl_cl_sh_RLWE_input_FIFO_q.rready),
        .M01_AXI_rresp(lcl_cl_sh_RLWE_input_FIFO_q.rresp),
        .M01_AXI_rvalid(lcl_cl_sh_RLWE_input_FIFO_q.rvalid),
        .M01_AXI_wdata(lcl_cl_sh_RLWE_input_FIFO_q.wdata),
        .M01_AXI_wlast(lcl_cl_sh_RLWE_input_FIFO_q.wlast),
        .M01_AXI_wready(lcl_cl_sh_RLWE_input_FIFO_q.wready),
        .M01_AXI_wstrb(lcl_cl_sh_RLWE_input_FIFO_q.wstrb),
        .M01_AXI_wvalid(lcl_cl_sh_RLWE_input_FIFO_q.wvalid),


        .M02_AXI_araddr(lcl_cl_sh_RLWE_output_FIFO_q.araddr),
        .M02_AXI_arburst(),
        .M02_AXI_arcache(),
        .M02_AXI_arid(lcl_cl_sh_RLWE_output_FIFO_q.arid[6:0]),
        .M02_AXI_arlen(lcl_cl_sh_RLWE_output_FIFO_q.arlen),
        .M02_AXI_arlock(),
        .M02_AXI_arprot(),
        .M02_AXI_arqos(),
        .M02_AXI_arready(lcl_cl_sh_RLWE_output_FIFO_q.arready),
        .M02_AXI_arregion(),
        .M02_AXI_arsize(lcl_cl_sh_RLWE_output_FIFO_q.arsize),
        .M02_AXI_arvalid(lcl_cl_sh_RLWE_output_FIFO_q.arvalid),
        .M02_AXI_awaddr(lcl_cl_sh_RLWE_output_FIFO_q.awaddr),
        .M02_AXI_awburst(),
        .M02_AXI_awcache(),
        .M02_AXI_awid(lcl_cl_sh_RLWE_output_FIFO_q.awid[6:0]),
        .M02_AXI_awlen(lcl_cl_sh_RLWE_output_FIFO_q.awlen),
        .M02_AXI_awlock(),
        .M02_AXI_awprot(),
        .M02_AXI_awqos(),
        .M02_AXI_awready(lcl_cl_sh_RLWE_output_FIFO_q.awready),
        .M02_AXI_awregion(),
        .M02_AXI_awsize(lcl_cl_sh_RLWE_output_FIFO_q.awsize),
        .M02_AXI_awvalid(lcl_cl_sh_RLWE_output_FIFO_q.awvalid),
        .M02_AXI_bid(lcl_cl_sh_RLWE_output_FIFO_q.bid[6:0]),
        .M02_AXI_bready(lcl_cl_sh_RLWE_output_FIFO_q.bready),
        .M02_AXI_bresp(lcl_cl_sh_RLWE_output_FIFO_q.bresp),
        .M02_AXI_bvalid(lcl_cl_sh_RLWE_output_FIFO_q.bvalid),
        .M02_AXI_rdata(lcl_cl_sh_RLWE_output_FIFO_q.rdata),
        .M02_AXI_rid(lcl_cl_sh_RLWE_output_FIFO_q.rid[6:0]),
        .M02_AXI_rlast(lcl_cl_sh_RLWE_output_FIFO_q.rlast),
        .M02_AXI_rready(lcl_cl_sh_RLWE_output_FIFO_q.rready),
        .M02_AXI_rresp(lcl_cl_sh_RLWE_output_FIFO_q.rresp),
        .M02_AXI_rvalid(lcl_cl_sh_RLWE_output_FIFO_q.rvalid),
        .M02_AXI_wdata(lcl_cl_sh_RLWE_output_FIFO_q.wdata),
        .M02_AXI_wlast(lcl_cl_sh_RLWE_output_FIFO_q.wlast),
        .M02_AXI_wready(lcl_cl_sh_RLWE_output_FIFO_q.wready),
        .M02_AXI_wstrb(lcl_cl_sh_RLWE_output_FIFO_q.wstrb),
        .M02_AXI_wvalid(lcl_cl_sh_RLWE_output_FIFO_q.wvalid),

//        .M03_AXI_arburst(),
//        .M03_AXI_arcache(),
//        .M03_AXI_arid(lcl_cl_sh_ddrd_q.arid[6:0]),
//        .M03_AXI_arlen(lcl_cl_sh_ddrd_q.arlen),
//        .M03_AXI_arlock(),
//        .M03_AXI_arprot(),
//        .M03_AXI_arqos(),
//        .M03_AXI_arready(lcl_cl_sh_ddrd_q.arready),
//        .M03_AXI_arregion(),
//        .M03_AXI_arsize(lcl_cl_sh_ddrd_q.arsize),
//        .M03_AXI_arvalid(lcl_cl_sh_ddrd_q.arvalid),
//        .M03_AXI_awaddr(lcl_cl_sh_ddrd_q.awaddr),
//        .M03_AXI_awburst(),
//        .M03_AXI_awcache(),
//        .M03_AXI_awid(lcl_cl_sh_ddrd_q.awid[6:0]),
//        .M03_AXI_awlen(lcl_cl_sh_ddrd_q.awlen),
//        .M03_AXI_awlock(),
//        .M03_AXI_awprot(),
//        .M03_AXI_awqos(),
//        .M03_AXI_awready(lcl_cl_sh_ddrd_q.awready),
//        .M03_AXI_awregion(),
//        .M03_AXI_awsize(lcl_cl_sh_ddrd_q.awsize),
//        .M03_AXI_awvalid(lcl_cl_sh_ddrd_q.awvalid),
//        .M03_AXI_bid(lcl_cl_sh_ddrd_q.bid[6:0]),
//        .M03_AXI_bready(lcl_cl_sh_ddrd_q.bready),
//        .M03_AXI_bresp(lcl_cl_sh_ddrd_q.bresp),
//        .M03_AXI_bvalid(lcl_cl_sh_ddrd_q.bvalid),
//        .M03_AXI_rdata(lcl_cl_sh_ddrd_q.rdata),
//        .M03_AXI_rid(lcl_cl_sh_ddrd_q.rid[6:0]),
//        .M03_AXI_rlast(lcl_cl_sh_ddrd_q.rlast),
//        .M03_AXI_rready(lcl_cl_sh_ddrd_q.rready),
//        .M03_AXI_rresp(lcl_cl_sh_ddrd_q.rresp),
//        .M03_AXI_rvalid(lcl_cl_sh_ddrd_q.rvalid),
//        .M03_AXI_wdata(lcl_cl_sh_ddrd_q.wdata),
//        .M03_AXI_wlast(lcl_cl_sh_ddrd_q.wlast),
//        .M03_AXI_wready(lcl_cl_sh_ddrd_q.wready),
//        .M03_AXI_wstrb(lcl_cl_sh_ddrd_q.wstrb),
//        .M03_AXI_wvalid(lcl_cl_sh_ddrd_q.wvalid),



        .S00_AXI_araddr(sh_cl_dma_pcis_q.araddr),
        .S00_AXI_arburst(2'b1),
        .S00_AXI_arcache(4'b11),
        .S00_AXI_arid(sh_cl_dma_pcis_q.arid[5:0]),
        .S00_AXI_arlen(sh_cl_dma_pcis_q.arlen),
        .S00_AXI_arlock(1'b0),
        .S00_AXI_arprot(3'b10),
        .S00_AXI_arqos(4'b0),
        .S00_AXI_arready(sh_cl_dma_pcis_q.arready),
        .S00_AXI_arregion(4'b0),
        .S00_AXI_arsize(sh_cl_dma_pcis_q.arsize),
        .S00_AXI_arvalid(sh_cl_dma_pcis_q.arvalid),
        .S00_AXI_awaddr(sh_cl_dma_pcis_q.awaddr),
        .S00_AXI_awburst(2'b1),
        .S00_AXI_awcache(4'b11),
        .S00_AXI_awid(sh_cl_dma_pcis_q.awid[5:0]),
        .S00_AXI_awlen(sh_cl_dma_pcis_q.awlen),
        .S00_AXI_awlock(1'b0),
        .S00_AXI_awprot(3'b10),
        .S00_AXI_awqos(4'b0),
        .S00_AXI_awready(sh_cl_dma_pcis_q.awready),
        .S00_AXI_awregion(4'b0),
        .S00_AXI_awsize(sh_cl_dma_pcis_q.awsize),
        .S00_AXI_awvalid(sh_cl_dma_pcis_q.awvalid),
        .S00_AXI_bid(sh_cl_dma_pcis_q.bid[5:0]),
        .S00_AXI_bready(sh_cl_dma_pcis_q.bready),
        .S00_AXI_bresp(sh_cl_dma_pcis_q.bresp),
        .S00_AXI_bvalid(sh_cl_dma_pcis_q.bvalid),
        .S00_AXI_rdata(sh_cl_dma_pcis_q.rdata),
        .S00_AXI_rid(sh_cl_dma_pcis_q.rid[5:0]),
        .S00_AXI_rlast(sh_cl_dma_pcis_q.rlast),
        .S00_AXI_rready(sh_cl_dma_pcis_q.rready),
        .S00_AXI_rresp(sh_cl_dma_pcis_q.rresp),
        .S00_AXI_rvalid(sh_cl_dma_pcis_q.rvalid),
        .S00_AXI_wdata(sh_cl_dma_pcis_q.wdata),
        .S00_AXI_wlast(sh_cl_dma_pcis_q.wlast),
        .S00_AXI_wready(sh_cl_dma_pcis_q.wready),
        .S00_AXI_wstrb(sh_cl_dma_pcis_q.wstrb),
        .S00_AXI_wvalid(sh_cl_dma_pcis_q.wvalid),

        .S01_AXI_araddr(fhe_core_ddr_master_bus_q2.araddr),
        .S01_AXI_arburst(2'b1),
        .S01_AXI_arcache(4'b11),
        .S01_AXI_arid(fhe_core_ddr_master_bus_q2.arid[5:0]),
        .S01_AXI_arlen(fhe_core_ddr_master_bus_q2.arlen),
        .S01_AXI_arlock(1'b0),
        .S01_AXI_arprot(3'b10),
        .S01_AXI_arqos(4'b0),
        .S01_AXI_arready(fhe_core_ddr_master_bus_q2.arready),
        .S01_AXI_arregion(4'b0),
        .S01_AXI_arsize(fhe_core_ddr_master_bus_q2.arsize),
        .S01_AXI_arvalid(fhe_core_ddr_master_bus_q2.arvalid),
        .S01_AXI_awaddr(fhe_core_ddr_master_bus_q2.awaddr),
        .S01_AXI_awburst(2'b1),
        .S01_AXI_awcache(4'b11),
        .S01_AXI_awid(fhe_core_ddr_master_bus_q2.awid[5:0]),
        .S01_AXI_awlen(fhe_core_ddr_master_bus_q2.awlen),
        .S01_AXI_awlock(1'b0),
        .S01_AXI_awprot(3'b10),
        .S01_AXI_awqos(4'b0),
        .S01_AXI_awready(fhe_core_ddr_master_bus_q2.awready),
        .S01_AXI_awregion(4'b0),
        .S01_AXI_awsize(fhe_core_ddr_master_bus_q2.awsize),
        .S01_AXI_awvalid(fhe_core_ddr_master_bus_q2.awvalid),
        .S01_AXI_bid(fhe_core_ddr_master_bus_q2.bid[5:0]),
        .S01_AXI_bready(fhe_core_ddr_master_bus_q2.bready),
        .S01_AXI_bresp(fhe_core_ddr_master_bus_q2.bresp),
        .S01_AXI_bvalid(fhe_core_ddr_master_bus_q2.bvalid),
        .S01_AXI_rdata(fhe_core_ddr_master_bus_q2.rdata),
        .S01_AXI_rid(fhe_core_ddr_master_bus_q2.rid[5:0]),
        .S01_AXI_rlast(fhe_core_ddr_master_bus_q2.rlast),
        .S01_AXI_rready(fhe_core_ddr_master_bus_q2.rready),
        .S01_AXI_rresp(fhe_core_ddr_master_bus_q2.rresp),
        .S01_AXI_rvalid(fhe_core_ddr_master_bus_q2.rvalid),
        .S01_AXI_wdata(fhe_core_ddr_master_bus_q2.wdata),
        .S01_AXI_wlast(fhe_core_ddr_master_bus_q2.wlast),
        .S01_AXI_wready(fhe_core_ddr_master_bus_q2.wready),
        .S01_AXI_wstrb(fhe_core_ddr_master_bus_q2.wstrb),
        .S01_AXI_wvalid(fhe_core_ddr_master_bus_q2.wvalid)
);

//(* dont_touch = "true" *) my_dma_axi_interconnect AXI_CROSSBAR(
//	    .M00_AXI_araddr(lcl_cl_sh_ddra_q.araddr),
//        .M00_AXI_arburst(),
//        .M00_AXI_arcache(),
//        .M00_AXI_arlen(lcl_cl_sh_ddra_q.arlen),
//        .M00_AXI_arlock(),
//        .M00_AXI_arprot(),
//        .M00_AXI_arqos(),
//        .M00_AXI_arready(lcl_cl_sh_ddra_q.arready),
//        .M00_AXI_arsize(lcl_cl_sh_ddra_q.arsize),
//        .M00_AXI_arvalid(lcl_cl_sh_ddra_q.arvalid),
//        .M00_AXI_awaddr(lcl_cl_sh_ddra_q.awaddr),
//        .M00_AXI_awburst(),
//        .M00_AXI_awcache(),
//        .M00_AXI_awlen(lcl_cl_sh_ddra_q.awlen),
//        .M00_AXI_awlock(),
//        .M00_AXI_awprot(),
//        .M00_AXI_awqos(),
//        .M00_AXI_awready(lcl_cl_sh_ddra_q.awready),
//        .M00_AXI_awsize(lcl_cl_sh_ddra_q.awsize),
//        .M00_AXI_awvalid(lcl_cl_sh_ddra_q.awvalid),
//        .M00_AXI_bready(lcl_cl_sh_ddra_q.bready),
//        .M00_AXI_bresp(lcl_cl_sh_ddra_q.bresp),
//        .M00_AXI_bvalid(lcl_cl_sh_ddra_q.bvalid),
//        .M00_AXI_rdata(lcl_cl_sh_ddra_q.rdata),
//        .M00_AXI_rlast(lcl_cl_sh_ddra_q.rlast),
//        .M00_AXI_rready(lcl_cl_sh_ddra_q.rready),
//        .M00_AXI_rresp(lcl_cl_sh_ddra_q.rresp),
//        .M00_AXI_rvalid(lcl_cl_sh_ddra_q.rvalid),
//        .M00_AXI_wdata(lcl_cl_sh_ddra_q.wdata),
//        .M00_AXI_wlast(lcl_cl_sh_ddra_q.wlast),
//        .M00_AXI_wready(lcl_cl_sh_ddra_q.wready),
//        .M00_AXI_wstrb(lcl_cl_sh_ddra_q.wstrb),
//        .M00_AXI_wvalid(lcl_cl_sh_ddra_q.wvalid),
//
//	    .M01_AXI_araddr(lcl_cl_sh_RLWE_input_FIFO_q.araddr),
//        .M01_AXI_arburst(),
//        .M01_AXI_arcache(),
//        .M01_AXI_arlen(lcl_cl_sh_RLWE_input_FIFO_q.arlen),
//        .M01_AXI_arlock(),
//        .M01_AXI_arprot(),
//        .M01_AXI_arqos(),
//        .M01_AXI_arready(lcl_cl_sh_RLWE_input_FIFO_q.arready),
//        .M01_AXI_arsize(lcl_cl_sh_RLWE_input_FIFO_q.arsize),
//        .M01_AXI_arvalid(lcl_cl_sh_RLWE_input_FIFO_q.arvalid),
//        .M01_AXI_awaddr(lcl_cl_sh_RLWE_input_FIFO_q.awaddr),
//        .M01_AXI_awburst(),
//        .M01_AXI_awcache(),
//        .M01_AXI_awlen(lcl_cl_sh_RLWE_input_FIFO_q.awlen),
//        .M01_AXI_awlock(),
//        .M01_AXI_awprot(),
//        .M01_AXI_awqos(),
//        .M01_AXI_awready(lcl_cl_sh_RLWE_input_FIFO_q.awready),
//        .M01_AXI_awsize(lcl_cl_sh_RLWE_input_FIFO_q.awsize),
//        .M01_AXI_awvalid(lcl_cl_sh_RLWE_input_FIFO_q.awvalid),
//        .M01_AXI_bready(lcl_cl_sh_RLWE_input_FIFO_q.bready),
//        .M01_AXI_bresp(lcl_cl_sh_RLWE_input_FIFO_q.bresp),
//        .M01_AXI_bvalid(lcl_cl_sh_RLWE_input_FIFO_q.bvalid),
//        .M01_AXI_rdata(lcl_cl_sh_RLWE_input_FIFO_q.rdata),
//        .M01_AXI_rlast(lcl_cl_sh_RLWE_input_FIFO_q.rlast),
//        .M01_AXI_rready(lcl_cl_sh_RLWE_input_FIFO_q.rready),
//        .M01_AXI_rresp(lcl_cl_sh_RLWE_input_FIFO_q.rresp),
//        .M01_AXI_rvalid(lcl_cl_sh_RLWE_input_FIFO_q.rvalid),
//        .M01_AXI_wdata(lcl_cl_sh_RLWE_input_FIFO_q.wdata),
//        .M01_AXI_wlast(lcl_cl_sh_RLWE_input_FIFO_q.wlast),
//        .M01_AXI_wready(lcl_cl_sh_RLWE_input_FIFO_q.wready),
//        .M01_AXI_wstrb(lcl_cl_sh_RLWE_input_FIFO_q.wstrb),
//        .M01_AXI_wvalid(lcl_cl_sh_RLWE_input_FIFO_q.wvalid),
//
//	    .M02_AXI_araddr(lcl_cl_sh_RLWE_output_FIFO_q.araddr),
//        .M02_AXI_arburst(),
//        .M02_AXI_arcache(),
//        .M02_AXI_arlen(lcl_cl_sh_RLWE_output_FIFO_q.arlen),
//        .M02_AXI_arlock(),
//        .M02_AXI_arprot(),
//        .M02_AXI_arqos(),
//        .M02_AXI_arready(lcl_cl_sh_RLWE_output_FIFO_q.arready),
//        .M02_AXI_arsize(lcl_cl_sh_RLWE_output_FIFO_q.arsize),
//        .M02_AXI_arvalid(lcl_cl_sh_RLWE_output_FIFO_q.arvalid),
//        .M02_AXI_awaddr(lcl_cl_sh_RLWE_output_FIFO_q.awaddr),
//        .M02_AXI_awburst(),
//        .M02_AXI_awcache(),
//        .M02_AXI_awlen(lcl_cl_sh_RLWE_output_FIFO_q.awlen),
//        .M02_AXI_awlock(),
//        .M02_AXI_awprot(),
//        .M02_AXI_awqos(),
//        .M02_AXI_awready(lcl_cl_sh_RLWE_output_FIFO_q.awready),
//        .M02_AXI_awsize(lcl_cl_sh_RLWE_output_FIFO_q.awsize),
//        .M02_AXI_awvalid(lcl_cl_sh_RLWE_output_FIFO_q.awvalid),
//        .M02_AXI_bready(lcl_cl_sh_RLWE_output_FIFO_q.bready),
//        .M02_AXI_bresp(lcl_cl_sh_RLWE_output_FIFO_q.bresp),
//        .M02_AXI_bvalid(lcl_cl_sh_RLWE_output_FIFO_q.bvalid),
//        .M02_AXI_rdata(lcl_cl_sh_RLWE_output_FIFO_q.rdata),
//        .M02_AXI_rlast(lcl_cl_sh_RLWE_output_FIFO_q.rlast),
//        .M02_AXI_rready(lcl_cl_sh_RLWE_output_FIFO_q.rready),
//        .M02_AXI_rresp(lcl_cl_sh_RLWE_output_FIFO_q.rresp),
//        .M02_AXI_rvalid(lcl_cl_sh_RLWE_output_FIFO_q.rvalid),
//        .M02_AXI_wdata(lcl_cl_sh_RLWE_output_FIFO_q.wdata),
//        .M02_AXI_wlast(lcl_cl_sh_RLWE_output_FIFO_q.wlast),
//        .M02_AXI_wready(lcl_cl_sh_RLWE_output_FIFO_q.wready),
//        .M02_AXI_wstrb(lcl_cl_sh_RLWE_output_FIFO_q.wstrb),
//        .M02_AXI_wvalid(lcl_cl_sh_RLWE_output_FIFO_q.wvalid),
//
//        .S00_AXI_araddr(sh_cl_dma_pcis_q.araddr),
//        .S00_AXI_arburst(2'b1),
//        .S00_AXI_arcache(4'b11),
//        .S00_AXI_arid(sh_cl_dma_pcis_q.arid[5:0]),
//        .S00_AXI_arlen(sh_cl_dma_pcis_q.arlen),
//        .S00_AXI_arlock(1'b0),
//        .S00_AXI_arprot(3'b10),
//        .S00_AXI_arqos(4'b0),
//        .S00_AXI_arready(sh_cl_dma_pcis_q.arready),
//        .S00_AXI_arsize(sh_cl_dma_pcis_q.arsize),
//        .S00_AXI_arvalid(sh_cl_dma_pcis_q.arvalid),
//        .S00_AXI_awaddr(sh_cl_dma_pcis_q.awaddr),
//        .S00_AXI_awburst(2'b1),
//        .S00_AXI_awcache(4'b11),
//        .S00_AXI_awid(sh_cl_dma_pcis_q.awid[5:0]),
//        .S00_AXI_awlen(sh_cl_dma_pcis_q.awlen),
//        .S00_AXI_awlock(1'b0),
//        .S00_AXI_awprot(3'b10),
//        .S00_AXI_awqos(4'b0),
//        .S00_AXI_awready(sh_cl_dma_pcis_q.awready),
//        .S00_AXI_awsize(sh_cl_dma_pcis_q.awsize),
//        .S00_AXI_awvalid(sh_cl_dma_pcis_q.awvalid),
//        .S00_AXI_bid(sh_cl_dma_pcis_q.bid[5:0]),
//        .S00_AXI_bready(sh_cl_dma_pcis_q.bready),
//        .S00_AXI_bresp(sh_cl_dma_pcis_q.bresp),
//        .S00_AXI_bvalid(sh_cl_dma_pcis_q.bvalid),
//        .S00_AXI_rdata(sh_cl_dma_pcis_q.rdata),
//        .S00_AXI_rid(sh_cl_dma_pcis_q.rid[5:0]),
//        .S00_AXI_rlast(sh_cl_dma_pcis_q.rlast),
//        .S00_AXI_rready(sh_cl_dma_pcis_q.rready),
//        .S00_AXI_rresp(sh_cl_dma_pcis_q.rresp),
//        .S00_AXI_rvalid(sh_cl_dma_pcis_q.rvalid),
//        .S00_AXI_wdata(sh_cl_dma_pcis_q.wdata),
//        .S00_AXI_wlast(sh_cl_dma_pcis_q.wlast),
//        .S00_AXI_wready(sh_cl_dma_pcis_q.wready),
//        .S00_AXI_wstrb(sh_cl_dma_pcis_q.wstrb),
//        .S00_AXI_wvalid(sh_cl_dma_pcis_q.wvalid),
//
//        .S01_AXI_araddr(fhe_core_ddr_master_bus_q.araddr),
//        .S01_AXI_arburst(2'b1),
//        .S01_AXI_arcache(4'b11),
//        .S01_AXI_arid(fhe_core_ddr_master_bus_q.arid[5:0]),
//        .S01_AXI_arlen(fhe_core_ddr_master_bus_q.arlen),
//        .S01_AXI_arlock(1'b0),
//        .S01_AXI_arprot(3'b10),
//        .S01_AXI_arqos(4'b0),
//        .S01_AXI_arready(fhe_core_ddr_master_bus_q.arready),
//        .S01_AXI_arsize(fhe_core_ddr_master_bus_q.arsize),
//        .S01_AXI_arvalid(fhe_core_ddr_master_bus_q.arvalid),
//        .S01_AXI_awaddr(fhe_core_ddr_master_bus_q.awaddr),
//        .S01_AXI_awburst(2'b1),
//        .S01_AXI_awcache(4'b11),
//        .S01_AXI_awid(fhe_core_ddr_master_bus_q.awid[5:0]),
//        .S01_AXI_awlen(fhe_core_ddr_master_bus_q.awlen),
//        .S01_AXI_awlock(1'b0),
//        .S01_AXI_awprot(3'b10),
//        .S01_AXI_awqos(4'b0),
//        .S01_AXI_awready(fhe_core_ddr_master_bus_q.awready),
//        .S01_AXI_awsize(fhe_core_ddr_master_bus_q.awsize),
//        .S01_AXI_awvalid(fhe_core_ddr_master_bus_q.awvalid),
//        .S01_AXI_bid(fhe_core_ddr_master_bus_q.bid[5:0]),
//        .S01_AXI_bready(fhe_core_ddr_master_bus_q.bready),
//        .S01_AXI_bresp(fhe_core_ddr_master_bus_q.bresp),
//        .S01_AXI_bvalid(fhe_core_ddr_master_bus_q.bvalid),
//        .S01_AXI_rdata(fhe_core_ddr_master_bus_q.rdata),
//        .S01_AXI_rid(fhe_core_ddr_master_bus_q.rid[5:0]),
//        .S01_AXI_rlast(fhe_core_ddr_master_bus_q.rlast),
//        .S01_AXI_rready(fhe_core_ddr_master_bus_q.rready),
//        .S01_AXI_rresp(fhe_core_ddr_master_bus_q.rresp),
//        .S01_AXI_rvalid(fhe_core_ddr_master_bus_q.rvalid),
//        .S01_AXI_wdata(fhe_core_ddr_master_bus_q.wdata),
//        .S01_AXI_wlast(fhe_core_ddr_master_bus_q.wlast),
//        .S01_AXI_wready(fhe_core_ddr_master_bus_q.wready),
//        .S01_AXI_wstrb(fhe_core_ddr_master_bus_q.wstrb),
//        .S01_AXI_wvalid(fhe_core_ddr_master_bus_q.wvalid),
//
//        .aclk(aclk),
//        .aresetn(slr1_sync_aresetn)
//);

//----------------------------
// flop the output of interconnect for DDRD
// back to back for SLR crossing
//----------------------------
//back to back register slices for SLR crossing
src_register_slice DDR_B_TST_AXI4_REG_SLC_1 (
    .aclk           (aclk),
    .aresetn        (slr1_sync_aresetn),
    .s_axi_awid     (lcl_cl_sh_ddrb_q.awid),
    .s_axi_awaddr   (lcl_cl_sh_ddrb_q.awaddr),
    .s_axi_awlen    (lcl_cl_sh_ddrb_q.awlen),
    .s_axi_awsize   (lcl_cl_sh_ddrb_q.awsize),
    .s_axi_awburst  (2'b1),
    .s_axi_awlock   (1'b0),
    .s_axi_awcache  (4'b11),
    .s_axi_awprot   (3'b10),
    .s_axi_awregion (4'b0),
    .s_axi_awqos    (4'b0),
    .s_axi_awvalid  (lcl_cl_sh_ddrb_q.awvalid),
    .s_axi_awready  (lcl_cl_sh_ddrb_q.awready),
    .s_axi_wdata    (lcl_cl_sh_ddrb_q.wdata),
    .s_axi_wstrb    (lcl_cl_sh_ddrb_q.wstrb),
    .s_axi_wlast    (lcl_cl_sh_ddrb_q.wlast),
    .s_axi_wvalid   (lcl_cl_sh_ddrb_q.wvalid),
    .s_axi_wready   (lcl_cl_sh_ddrb_q.wready),
    .s_axi_bid      (lcl_cl_sh_ddrb_q.bid),
    .s_axi_bresp    (lcl_cl_sh_ddrb_q.bresp),
    .s_axi_bvalid   (lcl_cl_sh_ddrb_q.bvalid),
    .s_axi_bready   (lcl_cl_sh_ddrb_q.bready),
    .s_axi_arid     (lcl_cl_sh_ddrb_q.arid),
    .s_axi_araddr   (lcl_cl_sh_ddrb_q.araddr),
    .s_axi_arlen    (lcl_cl_sh_ddrb_q.arlen),
    .s_axi_arsize   (lcl_cl_sh_ddrb_q.arsize),
    .s_axi_arburst  (2'b1),
    .s_axi_arlock   (1'b0),
    .s_axi_arcache  (4'b11),
    .s_axi_arprot   (3'b10),
    .s_axi_arregion (4'b0),
    .s_axi_arqos    (4'b0),
    .s_axi_arvalid  (lcl_cl_sh_ddrb_q.arvalid),
    .s_axi_arready  (lcl_cl_sh_ddrb_q.arready),
    .s_axi_rid      (lcl_cl_sh_ddrb_q.rid),
    .s_axi_rdata    (lcl_cl_sh_ddrb_q.rdata),
    .s_axi_rresp    (lcl_cl_sh_ddrb_q.rresp),
    .s_axi_rlast    (lcl_cl_sh_ddrb_q.rlast),
    .s_axi_rvalid   (lcl_cl_sh_ddrb_q.rvalid),
    .s_axi_rready   (lcl_cl_sh_ddrb_q.rready),
    .m_axi_awid     (lcl_cl_sh_ddrb_q2.awid),
    .m_axi_awaddr   (lcl_cl_sh_ddrb_q2.awaddr),
    .m_axi_awlen    (lcl_cl_sh_ddrb_q2.awlen),
    .m_axi_awsize   (lcl_cl_sh_ddrb_q2.awsize),
    .m_axi_awburst  (),
    .m_axi_awlock   (),
    .m_axi_awcache  (),
    .m_axi_awprot   (),
    .m_axi_awregion (),
    .m_axi_awqos    (),
    .m_axi_awvalid  (lcl_cl_sh_ddrb_q2.awvalid),
    .m_axi_awready  (lcl_cl_sh_ddrb_q2.awready),
    .m_axi_wdata    (lcl_cl_sh_ddrb_q2.wdata),
    .m_axi_wstrb    (lcl_cl_sh_ddrb_q2.wstrb),
    .m_axi_wlast    (lcl_cl_sh_ddrb_q2.wlast),
    .m_axi_wvalid   (lcl_cl_sh_ddrb_q2.wvalid),
    .m_axi_wready   (lcl_cl_sh_ddrb_q2.wready),
    .m_axi_bid      (lcl_cl_sh_ddrb_q2.bid),
    .m_axi_bresp    (lcl_cl_sh_ddrb_q2.bresp),
    .m_axi_bvalid   (lcl_cl_sh_ddrb_q2.bvalid),
    .m_axi_bready   (lcl_cl_sh_ddrb_q2.bready),
    .m_axi_arid     (lcl_cl_sh_ddrb_q2.arid),
    .m_axi_araddr   (lcl_cl_sh_ddrb_q2.araddr),
    .m_axi_arlen    (lcl_cl_sh_ddrb_q2.arlen),
    .m_axi_arsize   (lcl_cl_sh_ddrb_q2.arsize),
    .m_axi_arburst  (),
    .m_axi_arlock   (),
    .m_axi_arcache  (),
    .m_axi_arprot   (),
    .m_axi_arregion (),
    .m_axi_arqos    (),
    .m_axi_arvalid  (lcl_cl_sh_ddrb_q2.arvalid),
    .m_axi_arready  (lcl_cl_sh_ddrb_q2.arready),
    .m_axi_rid      (lcl_cl_sh_ddrb_q2.rid),
    .m_axi_rdata    (lcl_cl_sh_ddrb_q2.rdata),
    .m_axi_rresp    (lcl_cl_sh_ddrb_q2.rresp),
    .m_axi_rlast    (lcl_cl_sh_ddrb_q2.rlast),
    .m_axi_rvalid   (lcl_cl_sh_ddrb_q2.rvalid),
    .m_axi_rready   (lcl_cl_sh_ddrb_q2.rready)
    );

dest_register_slice DDR_B_TST_AXI4_REG_SLC_2 (
    .aclk           (aclk),
    .aresetn        (slr2_sync_aresetn),
    .s_axi_awid     (lcl_cl_sh_ddrb_q2.awid),
    .s_axi_awaddr   (lcl_cl_sh_ddrb_q2.awaddr),
    .s_axi_awlen    (lcl_cl_sh_ddrb_q2.awlen),
    .s_axi_awsize   (lcl_cl_sh_ddrb_q2.awsize),
    .s_axi_awburst  (2'b1),
    .s_axi_awlock   (1'b0),
    .s_axi_awcache  (4'b11),
    .s_axi_awprot   (3'b10),
    .s_axi_awregion (4'b0),
    .s_axi_awqos    (4'b0),
    .s_axi_awvalid  (lcl_cl_sh_ddrb_q2.awvalid),
    .s_axi_awready  (lcl_cl_sh_ddrb_q2.awready),
    .s_axi_wdata    (lcl_cl_sh_ddrb_q2.wdata),
    .s_axi_wstrb    (lcl_cl_sh_ddrb_q2.wstrb),
    .s_axi_wlast    (lcl_cl_sh_ddrb_q2.wlast),
    .s_axi_wvalid   (lcl_cl_sh_ddrb_q2.wvalid),
    .s_axi_wready   (lcl_cl_sh_ddrb_q2.wready),
    .s_axi_bid      (lcl_cl_sh_ddrb_q2.bid),
    .s_axi_bresp    (lcl_cl_sh_ddrb_q2.bresp),
    .s_axi_bvalid   (lcl_cl_sh_ddrb_q2.bvalid),
    .s_axi_bready   (lcl_cl_sh_ddrb_q2.bready),
    .s_axi_arid     (lcl_cl_sh_ddrb_q2.arid),
    .s_axi_araddr   (lcl_cl_sh_ddrb_q2.araddr),
    .s_axi_arlen    (lcl_cl_sh_ddrb_q2.arlen),
    .s_axi_arsize   (lcl_cl_sh_ddrb_q2.arsize),
    .s_axi_arburst  (2'b1),
    .s_axi_arlock   (1'b0),
    .s_axi_arcache  (4'b11),
    .s_axi_arprot   (3'b10),
    .s_axi_arregion (4'b0),
    .s_axi_arqos    (4'b0),
    .s_axi_arvalid  (lcl_cl_sh_ddrb_q2.arvalid),
    .s_axi_arready  (lcl_cl_sh_ddrb_q2.arready),
    .s_axi_rid      (lcl_cl_sh_ddrb_q2.rid),
    .s_axi_rdata    (lcl_cl_sh_ddrb_q2.rdata),
    .s_axi_rresp    (lcl_cl_sh_ddrb_q2.rresp),
    .s_axi_rlast    (lcl_cl_sh_ddrb_q2.rlast),
    .s_axi_rvalid   (lcl_cl_sh_ddrb_q2.rvalid),
    .s_axi_rready   (lcl_cl_sh_ddrb_q2.rready),
    .m_axi_awid     (lcl_cl_sh_ddrb_q3.awid),
    .m_axi_awaddr   (lcl_cl_sh_ddrb_q3.awaddr),
    .m_axi_awlen    (lcl_cl_sh_ddrb_q3.awlen),
    .m_axi_awsize   (lcl_cl_sh_ddrb_q3.awsize),
    .m_axi_awburst  (),
    .m_axi_awlock   (),
    .m_axi_awcache  (),
    .m_axi_awprot   (),
    .m_axi_awregion (),
    .m_axi_awqos    (),
    .m_axi_awvalid  (lcl_cl_sh_ddrb_q3.awvalid),
    .m_axi_awready  (lcl_cl_sh_ddrb_q3.awready),
    .m_axi_wdata    (lcl_cl_sh_ddrb_q3.wdata),
    .m_axi_wstrb    (lcl_cl_sh_ddrb_q3.wstrb),
    .m_axi_wlast    (lcl_cl_sh_ddrb_q3.wlast),
    .m_axi_wvalid   (lcl_cl_sh_ddrb_q3.wvalid),
    .m_axi_wready   (lcl_cl_sh_ddrb_q3.wready),
    .m_axi_bid      (lcl_cl_sh_ddrb_q3.bid),
    .m_axi_bresp    (lcl_cl_sh_ddrb_q3.bresp),
    .m_axi_bvalid   (lcl_cl_sh_ddrb_q3.bvalid),
    .m_axi_bready   (lcl_cl_sh_ddrb_q3.bready),
    .m_axi_arid     (lcl_cl_sh_ddrb_q3.arid),
    .m_axi_araddr   (lcl_cl_sh_ddrb_q3.araddr),
    .m_axi_arlen    (lcl_cl_sh_ddrb_q3.arlen),
    .m_axi_arsize   (lcl_cl_sh_ddrb_q3.arsize),
    .m_axi_arburst  (),
    .m_axi_arlock   (),
    .m_axi_arcache  (),
    .m_axi_arprot   (),
    .m_axi_arregion (),
    .m_axi_arqos    (),
    .m_axi_arvalid  (lcl_cl_sh_ddrb_q3.arvalid),
    .m_axi_arready  (lcl_cl_sh_ddrb_q3.arready),
    .m_axi_rid      (lcl_cl_sh_ddrb_q3.rid),
    .m_axi_rdata    (lcl_cl_sh_ddrb_q3.rdata),
    .m_axi_rresp    (lcl_cl_sh_ddrb_q3.rresp),
    .m_axi_rlast    (lcl_cl_sh_ddrb_q3.rlast),
    .m_axi_rvalid   (lcl_cl_sh_ddrb_q3.rvalid),
    .m_axi_rready   (lcl_cl_sh_ddrb_q3.rready)
);

assign lcl_cl_sh_ddrb.awid 			= {9'b0, lcl_cl_sh_ddrb_q3.awid[6:0]};	//this width mismatch should be set
assign lcl_cl_sh_ddrb.awaddr 		= lcl_cl_sh_ddrb_q3.awaddr;
assign lcl_cl_sh_ddrb.awlen 		= lcl_cl_sh_ddrb_q3.awlen;
assign lcl_cl_sh_ddrb.awsize		= lcl_cl_sh_ddrb_q3.awsize;
assign lcl_cl_sh_ddrb.awvalid		= lcl_cl_sh_ddrb_q3.awvalid;
assign lcl_cl_sh_ddrb_q3.awready	= lcl_cl_sh_ddrb.awready;

//assign lcl_cl_sh_ddrb.wid	 		= {9'b0, lcl_cl_sh_ddrb_q3.wid[6:0]};
assign lcl_cl_sh_ddrb.wdata	 		= lcl_cl_sh_ddrb_q3.wdata;
assign lcl_cl_sh_ddrb.wstrb	 		= lcl_cl_sh_ddrb_q3.wstrb;
assign lcl_cl_sh_ddrb.wlast	 		= lcl_cl_sh_ddrb_q3.wlast;
assign lcl_cl_sh_ddrb.wvalid		= lcl_cl_sh_ddrb_q3.wvalid;
assign lcl_cl_sh_ddrb_q3.wready		= lcl_cl_sh_ddrb.wready;
assign lcl_cl_sh_ddrb_q3.bid		= lcl_cl_sh_ddrb.bid;
assign lcl_cl_sh_ddrb_q3.bresp		= lcl_cl_sh_ddrb.bresp;
assign lcl_cl_sh_ddrb_q3.bvalid		= lcl_cl_sh_ddrb.bvalid;
assign lcl_cl_sh_ddrb.bready		= lcl_cl_sh_ddrb_q3.bready;

assign lcl_cl_sh_ddrb.arid 			= {9'b0, lcl_cl_sh_ddrb_q3.arid[6:0]};
assign lcl_cl_sh_ddrb.araddr		= lcl_cl_sh_ddrb_q3.araddr;
assign lcl_cl_sh_ddrb.arlen 		= lcl_cl_sh_ddrb_q3.arlen;
assign lcl_cl_sh_ddrb.arsize 		= lcl_cl_sh_ddrb_q3.arsize;
assign lcl_cl_sh_ddrb.arvalid 		= lcl_cl_sh_ddrb_q3.arvalid;
assign lcl_cl_sh_ddrb_q3.arready	= lcl_cl_sh_ddrb.arready;

assign lcl_cl_sh_ddrb_q3.rid		= lcl_cl_sh_ddrb.rid;
assign lcl_cl_sh_ddrb_q3.rdata		= lcl_cl_sh_ddrb.rdata;
assign lcl_cl_sh_ddrb_q3.rresp		= lcl_cl_sh_ddrb.rresp;
assign lcl_cl_sh_ddrb_q3.rlast		= lcl_cl_sh_ddrb.rlast;
assign lcl_cl_sh_ddrb_q3.rvalid		= lcl_cl_sh_ddrb.rvalid;
assign lcl_cl_sh_ddrb.rready		= lcl_cl_sh_ddrb_q3.rready;

//assign lcl_cl_sh_RLWE_output_FIFO_q.awready 	= 0;
//assign lcl_cl_sh_RLWE_output_FIFO_q.wready 		= 0;
//assign lcl_cl_sh_RLWE_output_FIFO_q.bid 		= 0;
//assign lcl_cl_sh_RLWE_output_FIFO_q.bresp 		= 0;
//assign lcl_cl_sh_RLWE_output_FIFO_q.bvalid		= 0;
//assign lcl_cl_sh_RLWE_output_FIFO_q.arready		= 0;
//assign lcl_cl_sh_RLWE_output_FIFO_q.rid			= 0;
//assign lcl_cl_sh_RLWE_output_FIFO_q.rdata		= 0;
//assign lcl_cl_sh_RLWE_output_FIFO_q.rresp		= 0;
//assign lcl_cl_sh_RLWE_output_FIFO_q.rlast		= 0;
//assign lcl_cl_sh_RLWE_output_FIFO_q.rvalid		= 0;

src_register_slice RLWE_INPUT_AXI4_REG_SLC_1 (
    .aclk           (aclk),
    .aresetn        (slr1_sync_aresetn),
    .s_axi_awid     (lcl_cl_sh_RLWE_input_FIFO_q.awid),
    .s_axi_awaddr   (lcl_cl_sh_RLWE_input_FIFO_q.awaddr),
    .s_axi_awlen    (lcl_cl_sh_RLWE_input_FIFO_q.awlen),
    .s_axi_awsize   (lcl_cl_sh_RLWE_input_FIFO_q.awsize),
    .s_axi_awburst  (2'b1),
    .s_axi_awlock   (1'b0),
    .s_axi_awcache  (4'b11),
    .s_axi_awprot   (3'b10),
    .s_axi_awregion (4'b0),
    .s_axi_awqos    (4'b0),
    .s_axi_awvalid  (lcl_cl_sh_RLWE_input_FIFO_q.awvalid),
    .s_axi_awready  (lcl_cl_sh_RLWE_input_FIFO_q.awready),
    .s_axi_wdata    (lcl_cl_sh_RLWE_input_FIFO_q.wdata),
    .s_axi_wstrb    (lcl_cl_sh_RLWE_input_FIFO_q.wstrb),
    .s_axi_wlast    (lcl_cl_sh_RLWE_input_FIFO_q.wlast),
    .s_axi_wvalid   (lcl_cl_sh_RLWE_input_FIFO_q.wvalid),
    .s_axi_wready   (lcl_cl_sh_RLWE_input_FIFO_q.wready),
    .s_axi_bid      (lcl_cl_sh_RLWE_input_FIFO_q.bid),
    .s_axi_bresp    (lcl_cl_sh_RLWE_input_FIFO_q.bresp),
    .s_axi_bvalid   (lcl_cl_sh_RLWE_input_FIFO_q.bvalid),
    .s_axi_bready   (lcl_cl_sh_RLWE_input_FIFO_q.bready),
    .s_axi_arid     (lcl_cl_sh_RLWE_input_FIFO_q.arid),
    .s_axi_araddr   (lcl_cl_sh_RLWE_input_FIFO_q.araddr),
    .s_axi_arlen    (lcl_cl_sh_RLWE_input_FIFO_q.arlen),
    .s_axi_arsize   (lcl_cl_sh_RLWE_input_FIFO_q.arsize),
    .s_axi_arburst  (2'b1),
    .s_axi_arlock   (1'b0),
    .s_axi_arcache  (4'b11),
    .s_axi_arprot   (3'b10),
    .s_axi_arregion (4'b0),
    .s_axi_arqos    (4'b0),
    .s_axi_arvalid  (lcl_cl_sh_RLWE_input_FIFO_q.arvalid),
    .s_axi_arready  (lcl_cl_sh_RLWE_input_FIFO_q.arready),
    .s_axi_rid      (lcl_cl_sh_RLWE_input_FIFO_q.rid),
    .s_axi_rdata    (lcl_cl_sh_RLWE_input_FIFO_q.rdata),
    .s_axi_rresp    (lcl_cl_sh_RLWE_input_FIFO_q.rresp),
    .s_axi_rlast    (lcl_cl_sh_RLWE_input_FIFO_q.rlast),
    .s_axi_rvalid   (lcl_cl_sh_RLWE_input_FIFO_q.rvalid),
    .s_axi_rready   (lcl_cl_sh_RLWE_input_FIFO_q.rready),
    .m_axi_awid     (lcl_cl_sh_RLWE_input_FIFO_q2.awid),
    .m_axi_awaddr   (lcl_cl_sh_RLWE_input_FIFO_q2.awaddr),
    .m_axi_awlen    (lcl_cl_sh_RLWE_input_FIFO_q2.awlen),
    .m_axi_awsize   (lcl_cl_sh_RLWE_input_FIFO_q2.awsize),
    .m_axi_awburst  (),
    .m_axi_awlock   (),
    .m_axi_awcache  (),
    .m_axi_awprot   (),
    .m_axi_awregion (),
    .m_axi_awqos    (),
    .m_axi_awvalid  (lcl_cl_sh_RLWE_input_FIFO_q2.awvalid),
    .m_axi_awready  (lcl_cl_sh_RLWE_input_FIFO_q2.awready),
    .m_axi_wdata    (lcl_cl_sh_RLWE_input_FIFO_q2.wdata),
    .m_axi_wstrb    (lcl_cl_sh_RLWE_input_FIFO_q2.wstrb),
    .m_axi_wlast    (lcl_cl_sh_RLWE_input_FIFO_q2.wlast),
    .m_axi_wvalid   (lcl_cl_sh_RLWE_input_FIFO_q2.wvalid),
    .m_axi_wready   (lcl_cl_sh_RLWE_input_FIFO_q2.wready),
    .m_axi_bid      (lcl_cl_sh_RLWE_input_FIFO_q2.bid),
    .m_axi_bresp    (lcl_cl_sh_RLWE_input_FIFO_q2.bresp),
    .m_axi_bvalid   (lcl_cl_sh_RLWE_input_FIFO_q2.bvalid),
    .m_axi_bready   (lcl_cl_sh_RLWE_input_FIFO_q2.bready),
    .m_axi_arid     (lcl_cl_sh_RLWE_input_FIFO_q2.arid),
    .m_axi_araddr   (lcl_cl_sh_RLWE_input_FIFO_q2.araddr),
    .m_axi_arlen    (lcl_cl_sh_RLWE_input_FIFO_q2.arlen),
    .m_axi_arsize   (lcl_cl_sh_RLWE_input_FIFO_q2.arsize),
    .m_axi_arburst  (),
    .m_axi_arlock   (),
    .m_axi_arcache  (),
    .m_axi_arprot   (),
    .m_axi_arregion (),
    .m_axi_arqos    (),
    .m_axi_arvalid  (lcl_cl_sh_RLWE_input_FIFO_q2.arvalid),
    .m_axi_arready  (lcl_cl_sh_RLWE_input_FIFO_q2.arready),
    .m_axi_rid      (lcl_cl_sh_RLWE_input_FIFO_q2.rid),
    .m_axi_rdata    (lcl_cl_sh_RLWE_input_FIFO_q2.rdata),
    .m_axi_rresp    (lcl_cl_sh_RLWE_input_FIFO_q2.rresp),
    .m_axi_rlast    (lcl_cl_sh_RLWE_input_FIFO_q2.rlast),
    .m_axi_rvalid   (lcl_cl_sh_RLWE_input_FIFO_q2.rvalid),
    .m_axi_rready   (lcl_cl_sh_RLWE_input_FIFO_q2.rready)
    );

dest_register_slice RLWE_INPUT_AXI4_REG_SLC_2 (
    .aclk           (aclk),
    .aresetn        (slr2_sync_aresetn),
    .s_axi_awid     (lcl_cl_sh_RLWE_input_FIFO_q2.awid),
    .s_axi_awaddr   (lcl_cl_sh_RLWE_input_FIFO_q2.awaddr),
    .s_axi_awlen    (lcl_cl_sh_RLWE_input_FIFO_q2.awlen),
    .s_axi_awsize   (lcl_cl_sh_RLWE_input_FIFO_q2.awsize),
    .s_axi_awburst  (2'b1),
    .s_axi_awlock   (1'b0),
    .s_axi_awcache  (4'b11),
    .s_axi_awprot   (3'b10),
    .s_axi_awregion (4'b0),
    .s_axi_awqos    (4'b0),
    .s_axi_awvalid  (lcl_cl_sh_RLWE_input_FIFO_q2.awvalid),
    .s_axi_awready  (lcl_cl_sh_RLWE_input_FIFO_q2.awready),
    .s_axi_wdata    (lcl_cl_sh_RLWE_input_FIFO_q2.wdata),
    .s_axi_wstrb    (lcl_cl_sh_RLWE_input_FIFO_q2.wstrb),
    .s_axi_wlast    (lcl_cl_sh_RLWE_input_FIFO_q2.wlast),
    .s_axi_wvalid   (lcl_cl_sh_RLWE_input_FIFO_q2.wvalid),
    .s_axi_wready   (lcl_cl_sh_RLWE_input_FIFO_q2.wready),
    .s_axi_bid      (lcl_cl_sh_RLWE_input_FIFO_q2.bid),
    .s_axi_bresp    (lcl_cl_sh_RLWE_input_FIFO_q2.bresp),
    .s_axi_bvalid   (lcl_cl_sh_RLWE_input_FIFO_q2.bvalid),
    .s_axi_bready   (lcl_cl_sh_RLWE_input_FIFO_q2.bready),
    .s_axi_arid     (lcl_cl_sh_RLWE_input_FIFO_q2.arid),
    .s_axi_araddr   (lcl_cl_sh_RLWE_input_FIFO_q2.araddr),
    .s_axi_arlen    (lcl_cl_sh_RLWE_input_FIFO_q2.arlen),
    .s_axi_arsize   (lcl_cl_sh_RLWE_input_FIFO_q2.arsize),
    .s_axi_arburst  (2'b1),
    .s_axi_arlock   (1'b0),
    .s_axi_arcache  (4'b11),
    .s_axi_arprot   (3'b10),
    .s_axi_arregion (4'b0),
    .s_axi_arqos    (4'b0),
    .s_axi_arvalid  (lcl_cl_sh_RLWE_input_FIFO_q2.arvalid),
    .s_axi_arready  (lcl_cl_sh_RLWE_input_FIFO_q2.arready),
    .s_axi_rid      (lcl_cl_sh_RLWE_input_FIFO_q2.rid),
    .s_axi_rdata    (lcl_cl_sh_RLWE_input_FIFO_q2.rdata),
    .s_axi_rresp    (lcl_cl_sh_RLWE_input_FIFO_q2.rresp),
    .s_axi_rlast    (lcl_cl_sh_RLWE_input_FIFO_q2.rlast),
    .s_axi_rvalid   (lcl_cl_sh_RLWE_input_FIFO_q2.rvalid),
    .s_axi_rready   (lcl_cl_sh_RLWE_input_FIFO_q2.rready),
    .m_axi_awid     (lcl_cl_sh_RLWE_input_FIFO_q3.awid),
    .m_axi_awaddr   (lcl_cl_sh_RLWE_input_FIFO_q3.awaddr),
    .m_axi_awlen    (lcl_cl_sh_RLWE_input_FIFO_q3.awlen),
    .m_axi_awsize   (lcl_cl_sh_RLWE_input_FIFO_q3.awsize),
    .m_axi_awburst  (),
    .m_axi_awlock   (),
    .m_axi_awcache  (),
    .m_axi_awprot   (),
    .m_axi_awregion (),
    .m_axi_awqos    (),
    .m_axi_awvalid  (lcl_cl_sh_RLWE_input_FIFO_q3.awvalid),
    .m_axi_awready  (lcl_cl_sh_RLWE_input_FIFO_q3.awready),
    .m_axi_wdata    (lcl_cl_sh_RLWE_input_FIFO_q3.wdata),
    .m_axi_wstrb    (lcl_cl_sh_RLWE_input_FIFO_q3.wstrb),
    .m_axi_wlast    (lcl_cl_sh_RLWE_input_FIFO_q3.wlast),
    .m_axi_wvalid   (lcl_cl_sh_RLWE_input_FIFO_q3.wvalid),
    .m_axi_wready   (lcl_cl_sh_RLWE_input_FIFO_q3.wready),
    .m_axi_bid      (lcl_cl_sh_RLWE_input_FIFO_q3.bid),
    .m_axi_bresp    (lcl_cl_sh_RLWE_input_FIFO_q3.bresp),
    .m_axi_bvalid   (lcl_cl_sh_RLWE_input_FIFO_q3.bvalid),
    .m_axi_bready   (lcl_cl_sh_RLWE_input_FIFO_q3.bready),
    .m_axi_arid     (lcl_cl_sh_RLWE_input_FIFO_q3.arid),
    .m_axi_araddr   (lcl_cl_sh_RLWE_input_FIFO_q3.araddr),
    .m_axi_arlen    (lcl_cl_sh_RLWE_input_FIFO_q3.arlen),
    .m_axi_arsize   (lcl_cl_sh_RLWE_input_FIFO_q3.arsize),
    .m_axi_arburst  (),
    .m_axi_arlock   (),
    .m_axi_arcache  (),
    .m_axi_arprot   (),
    .m_axi_arregion (),
    .m_axi_arqos    (),
    .m_axi_arvalid  (lcl_cl_sh_RLWE_input_FIFO_q3.arvalid),
    .m_axi_arready  (lcl_cl_sh_RLWE_input_FIFO_q3.arready),
    .m_axi_rid      (lcl_cl_sh_RLWE_input_FIFO_q3.rid),
    .m_axi_rdata    (lcl_cl_sh_RLWE_input_FIFO_q3.rdata),
    .m_axi_rresp    (lcl_cl_sh_RLWE_input_FIFO_q3.rresp),
    .m_axi_rlast    (lcl_cl_sh_RLWE_input_FIFO_q3.rlast),
    .m_axi_rvalid   (lcl_cl_sh_RLWE_input_FIFO_q3.rvalid),
    .m_axi_rready   (lcl_cl_sh_RLWE_input_FIFO_q3.rready)
);

//direct connection for the RLWE FIFO IF, if hard to meet timming, add a reg
//slice
assign lcl_cl_sh_RLWE_input_FIFO_q3.awready 	= lcl_cl_sh_RLWE_input_FIFO.awready;
assign lcl_cl_sh_RLWE_input_FIFO_q3.wready 		= lcl_cl_sh_RLWE_input_FIFO.wready;
assign lcl_cl_sh_RLWE_input_FIFO_q3.bid 		= lcl_cl_sh_RLWE_input_FIFO.bid;
assign lcl_cl_sh_RLWE_input_FIFO_q3.bresp 		= lcl_cl_sh_RLWE_input_FIFO.bresp;
assign lcl_cl_sh_RLWE_input_FIFO_q3.bvalid 		= lcl_cl_sh_RLWE_input_FIFO.bvalid;
assign lcl_cl_sh_RLWE_input_FIFO_q3.arready 	= lcl_cl_sh_RLWE_input_FIFO.arready;
assign lcl_cl_sh_RLWE_input_FIFO_q3.rid 		= lcl_cl_sh_RLWE_input_FIFO.rid;
assign lcl_cl_sh_RLWE_input_FIFO_q3.rdata 		= lcl_cl_sh_RLWE_input_FIFO.rdata;
assign lcl_cl_sh_RLWE_input_FIFO_q3.rresp 		= lcl_cl_sh_RLWE_input_FIFO.rresp;
assign lcl_cl_sh_RLWE_input_FIFO_q3.rlast 		= lcl_cl_sh_RLWE_input_FIFO.rlast;
assign lcl_cl_sh_RLWE_input_FIFO_q3.rvalid 		= lcl_cl_sh_RLWE_input_FIFO.rvalid;

assign lcl_cl_sh_RLWE_input_FIFO.awid 		= {9'b0, lcl_cl_sh_RLWE_input_FIFO_q3.awid[6 : 0]};
assign lcl_cl_sh_RLWE_input_FIFO.awaddr 	= lcl_cl_sh_RLWE_input_FIFO_q3.awaddr;
assign lcl_cl_sh_RLWE_input_FIFO.awlen 		= lcl_cl_sh_RLWE_input_FIFO_q3.awlen;
assign lcl_cl_sh_RLWE_input_FIFO.awsize 	= lcl_cl_sh_RLWE_input_FIFO_q3.awsize;
assign lcl_cl_sh_RLWE_input_FIFO.awvalid 	= lcl_cl_sh_RLWE_input_FIFO_q3.awvalid;
assign lcl_cl_sh_RLWE_input_FIFO.wid 		= lcl_cl_sh_RLWE_input_FIFO_q3.wid;
assign lcl_cl_sh_RLWE_input_FIFO.wdata		= lcl_cl_sh_RLWE_input_FIFO_q3.wdata;
assign lcl_cl_sh_RLWE_input_FIFO.wstrb 		= lcl_cl_sh_RLWE_input_FIFO_q3.wstrb;
assign lcl_cl_sh_RLWE_input_FIFO.wlast 		= lcl_cl_sh_RLWE_input_FIFO_q3.wlast;
assign lcl_cl_sh_RLWE_input_FIFO.wvalid 	= lcl_cl_sh_RLWE_input_FIFO_q3.wvalid;
assign lcl_cl_sh_RLWE_input_FIFO.bready 	= lcl_cl_sh_RLWE_input_FIFO_q3.bready;
assign lcl_cl_sh_RLWE_input_FIFO.arid 		= {9'b0, lcl_cl_sh_RLWE_input_FIFO_q3.arid[6 : 0]};
assign lcl_cl_sh_RLWE_input_FIFO.araddr 	= lcl_cl_sh_RLWE_input_FIFO_q3.araddr;
assign lcl_cl_sh_RLWE_input_FIFO.arlen 		= lcl_cl_sh_RLWE_input_FIFO_q3.arlen;
assign lcl_cl_sh_RLWE_input_FIFO.arsize 	= lcl_cl_sh_RLWE_input_FIFO_q3.arsize;
assign lcl_cl_sh_RLWE_input_FIFO.arvalid 	= lcl_cl_sh_RLWE_input_FIFO_q3.arvalid;
assign lcl_cl_sh_RLWE_input_FIFO.rready 	= lcl_cl_sh_RLWE_input_FIFO_q3.rready;

src_register_slice RLWE_OUTPUT_AXI4_REG_SLC_1 (
    .aclk           (aclk),
    .aresetn        (slr1_sync_aresetn),
    .s_axi_awid     (lcl_cl_sh_RLWE_output_FIFO_q.awid),
    .s_axi_awaddr   (lcl_cl_sh_RLWE_output_FIFO_q.awaddr),
    .s_axi_awlen    (lcl_cl_sh_RLWE_output_FIFO_q.awlen),
    .s_axi_awsize   (lcl_cl_sh_RLWE_output_FIFO_q.awsize),
    .s_axi_awburst  (2'b1),
    .s_axi_awlock   (1'b0),
    .s_axi_awcache  (4'b11),
    .s_axi_awprot   (3'b10),
    .s_axi_awregion (4'b0),
    .s_axi_awqos    (4'b0),
    .s_axi_awvalid  (lcl_cl_sh_RLWE_output_FIFO_q.awvalid),
    .s_axi_awready  (lcl_cl_sh_RLWE_output_FIFO_q.awready),
    .s_axi_wdata    (lcl_cl_sh_RLWE_output_FIFO_q.wdata),
    .s_axi_wstrb    (lcl_cl_sh_RLWE_output_FIFO_q.wstrb),
    .s_axi_wlast    (lcl_cl_sh_RLWE_output_FIFO_q.wlast),
    .s_axi_wvalid   (lcl_cl_sh_RLWE_output_FIFO_q.wvalid),
    .s_axi_wready   (lcl_cl_sh_RLWE_output_FIFO_q.wready),
    .s_axi_bid      (lcl_cl_sh_RLWE_output_FIFO_q.bid),
    .s_axi_bresp    (lcl_cl_sh_RLWE_output_FIFO_q.bresp),
    .s_axi_bvalid   (lcl_cl_sh_RLWE_output_FIFO_q.bvalid),
    .s_axi_bready   (lcl_cl_sh_RLWE_output_FIFO_q.bready),
    .s_axi_arid     (lcl_cl_sh_RLWE_output_FIFO_q.arid),
    .s_axi_araddr   (lcl_cl_sh_RLWE_output_FIFO_q.araddr),
    .s_axi_arlen    (lcl_cl_sh_RLWE_output_FIFO_q.arlen),
    .s_axi_arsize   (lcl_cl_sh_RLWE_output_FIFO_q.arsize),
    .s_axi_arburst  (2'b1),
    .s_axi_arlock   (1'b0),
    .s_axi_arcache  (4'b11),
    .s_axi_arprot   (3'b10),
    .s_axi_arregion (4'b0),
    .s_axi_arqos    (4'b0),
    .s_axi_arvalid  (lcl_cl_sh_RLWE_output_FIFO_q.arvalid),
    .s_axi_arready  (lcl_cl_sh_RLWE_output_FIFO_q.arready),
    .s_axi_rid      (lcl_cl_sh_RLWE_output_FIFO_q.rid),
    .s_axi_rdata    (lcl_cl_sh_RLWE_output_FIFO_q.rdata),
    .s_axi_rresp    (lcl_cl_sh_RLWE_output_FIFO_q.rresp),
    .s_axi_rlast    (lcl_cl_sh_RLWE_output_FIFO_q.rlast),
    .s_axi_rvalid   (lcl_cl_sh_RLWE_output_FIFO_q.rvalid),
    .s_axi_rready   (lcl_cl_sh_RLWE_output_FIFO_q.rready),
    .m_axi_awid     (lcl_cl_sh_RLWE_output_FIFO_q2.awid),
    .m_axi_awaddr   (lcl_cl_sh_RLWE_output_FIFO_q2.awaddr),
    .m_axi_awlen    (lcl_cl_sh_RLWE_output_FIFO_q2.awlen),
    .m_axi_awsize   (lcl_cl_sh_RLWE_output_FIFO_q2.awsize),
    .m_axi_awburst  (),
    .m_axi_awlock   (),
    .m_axi_awcache  (),
    .m_axi_awprot   (),
    .m_axi_awregion (),
    .m_axi_awqos    (),
    .m_axi_awvalid  (lcl_cl_sh_RLWE_output_FIFO_q2.awvalid),
    .m_axi_awready  (lcl_cl_sh_RLWE_output_FIFO_q2.awready),
    .m_axi_wdata    (lcl_cl_sh_RLWE_output_FIFO_q2.wdata),
    .m_axi_wstrb    (lcl_cl_sh_RLWE_output_FIFO_q2.wstrb),
    .m_axi_wlast    (lcl_cl_sh_RLWE_output_FIFO_q2.wlast),
    .m_axi_wvalid   (lcl_cl_sh_RLWE_output_FIFO_q2.wvalid),
    .m_axi_wready   (lcl_cl_sh_RLWE_output_FIFO_q2.wready),
    .m_axi_bid      (lcl_cl_sh_RLWE_output_FIFO_q2.bid),
    .m_axi_bresp    (lcl_cl_sh_RLWE_output_FIFO_q2.bresp),
    .m_axi_bvalid   (lcl_cl_sh_RLWE_output_FIFO_q2.bvalid),
    .m_axi_bready   (lcl_cl_sh_RLWE_output_FIFO_q2.bready),
    .m_axi_arid     (lcl_cl_sh_RLWE_output_FIFO_q2.arid),
    .m_axi_araddr   (lcl_cl_sh_RLWE_output_FIFO_q2.araddr),
    .m_axi_arlen    (lcl_cl_sh_RLWE_output_FIFO_q2.arlen),
    .m_axi_arsize   (lcl_cl_sh_RLWE_output_FIFO_q2.arsize),
    .m_axi_arburst  (),
    .m_axi_arlock   (),
    .m_axi_arcache  (),
    .m_axi_arprot   (),
    .m_axi_arregion (),
    .m_axi_arqos    (),
    .m_axi_arvalid  (lcl_cl_sh_RLWE_output_FIFO_q2.arvalid),
    .m_axi_arready  (lcl_cl_sh_RLWE_output_FIFO_q2.arready),
    .m_axi_rid      (lcl_cl_sh_RLWE_output_FIFO_q2.rid),
    .m_axi_rdata    (lcl_cl_sh_RLWE_output_FIFO_q2.rdata),
    .m_axi_rresp    (lcl_cl_sh_RLWE_output_FIFO_q2.rresp),
    .m_axi_rlast    (lcl_cl_sh_RLWE_output_FIFO_q2.rlast),
    .m_axi_rvalid   (lcl_cl_sh_RLWE_output_FIFO_q2.rvalid),
    .m_axi_rready   (lcl_cl_sh_RLWE_output_FIFO_q2.rready)
    );

dest_register_slice RLWE_OUTPUT_AXI4_REG_SLC_2 (
    .aclk           (aclk),
    .aresetn        (slr2_sync_aresetn),
    .s_axi_awid     (lcl_cl_sh_RLWE_output_FIFO_q2.awid),
    .s_axi_awaddr   (lcl_cl_sh_RLWE_output_FIFO_q2.awaddr),
    .s_axi_awlen    (lcl_cl_sh_RLWE_output_FIFO_q2.awlen),
    .s_axi_awsize   (lcl_cl_sh_RLWE_output_FIFO_q2.awsize),
    .s_axi_awburst  (2'b1),
    .s_axi_awlock   (1'b0),
    .s_axi_awcache  (4'b11),
    .s_axi_awprot   (3'b10),
    .s_axi_awregion (4'b0),
    .s_axi_awqos    (4'b0),
    .s_axi_awvalid  (lcl_cl_sh_RLWE_output_FIFO_q2.awvalid),
    .s_axi_awready  (lcl_cl_sh_RLWE_output_FIFO_q2.awready),
    .s_axi_wdata    (lcl_cl_sh_RLWE_output_FIFO_q2.wdata),
    .s_axi_wstrb    (lcl_cl_sh_RLWE_output_FIFO_q2.wstrb),
    .s_axi_wlast    (lcl_cl_sh_RLWE_output_FIFO_q2.wlast),
    .s_axi_wvalid   (lcl_cl_sh_RLWE_output_FIFO_q2.wvalid),
    .s_axi_wready   (lcl_cl_sh_RLWE_output_FIFO_q2.wready),
    .s_axi_bid      (lcl_cl_sh_RLWE_output_FIFO_q2.bid),
    .s_axi_bresp    (lcl_cl_sh_RLWE_output_FIFO_q2.bresp),
    .s_axi_bvalid   (lcl_cl_sh_RLWE_output_FIFO_q2.bvalid),
    .s_axi_bready   (lcl_cl_sh_RLWE_output_FIFO_q2.bready),
    .s_axi_arid     (lcl_cl_sh_RLWE_output_FIFO_q2.arid),
    .s_axi_araddr   (lcl_cl_sh_RLWE_output_FIFO_q2.araddr),
    .s_axi_arlen    (lcl_cl_sh_RLWE_output_FIFO_q2.arlen),
    .s_axi_arsize   (lcl_cl_sh_RLWE_output_FIFO_q2.arsize),
    .s_axi_arburst  (2'b1),
    .s_axi_arlock   (1'b0),
    .s_axi_arcache  (4'b11),
    .s_axi_arprot   (3'b10),
    .s_axi_arregion (4'b0),
    .s_axi_arqos    (4'b0),
    .s_axi_arvalid  (lcl_cl_sh_RLWE_output_FIFO_q2.arvalid),
    .s_axi_arready  (lcl_cl_sh_RLWE_output_FIFO_q2.arready),
    .s_axi_rid      (lcl_cl_sh_RLWE_output_FIFO_q2.rid),
    .s_axi_rdata    (lcl_cl_sh_RLWE_output_FIFO_q2.rdata),
    .s_axi_rresp    (lcl_cl_sh_RLWE_output_FIFO_q2.rresp),
    .s_axi_rlast    (lcl_cl_sh_RLWE_output_FIFO_q2.rlast),
    .s_axi_rvalid   (lcl_cl_sh_RLWE_output_FIFO_q2.rvalid),
    .s_axi_rready   (lcl_cl_sh_RLWE_output_FIFO_q2.rready),
    .m_axi_awid     (lcl_cl_sh_RLWE_output_FIFO_q3.awid),
    .m_axi_awaddr   (lcl_cl_sh_RLWE_output_FIFO_q3.awaddr),
    .m_axi_awlen    (lcl_cl_sh_RLWE_output_FIFO_q3.awlen),
    .m_axi_awsize   (lcl_cl_sh_RLWE_output_FIFO_q3.awsize),
    .m_axi_awburst  (),
    .m_axi_awlock   (),
    .m_axi_awcache  (),
    .m_axi_awprot   (),
    .m_axi_awregion (),
    .m_axi_awqos    (),
    .m_axi_awvalid  (lcl_cl_sh_RLWE_output_FIFO_q3.awvalid),
    .m_axi_awready  (lcl_cl_sh_RLWE_output_FIFO_q3.awready),
    .m_axi_wdata    (lcl_cl_sh_RLWE_output_FIFO_q3.wdata),
    .m_axi_wstrb    (lcl_cl_sh_RLWE_output_FIFO_q3.wstrb),
    .m_axi_wlast    (lcl_cl_sh_RLWE_output_FIFO_q3.wlast),
    .m_axi_wvalid   (lcl_cl_sh_RLWE_output_FIFO_q3.wvalid),
    .m_axi_wready   (lcl_cl_sh_RLWE_output_FIFO_q3.wready),
    .m_axi_bid      (lcl_cl_sh_RLWE_output_FIFO_q3.bid),
    .m_axi_bresp    (lcl_cl_sh_RLWE_output_FIFO_q3.bresp),
    .m_axi_bvalid   (lcl_cl_sh_RLWE_output_FIFO_q3.bvalid),
    .m_axi_bready   (lcl_cl_sh_RLWE_output_FIFO_q3.bready),
    .m_axi_arid     (lcl_cl_sh_RLWE_output_FIFO_q3.arid),
    .m_axi_araddr   (lcl_cl_sh_RLWE_output_FIFO_q3.araddr),
    .m_axi_arlen    (lcl_cl_sh_RLWE_output_FIFO_q3.arlen),
    .m_axi_arsize   (lcl_cl_sh_RLWE_output_FIFO_q3.arsize),
    .m_axi_arburst  (),
    .m_axi_arlock   (),
    .m_axi_arcache  (),
    .m_axi_arprot   (),
    .m_axi_arregion (),
    .m_axi_arqos    (),
    .m_axi_arvalid  (lcl_cl_sh_RLWE_output_FIFO_q3.arvalid),
    .m_axi_arready  (lcl_cl_sh_RLWE_output_FIFO_q3.arready),
    .m_axi_rid      (lcl_cl_sh_RLWE_output_FIFO_q3.rid),
    .m_axi_rdata    (lcl_cl_sh_RLWE_output_FIFO_q3.rdata),
    .m_axi_rresp    (lcl_cl_sh_RLWE_output_FIFO_q3.rresp),
    .m_axi_rlast    (lcl_cl_sh_RLWE_output_FIFO_q3.rlast),
    .m_axi_rvalid   (lcl_cl_sh_RLWE_output_FIFO_q3.rvalid),
    .m_axi_rready   (lcl_cl_sh_RLWE_output_FIFO_q3.rready)
);



//direct connection for the RLWE FIFO IF, if hard to meet timming, add a reg
//slice
assign lcl_cl_sh_RLWE_output_FIFO_q3.awready	= lcl_cl_sh_RLWE_output_FIFO.awready;
assign lcl_cl_sh_RLWE_output_FIFO_q3.wready 	= lcl_cl_sh_RLWE_output_FIFO.wready;
assign lcl_cl_sh_RLWE_output_FIFO_q3.bid 		= lcl_cl_sh_RLWE_output_FIFO.bid;
assign lcl_cl_sh_RLWE_output_FIFO_q3.bresp 		= lcl_cl_sh_RLWE_output_FIFO.bresp;
assign lcl_cl_sh_RLWE_output_FIFO_q3.bvalid 	= lcl_cl_sh_RLWE_output_FIFO.bvalid;
assign lcl_cl_sh_RLWE_output_FIFO_q3.arready	= lcl_cl_sh_RLWE_output_FIFO.arready;
assign lcl_cl_sh_RLWE_output_FIFO_q3.rid 		= lcl_cl_sh_RLWE_output_FIFO.rid;
assign lcl_cl_sh_RLWE_output_FIFO_q3.rdata 		= lcl_cl_sh_RLWE_output_FIFO.rdata;
assign lcl_cl_sh_RLWE_output_FIFO_q3.rresp 		= lcl_cl_sh_RLWE_output_FIFO.rresp;
assign lcl_cl_sh_RLWE_output_FIFO_q3.rlast 		= lcl_cl_sh_RLWE_output_FIFO.rlast;
assign lcl_cl_sh_RLWE_output_FIFO_q3.rvalid 	= lcl_cl_sh_RLWE_output_FIFO.rvalid;

assign lcl_cl_sh_RLWE_output_FIFO.awid 		= {9'b0, lcl_cl_sh_RLWE_output_FIFO_q3.awid[6 : 0]};
assign lcl_cl_sh_RLWE_output_FIFO.awaddr 	= lcl_cl_sh_RLWE_output_FIFO_q3.awaddr;
assign lcl_cl_sh_RLWE_output_FIFO.awlen 	= lcl_cl_sh_RLWE_output_FIFO_q3.awlen;
assign lcl_cl_sh_RLWE_output_FIFO.awsize 	= lcl_cl_sh_RLWE_output_FIFO_q3.awsize;
assign lcl_cl_sh_RLWE_output_FIFO.awvalid 	= lcl_cl_sh_RLWE_output_FIFO_q3.awvalid;
assign lcl_cl_sh_RLWE_output_FIFO.wid 		= lcl_cl_sh_RLWE_output_FIFO_q3.wid;
assign lcl_cl_sh_RLWE_output_FIFO.wdata		= lcl_cl_sh_RLWE_output_FIFO_q3.wdata;
assign lcl_cl_sh_RLWE_output_FIFO.wstrb 	= lcl_cl_sh_RLWE_output_FIFO_q3.wstrb;
assign lcl_cl_sh_RLWE_output_FIFO.wlast 	= lcl_cl_sh_RLWE_output_FIFO_q3.wlast;
assign lcl_cl_sh_RLWE_output_FIFO.wvalid 	= lcl_cl_sh_RLWE_output_FIFO_q3.wvalid;
assign lcl_cl_sh_RLWE_output_FIFO.bready 	= lcl_cl_sh_RLWE_output_FIFO_q3.bready;
assign lcl_cl_sh_RLWE_output_FIFO.arid 		= {9'b0, lcl_cl_sh_RLWE_output_FIFO_q3.arid[6 : 0]};
assign lcl_cl_sh_RLWE_output_FIFO.araddr 	= lcl_cl_sh_RLWE_output_FIFO_q3.araddr;
assign lcl_cl_sh_RLWE_output_FIFO.arlen 	= lcl_cl_sh_RLWE_output_FIFO_q3.arlen;
assign lcl_cl_sh_RLWE_output_FIFO.arsize 	= lcl_cl_sh_RLWE_output_FIFO_q3.arsize;
assign lcl_cl_sh_RLWE_output_FIFO.arvalid 	= lcl_cl_sh_RLWE_output_FIFO_q3.arvalid;
assign lcl_cl_sh_RLWE_output_FIFO.rready 	= lcl_cl_sh_RLWE_output_FIFO_q3.rready;


endmodule

