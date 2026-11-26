// ============================================================================
// File: control_unit.sv
// Project: RV32I RISC-V SoC (Phase 2 - CPU Core)
// Description: Main Control Unit. Generates ALU opcodes, multiplexer selects,
//              memory read/write, register write enables, branch/jump flags,
//              and immediate format selects for all RV32I instruction classes.
//              Guarantees zero write side effects for illegal instructions.
// ============================================================================

`timescale 1ns / 1ps

module control_unit (
    input  logic [6:0] opcode_i,
    input  logic [2:0] funct3_i,
    input  logic [6:0] funct7_i,
    input  logic       illegal_instr_i,
    output logic [2:0] imm_type_o,
    output logic [3:0] alu_op_o,
    output logic       alu_src_a_o,      // 0: rs1_data, 1: pc
    output logic       alu_src_b_o,      // 0: rs2_data, 1: immediate
    output logic       mem_read_o,
    output logic       mem_write_o,
    output logic       reg_write_o,
    output logic [1:0] wb_sel_o,         // 00: ALU, 01: MEM, 10: PC+4
    output logic       branch_o,
    output logic       jump_o,
    output logic       jalr_o,
    output logic       sys_ecall_o,
    output logic       sys_ebreak_o,
    output logic       sys_fence_o
);

    // RV32I Major Opcodes
    localparam [6:0] OPC_LUI      = 7'b0110111;
    localparam [6:0] OPC_AUIPC    = 7'b0010111;
    localparam [6:0] OPC_JAL      = 7'b1101111;
    localparam [6:0] OPC_JALR     = 7'b1100111;
    localparam [6:0] OPC_BRANCH   = 7'b1100011;
    localparam [6:0] OPC_LOAD     = 7'b0000011;
    localparam [6:0] OPC_STORE    = 7'b0100011;
    localparam [6:0] OPC_OP_IMM   = 7'b0010011;
    localparam [6:0] OPC_OP       = 7'b0110011;
    localparam [6:0] OPC_MISC_MEM = 7'b0001111;
    localparam [6:0] OPC_SYSTEM   = 7'b1110011;

    // Immediate format selection encoding
    localparam [2:0] IMM_I = 3'b000;
    localparam [2:0] IMM_S = 3'b001;
    localparam [2:0] IMM_B = 3'b010;
    localparam [2:0] IMM_U = 3'b011;
    localparam [2:0] IMM_J = 3'b100;

    // ALU Operation Codes
    localparam [3:0] ALU_ADD  = 4'b0000;
    localparam [3:0] ALU_SUB  = 4'b0001;
    localparam [3:0] ALU_SLL  = 4'b0010;
    localparam [3:0] ALU_SLT  = 4'b0011;
    localparam [3:0] ALU_SLTU = 4'b0100;
    localparam [3:0] ALU_XOR  = 4'b0101;
    localparam [3:0] ALU_SRL  = 4'b0110;
    localparam [3:0] ALU_SRA  = 4'b0111;
    localparam [3:0] ALU_OR   = 4'b1000;
    localparam [3:0] ALU_AND  = 4'b1001;
    localparam [3:0] ALU_PASS_B = 4'b1010;

    // Writeback Source Selects
    localparam [1:0] WB_ALU = 2'b00;
    localparam [1:0] WB_MEM = 2'b01;
    localparam [1:0] WB_PC4 = 2'b10;

    always_comb begin
        // Default benign assignments (no side effects)
        imm_type_o   = IMM_I;
        alu_op_o     = ALU_ADD;
        alu_src_a_o  = 1'b0; // rs1
        alu_src_b_o  = 1'b0; // rs2
        mem_read_o   = 1'b0;
        mem_write_o  = 1'b0;
        reg_write_o  = 1'b0;
        wb_sel_o     = WB_ALU;
        branch_o     = 1'b0;
        jump_o       = 1'b0;
        jalr_o       = 1'b0;
        sys_ecall_o  = 1'b0;
        sys_ebreak_o = 1'b0;
        sys_fence_o  = 1'b0;

        if (!illegal_instr_i) begin
            case (opcode_i)
                OPC_LUI: begin
                    imm_type_o  = IMM_U;
                    alu_op_o    = ALU_PASS_B; // Pass immediate to result
                    alu_src_b_o = 1'b1;        // Immediate
                    reg_write_o = 1'b1;
                    wb_sel_o    = WB_ALU;
                end

                OPC_AUIPC: begin
                    imm_type_o  = IMM_U;
                    alu_op_o    = ALU_ADD;
                    alu_src_a_o = 1'b1;        // PC
                    alu_src_b_o = 1'b1;        // Immediate
                    reg_write_o = 1'b1;
                    wb_sel_o    = WB_ALU;
                end

                OPC_JAL: begin
                    imm_type_o  = IMM_J;
                    jump_o      = 1'b1;
                    reg_write_o = 1'b1;
                    wb_sel_o    = WB_PC4;      // Link address PC+4
                end

                OPC_JALR: begin
                    imm_type_o  = IMM_I;
                    jump_o      = 1'b1;
                    jalr_o      = 1'b1;
                    reg_write_o = 1'b1;
                    wb_sel_o    = WB_PC4;      // Link address PC+4
                end

                OPC_BRANCH: begin
                    imm_type_o  = IMM_B;
                    alu_op_o    = ALU_SUB;     // ALU branch comparator evaluates condition
                    alu_src_a_o = 1'b0;        // rs1
                    alu_src_b_o = 1'b0;        // rs2
                    branch_o    = 1'b1;
                end

                OPC_LOAD: begin
                    imm_type_o  = IMM_I;
                    alu_op_o    = ALU_ADD;     // Effective address calculation: rs1 + imm
                    alu_src_b_o = 1'b1;
                    mem_read_o  = 1'b1;
                    reg_write_o = 1'b1;
                    wb_sel_o    = WB_MEM;
                end

                OPC_STORE: begin
                    imm_type_o  = IMM_S;
                    alu_op_o    = ALU_ADD;     // Effective address calculation: rs1 + imm
                    alu_src_b_o = 1'b1;
                    mem_write_o = 1'b1;
                end

                OPC_OP_IMM: begin
                    imm_type_o  = IMM_I;
                    alu_src_b_o = 1'b1;        // Immediate operand
                    reg_write_o = 1'b1;
                    wb_sel_o    = WB_ALU;

                    case (funct3_i)
                        3'b000: alu_op_o = ALU_ADD;  // ADDI
                        3'b010: alu_op_o = ALU_SLT;  // SLTI
                        3'b011: alu_op_o = ALU_SLTU; // SLTIU
                        3'b100: alu_op_o = ALU_XOR;  // XORI
                        3'b110: alu_op_o = ALU_OR;   // ORI
                        3'b111: alu_op_o = ALU_AND;  // ANDI
                        3'b001: alu_op_o = ALU_SLL;  // SLLI
                        3'b101: begin
                            if (funct7_i[5]) alu_op_o = ALU_SRA; // SRAI
                            else             alu_op_o = ALU_SRL; // SRLI
                        end
                        default: alu_op_o = ALU_ADD;
                    endcase
                end

                OPC_OP: begin
                    alu_src_a_o = 1'b0;        // rs1
                    alu_src_b_o = 1'b0;        // rs2
                    reg_write_o = 1'b1;
                    wb_sel_o    = WB_ALU;

                    case (funct3_i)
                        3'b000: begin
                            if (funct7_i[5]) alu_op_o = ALU_SUB; // SUB
                            else             alu_op_o = ALU_ADD; // ADD
                        end
                        3'b001: alu_op_o = ALU_SLL;  // SLL
                        3'b010: alu_op_o = ALU_SLT;  // SLT
                        3'b011: alu_op_o = ALU_SLTU; // SLTU
                        3'b100: alu_op_o = ALU_XOR;  // XOR
                        3'b101: begin
                            if (funct7_i[5]) alu_op_o = ALU_SRA; // SRA
                            else             alu_op_o = ALU_SRL; // SRL
                        end
                        3'b110: alu_op_o = ALU_OR;   // OR
                        3'b111: alu_op_o = ALU_AND;  // AND
                        default: alu_op_o = ALU_ADD;
                    endcase
                end

                OPC_MISC_MEM: begin
                    // FENCE treated as NOP in Phase 2
                    sys_fence_o = 1'b1;
                end

                OPC_SYSTEM: begin
                    if (funct7_i == 7'b0000000 && funct3_i == 3'b000) begin
                        // bit 20 distinguishes ECALL (0) and EBREAK (1)
                        if (funct7_i[0] == 1'b0) begin
                            sys_ecall_o = 1'b1;
                        end else begin
                            sys_ebreak_o = 1'b1;
                        end
                    end
                end

                default: begin
                    // Benign defaults maintained
                end
            endcase
        end
    end

endmodule
