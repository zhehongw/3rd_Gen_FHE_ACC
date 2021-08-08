`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/24/2021 08:50:59 PM
// Design Name: 
// Module Name: axil_bar1_slave
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: this module is used to program the NTT/iNTT twiddle factor buffers, for now it only support write functionality. No reading the buffers.
// And it only supports `MAX_LEN = 2048, `LINE_SIZE = 2 or 4
// Make sure the data are seperate into two 27-bit numbers with leading zeros
// to form 32 bit transferred data  
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "common.vh"
module axil_bar1_slave #(
	parameter STAGES = $clog2(`MAX_LEN),
	parameter COL_WIDTH = `BIT_WIDTH / 2 
)(  
	input 	clk, 
	input 	rstn,
    axi_bus_if.to_master sh_cl_bar1_bus,

    ROU_config_if.to_ROU_table rou_wr_port [0 : STAGES - 1],
	ROU_config_if.to_ROU_table irou_wr_port

);
//this module is used to setup all the ROU tables in the cl

axi_bus_if sh_cl_bar1_bus_q();
axi_bus_if sh_cl_bar1_bus_q2();

//---------------------------------
// flop the input BAR1 bus
//---------------------------------
axi_register_slice_light AXIL_BAR1_REG_SLC_1 (
	.aclk          (clk),
	.aresetn       (rstn),
	.s_axi_awaddr  (sh_cl_bar1_bus.awaddr[31:0]),
	.s_axi_awvalid (sh_cl_bar1_bus.awvalid),
	.s_axi_awready (sh_cl_bar1_bus.awready),
	.s_axi_wdata   (sh_cl_bar1_bus.wdata[31:0]),
	.s_axi_wstrb   (sh_cl_bar1_bus.wstrb[3:0]),
	.s_axi_wvalid  (sh_cl_bar1_bus.wvalid),
	.s_axi_wready  (sh_cl_bar1_bus.wready),
	.s_axi_bresp   (sh_cl_bar1_bus.bresp),
	.s_axi_bvalid  (sh_cl_bar1_bus.bvalid),
	.s_axi_bready  (sh_cl_bar1_bus.bready),
	.s_axi_araddr  (sh_cl_bar1_bus.araddr[31:0]),
	.s_axi_arvalid (sh_cl_bar1_bus.arvalid),
	.s_axi_arready (sh_cl_bar1_bus.arready),
	.s_axi_rdata   (sh_cl_bar1_bus.rdata[31:0]),
	.s_axi_rresp   (sh_cl_bar1_bus.rresp),
	.s_axi_rvalid  (sh_cl_bar1_bus.rvalid),
	.s_axi_rready  (sh_cl_bar1_bus.rready),
	
	.m_axi_awaddr  (sh_cl_bar1_bus_q.awaddr[31:0]), 
	.m_axi_awvalid (sh_cl_bar1_bus_q.awvalid),
	.m_axi_awready (sh_cl_bar1_bus_q.awready),
	.m_axi_wdata   (sh_cl_bar1_bus_q.wdata[31:0]),  
	.m_axi_wstrb   (sh_cl_bar1_bus_q.wstrb[3:0]),
	.m_axi_wvalid  (sh_cl_bar1_bus_q.wvalid), 
	.m_axi_wready  (sh_cl_bar1_bus_q.wready), 
	.m_axi_bresp   (sh_cl_bar1_bus_q.bresp),  
	.m_axi_bvalid  (sh_cl_bar1_bus_q.bvalid), 
	.m_axi_bready  (sh_cl_bar1_bus_q.bready), 
	.m_axi_araddr  (sh_cl_bar1_bus_q.araddr[31:0]), 
	.m_axi_arvalid (sh_cl_bar1_bus_q.arvalid),
	.m_axi_arready (sh_cl_bar1_bus_q.arready),
	.m_axi_rdata   (sh_cl_bar1_bus_q.rdata[31:0]),  
	.m_axi_rresp   (sh_cl_bar1_bus_q.rresp),  
	.m_axi_rvalid  (sh_cl_bar1_bus_q.rvalid), 
	.m_axi_rready  (sh_cl_bar1_bus_q.rready)
);

axi_register_slice_light AXIL_BAR1_REG_SLC_2 (
	.aclk          (clk),
	.aresetn       (rstn),
	.s_axi_awaddr  (sh_cl_bar1_bus_q.awaddr[31:0]),
	.s_axi_awvalid (sh_cl_bar1_bus_q.awvalid),
	.s_axi_awready (sh_cl_bar1_bus_q.awready),
	.s_axi_wdata   (sh_cl_bar1_bus_q.wdata[31:0]),
	.s_axi_wstrb   (sh_cl_bar1_bus_q.wstrb[3:0]),
	.s_axi_wvalid  (sh_cl_bar1_bus_q.wvalid),
	.s_axi_wready  (sh_cl_bar1_bus_q.wready),
	.s_axi_bresp   (sh_cl_bar1_bus_q.bresp),
	.s_axi_bvalid  (sh_cl_bar1_bus_q.bvalid),
	.s_axi_bready  (sh_cl_bar1_bus_q.bready),
	.s_axi_araddr  (sh_cl_bar1_bus_q.araddr[31:0]),
	.s_axi_arvalid (sh_cl_bar1_bus_q.arvalid),
	.s_axi_arready (sh_cl_bar1_bus_q.arready),
	.s_axi_rdata   (sh_cl_bar1_bus_q.rdata[31:0]),
	.s_axi_rresp   (sh_cl_bar1_bus_q.rresp),
	.s_axi_rvalid  (sh_cl_bar1_bus_q.rvalid),
	.s_axi_rready  (sh_cl_bar1_bus_q.rready),
	
	.m_axi_awaddr  (sh_cl_bar1_bus_q2.awaddr[31:0]), 
	.m_axi_awvalid (sh_cl_bar1_bus_q2.awvalid),
	.m_axi_awready (sh_cl_bar1_bus_q2.awready),
	.m_axi_wdata   (sh_cl_bar1_bus_q2.wdata[31:0]),  
	.m_axi_wstrb   (sh_cl_bar1_bus_q2.wstrb[3:0]),
	.m_axi_wvalid  (sh_cl_bar1_bus_q2.wvalid), 
	.m_axi_wready  (sh_cl_bar1_bus_q2.wready), 
	.m_axi_bresp   (sh_cl_bar1_bus_q2.bresp),  
	.m_axi_bvalid  (sh_cl_bar1_bus_q2.bvalid), 
	.m_axi_bready  (sh_cl_bar1_bus_q2.bready), 
	.m_axi_araddr  (sh_cl_bar1_bus_q2.araddr[31:0]), 
	.m_axi_arvalid (sh_cl_bar1_bus_q2.arvalid),
	.m_axi_arready (sh_cl_bar1_bus_q2.arready),
	.m_axi_rdata   (sh_cl_bar1_bus_q2.rdata[31:0]),  
	.m_axi_rresp   (sh_cl_bar1_bus_q2.rresp),  
	.m_axi_rvalid  (sh_cl_bar1_bus_q2.rvalid), 
	.m_axi_rready  (sh_cl_bar1_bus_q2.rready)
);

logic wr_active;
logic [$clog2(`MAX_LEN * 8 * 2) - 1 : 0] wr_addr; 	//ROU table + iROU table = 32KB, 15 bits


