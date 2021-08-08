`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2021 03:28:24 PM
// Design Name: 
// Module Name: accumulator
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: //accumulator need not to instantiate a FIFO inside, it
// directly write back to global RLWE buffer, add two stage pipeline
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "common.vh"
module accumulator #(

)(
    input clk, rstn,
	//to preceding poly_mult_RLWE FIFO
    myFIFO_NTT_sink_if.to_FIFO mult_FIFO [1 : 0],
	//to next global RLWE buffer
	myFIFO_NTT_source_if.to_FIFO out_to_next_stage [1 : 0], //0 for poly a, 1 for poly b
	output logic [1 : 0] output_wr_enable,		//write enable signal for output poly ram
	input [`BIT_WIDTH * `LINE_SIZE - 1 : 0] outram_doutA [1 : 0],	//data read from the output poly ram
	input [`BIT_WIDTH * `LINE_SIZE - 1 : 0] outram_doutB [1 : 0],
	config_if.to_top config_ports

);

typedef enum logic [2 : 0] {IDLE, RD1, COMPUTE, WR1, WR2, WAIT} acc_states;

logic [1 : 0] temp_weA, temp_weB; 
logic [1 : 0] temp_enA, temp_enB; 
logic [`ADDR_WIDTH - 1 : 0] temp_addrA [1 : 0];
logic [`ADDR_WIDTH - 1 : 0] temp_addrB [1 : 0];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] temp_dinA [1 : 0];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] temp_dinB [1 : 0];

logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] temp_doutA [1 : 0];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] temp_doutB [1 : 0];

poly_ram_block temp_buffer [1 : 0](
    .clk(clk), 
	.weA(temp_weA),
	.weB(temp_weB),
    .addrA(temp_addrA),
    .addrB(temp_addrB),
    .dinA(temp_dinA),
    .dinB(temp_dinB),
	.enA(temp_enA),
	.enB(temp_enB),
    .doutA(temp_doutA),
    .doutB(temp_doutB)
);

logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] add_in_aA [1 : 0];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] add_in_bA [1 : 0];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] add_in_aA_q [1 : 0];	//on pipeline stage for add in data 
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] add_in_bA_q [1 : 0];

logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] add_outA_q [1 : 0];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] add_outA [1 : 0];

logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] add_in_aB [1 : 0];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] add_in_bB [1 : 0];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] add_in_aB_q [1 : 0];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] add_in_bB_q [1 : 0];

logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] add_outB_q [1 : 0];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] add_outB [1 : 0];

logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] sub_in_aA [1 : 0];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] sub_in_bA [1 : 0];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] sub_in_aA_q [1 : 0];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] sub_in_bA_q [1 : 0];

logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] sub_outA_q [1 : 0];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] sub_outA [1 : 0];

logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] sub_in_aB [1 : 0];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] sub_in_bB [1 : 0];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] sub_in_aB_q [1 : 0];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] sub_in_bB_q [1 : 0];

logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] sub_outB_q [1 : 0];
logic [`BIT_WIDTH * `LINE_SIZE - 1 : 0] sub_outB [1 : 0];

always_ff @(posedge clk) begin
	for(integer i = 0; i < 2; i++) begin
		add_in_aA_q[i] 	<= `SD add_in_aA[i];
		add_in_bA_q[i] 	<= `SD add_in_bA[i];
		add_outA[i] 	<= `SD add_outA_q[i];
		
		add_in_aB_q[i] 	<= `SD add_in_aB[i];
		add_in_bB_q[i] 	<= `SD add_in_bB[i];
		add_outB[i] 	<= `SD add_outB_q[i];

		sub_in_aA_q[i] 	<= `SD sub_in_aA[i];
		sub_in_bA_q[i] 	<= `SD sub_in_bA[i];
		sub_outA[i] 	<= `SD sub_outA_q[i];
		
		sub_in_aB_q[i] 	<= `SD sub_in_aB[i];
		sub_in_bB_q[i] 	<= `SD sub_in_bB[i];
		sub_outB[i] 	<= `SD sub_outB_q[i];
	end
end


genvar i, j;
generate
	for(j = 0; j < 2; j++) begin
		for(i = 0; i < `LINE_SIZE; i++) begin
			mod_add adderA(
				//start to add add_inaA_q to here
				.a(add_in_aA_q[j][i * `BIT_WIDTH +: `BIT_WIDTH]),
				.b(add_in_bA_q[j][i * `BIT_WIDTH +: `BIT_WIDTH]),
				.q(config_ports.q),
				.out(add_outA_q[j][i * `BIT_WIDTH +: `BIT_WIDTH])
			);
			mod_add adderB(
				.a(add_in_aB_q[j][i * `BIT_WIDTH +: `BIT_WIDTH]),
				.b(add_in_bB_q[j][i * `BIT_WIDTH +: `BIT_WIDTH]),
				.q(config_ports.q),
				.out(add_outB_q[j][i * `BIT_WIDTH +: `BIT_WIDTH])
			);
			mod_sub subtractorA(
				.a(sub_in_aA_q[j][i * `BIT_WIDTH +: `BIT_WIDTH]),
				.b(sub_in_bA_q[j][i * `BIT_WIDTH +: `BIT_WIDTH]),
				.q(config_ports.q),
				.out(sub_outA_q[j][i * `BIT_WIDTH +: `BIT_WIDTH])
			);
			mod_sub subtractorB(
				.a(sub_in_aB_q[j][i * `BIT_WIDTH +: `BIT_WIDTH]),
				.b(sub_in_bB_q[j][i * `BIT_WIDTH +: `BIT_WIDTH]),
				.q(config_ports.q),
				.out(sub_outB_q[j][i * `BIT_WIDTH +: `BIT_WIDTH])
			);
		end
	end
