// 4-bit unsigned array multiplier.
// Inputs and output are registered, so latency is 2 clock cycles.
module mult_array (
    input  wire       clk,
    input  wire       rst_n,   // async reset, active low
    input  wire [3:0] a,
    input  wire [3:0] b,
    output reg  [7:0] p
);

    // ---- Stage 1: register the inputs (8 flip-flops) ----
    reg [3:0] a_r, b_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_r <= 4'b0;
            b_r <= 4'b0;
        end else begin
            a_r <= a;
            b_r <= b;
        end
    end

    // ---- Partial products: ppN[j] = a_r[j] AND b_r[N]  (16 AND gates) ----
    wire [3:0] pp0 = a_r & {4{b_r[0]}};
    wire [3:0] pp1 = a_r & {4{b_r[1]}};
    wire [3:0] pp2 = a_r & {4{b_r[2]}};
    wire [3:0] pp3 = a_r & {4{b_r[3]}};

    // ---- Row 0: only AND gates, nothing to add ----
    // p[0] is final. The other three bits go down to row 1.
    wire [3:0] r0 = {1'b0, pp0[3], pp0[2], pp0[1]};

    // ---- Row 1: 4 full adders ----
    wire [3:0] s1;
    wire [4:0] c1;
    assign c1[0] = 1'b0;
    genvar j;
    generate
        for (j = 0; j < 4; j = j + 1) begin : row1
            full_adder fa (.a(pp1[j]), .b(r0[j]), .cin(c1[j]),
                           .sum(s1[j]), .cout(c1[j+1]));
        end
    endgenerate
    wire [3:0] r1 = {c1[4], s1[3], s1[2], s1[1]};

    // ---- Row 2: 4 full adders ----
    wire [3:0] s2;
    wire [4:0] c2;
    assign c2[0] = 1'b0;
    generate
        for (j = 0; j < 4; j = j + 1) begin : row2
            full_adder fa (.a(pp2[j]), .b(r1[j]), .cin(c2[j]),
                           .sum(s2[j]), .cout(c2[j+1]));
        end
    endgenerate
    wire [3:0] r2 = {c2[4], s2[3], s2[2], s2[1]};

    // ---- Row 3: 4 full adders (also makes the top 4 product bits) ----
    wire [3:0] s3;
    wire [4:0] c3;
    assign c3[0] = 1'b0;
    generate
        for (j = 0; j < 4; j = j + 1) begin : row3
            full_adder fa (.a(pp3[j]), .b(r2[j]), .cin(c3[j]),
                           .sum(s3[j]), .cout(c3[j+1]));
        end
    endgenerate

    // ---- Collect the 8 product bits ----
    //            p[7:4]                      p[3]    p[2]    p[1]    p[0]
    wire [7:0] prod = {c3[4], s3[3], s3[2], s3[1], s3[0], s2[0], s1[0], pp0[0]};

    // ---- Stage 2: register the product (8 flip-flops) ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) p <= 8'b0;
        else        p <= prod;
    end

endmodule
