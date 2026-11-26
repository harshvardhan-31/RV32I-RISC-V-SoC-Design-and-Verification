// ============================================================================
// File: immediate_generator.sv
// Project: RV32I RISC-V SoC (Phase 2 - CPU Core)
// Description: Extracts and sign-extends immediate values from 32-bit RV32I
//              instructions for I, S, B, U, and J formats.
// ============================================================================

`timescale 1ns / 1ps

module immediate_generator (
    input  logic [31:0] instr_i,
    input  logic [2:0]  imm_type_i,
    output logic [31:0] imm_o
);

    // Immediate format selection encoding
    localparam [2:0] IMM_I = 3'b000;
    localparam [2:0] IMM_S = 3'b001;
    localparam [2:0] IMM_B = 3'b010;
    localparam [2:0] IMM_U = 3'b011;
    localparam [2:0] IMM_J = 3'b100;

    always_comb begin
        case (imm_type_i)
            IMM_I: begin
                // I-type: imm[11:0] = instr[31:20], sign-extended
                imm_o = {{20{instr_i[31]}}, instr_i[31:20]};
            end

            IMM_S: begin
                // S-type: imm[11:5] = instr[31:25], imm[4:0] = instr[11:7]
                imm_o = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
            end

            IMM_B: begin
                // B-type: imm[12|10:5|4:1|11], bit 0 implied 0
                imm_o = {{19{instr_i[31]}}, instr_i[31], instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};
            end

            IMM_U: begin
                // U-type: imm[31:12] = instr[31:12], lower 12 bits zero
                imm_o = {instr_i[31:12], 12'h000};
            end

            IMM_J: begin
                // J-type: imm[20|10:1|11|19:12], bit 0 implied 0
                imm_o = {{11{instr_i[31]}}, instr_i[31], instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};
            end

            default: begin
                imm_o = 32'h0000_0000;
            end
        endcase
    end

endmodule