endgenerate 


acc_states state, next;
`ifndef FPGA_LESS_RST
	logic [`ADDR_WIDTH - 1 : 0] rd_addrA;
	logic [`ADDR_WIDTH - 1 : 0] rd_addrB;
	logic [5 : 0]				poly_counter;	//used to count number of polys accumulated
	logic 						wr_addr_sel;	//sel which ram to write to, 0 to output ram, 1 to temp ram
`else
	logic [`ADDR_WIDTH - 1 : 0] rd_addrA = 0;
	logic [`ADDR_WIDTH - 1 : 0] rd_addrB = 1;
	logic [5 : 0]				poly_counter = 0;	//used to count number of polys accumulated
	logic 						wr_addr_sel = 0;	//sel which ram to write to, 0 to output ram, 1 to temp ram
`endif

logic [`ADDR_WIDTH - 1 : 0] rd_addrA_next;
logic [`ADDR_WIDTH - 1 : 0] rd_addrB_next;
logic [`ADDR_WIDTH - 1 : 0] wr_addrA, wr_addrB;
logic [`ADDR_WIDTH - 1 : 0] wr_addrA_q, wr_addrB_q;
logic [`ADDR_WIDTH - 1 : 0] wr_addrA_piped, wr_addrB_piped;

logic [5 : 0]	poly_counter_next;	//used to count number of polys accumulated

logic wr_addr_sel_next;	//sel which ram to write to, 0 to output ram, 1 to temp ram
//logic rd_addr_sel, rd_addr_sel_next;	//sel which ram to read from, 0 from output ram, 1 from temp ram
logic rd_addr_sel;	//sel which ram to read from, 0 from output ram, 1 from temp ram
logic rd_finish, wr_finish;
logic add_sub_sel;	//selection of addition or subtraction, 0 for adder, 1 for subtraction


pipeline #(.STAGE_NUM(2), .BIT_WIDTH(`ADDR_WIDTH * 2)) wr_addr_pipe(
	.clk(clk),
	.rstn(rstn),
	.pipe_in({wr_addrA_q, wr_addrB_q}),
	.pipe_out({wr_addrA_piped, wr_addrB_piped})
);



