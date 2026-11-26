// ============================================================================
// File: alu.sv
// Project: RV32I RISC-V SoC (Phase 2 - CPU Core)
// Description: Arithmetic Logic Unit (ALU).
//              Performs 32-bit arithmetic (ADD, SUB), logical (AND, OR, XOR),
//              shift (SLL, SRL, SRA with 5-bit shamt), comparisons (SLT, SLTU),
//              and branch comparisons (EQ, NE, LT, GE, LTU, GEU).
// ============================================================================

`timescale 1ns / 1ps

module alu (
    input  logic [31:0] op_a_i,
    input  logic [31:0] op_b_i,
    input  logic [3:0]  alu_op_i,
    input  logic [2:0]  funct3_i,        // Branch condition type
    output logic [31:0] result_o,
    output logic        branch_taken_o
);

    // ALU Operation Codes
    localparam [3:0] ALU_ADD    = 4'b0000;
    localparam [3:0] ALU_SUB    = 4'b0001;
    localparam [3:0] ALU_SLL    = 4'b0010;
    localparam [3:0] ALU_SLT    = 4'b0011;
    localparam [3:0] ALU_SLTU   = 4'b0100;
    localparam [3:0] ALU_XOR    = 4'b0101;
    localparam [3:0] ALU_SRL    = 4'b0110;
    localparam [3:0] ALU_SRA    = 4'b0111;
    localparam [3:0] ALU_OR     = 4'b1000;
    localparam [3:0] ALU_AND    = 4'b1001;
    localparam [3:0] ALU_PASS_B = 4'b1010;

    // Shift amount is strictly lower 5 bits of op_b
    logic [4:0] shamt;
    assign shamt = op_b_i[4:0];

    // Arithmetic and logical computation
    always_comb begin
        case (alu_op_i)
            ALU_ADD:    result_o = op_a_i + op_b_i;
            ALU_SUB:    result_o = op_a_i - op_b_i;
            ALU_SLL:    result_o = op_a_i << shamt;
            ALU_SLT:    result_o = ($signed(op_a_i) < $signed(op_b_i)) ? 32'd1 : 32'd0;
            ALU_SLTU:   result_o = (op_a_i < op_b_i) ? 32'd1 : 32'd0;
            ALU_XOR:    result_o = op_a_i ^ op_b_i;
            ALU_SRL:    result_o = op_a_i >> shamt;
            ALU_SRA:    result_o = $signed(op_a_i) >>> shamt;
            ALU_OR:     result_o = op_a_i | op_b_i;
            ALU_AND:    result_o = op_a_i & op_b_i;
            ALU_PASS_B: result_o = op_b_i;
            default:    result_o = 32'h0000_0000;
        endcase
    end

    // Branch condition evaluation
    always_comb begin
        case (funct3_i)
            3'b000: branch_taken_o = (op_a_i == op_b_i);                    // BEQ
            3'b001: branch_taken_o = (op_a_i != op_b_i);                    // BNE
            3'b100: branch_taken_o = ($signed(op_a_i) < $signed(op_b_i));   // BLT
            3'b101: branch_taken_o = ($signed(op_a_i) >= $signed(op_b_i));  // BGE
            3'b110: branch_taken_o = (op_a_i < op_b_i);                     // BLTU
            3'b111: branch_taken_o = (op_a_i >= op_b_i);                    // BGEU
            default: branch_taken_o = 1'b0;
        endcase
    end

endmodule
