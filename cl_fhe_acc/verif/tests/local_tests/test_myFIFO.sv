`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/25/2021 04:53:09 PM
// Design Name: 
// Module Name: test_myFIFO
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "common.vh"
module test_myFIFO #(
	parameter POINTER_WIDTH = 1,
	parameter FIFO_DEPTH = 2**POINTER_WIDTH
)(

    );
    logic clk, rstn;
	//source ports

    myFIFO_source_if source_if();
	//sink ports
    myFIFO_sink_if sink_if();
    
    myFIFO_NTT #(.POINTER_WIDTH(POINTER_WIDTH), .FIFO_DEPTH(FIFO_DEPTH)) DUT(
        .clk(clk),
        .rstn(rstn),
        .source_ports(source_if),
        .sink_ports(sink_if)
    );
    
	logic write_en, read_en;

    initial begin 
		$monitor("[%t]: rstn = %h, wr_en = %h, rd_en = %h, full = %h, empty = %h, wr_ptr = %h, rd_ptr = %h, addr_wrA = %h, addr_wrB = %h", $time, rstn, write_en, read_en, source_if.full, sink_if.empty, DUT.wr_pointer, DUT.rd_pointer, source_if.addrA, source_if.addrB);
		$monitor("[%t]: rstn = %h, wr_en = %h, rd_en = %h, full = %h, empty = %h, wr_ptr = %h, rd_ptr = %h, FIFO[%h] = %h, FIFO[%h] = %h", $time, rstn, write_en, read_en, source_if.full, sink_if.empty, DUT.wr_pointer, DUT.rd_pointer, sink_if.addrA, sink_if.dA, sink_if.addrB, sink_if.dB);
        clk = 0;
        rstn = 0;
		write_en = 0;
		read_en = 0;

        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
		rstn = 1;
		
		//first write the FIFO to full
		write_en = 1;
		@(negedge clk);
		@(negedge clk);
		@(posedge source_if.full);
		write_en = 0;

		//then read the FIFO to empty;
		@(negedge clk);
		read_en = 1;
		@(negedge clk);
		@(posedge sink_if.empty);
		read_en = 0;
		
		//finally test write and read simultaneously
		@(negedge clk);
		read_en = 1;
	 	write_en = 1;	

		#100000;
		$finish;
    end
	


	//source stimulate	
	typedef enum logic [3 : 0] {WRITE_IDLE, WRITE} source_states;
	source_states sr_state, sr_state_next;
	logic	[`ADDR_WIDTH - 1 : 0] 		addr_wrA_next;
	logic	[`ADDR_WIDTH - 1 : 0] 		addr_wrB_next;
	always_ff @(posedge clk)begin
		if(!rstn) begin
			sr_state <= `SD WRITE_IDLE;
			source_if.addrA <= `SD 0;
			source_if.addrB <= `SD 1 << (`ADDR_WIDTH - 1);
			source_if.dA <= `SD 0;
			source_if.dB <= `SD 0;
		end else begin
			sr_state <= `SD sr_state_next;
			source_if.addrA <= `SD addr_wrA_next;
			source_if.addrB <= `SD addr_wrB_next;
			source_if.dA <= `SD source_if.dA + 1;
			source_if.dB <= `SD source_if.dB + 1;
		end
	end
	
	always_comb begin
		case(sr_state)
			WRITE_IDLE: begin
				if(!source_if.full && write_en) begin
					source_if.wr_finish = 0;
					sr_state_next = WRITE;
					addr_wrA_next = source_if.addrA + 1;
					addr_wrB_next = source_if.addrB + 1;
				end else begin
					source_if.wr_finish = 1;
					sr_state_next = WRITE_IDLE;
					addr_wrA_next = 0;
					addr_wrB_next = 1 << (`ADDR_WIDTH - 1);
				end
			end
			WRITE: begin
				if(source_if.addrB == {`ADDR_WIDTH{1'b1}})begin
					source_if.wr_finish = 1;
					sr_state_next = WRITE_IDLE;
					addr_wrA_next = 0;
					addr_wrB_next = 1 << (`ADDR_WIDTH - 1);
				end else begin
					source_if.wr_finish = 0;
					sr_state_next = WRITE;
					addr_wrA_next = source_if.addrA + 1;
					addr_wrB_next = source_if.addrB + 1;
				end
			end
		endcase
	end

	//sink stimulate
   	typedef enum logic [3 : 0] {READ_IDLE, READ} sink_states;
	sink_states si_state, si_state_next;
	logic	[`ADDR_WIDTH - 1 : 0] 		addr_rdA_next;
	logic	[`ADDR_WIDTH - 1 : 0] 		addr_rdB_next;
	always_ff @(posedge clk)begin
		if(!rstn) begin
			si_state <= `SD READ_IDLE;
			sink_if.addrA <= `SD 0;
			sink_if.addrB <= `SD 1 << (`ADDR_WIDTH - 1);
		end else begin
			si_state <= `SD si_state_next;
			sink_if.addrA <= `SD addr_rdA_next;
			sink_if.addrB <= `SD addr_rdB_next;
		end
	end
	
	always_comb begin
		case(si_state)
			READ_IDLE: begin
				if(!sink_if.empty & read_en) begin
					sink_if.rd_finish = 0;
					si_state_next = READ;
					addr_rdA_next = sink_if.addrA + 1;
					addr_rdB_next = sink_if.addrB + 1;
				end else begin
					sink_if.rd_finish = 1;
					si_state_next = READ_IDLE;
					addr_rdA_next = 0;
					addr_rdB_next = 1 << (`ADDR_WIDTH - 1);
				end
			end
			READ: begin
				if(sink_if.addrB == {`ADDR_WIDTH{1'b0}})begin
					sink_if.rd_finish = 1;
					si_state_next = READ_IDLE;
					addr_rdA_next = 0;
					addr_rdB_next = 1 << (`ADDR_WIDTH - 1);
				end else begin
					sink_if.rd_finish = 0;
					si_state_next = READ;
					addr_rdA_next = sink_if.addrA + 1;
					addr_rdB_next = sink_if.addrB + 1;
				end
			end
		endcase
	end
	
    always #5 clk = ~clk;
    
endmodule
