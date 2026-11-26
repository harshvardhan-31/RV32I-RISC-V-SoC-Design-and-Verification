// ============================================================================
// File: id_ex_reg.sv
// Project: RV32I RISC-V SoC (Phase 2 - CPU Core)
// Description: ID/EX Pipeline Register. Latches operands, immediate, control
//              signals, and instruction metadata between ID and EX stages.
//              Supports synchronous reset, stall (hold), and flush (bubble).
// ============================================================================

`timescale 1ns / 1ps

module id_ex_reg (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        stall_i,
    input  logic        flush_i,
    input  logic        valid_i,
    input  logic [31:0] pc_i,
    input  logic [31:0] pc_plus4_i,
    input  logic [31:0] rs1_data_i,
    input  logic [31:0] rs2_data_i,
    input  logic [31:0] imm_i,
    input  logic [4:0]  rs1_addr_i,
    input  logic [4:0]  rs2_addr_i,
    input  logic [4:0]  rd_addr_i,
    input  logic [2:0]  funct3_i,
    input  logic [3:0]  alu_op_i,
    input  logic        alu_src_a_i,
    input  logic        alu_src_b_i,
    input  logic        branch_i,
    input  logic        jump_i,
    input  logic        jalr_i,
    input  logic        mem_read_i,
    input  logic        mem_write_i,
    input  logic        reg_write_i,
    input  logic [1:0]  wb_sel_i,

    output logic        valid_o,
    output logic [31:0] pc_o,
    output logic [31:0] pc_plus4_o,
    output logic [31:0] rs1_data_o,
    output logic [31:0] rs2_data_o,
    output logic [31:0] imm_o,
    output logic [4:0]  rs1_addr_o,
    output logic [4:0]  rs2_addr_o,
    output logic [4:0]  rd_addr_o,
    output logic [2:0]  funct3_o,
    output logic [3:0]  alu_op_o,
    output logic        alu_src_a_o,
    output logic        alu_src_b_o,
    output logic        branch_o,
    output logic        jump_o,
    output logic        jalr_o,
    output logic        mem_read_o,
    output logic        mem_write_o,
    output logic        reg_write_o,
    output logic [1:0]  wb_sel_o
);

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            valid_o      <= 1'b0;
            pc_o         <= 32'h0000_0000;
            pc_plus4_o   <= 32'h0000_0000;
            rs1_data_o   <= 32'h0000_0000;
            rs2_data_o   <= 32'h0000_0000;
            imm_o        <= 32'h0000_0000;
            rs1_addr_o   <= 5'd0;
            rs2_addr_o   <= 5'd0;
            rd_addr_o    <= 5'd0;
            funct3_o     <= 3'd0;
            alu_op_o     <= 4'd0;
            alu_src_a_o  <= 1'b0;
            alu_src_b_o  <= 1'b0;
            branch_o     <= 1'b0;
            jump_o       <= 1'b0;
            jalr_o       <= 1'b0;
            mem_read_o   <= 1'b0;
            mem_write_o  <= 1'b0;
            reg_write_o  <= 1'b0;
            wb_sel_o     <= 2'b00;
        end else if (flush_i) begin
            // Bubble insertion on branch mispredict or redirect
            valid_o      <= 1'b0;
            pc_o         <= 32'h0000_0000;
            pc_plus4_o   <= 32'h0000_0000;
            rs1_data_o   <= 32'h0000_0000;
            rs2_data_o   <= 32'h0000_0000;
            imm_o        <= 32'h0000_0000;
            rs1_addr_o   <= 5'd0;
            rs2_addr_o   <= 5'd0;
            rd_addr_o    <= 5'd0;
            funct3_o     <= 3'd0;
            alu_op_o     <= 4'd0;
            alu_src_a_o  <= 1'b0;
            alu_src_b_o  <= 1'b0;
            branch_o     <= 1'b0;
            jump_o       <= 1'b0;
            jalr_o       <= 1'b0;
            mem_read_o   <= 1'b0;
            mem_write_o  <= 1'b0;
            reg_write_o  <= 1'b0;
            wb_sel_o     <= 2'b00;
        end else if (!stall_i) begin
            valid_o      <= valid_i;
            pc_o         <= pc_i;
            pc_plus4_o   <= pc_plus4_i;
            rs1_data_o   <= rs1_data_i;
            rs2_data_o   <= rs2_data_i;
            imm_o        <= imm_i;
            rs1_addr_o   <= rs1_addr_i;
            rs2_addr_o   <= rs2_addr_i;
            rd_addr_o    <= rd_addr_i;
            funct3_o     <= funct3_i;
            alu_op_o     <= alu_op_i;
            alu_src_a_o  <= alu_src_a_i;
            alu_src_b_o  <= alu_src_b_i;
            branch_o     <= branch_i;
            jump_o       <= jump_i;
            jalr_o       <= jalr_i;
            mem_read_o   <= mem_read_i;
            mem_write_o  <= mem_write_i;
            reg_write_o  <= reg_write_i;
            wb_sel_o     <= wb_sel_i;
        end
    end

endmodule