assign out_to_next_stage[0].rlwe_id = mult_FIFO[0].rlwe_id;
assign out_to_next_stage[1].rlwe_id = mult_FIFO[1].rlwe_id;
assign out_to_next_stage[0].poly_id = mult_FIFO[0].poly_id;
assign out_to_next_stage[1].poly_id = mult_FIFO[1].poly_id;
assign out_to_next_stage[0].opcode = mult_FIFO[0].opcode;
assign out_to_next_stage[1].opcode = mult_FIFO[1].opcode;

assign mult_FIFO[0].rd_finish = rd_finish;
assign mult_FIFO[1].rd_finish = rd_finish;
assign out_to_next_stage[0].wr_finish = wr_finish;
assign out_to_next_stage[1].wr_finish = wr_finish;

//connect ram data to adder and subtractors
assign add_in_aA[0] = mult_FIFO[0].dA;
assign add_in_aB[0] = mult_FIFO[0].dB;
assign add_in_bA[0] = poly_counter == 0 ? 0 : rd_addr_sel ? temp_doutA[0] : outram_doutA[0];
assign add_in_bB[0] = poly_counter == 0 ? 0 : rd_addr_sel ? temp_doutB[0] : outram_doutB[0];
assign add_in_aA[1] = mult_FIFO[1].dA;
assign add_in_aB[1] = mult_FIFO[1].dB;
assign add_in_bA[1] = poly_counter == 0 ? 0 : rd_addr_sel ? temp_doutA[1] : outram_doutA[1];
assign add_in_bB[1] = poly_counter == 0 ? 0 : rd_addr_sel ? temp_doutB[1] : outram_doutB[1];

always_comb begin
	if(mult_FIFO[0].opcode == `RLWESUBS && mult_FIFO[1].opcode == `RLWESUBS && mult_FIFO[0].poly_id == `POLY_B && mult_FIFO[1].poly_id == `POLY_B) begin
		sub_in_aA[0] = mult_FIFO[0].dA;
		sub_in_aB[0] = mult_FIFO[0].dB;
		sub_in_bA[0] = rd_addr_sel ? temp_doutA[0] : outram_doutA[0];
		sub_in_bB[0] = rd_addr_sel ? temp_doutB[0] : outram_doutB[0];
		sub_in_aA[1] = mult_FIFO[1].dA;
		sub_in_aB[1] = mult_FIFO[1].dB;                             
		sub_in_bA[1] = rd_addr_sel ? temp_doutA[1] : outram_doutA[1];
		sub_in_bB[1] = rd_addr_sel ? temp_doutB[1] : outram_doutB[1];
	end else begin
		sub_in_aA[0] = 0;
		sub_in_aB[0] = 0;
		sub_in_bA[0] = 0;
		sub_in_bB[0] = 0;
		sub_in_aA[1] = 0;
		sub_in_aB[1] = 0;
		sub_in_bA[1] = 0;
		sub_in_bB[1] = 0;
	end
end

//connect add/sub result to the output rams and temp rams
assign out_to_next_stage[0].dA = add_sub_sel ? sub_outA[0] : add_outA[0];
assign out_to_next_stage[0].dB = add_sub_sel ? sub_outB[0] : add_outB[0];
assign out_to_next_stage[1].dA = add_sub_sel ? sub_outA[1] : add_outA[1];
assign out_to_next_stage[1].dB = add_sub_sel ? sub_outB[1] : add_outB[1];
assign temp_dinA[0] = add_sub_sel ? sub_outA[0] : add_outA[0];
assign temp_dinB[0] = add_sub_sel ? sub_outB[0] : add_outB[0];
assign temp_dinA[1] = add_sub_sel ? sub_outA[1] : add_outA[1];
assign temp_dinB[1] = add_sub_sel ? sub_outB[1] : add_outB[1];

