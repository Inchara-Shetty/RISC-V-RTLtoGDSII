module rv32_regfile (
    input  wire        clk,
    input  wire        we,
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    input  wire [4:0]  rd,
    input  wire [31:0] wdata,
    output wire [31:0] rdata1,
    output wire [31:0] rdata2
);
    reg [31:0] regs [0:31];

    // Combinational reads (x0 is always zero)
    assign rdata1 = (rs1 == 5'd0) ? 32'b0 : regs[rs1];
    assign rdata2 = (rs2 == 5'd0) ? 32'b0 : regs[rs2];

    // Synchronous write (ignore writes to x0)
    always @(posedge clk) begin
        if (we && (rd != 5'd0))
            regs[rd] <= wdata;
    end
endmodule
