`timescale 1ns/1ps
// Exhaustive self-checking testbench for mult_array.
module tb_mult;
    reg        clk   = 0;
    reg        rst_n = 0;
    reg  [3:0] a     = 0;
    reg  [3:0] b     = 0;
    wire [7:0] p;

    integer i, j, errors;
    reg [7:0] expected;

    mult_array dut (.clk(clk), .rst_n(rst_n), .a(a), .b(b), .p(p));

    // 10 ns clock period
    always #5 clk = ~clk;

    initial begin
        $dumpfile("mult.vcd");
        $dumpvars(0, tb_mult);
        errors = 0;

        // Hold reset low for the first 2 clock cycles
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1;

        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                @(negedge clk);
                a = i;                 // apply inputs
                b = j;
                @(posedge clk);        // edge 1: inputs captured
                @(posedge clk);        // edge 2: product captured
                @(negedge clk);        // check half a cycle later
                expected = i * j;      // * is allowed in the testbench only
                if (p !== expected) begin
                    errors = errors + 1;
                    $display("MISMATCH: a=%0d b=%0d expected=%0d got=%0d",
                             i, j, expected, p);
                end
            end
        end

        if (errors == 0)
            $display("PASS: 256 vectors checked, 0 errors");
        else
            $display("FAIL: 256 vectors checked, %0d errors", errors);
        $finish;
    end
endmodule