//generate read/write enable for output ram and temp ram
always_comb begin
    case(state)
        IDLE, WAIT: begin
            output_wr_enable[0] = 0;
            output_wr_enable[1] = 0;
        	temp_weA[0] = 0;
        	temp_weB[0] = 0;
        	temp_weA[1] = 0;
        	temp_weB[1] = 0;
        end
        default: begin
            output_wr_enable[0] = ~wr_addr_sel;
            output_wr_enable[1] = ~wr_addr_sel;
        	temp_weA[0] = wr_addr_sel;
        	temp_weB[0] = wr_addr_sel;
        	temp_weA[1] = wr_addr_sel;
        	temp_weB[1] = wr_addr_sel;
        end
    endcase
    temp_enA[0] = rd_addr_sel;
    temp_enB[0] = rd_addr_sel;
    temp_enA[1] = rd_addr_sel;
    temp_enB[1] = rd_addr_sel;
end

assign add_sub_sel = mult_FIFO[0].opcode == `RLWESUBS && mult_FIFO[1].opcode == `RLWESUBS && mult_FIFO[0].poly_id == `POLY_B && mult_FIFO[1].poly_id == `POLY_B ? 1 : 0;

//addr of input ram fifo
assign mult_FIFO[0].addrA = rd_addrA;
assign mult_FIFO[0].addrB = rd_addrB;
assign mult_FIFO[1].addrA = rd_addrA;
assign mult_FIFO[1].addrB = rd_addrB;

//addr of output ram and temp ram
assign out_to_next_stage[0].addrA 	= wr_addr_sel ? rd_addrA : wr_addrA_piped;
assign out_to_next_stage[0].addrB 	= wr_addr_sel ? rd_addrB : wr_addrB_piped;
assign out_to_next_stage[1].addrA 	= wr_addr_sel ? rd_addrA : wr_addrA_piped;
assign out_to_next_stage[1].addrB 	= wr_addr_sel ? rd_addrB : wr_addrB_piped;
assign temp_addrA[0] 				= wr_addr_sel ? wr_addrA_piped : rd_addrA;
assign temp_addrB[0] 				= wr_addr_sel ? wr_addrB_piped : rd_addrB;
assign temp_addrA[1] 				= wr_addr_sel ? wr_addrA_piped : rd_addrA;
assign temp_addrB[1] 				= wr_addr_sel ? wr_addrB_piped : rd_addrB;

assign rd_addr_sel = ~wr_addr_sel;

//state machine 
`ifndef FPGA_LESS_RST 
	always_ff @(posedge clk) begin
		if(!rstn) begin
			state 			<= `SD IDLE;
			rd_addrA 		<= `SD 0;
			rd_addrB 		<= `SD 1;
			wr_addr_sel 	<= `SD 0;
			poly_counter 	<= `SD 0;
		end else begin
			state 			<= `SD next;
			rd_addrA 		<= `SD rd_addrA_next;
			rd_addrB 		<= `SD rd_addrB_next;
			wr_addr_sel 	<= `SD wr_addr_sel_next;
			poly_counter 	<= `SD poly_counter_next;
		end
		wr_addrA 		<= `SD rd_addrA;
		wr_addrB 		<= `SD rd_addrB;
		wr_addrA_q 		<= `SD wr_addrA;
		wr_addrB_q 		<= `SD wr_addrB;
	end 
`else
	always_ff @(posedge clk) begin
		if(!rstn) begin
			state 			<= `SD IDLE;
		end else begin
			state 			<= `SD next;
		end
		wr_addrA 		<= `SD rd_addrA;
		wr_addrB 		<= `SD rd_addrB;
		wr_addrA_q 		<= `SD wr_addrA;
		wr_addrB_q 		<= `SD wr_addrB;
		rd_addrA 		<= `SD rd_addrA_next;
		rd_addrB 		<= `SD rd_addrB_next;
		wr_addr_sel 	<= `SD wr_addr_sel_next;
		poly_counter 	<= `SD poly_counter_next;
	end 
