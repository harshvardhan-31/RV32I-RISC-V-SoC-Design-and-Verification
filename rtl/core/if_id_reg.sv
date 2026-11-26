// ============================================================================
// File: if_id_reg.sv
// Project: RV32I RISC-V SoC (Phase 2 - CPU Core)
// Description: IF/ID Pipeline Register. Latches PC and instruction between
//              Instruction Fetch and Instruction Decode stages.
//              Supports synchronous reset, stall (hold), and flush.
// ============================================================================

`timescale 1ns / 1ps

module if_id_reg (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        stall_i,        // Hold pipeline register contents
    input  logic        flush_i,        // Flush pipeline register (insert bubble)
    input  logic        valid_i,        // Valid bit from IF stage
    input  logic [31:0] pc_i,           // PC of fetched instruction
    input  logic [31:0] pc_plus4_i,     // PC+4 of fetched instruction
    input  logic [31:0] instr_i,        // 32-bit instruction fetched from IMEM
    output logic        valid_o,        // Valid bit to ID stage
    output logic [31:0] pc_o,           // Registered PC
    output logic [31:0] pc_plus4_o,     // Registered PC+4
    output logic [31:0] instr_o         // Registered instruction
);

    // RV32I NOP instruction encoding: addi x0, x0, 0 = 32'h00000013
    localparam [31:0] INSTR_NOP = 32'h0000_0013;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            valid_o    <= 1'b0;
            pc_o       <= 32'h0000_0000;
            pc_plus4_o <= 32'h0000_0000;
            instr_o    <= INSTR_NOP;
        end else if (flush_i) begin
            valid_o    <= 1'b0;
            pc_o       <= 32'h0000_0000;
            pc_plus4_o <= 32'h0000_0000;
            instr_o    <= INSTR_NOP;
        end else if (!stall_i) begin
            valid_o    <= valid_i;
            pc_o       <= pc_i;
            pc_plus4_o <= pc_plus4_i;
            instr_o    <= instr_i;
        end
        // If stall_i is high and no flush/reset, state is held unchanged
    end

endmodule
