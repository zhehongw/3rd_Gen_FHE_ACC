`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/22/2021 09:07:59 PM
// Design Name: 
// Module Name: test_mod_add
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
module test_mod_add #(

)(
    );
    
    //import "DPI-C" function longint return_number(input longint in);
    longint a, b, q;
    longint out;
    longint mask;
    longint temp;
    mod_add DUT (.a(a), .b(b), .q(q), .out(out));
    initial begin
    $monitor("[%t]: a = %h, b = %h, out = %h, temp = %h, q = %h", $time, a, b, out, temp, q);
    q = `BIT_WIDTH'h3F_FFFF_FFFE_D001;
    mask = (1 << `BIT_WIDTH) - 1;
    $display("start test.");
    
    #5;
    $display("test c function call");
    //temp = return_number(q);
    //assert(temp == (q - 1)) $display("return correct.");
    $display("temp = %h, q = %h", temp, q);
    //corner cases 
    
    
    a = 0;
    b = 0;
    #5;
    assert(out == 0);
    //$display("out = %h", out);
    
    a = q - 1;
    b = q - 1;
    #5;
    assert(out == q - 2) 
        else $display("out = %h", out);
    //$display("out = %h", out);
    
 
    a = q - 1;
    b = 1;
    #5;
    assert(out == 0)
        else $display("out = %h", out);
    //$display("out = %h", out);
    

    for(int i = 0; i < 4096; i++)begin 
        a = {$random, $random};
        a = (a & mask) % q;
        b = {$random, $random};
        b = (b & mask) % q;
        temp = (a + b) % q;
        #5;
        assert(out == temp);
        //$display("out = %h, temp = %h", out, temp);
    end
    $display("test pass");
    #1000;
    $finish;     
    end
    
endmodule
