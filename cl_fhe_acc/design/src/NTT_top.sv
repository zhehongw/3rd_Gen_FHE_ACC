`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/03/2021 05:29:20 PM
// Design Name: 
// Module Name: NTT_top
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


module NTT_top #(
    parameter STAGES = $clog2(`MAX_LEN)
)(
    input clk,
    input rstn,
    myFIFO_NTT_sink_if.to_FIFO input_FIFO,
    myFIFO_NTT_sink_if.to_sink out_to_next_stage,
    config_if.to_top config_ports,
	input ROB_empty_NTT,
    ROU_config_if.to_axil_bar1 rou_wr_port [0 : STAGES - 1]    
);

myFIFO_NTT_sink_if NTT_stage_if [0 : STAGES - 1] ();

myFIFO_NTT_sink_if leading_stage_input_mux();
myFIFO_NTT_sink_if leading_stage_output_mux();


always_comb begin
    NTT_stage_if[0].addrA 		= out_to_next_stage.addrA;
    NTT_stage_if[0].addrB 		= out_to_next_stage.addrB;
    out_to_next_stage.dA 		= NTT_stage_if[0].dA;
    out_to_next_stage.dB 		= NTT_stage_if[0].dB;
    NTT_stage_if[0].rd_finish 	= out_to_next_stage.rd_finish;
    out_to_next_stage.empty 	= NTT_stage_if[0].empty;
    out_to_next_stage.rlwe_id 	= NTT_stage_if[0].rlwe_id;
    out_to_next_stage.poly_id 	= NTT_stage_if[0].poly_id;
    out_to_next_stage.opcode 	= NTT_stage_if[0].opcode;
end

//muxes to support variable length NTT, currently two lengths
always_comb begin
	if(config_ports.length == `MAX_LEN) begin
		NTT_stage_if[STAGES - 1].dA 		= leading_stage_output_mux.dA;
		NTT_stage_if[STAGES - 1].dB 		= leading_stage_output_mux.dB;
		NTT_stage_if[STAGES - 1].empty 		= leading_stage_output_mux.empty;
		NTT_stage_if[STAGES - 1].rlwe_id 	= leading_stage_output_mux.rlwe_id;
		NTT_stage_if[STAGES - 1].poly_id 	= leading_stage_output_mux.poly_id;
		NTT_stage_if[STAGES - 1].opcode 	= leading_stage_output_mux.opcode;
		leading_stage_output_mux.rd_finish 	= NTT_stage_if[STAGES - 1].rd_finish;
	end else begin
		NTT_stage_if[STAGES - 1].dA 		= input_FIFO.dA;
		NTT_stage_if[STAGES - 1].dB 		= input_FIFO.dB;
		NTT_stage_if[STAGES - 1].empty 		= input_FIFO.empty;
		NTT_stage_if[STAGES - 1].rlwe_id 	= input_FIFO.rlwe_id;
		NTT_stage_if[STAGES - 1].poly_id 	= input_FIFO.poly_id;
		NTT_stage_if[STAGES - 1].opcode 	= input_FIFO.opcode;
		leading_stage_output_mux.rd_finish 	= 1;	//tie high rd_finish to prevent the leading stage from running accidentally
	end
	leading_stage_output_mux.addrA = NTT_stage_if[STAGES - 1].addrA;
	leading_stage_output_mux.addrB = NTT_stage_if[STAGES - 1].addrB;
end

always_comb begin
	if(config_ports.length == `MAX_LEN) begin
		input_FIFO.addrA 				= leading_stage_input_mux.addrA;
		input_FIFO.addrB 				= leading_stage_input_mux.addrB;
		input_FIFO.rd_finish 			= leading_stage_input_mux.rd_finish;
		leading_stage_input_mux.empty	= input_FIFO.empty;
	end else begin
		input_FIFO.addrA 				= NTT_stage_if[STAGES - 1].addrA;
		input_FIFO.addrB 				= NTT_stage_if[STAGES - 1].addrB;
		input_FIFO.rd_finish 			= NTT_stage_if[STAGES - 1].rd_finish;
		leading_stage_input_mux.empty 	= 1; //tie high empty to prevent the leading stage from running accidentally
	end
	leading_stage_input_mux.dA 		= input_FIFO.dA;
	leading_stage_input_mux.dB 		= input_FIFO.dB;
	leading_stage_input_mux.rlwe_id	= input_FIFO.rlwe_id;
	leading_stage_input_mux.poly_id	= input_FIFO.poly_id;
	leading_stage_input_mux.opcode	= input_FIFO.opcode;
end

//stage 10
NTT_leading_stage #(.STAGE_NUM(STAGES - 1)) leading_stage_10 (
    .clk(clk), 
    .rstn(rstn),
    .input_FIFO(leading_stage_input_mux),
    .out_to_next_stage(leading_stage_output_mux),
	.config_ports(config_ports),
	.ROB_empty_NTT(ROB_empty_NTT),
    .rou_wr_port(rou_wr_port[STAGES - 1])
);
//stage 9
NTT_leading_stage #(.STAGE_NUM(STAGES - 2)) leading_stage_9 (
    .clk(clk), 
    .rstn(rstn),
    .input_FIFO(NTT_stage_if[STAGES - 1]),
    .out_to_next_stage(NTT_stage_if[STAGES - 2]),
    .config_ports(config_ports),
	.ROB_empty_NTT(ROB_empty_NTT),
    .rou_wr_port(rou_wr_port[STAGES - 2])
);

//the rest of the stages
genvar i;
generate 
    for(i = 0; i < STAGES - 2; i++) begin: GENERATE_STAGE
        NTT_stage #(.STAGE_NUM(i)) stage (
            .clk(clk), 
            .rstn(rstn),
            .input_FIFO(NTT_stage_if[i + 1]),
	        .out_to_next_stage(NTT_stage_if[i]),
	        .config_ports(config_ports),
	        .rou_wr_port(rou_wr_port[i])
        );
    end
endgenerate 

endmodule