`endif

always_comb begin
	case(state)
		IDLE: begin
			if(!mult_FIFO[0].empty && !mult_FIFO[1].empty && !out_to_next_stage[0].full && !out_to_next_stage[1].full)begin
				next 				= RD1;
			end else begin
				next 				= IDLE;
			end
			if(mult_FIFO[0].opcode == `RLWESUBS && mult_FIFO[1].opcode == `RLWESUBS) begin
				wr_addr_sel_next 	= 0;
			end else begin
				wr_addr_sel_next 	= 1;
			end
			rd_addrA_next 		= 0;
			rd_addrB_next 		= 1;
			//wr_addr_sel_next 	= 0;
			poly_counter_next 	= 0;
			rd_finish 			= 1;
			wr_finish 			= 1;
		end
		RD1: begin
			next 				= COMPUTE;
			rd_addrA_next 		= rd_addrA + 2;
			rd_addrB_next 		= rd_addrB + 2;
			poly_counter_next 	= poly_counter;
			rd_finish 			= 0;
			wr_finish 			= 0;
			wr_addr_sel_next 	= wr_addr_sel;
		end
		COMPUTE: begin
			if(wr_addrB_q == ((config_ports.length >> $clog2(`LINE_SIZE)) - 1)) begin
				next 				= WR1;
				rd_addrA_next 		= 0;
				rd_addrB_next 		= 1;	
				rd_finish 			= 0;
			end else begin
				next 				= COMPUTE;
				rd_addrA_next 		= rd_addrA + 2;
				rd_addrB_next 		= rd_addrB + 2;
				rd_finish 			= 0;
			end
			wr_finish 			= 0;
			wr_addr_sel_next 	= wr_addr_sel;
			poly_counter_next 	= poly_counter;
		end
		WR1: begin
		//wait for two cycle to clean up the pipeline	
			next 				= WR2;
			wr_addr_sel_next 	= wr_addr_sel;
			poly_counter_next 	= poly_counter;
			wr_finish 			= 0;
			rd_addrA_next 		= 0;
			rd_addrB_next 		= 1;
			rd_finish 			= 0;
		end
		WR2: begin
			if(mult_FIFO[0].opcode == `RLWESUBS && mult_FIFO[1].opcode == `RLWESUBS && mult_FIFO[0].poly_id == `POLY_B && mult_FIFO[1].poly_id == `POLY_B) begin
				next 				= IDLE;
				wr_addr_sel_next 	= 0;
				poly_counter_next 	= 0;
				wr_finish 			= 1;
			end else begin
				next 				= WAIT;
				wr_addr_sel_next 	= ~wr_addr_sel;
				poly_counter_next 	= poly_counter + 1;
				wr_finish 			= 0;
			end
			rd_addrA_next  		= 0;
			rd_addrB_next 		= 1;
			rd_finish 			= 1;
		end
		WAIT: begin
			if(poly_counter == (config_ports.digitG << 1)) begin
				next 				= IDLE;
				rd_addrA_next 		= 0;
				rd_addrB_next 		= 1;
				wr_addr_sel_next 	= 0;
				poly_counter_next 	= 0;
				rd_finish 			= 1;
				wr_finish 			= 1;
			end else begin
				if(!mult_FIFO[0].empty && !mult_FIFO[1].empty) begin
					next 				= RD1;
				end else begin
					next 				= WAIT;
				end
				rd_addrA_next 		= 0;
				rd_addrB_next 		= 1;
				rd_finish 			= 1;
				wr_finish 			= 0;
				wr_addr_sel_next 	= wr_addr_sel;
				poly_counter_next 	= poly_counter;
			end
		end
		default: begin
			next 				= IDLE;
			rd_addrA_next 		= 0;
			rd_addrB_next 		= 1;
			wr_addr_sel_next 	= 0;
			poly_counter_next 	= 0;
			rd_finish 			= 1;
			wr_finish 			= 1;
		end
	endcase
end


endmodule