//aw channel
always_ff @(posedge clk) begin
	if(!rstn)begin
		wr_active 	<= `SD 0;
		wr_addr 	<= `SD 0;
	end else begin
		wr_active 	<= `SD (~wr_active) && (sh_cl_bar1_bus_q2.awvalid || sh_cl_bar1_bus_q2.wvalid) ? 1'b1 :
	   					wr_active && sh_cl_bar1_bus_q2.bready && sh_cl_bar1_bus_q2.bvalid ? 1'b0 : wr_active;
		wr_addr 	<= `SD sh_cl_bar1_bus_q2.awvalid ? sh_cl_bar1_bus_q2.awaddr[$clog2(`MAX_LEN * 8 * 2) - 1 : 0] : wr_addr;
	end
end
assign sh_cl_bar1_bus_q2.awready = wr_active && sh_cl_bar1_bus_q2.awvalid;

//w channel 
assign sh_cl_bar1_bus_q2.wready  = wr_active && sh_cl_bar1_bus_q2.wvalid;

//this part need to be changed if `MAX_LEN and `LINE_SIZE changes, currently
//only support `MAX_LEN = 2k, and `LINE_SIZE = 2 or 4
//currently, do a one cycle write, if not meeting the timing, just add
//another ff stage after it, no performance requirement on this block

always_comb begin
	//for(integer i = 0; i < STAGES; i++) begin
	//	rou_wr_port[i].we 	= 0;
	//	//rou_wr_port[i].addr = 0;
	//	rou_wr_port[i].din 	= sh_cl_bar1_bus_q.wdata[COL_WIDTH - 1 : 0];
	//end
	//not sure why the loop does not work	
	rou_wr_port[STAGES - 1].we 		= 0;
	rou_wr_port[STAGES - 2].we 		= 0;
	rou_wr_port[STAGES - 3].we 		= 0;
	rou_wr_port[STAGES - 4].we 		= 0;
	rou_wr_port[STAGES - 5].we 		= 0;
	rou_wr_port[STAGES - 6].we 		= 0;
	rou_wr_port[STAGES - 7].we 		= 0;
	rou_wr_port[STAGES - 8].we 		= 0;
	rou_wr_port[STAGES - 9].we 		= 0;
	rou_wr_port[STAGES - 10].we 	= 0;
	rou_wr_port[STAGES - 11].we 	= 0;
	rou_wr_port[STAGES - 1].din 	= sh_cl_bar1_bus_q2.wdata[COL_WIDTH - 1 : 0];
	rou_wr_port[STAGES - 2].din 	= sh_cl_bar1_bus_q2.wdata[COL_WIDTH - 1 : 0];
	rou_wr_port[STAGES - 3].din 	= sh_cl_bar1_bus_q2.wdata[COL_WIDTH - 1 : 0];
	rou_wr_port[STAGES - 4].din 	= sh_cl_bar1_bus_q2.wdata[COL_WIDTH - 1 : 0];
	rou_wr_port[STAGES - 5].din 	= sh_cl_bar1_bus_q2.wdata[COL_WIDTH - 1 : 0];
	rou_wr_port[STAGES - 6].din 	= sh_cl_bar1_bus_q2.wdata[COL_WIDTH - 1 : 0];
	rou_wr_port[STAGES - 7].din 	= sh_cl_bar1_bus_q2.wdata[COL_WIDTH - 1 : 0];
	rou_wr_port[STAGES - 8].din 	= sh_cl_bar1_bus_q2.wdata[COL_WIDTH - 1 : 0];
	rou_wr_port[STAGES - 9].din 	= sh_cl_bar1_bus_q2.wdata[COL_WIDTH - 1 : 0];
	rou_wr_port[STAGES - 10].din 	= sh_cl_bar1_bus_q2.wdata[COL_WIDTH - 1 : 0];
	rou_wr_port[STAGES - 11].din 	= sh_cl_bar1_bus_q2.wdata[COL_WIDTH - 1 : 0];

	irou_wr_port.we 	= 0;
	//irou_wr_port.addr 	= 0;
	//irou_wr_port.din 	= 0;
	
	//tie the data and addr to the desired input directly 
	//ROU table
	rou_wr_port[STAGES - 1].addr[0] 		= 0;
	rou_wr_port[STAGES - 2].addr[1 : 0] 	= {1'b0, wr_addr[3]};
	rou_wr_port[STAGES - 3].addr[2 : 0] 	= {1'b0, wr_addr[4 : 3]};
	rou_wr_port[STAGES - 4].addr[3 : 0] 	= {1'b0, wr_addr[5 : 3]};
	rou_wr_port[STAGES - 5].addr[4 : 0] 	= {1'b0, wr_addr[6 : 3]};
	rou_wr_port[STAGES - 6].addr[5 : 0] 	= {1'b0, wr_addr[7 : 3]};
	rou_wr_port[STAGES - 7].addr[6 : 0] 	= {1'b0, wr_addr[8 : 3]};
	rou_wr_port[STAGES - 8].addr[7 : 0] 	= {1'b0, wr_addr[9 : 3]};
	rou_wr_port[STAGES - 9].addr[8 : 0] 	= {1'b0, wr_addr[10 : 3]};
	if(`LINE_SIZE == 2) begin
		rou_wr_port[STAGES - 10].addr[9 : 0] 	= {1'b0, wr_addr[11 : 3]};
		rou_wr_port[STAGES - 11].addr[9 : 0] 	= {1'b0, wr_addr[12 : 4]};
	end else if(`LINE_SIZE == 4) begin
		rou_wr_port[STAGES - 10].addr[8 : 0] 	= {1'b0, wr_addr[11 : 4]};
		rou_wr_port[STAGES - 11].addr[8 : 0] 	= {1'b0, wr_addr[12 : 5]};
	end else begin
		rou_wr_port[STAGES - 10].addr[8 : 0] 	= 0;
		rou_wr_port[STAGES - 11].addr[8 : 0] 	= 0;
	end
	
	//iROU table
	irou_wr_port.addr 	= wr_addr[2 + $clog2(`LINE_SIZE * 2) +: `ADDR_WIDTH];
	irou_wr_port.din 	= sh_cl_bar1_bus_q2.wdata[COL_WIDTH - 1 : 0];

	// addr are DW aligned, so only take care of the 13 MSBs, and since the
	// addresses need to be accessed start from 8, another LSB can be removed  
	if(sh_cl_bar1_bus_q2.wready) begin
		casez(wr_addr[$clog2(`MAX_LEN * 8 * 2) - 1 : 3])
			12'b1???_????_????:begin
				for(integer i = 0; i < `LINE_SIZE * 2; i++) begin
					if(wr_addr[2 +: $clog2(`LINE_SIZE * 2)] == i) begin
						irou_wr_port.we[i] = 1'b1;
					end
				end
			end
			12'b01??_????_????:begin
				for(integer i = 0; i < `LINE_SIZE * 2; i++) begin
					if(wr_addr[2 +: $clog2(`LINE_SIZE * 2)] == i) begin
						rou_wr_port[STAGES - 11].we[i] 	= 1'b1;
					end
				end
			end
			12'b001?_????_????:begin 
				for(integer i = 0; i < `LINE_SIZE; i++) begin
					if(wr_addr[2 +: $clog2(`LINE_SIZE)] == i) begin
						rou_wr_port[STAGES - 10].we[i] 	= 1'b1;
					end
				end
			end
			12'b0001_????_????:begin 
				rou_wr_port[STAGES - 9].we[1 : 0] 	= {wr_addr[2], ~wr_addr[2]};
			end
			12'b0000_1???_????:begin 
				rou_wr_port[STAGES - 8].we[1 : 0] 	= {wr_addr[2], ~wr_addr[2]};
			end
			12'b0000_01??_????:begin
				rou_wr_port[STAGES - 7].we[1 : 0] 	= {wr_addr[2], ~wr_addr[2]};
		   	end
			12'b0000_001?_????:begin
				rou_wr_port[STAGES - 6].we[1 : 0] 	= {wr_addr[2], ~wr_addr[2]};
			end
			12'b0000_0001_????:begin
				rou_wr_port[STAGES - 5].we[1 : 0] 	= {wr_addr[2], ~wr_addr[2]};
		   	end
			12'b0000_0000_1???:begin
				rou_wr_port[STAGES - 4].we[1 : 0] 	= {wr_addr[2], ~wr_addr[2]};
			end
			12'b0000_0000_01??:begin
				rou_wr_port[STAGES - 3].we[1 : 0] 	= {wr_addr[2], ~wr_addr[2]};
			end
			12'b0000_0000_001?:begin 
				rou_wr_port[STAGES - 2].we[1 : 0] 	= {wr_addr[2], ~wr_addr[2]};
			end
			12'b0000_0000_0001:begin
				rou_wr_port[STAGES - 1].we[1 : 0] 	= {wr_addr[2], ~wr_addr[2]};
			end
		endcase
	end
