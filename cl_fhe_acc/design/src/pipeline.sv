`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/24/2021 08:50:59 PM
// Design Name: 
// Module Name: pipeline
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description:  simple pipeline for synchronization
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "common.vh"
module pipeline #(
	parameter STAGE_NUM = 1,
	parameter BIT_WIDTH = `BIT_WIDTH
)( 
    input 	clk, rstn,
	input 	[BIT_WIDTH - 1 : 0] pipe_in,
	output logic [BIT_WIDTH - 1 : 0] pipe_out
);

//use shreg_extract=no directs Vivado to not infer shift registers

`ifdef FPGA_LESS_RST
   (*shreg_extract="no"*) logic [BIT_WIDTH - 1 : 0] pipe[STAGE_NUM - 1 : 0] = '{default:'0};
`else
   (*shreg_extract="no"*) logic [BIT_WIDTH - 1 : 0] pipe[STAGE_NUM - 1 : 0];
`endif

integer i;

`ifdef FPGA_LESS_RST
	always @(posedge clk)
`else
	always @(posedge clk)
    	if (!rst_n)
    		begin
    		   for (i = 0; i < STAGE_NUM; i++)
    		      pipe[i] <= `SD 0;
    		end else
`endif
    begin
       pipe[0] <= `SD pipe_in;
 
       if (STAGE_NUM > 1)
       begin
          for (i = 1; i < STAGE_NUM; i++)
             pipe[i] <= `SD pipe[i-1];
       end
    end

assign pipe_out = pipe[STAGE_NUM - 1];
endmodule
