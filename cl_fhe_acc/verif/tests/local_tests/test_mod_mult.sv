`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/22/2021 09:07:59 PM
// Design Name: 
// Module Name: test_mod_mult
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
module test_mod_mult #(

)(
    );
    
    //import "DPI-C" function longint return_number(input longint in);
    longint a, b, q;
    logic [127 : 0] prod;
    longint out;
    longint mask;
    longint temp;
    int k, k_p1, k_m1;
    
	logic [127 : 0]	m;		// precomputed
	longint mod_mask; //precomputed, used to do mod 2^(k+1), it equals to 2^(k+1)-1, supplied by shell
	
//    mod_mult #(.MAX_BIT_WIDTH(BIT_WIDTH)) DUT (.a(a), 
//                                               .b(b), 
//                                               .q(q), 
//                                               .m(m[BIT_WIDTH : 0]), 
//                                               .k_p1(k_p1), 
//                                               .k_m1(k_m1), 
//                                               .mod_mask(mod_mask),
//                                               .out(out));
    mod_mult #(.MAX_BIT_WIDTH(`BIT_WIDTH)) DUT (.a(a), 
                                               .b(b), 
                                               .q(q), 
                                               .m(m[`BIT_WIDTH : 0]), 
                                               .k2(k*2),
                                               .out(out));
    initial begin
    $monitor("[%t]: a = %h, b = %h, out = %h, temp = %h, prod = %h, m = %h", $time, a, b, out, temp, prod, m);
    q = 54'h3F_FFFF_FFFE_D001;
    k = `BIT_WIDTH;  
    mask = (1 << k) - 1;
    m = (1 << (k * 2)) / q;
    k_p1 = k + 1;
    k_m1 = k - 1;
    mod_mask = (1 << (k+1)) - 1;
    a = 0;
    b = 0;
    out = 0;
    $display("start test.");

    //corner cases 
    
    
    a = 0;
    b = 0;
    #5;
    assert(out == 0);
    //$display("out = %h", out);
    
    a = q - 1;
    b = q - 1;
    prod = a * b;
    temp = prod % q;
    #5;
    assert(out == temp);
    //$display("out = %h", out);
    
 
    a = q - 1;
    b = 1;
    #5;
    assert(out == q - 1);
    //$display("out = %h", out);
    

    for(int i = 0; i < 4096; i++)begin 
        a = {$random, $random};
        a = (a & mask) % q;
        b = {$random, $random};
        b = (b & mask) % q;
        prod = a * b;
        temp = prod % q;
        #5;
        assert(out == temp);
        //$display("out = %h, temp = %h", out, temp);
    end
    $display("start sweep.");
    b = q - 1;
    for(a = q - 1; a > (q / 2); a = a - q/4096)begin
       prod = a * b;
       temp = prod % q;
       #5;
       assert(out == temp);
    end
    $display("test pass for 54 bit, start test for 27 bits.");
    
    q = 27'h7FF6001;
    k = 27;
    mask = (1 << k) - 1;
    m = (1 << (k * 2)) / q;
    for(int i = 0; i < 4096; i++)begin 
        a = {$random, $random};
        a = (a & mask) % q;
        b = {$random, $random};
        b = (b & mask) % q;
        prod = a * b;
        temp = prod % q;
        #5;
        assert(out == temp);
        //$display("out = %h, temp = %h", out, temp);
    end
    $display("start sweep.");
    b = q - 1;
    for(a = q - 1; a > (q / 2); a = a - 10)begin
       prod = a * b;
       temp = prod % q;
       #5;
       assert(out == temp);
    end
    
    $display("test pass for 27 bit.");
    
    
    #1000;
    $finish;     
    end
endmodule
