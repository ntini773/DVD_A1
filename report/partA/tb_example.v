`timescale 1ns/1ps
// Waveform helper for the report: reset, then ONE multiplication (9 x 7).
module tb_example;
    reg        clk   = 0;
    reg        rst_n = 0;
    reg  [3:0] a     = 0;
    reg  [3:0] b     = 0;
    wire [7:0] p;
    mult_array dut (.clk(clk), .rst_n(rst_n), .a(a), .b(b), .p(p));
    always #5 clk = ~clk;                // posedges at 5, 15, 25, 35, 45 ns
    initial begin
        $dumpfile("report/partA/example.vcd");
        $dumpvars(0, tb_example);
        #20 rst_n = 1;                   // reset held low for 2 clock edges (5, 15 ns)
        #10 a = 9; b = 7;              // inputs change at 30 ns
        #60 $display("a=%0d b=%0d p=%0d (expected 63)", a, b, p);
        $finish;
    end
endmodule
