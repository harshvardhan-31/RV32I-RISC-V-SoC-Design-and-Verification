// ============================================================================
// File: instruction_decoder.sv
// Project: RV32I RISC-V SoC (Phase 2 - CPU Core)
// Description: Decodes 32-bit RV32I instructions. Extracts opcode, rd, rs1, rs2,
//              funct3, funct7, identifies instruction classes, and detects illegal encodings.
// ============================================================================

`timescale 1ns / 1ps

module instruction_decoder (
    input  logic [31:0] instr_i,
    output logic [6:0]  opcode_o,
    output logic [4:0]  rd_o,
    output logic [2:0]  funct3_o,
    output logic [4:0]  rs1_o,
    output logic [4:0]  rs2_o,
    output logic [6:0]  funct7_o,
    output logic        rs1_used_o,
    output logic        rs2_used_o,
    output logic        rd_used_o,
    output logic        illegal_instr_o
);

    // Standard RV32I field slicing
    assign opcode_o = instr_i[6:0];
    assign rd_o     = instr_i[11:7];
    assign funct3_o = instr_i[14:12];
    assign rs1_o    = instr_i[19:15];
    assign rs2_o    = instr_i[24:20];
    assign funct7_o = instr_i[31:25];

    // RV32I Major Opcodes
    localparam [6:0] OPC_LUI    = 7'b0110111;
    localparam [6:0] OPC_AUIPC  = 7'b0010111;
    localparam [6:0] OPC_JAL    = 7'b1101111;
    localparam [6:0] OPC_JALR   = 7'b1100111;
    localparam [6:0] OPC_BRANCH = 7'b1100011;
    localparam [6:0] OPC_LOAD   = 7'b0000011;
    localparam [6:0] OPC_STORE  = 7'b0100011;
    localparam [6:0] OPC_OP_IMM = 7'b0010011;
    localparam [6:0] OPC_OP     = 7'b0110011;
    localparam [6:0] OPC_MISC_MEM = 7'b0001111; // FENCE
    localparam [6:0] OPC_SYSTEM = 7'b1110011; // ECALL, EBREAK

    // Decode register usage and validate opcode/funct combinations
    always_comb begin
        rs1_used_o      = 1'b0;
        rs2_used_o      = 1'b0;
        rd_used_o       = 1'b0;
        illegal_instr_o = 1'b0;

        case (opcode_o)
            OPC_LUI, OPC_AUIPC: begin
                rd_used_o = 1'b1;
            end

            OPC_JAL: begin
                rd_used_o = 1'b1;
            end

            OPC_JALR: begin
                rs1_used_o = 1'b1;
                rd_used_o  = 1'b1;
                if (funct3_o != 3'b000) begin
                    illegal_instr_o = 1'b1;
                end
            end

            OPC_BRANCH: begin
                rs1_used_o = 1'b1;
                rs2_used_o = 1'b1;
                // Valid funct3: BEQ(000), BNE(001), BLT(100), BGE(101), BLTU(110), BGEU(111)
                case (funct3_o)
                    3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111: illegal_instr_o = 1'b0;
                    default: illegal_instr_o = 1'b1;
                endcase
            end

            OPC_LOAD: begin
                rs1_used_o = 1'b1;
                rd_used_o  = 1'b1;
                // Valid funct3: LB(000), LH(001), LW(010), LBU(100), LHU(101)
                case (funct3_o)
                    3'b000, 3'b001, 3'b010, 3'b100, 3'b101: illegal_instr_o = 1'b0;
                    default: illegal_instr_o = 1'b1;
                endcase
            end

            OPC_STORE: begin
                rs1_used_o = 1'b1;
                rs2_used_o = 1'b1;
                // Valid funct3: SB(000), SH(001), SW(010)
                case (funct3_o)
                    3'b000, 3'b001, 3'b010: illegal_instr_o = 1'b0;
                    default: illegal_instr_o = 1'b1;
                endcase
            end

            OPC_OP_IMM: begin
                rs1_used_o = 1'b1;
                rd_used_o  = 1'b1;
                case (funct3_o)
                    3'b000, 3'b010, 3'b011, 3'b100, 3'b110, 3'b111: begin
                        // ADDI, SLTI, SLTIU, XORI, ORI, ANDI
                        illegal_instr_o = 1'b0;
                    end
                    3'b001: begin
                        // SLLI: funct7 must be 7'b0000000
                        if (funct7_o != 7'b0000000) illegal_instr_o = 1'b1;
                    end
                    3'b101: begin
                        // SRLI (funct7 = 7'b0000000) or SRAI (funct7 = 7'b0100000)
                        if (funct7_o != 7'b0000000 && funct7_o != 7'b0100000) begin
                            illegal_instr_o = 1'b1;
                        end
                    end
                    default: illegal_instr_o = 1'b1;
                endcase
            end

            OPC_OP: begin
                rs1_used_o = 1'b1;
                rs2_used_o = 1'b1;
                rd_used_o  = 1'b1;
                case (funct3_o)
                    3'b000: begin
                        // ADD (funct7=0000000) or SUB (funct7=0100000)
                        if (funct7_o != 7'b0000000 && funct7_o != 7'b0100000) illegal_instr_o = 1'b1;
                    end
                    3'b001: begin
                        // SLL (funct7=0000000)
                        if (funct7_o != 7'b0000000) illegal_instr_o = 1'b1;
                    end
                    3'b010: begin
                        // SLT (funct7=0000000)
                        if (funct7_o != 7'b0000000) illegal_instr_o = 1'b1;
                    end
                    3'b011: begin
                        // SLTU (funct7=0000000)
                        if (funct7_o != 7'b0000000) illegal_instr_o = 1'b1;
                    end
                    3'b100: begin
                        // XOR (funct7=0000000)
                        if (funct7_o != 7'b0000000) illegal_instr_o = 1'b1;
                    end
                    3'b101: begin
                        // SRL (funct7=0000000) or SRA (funct7=0100000)
                        if (funct7_o != 7'b0000000 && funct7_o != 7'b0100000) illegal_instr_o = 1'b1;
                    end
                    3'b110: begin
                        // OR (funct7=0000000)
                        if (funct7_o != 7'b0000000) illegal_instr_o = 1'b1;
                    end
                    3'b111: begin
                        // AND (funct7=0000000)
                        if (funct7_o != 7'b0000000) illegal_instr_o = 1'b1;
                    end
                    default: illegal_instr_o = 1'b1;
                endcase
            end

            OPC_MISC_MEM: begin
                // FENCE: treated as valid NOP in Phase 2
                if (funct3_o == 3'b000) illegal_instr_o = 1'b0;
                else illegal_instr_o = 1'b1;
            end

            OPC_SYSTEM: begin
                // ECALL (imm=12'h000) and EBREAK (imm=12'h001)
                if (funct3_o == 3'b000 && (instr_i[31:20] == 12'h000 || instr_i[31:20] == 12'h001)) begin
                    illegal_instr_o = 1'b0;
                end else begin
                    illegal_instr_o = 1'b1;
                end
            end

            default: begin
                illegal_instr_o = 1'b1;
            end
        endcase
    end

endmodule
