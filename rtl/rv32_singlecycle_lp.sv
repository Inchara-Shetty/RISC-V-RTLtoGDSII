//Top-level design 
module rv32_singlecycle_powerlens #(
    parameter RESET_PC = 32'h0000_0000,

    // PowerLens knobs
    parameter ENABLE_OPERAND_ISO = 1,   // operand isolation on ALU inputs
    parameter ENABLE_MEM_ISO     = 1,   // isolate dmem signals when not used
    parameter ENABLE_RF_WE_GATING= 1    // gate rf write enable (cleaner switching)
) (
    input  wire        clk,
    input  wire        resetn,

    // Instruction memory (assumed comb read)
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,

    // Data memory
    output wire        dmem_we,
    output wire [3:0]  dmem_wstrb,
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    input  wire [31:0] dmem_rdata
);

    // -----------------------------
    // PC register
    // -----------------------------
    reg [31:0] pc_q, pc_d;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) pc_q <= RESET_PC;
        else         pc_q <= pc_d;
    end

    assign imem_addr = pc_q;
    wire [31:0] instr = imem_rdata;

    // -----------------------------
    // Decode
    // -----------------------------
    wire [6:0]  opcode = instr[6:0];
    wire [4:0]  rd     = instr[11:7];
    wire [2:0]  funct3 = instr[14:12];
    wire [4:0]  rs1    = instr[19:15];
    wire [4:0]  rs2    = instr[24:20];
    wire [6:0]  funct7 = instr[31:25];

    // -----------------------------
    // Immediates
    // -----------------------------
    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'b0};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    // -----------------------------
    // Regfile
    // -----------------------------
    wire [31:0] rs1_rdata, rs2_rdata;
    reg  [31:0] rf_wdata;
    reg         rf_we;

    rv32_regfile rf (
        .clk   (clk),
        .we    (rf_we),
        .rs1   (rs1),
        .rs2   (rs2),
        .rd    (rd),
        .wdata (rf_wdata),
        .rdata1(rs1_rdata),
        .rdata2(rs2_rdata)
    );

    // -----------------------------
    // Control decode (simple wires)
    // -----------------------------
    wire is_rtype  = (opcode == 7'b0110011);
    wire is_itype  = (opcode == 7'b0010011);
    wire is_load   = (opcode == 7'b0000011);
    wire is_store  = (opcode == 7'b0100011);
    wire is_branch = (opcode == 7'b1100011);
    wire is_jal    = (opcode == 7'b1101111);
    wire is_jalr   = (opcode == 7'b1100111);
    wire is_lui    = (opcode == 7'b0110111);
    wire is_auipc  = (opcode == 7'b0010111);

    // -----------------------------
    // ALU + operand isolation
    // -----------------------------
    reg  [31:0] alu_a_raw, alu_b_raw;
    reg  [31:0] alu_a, alu_b;
    reg  [3:0]  alu_op;
    wire [31:0] alu_y;
    wire        alu_zero;

    // choose imm for B?
    reg         alu_src_imm;
    reg  [31:0] alu_imm;

    // instruction uses ALU meaningfully?
    // (even branches use compare; loads/stores use address calc)
    wire alu_used = is_rtype | is_itype | is_load | is_store | is_branch | is_lui;

    always @* begin
        alu_a_raw   = rs1_rdata;
        alu_b_raw   = rs2_rdata;
        alu_src_imm = 1'b0;
        alu_imm     = imm_i;
        alu_op      = 4'h0; // ADD default

        if (is_rtype) begin
            unique case (funct3)
                3'b000: alu_op = (funct7[5] ? 4'h1 : 4'h0); // SUB/ADD
                3'b111: alu_op = 4'h2;
                3'b110: alu_op = 4'h3;
                3'b100: alu_op = 4'h4;
                3'b010: alu_op = 4'h5;
                3'b011: alu_op = 4'h6;
                3'b001: alu_op = 4'h7;
                3'b101: alu_op = (funct7[5] ? 4'h9 : 4'h8);
                default: alu_op = 4'h0;
            endcase
        end else if (is_itype) begin
            alu_src_imm = 1'b1;
            unique case (funct3)
                3'b000: begin alu_op = 4'h0; alu_imm = imm_i; end
                3'b111: begin alu_op = 4'h2; alu_imm = imm_i; end
                3'b110: begin alu_op = 4'h3; alu_imm = imm_i; end
                3'b100: begin alu_op = 4'h4; alu_imm = imm_i; end
                3'b010: begin alu_op = 4'h5; alu_imm = imm_i; end
                3'b011: begin alu_op = 4'h6; alu_imm = imm_i; end
                3'b001: begin alu_op = 4'h7; alu_imm = {27'b0, instr[24:20]}; end
                3'b101: begin alu_imm = {27'b0, instr[24:20]};
                               alu_op  = (funct7[5] ? 4'h9 : 4'h8);
                        end
                default: begin alu_op = 4'h0; alu_imm = imm_i; end
            endcase
        end else if (is_load) begin
            alu_src_imm = 1'b1;
            alu_op      = 4'h0;
            alu_imm     = imm_i;
        end else if (is_store) begin
            alu_src_imm = 1'b1;
            alu_op      = 4'h0;
            alu_imm     = imm_s;
        end else if (is_branch) begin
            // we don't need ALU result, but compare uses rs1/rs2 (handled separately)
            alu_op = 4'h0;
        end else if (is_lui) begin
            alu_a_raw   = 32'b0;
            alu_src_imm = 1'b1;
            alu_imm     = imm_u;
            alu_op      = 4'h0;
        end
    end

    // Operand isolation:
    // if alu not used, drive stable zeros (reduces internal toggles)
    generate
        if (ENABLE_OPERAND_ISO) begin : G_ALU_ISO
            always @* begin
                if (alu_used) begin
                    alu_a = alu_a_raw;
                    alu_b = alu_src_imm ? alu_imm : alu_b_raw;
                end else begin
                    alu_a = 32'b0;
                    alu_b = 32'b0;
                end
            end
        end else begin : G_ALU_NOISO
            always @* begin
                alu_a = alu_a_raw;
                alu_b = alu_src_imm ? alu_imm : alu_b_raw;
            end
        end
    endgenerate

    rv32_alu alu (
        .a    (alu_a),
        .b    (alu_b),
        .op   (alu_op),
        .y    (alu_y),
        .zero (alu_zero)
    );

    // -----------------------------
    // Branch / next PC
    // -----------------------------
    wire [31:0] pc_plus4   = pc_q + 32'd4;
    wire [31:0] pc_branch  = pc_q + imm_b;
    wire [31:0] pc_jal     = pc_q + imm_j;
    wire [31:0] pc_jalr    = (rs1_rdata + imm_i) & 32'hFFFF_FFFE;

    wire signed [31:0] rs1_s = rs1_rdata;
    wire signed [31:0] rs2_s = rs2_rdata;

    wire eq  = (rs1_rdata == rs2_rdata);
    wire lt  = (rs1_s < rs2_s);
    wire ltu = (rs1_rdata < rs2_rdata);

    reg branch_taken;
    always @* begin
        branch_taken = 1'b0;
        if (is_branch) begin
            unique case (funct3)
                3'b000: branch_taken = eq;    // BEQ
                3'b001: branch_taken = !eq;   // BNE
                3'b100: branch_taken = lt;    // BLT
                3'b101: branch_taken = !lt;   // BGE
                3'b110: branch_taken = ltu;   // BLTU
                3'b111: branch_taken = !ltu;  // BGEU
                default: branch_taken = 1'b0;
            endcase
        end
    end

    // -----------------------------
    // Memory interface isolation
    // -----------------------------
    reg        mem_we_r;
    reg [3:0]  mem_wstrb_r;
    reg [31:0] mem_addr_r;
    reg [31:0] mem_wdata_r;

    wire mem_used = is_load | is_store;

    always @* begin
        mem_we_r    = 1'b0;
        mem_wstrb_r = 4'b0000;
        mem_addr_r  = 32'b0;
        mem_wdata_r = 32'b0;

        if (mem_used) begin
            mem_addr_r = alu_y;
            if (is_store) begin
                mem_we_r    = 1'b1;
                mem_wstrb_r = 4'b1111; // SW
                mem_wdata_r = rs2_rdata;
            end
        end
    end

    generate
        if (ENABLE_MEM_ISO) begin : G_MEM_ISO
            assign dmem_we    = mem_used ? mem_we_r    : 1'b0;
            assign dmem_wstrb = mem_used ? mem_wstrb_r : 4'b0000;
            assign dmem_addr  = mem_used ? mem_addr_r  : 32'b0;
            assign dmem_wdata = mem_used ? mem_wdata_r : 32'b0;
        end else begin : G_MEM_NOISO
            assign dmem_we    = mem_we_r;
            assign dmem_wstrb = mem_wstrb_r;
            assign dmem_addr  = mem_addr_r;
            assign dmem_wdata = mem_wdata_r;
        end
    endgenerate

    // -----------------------------
    // Writeback + PC update
    // -----------------------------
    // wb_sel: 0=ALU, 1=Load, 2=PC+4, 3=AUIPC
    reg [1:0] wb_sel;

    always @* begin
        pc_d     = pc_plus4;
        rf_we    = 1'b0;
        wb_sel   = 2'd0;

        if (is_rtype || is_itype || is_lui) begin
            rf_we  = 1'b1;
            wb_sel = 2'd0;
        end else if (is_load) begin
            rf_we  = 1'b1;
            wb_sel = 2'd1;
        end else if (is_jal || is_jalr) begin
            rf_we  = 1'b1;
            wb_sel = 2'd2;
        end else if (is_auipc) begin
            rf_we  = 1'b1;
            wb_sel = 2'd3;
        end

        if (is_branch && branch_taken) pc_d = pc_branch;
        if (is_jal)  pc_d = pc_jal;
        if (is_jalr) pc_d = pc_jalr;

        // Optional "rf write enable gating" knob:
        if (ENABLE_RF_WE_GATING) begin
            // Avoid toggling rf write path for rd=x0 (helps power a bit)
            if (rd == 5'd0) rf_we = 1'b0;
        end
    end

    always @* begin
        unique case (wb_sel)
            2'd0: rf_wdata = alu_y;
            2'd1: rf_wdata = dmem_rdata;
            2'd2: rf_wdata = pc_plus4;
            2'd3: rf_wdata = pc_q + imm_u;
            default: rf_wdata = alu_y;
        endcase
    end

endmodule
module rv32_singlecycle_powerlens #(
    parameter RESET_PC = 32'h0000_0000,

    // PowerLens knobs
    parameter ENABLE_OPERAND_ISO = 1,   // operand isolation on ALU inputs
    parameter ENABLE_MEM_ISO     = 1,   // isolate dmem signals when not used
    parameter ENABLE_RF_WE_GATING= 1    // gate rf write enable (cleaner switching)
) (
    input  wire        clk,
    input  wire        resetn,

    // Instruction memory (assumed comb read)
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,

    // Data memory
    output wire        dmem_we,
    output wire [3:0]  dmem_wstrb,
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    input  wire [31:0] dmem_rdata
);

    // -----------------------------
    // PC register
    // -----------------------------
    reg [31:0] pc_q, pc_d;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) pc_q <= RESET_PC;
        else         pc_q <= pc_d;
    end

    assign imem_addr = pc_q;
    wire [31:0] instr = imem_rdata;

    // -----------------------------
    // Decode
    // -----------------------------
    wire [6:0]  opcode = instr[6:0];
    wire [4:0]  rd     = instr[11:7];
    wire [2:0]  funct3 = instr[14:12];
    wire [4:0]  rs1    = instr[19:15];
    wire [4:0]  rs2    = instr[24:20];
    wire [6:0]  funct7 = instr[31:25];

    // -----------------------------
    // Immediates
    // -----------------------------
    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'b0};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    // -----------------------------
    // Regfile
    // -----------------------------
    wire [31:0] rs1_rdata, rs2_rdata;
    reg  [31:0] rf_wdata;
    reg         rf_we;

    rv32_regfile rf (
        .clk   (clk),
        .we    (rf_we),
        .rs1   (rs1),
        .rs2   (rs2),
        .rd    (rd),
        .wdata (rf_wdata),
        .rdata1(rs1_rdata),
        .rdata2(rs2_rdata)
    );

    // -----------------------------
    // Control decode (simple wires)
    // -----------------------------
    wire is_rtype  = (opcode == 7'b0110011);
    wire is_itype  = (opcode == 7'b0010011);
    wire is_load   = (opcode == 7'b0000011);
    wire is_store  = (opcode == 7'b0100011);
    wire is_branch = (opcode == 7'b1100011);
    wire is_jal    = (opcode == 7'b1101111);
    wire is_jalr   = (opcode == 7'b1100111);
    wire is_lui    = (opcode == 7'b0110111);
    wire is_auipc  = (opcode == 7'b0010111);

    // -----------------------------
    // ALU + operand isolation
    // -----------------------------
    reg  [31:0] alu_a_raw, alu_b_raw;
    reg  [31:0] alu_a, alu_b;
    reg  [3:0]  alu_op;
    wire [31:0] alu_y;
    wire        alu_zero;

    // choose imm for B?
    reg         alu_src_imm;
    reg  [31:0] alu_imm;

    // instruction uses ALU meaningfully?
    // (even branches use compare; loads/stores use address calc)
    wire alu_used = is_rtype | is_itype | is_load | is_store | is_branch | is_lui;

    always @* begin
        alu_a_raw   = rs1_rdata;
        alu_b_raw   = rs2_rdata;
        alu_src_imm = 1'b0;
        alu_imm     = imm_i;
        alu_op      = 4'h0; // ADD default

        if (is_rtype) begin
            unique case (funct3)
                3'b000: alu_op = (funct7[5] ? 4'h1 : 4'h0); // SUB/ADD
                3'b111: alu_op = 4'h2;
                3'b110: alu_op = 4'h3;
                3'b100: alu_op = 4'h4;
                3'b010: alu_op = 4'h5;
                3'b011: alu_op = 4'h6;
                3'b001: alu_op = 4'h7;
                3'b101: alu_op = (funct7[5] ? 4'h9 : 4'h8);
                default: alu_op = 4'h0;
            endcase
        end else if (is_itype) begin
            alu_src_imm = 1'b1;
            unique case (funct3)
                3'b000: begin alu_op = 4'h0; alu_imm = imm_i; end
                3'b111: begin alu_op = 4'h2; alu_imm = imm_i; end
                3'b110: begin alu_op = 4'h3; alu_imm = imm_i; end
                3'b100: begin alu_op = 4'h4; alu_imm = imm_i; end
                3'b010: begin alu_op = 4'h5; alu_imm = imm_i; end
                3'b011: begin alu_op = 4'h6; alu_imm = imm_i; end
                3'b001: begin alu_op = 4'h7; alu_imm = {27'b0, instr[24:20]}; end
                3'b101: begin alu_imm = {27'b0, instr[24:20]};
                               alu_op  = (funct7[5] ? 4'h9 : 4'h8);
                        end
                default: begin alu_op = 4'h0; alu_imm = imm_i; end
            endcase
        end else if (is_load) begin
            alu_src_imm = 1'b1;
            alu_op      = 4'h0;
            alu_imm     = imm_i;
        end else if (is_store) begin
            alu_src_imm = 1'b1;
            alu_op      = 4'h0;
            alu_imm     = imm_s;
        end else if (is_branch) begin
            // we don't need ALU result, but compare uses rs1/rs2 (handled separately)
            alu_op = 4'h0;
        end else if (is_lui) begin
            alu_a_raw   = 32'b0;
            alu_src_imm = 1'b1;
            alu_imm     = imm_u;
            alu_op      = 4'h0;
        end
    end

    // Operand isolation:
    // if alu not used, drive stable zeros (reduces internal toggles)
    generate
        if (ENABLE_OPERAND_ISO) begin : G_ALU_ISO
            always @* begin
                if (alu_used) begin
                    alu_a = alu_a_raw;
                    alu_b = alu_src_imm ? alu_imm : alu_b_raw;
                end else begin
                    alu_a = 32'b0;
                    alu_b = 32'b0;
                end
            end
        end else begin : G_ALU_NOISO
            always @* begin
                alu_a = alu_a_raw;
                alu_b = alu_src_imm ? alu_imm : alu_b_raw;
            end
        end
    endgenerate

    rv32_alu alu (
        .a    (alu_a),
        .b    (alu_b),
        .op   (alu_op),
        .y    (alu_y),
        .zero (alu_zero)
    );

    // -----------------------------
    // Branch / next PC
    // -----------------------------
    wire [31:0] pc_plus4   = pc_q + 32'd4;
    wire [31:0] pc_branch  = pc_q + imm_b;
    wire [31:0] pc_jal     = pc_q + imm_j;
    wire [31:0] pc_jalr    = (rs1_rdata + imm_i) & 32'hFFFF_FFFE;

    wire signed [31:0] rs1_s = rs1_rdata;
    wire signed [31:0] rs2_s = rs2_rdata;

    wire eq  = (rs1_rdata == rs2_rdata);
    wire lt  = (rs1_s < rs2_s);
    wire ltu = (rs1_rdata < rs2_rdata);

    reg branch_taken;
    always @* begin
        branch_taken = 1'b0;
        if (is_branch) begin
            unique case (funct3)
                3'b000: branch_taken = eq;    // BEQ
                3'b001: branch_taken = !eq;   // BNE
                3'b100: branch_taken = lt;    // BLT
                3'b101: branch_taken = !lt;   // BGE
                3'b110: branch_taken = ltu;   // BLTU
                3'b111: branch_taken = !ltu;  // BGEU
                default: branch_taken = 1'b0;
            endcase
        end
    end

    // -----------------------------
    // Memory interface isolation
    // -----------------------------
    reg        mem_we_r;
    reg [3:0]  mem_wstrb_r;
    reg [31:0] mem_addr_r;
    reg [31:0] mem_wdata_r;

    wire mem_used = is_load | is_store;

    always @* begin
        mem_we_r    = 1'b0;
        mem_wstrb_r = 4'b0000;
        mem_addr_r  = 32'b0;
        mem_wdata_r = 32'b0;

        if (mem_used) begin
            mem_addr_r = alu_y;
            if (is_store) begin
                mem_we_r    = 1'b1;
                mem_wstrb_r = 4'b1111; // SW
                mem_wdata_r = rs2_rdata;
            end
        end
    end

    generate
        if (ENABLE_MEM_ISO) begin : G_MEM_ISO
            assign dmem_we    = mem_used ? mem_we_r    : 1'b0;
            assign dmem_wstrb = mem_used ? mem_wstrb_r : 4'b0000;
            assign dmem_addr  = mem_used ? mem_addr_r  : 32'b0;
            assign dmem_wdata = mem_used ? mem_wdata_r : 32'b0;
        end else begin : G_MEM_NOISO
            assign dmem_we    = mem_we_r;
            assign dmem_wstrb = mem_wstrb_r;
            assign dmem_addr  = mem_addr_r;
            assign dmem_wdata = mem_wdata_r;
        end
    endgenerate

    // -----------------------------
    // Writeback + PC update
    // -----------------------------
    // wb_sel: 0=ALU, 1=Load, 2=PC+4, 3=AUIPC
    reg [1:0] wb_sel;

    always @* begin
        pc_d     = pc_plus4;
        rf_we    = 1'b0;
        wb_sel   = 2'd0;

        if (is_rtype || is_itype || is_lui) begin
            rf_we  = 1'b1;
            wb_sel = 2'd0;
        end else if (is_load) begin
            rf_we  = 1'b1;
            wb_sel = 2'd1;
        end else if (is_jal || is_jalr) begin
            rf_we  = 1'b1;
            wb_sel = 2'd2;
        end else if (is_auipc) begin
            rf_we  = 1'b1;
            wb_sel = 2'd3;
        end

        if (is_branch && branch_taken) pc_d = pc_branch;
        if (is_jal)  pc_d = pc_jal;
        if (is_jalr) pc_d = pc_jalr;

        // Optional "rf write enable gating" knob:
        if (ENABLE_RF_WE_GATING) begin
            // Avoid toggling rf write path for rd=x0 (helps power a bit)
            if (rd == 5'd0) rf_we = 1'b0;
        end
    end

    always @* begin
        unique case (wb_sel)
            2'd0: rf_wdata = alu_y;
            2'd1: rf_wdata = dmem_rdata;
            2'd2: rf_wdata = pc_plus4;
            2'd3: rf_wdata = pc_q + imm_u;
            default: rf_wdata = alu_y;
        endcase
    end

endmodule
