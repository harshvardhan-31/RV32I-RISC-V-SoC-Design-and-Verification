// ============================================================================
// File: ex_mem_reg.sv
// Project: RV32I RISC-V SoC (Phase 2 - CPU Core)
// Description: EX/MEM Pipeline Register. Latches execution results, store data,
//              memory controls, and destination register info between EX and MEM stages.
//              Supports synchronous reset, stall (hold), and flush.
// ============================================================================

`timescale 1ns / 1ps

module ex_mem_reg (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        stall_i,
    input  logic        flush_i,
    input  logic        valid_i,
    input  logic [31:0] pc_plus4_i,
    input  logic [31:0] alu_result_i,
    input  logic [31:0] rs2_data_i,      // Store data
    input  logic [4:0]  rd_addr_i,
    input  logic [2:0]  funct3_i,
    input  logic        mem_read_i,
    input  logic        mem_write_i,
    input  logic        reg_write_i,
    input  logic [1:0]  wb_sel_i,

    output logic        valid_o,
    output logic [31:0] pc_plus4_o,
    output logic [31:0] alu_result_o,
    output logic [31:0] rs2_data_o,
    output logic [4:0]  rd_addr_o,
    output logic [2:0]  funct3_o,
    output logic        mem_read_o,
    output logic        mem_write_o,
    output logic        reg_write_o,
    output logic [1:0]  wb_sel_o
);

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            valid_o      <= 1'b0;
            pc_plus4_o   <= 32'h0000_0000;
            alu_result_o <= 32'h0000_0000;
            rs2_data_o   <= 32'h0000_0000;
            rd_addr_o    <= 5'd0;
            funct3_o     <= 3'd0;
            mem_read_o   <= 1'b0;
            mem_write_o  <= 1'b0;
            reg_write_o  <= 1'b0;
            wb_sel_o     <= 2'b00;
        end else if (flush_i) begin
            valid_o      <= 1'b0;
            pc_plus4_o   <= 32'h0000_0000;
            alu_result_o <= 32'h0000_0000;
            rs2_data_o   <= 32'h0000_0000;
            rd_addr_o    <= 5'd0;
            funct3_o     <= 3'd0;
            mem_read_o   <= 1'b0;
            mem_write_o  <= 1'b0;
            reg_write_o  <= 1'b0;
            wb_sel_o     <= 2'b00;
        end else if (!stall_i) begin
            valid_o      <= valid_i;
            pc_plus4_o   <= pc_plus4_i;
            alu_result_o <= alu_result_i;
            rs2_data_o   <= rs2_data_i;
            rd_addr_o    <= rd_addr_i;
            funct3_o     <= funct3_i;
            mem_read_o   <= mem_read_i;
            mem_write_o  <= mem_write_i;
            reg_write_o  <= reg_write_i;
            wb_sel_o     <= wb_sel_i;
        end
    end

endmodule
