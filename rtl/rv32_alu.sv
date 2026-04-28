module rv32_alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  op,
    output reg  [31:0] y,
    output wire        zero
);
    wire signed [31:0] as = a;
    wire signed [31:0] bs = b;

    always @* begin
        unique case (op)
            4'h0: y = a + b;                       // ADD
            4'h1: y = a - b;                       // SUB
            4'h2: y = a & b;                       // AND
            4'h3: y = a | b;                       // OR
            4'h4: y = a ^ b;                       // XOR
            4'h5: y = (as < bs) ? 32'd1 : 32'd0;   // SLT
            4'h6: y = (a < b)  ? 32'd1 : 32'd0;    // SLTU
            4'h7: y = a << b[4:0];                 // SLL
            4'h8: y = a >> b[4:0];                 // SRL
            4'h9: y = as >>> b[4:0];               // SRA
            default: y = a + b;
        endcase
    end

    assign zero = (y == 32'b0);
endmodule
