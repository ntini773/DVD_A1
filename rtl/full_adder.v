// Full adder: adds three 1-bit inputs, gives a sum bit and a carry bit.
module full_adder (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire cout
);
    assign sum  = a ^ b ^ cin;                     // 1 when an odd number of inputs are 1
    assign cout = (a & b) | (a & cin) | (b & cin); // 1 when two or more inputs are 1
endmodule