end

//b channel
always_ff @(posedge clk)begin
	if(!rstn)begin
		sh_cl_bar1_bus_q2.bvalid 	<= `SD 0;
	end else begin
		sh_cl_bar1_bus_q2.bvalid 	<= `SD ~sh_cl_bar1_bus_q2.bvalid && sh_cl_bar1_bus_q2.wready ? 1'b1 :
									sh_cl_bar1_bus_q2.bvalid && sh_cl_bar1_bus_q2.bready ? 1'b0 : sh_cl_bar1_bus_q2.bvalid;
	end
end

assign sh_cl_bar1_bus_q2.bresp = 0;

//AXIL read request, for now, no reading functionality to the ROU/iROU table,
//always return DEAD_BEEF
logic [$clog2(`MAX_LEN * 8 * 2) - 1 : 0] 	re_addr;
logic arvalid_q;	//all the AXI outputs are not allowed to be dependent 
					//combinatorially on the inputs, but must instead be registered
					//since the arready can be directly dependent on the arvalid combinatorialy,
					//arvalid has to be latched first

//ar channel
always_ff @(posedge clk)begin
	if(!rstn)begin
		arvalid_q 	<= `SD 0;
		re_addr 	<= `SD 0;
	end else begin
		arvalid_q 	<= `SD sh_cl_bar1_bus_q2.arvalid;
		re_addr 	<= `SD sh_cl_bar1_bus_q2.arvalid ? sh_cl_bar1_bus_q2.araddr[$clog2(`MAX_LEN * 8 * 2) - 1 : 0] : re_addr;
	end
end
assign sh_cl_bar1_bus_q2.arready = arvalid_q && (~sh_cl_bar1_bus_q2.rvalid);

//rd channel
always_ff @(posedge clk)begin
	if(!rstn)begin
		sh_cl_bar1_bus_q2.rvalid	<= `SD 0;
		sh_cl_bar1_bus_q2.rdata 	<= `SD 0;
	end else if(sh_cl_bar1_bus_q2.rvalid && sh_cl_bar1_bus_q2.rready) begin
		sh_cl_bar1_bus_q2.rvalid	<= `SD 0;
		sh_cl_bar1_bus_q2.rdata	<= `SD 0;
	end else if(arvalid_q)begin
		sh_cl_bar1_bus_q2.rvalid	<= `SD 1;
		sh_cl_bar1_bus_q2.rdata 	<= `SD 32'hDEAD_BEEF;
	end
end

assign sh_cl_bar1_bus_q2.rresp = 0;

endmodule
