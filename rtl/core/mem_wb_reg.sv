// ============================================================================
// File: mem_wb_reg.sv
// Project: RV32I RISC-V SoC (Phase 2 - CPU Core)
// Description: MEM/WB Pipeline Register. Latches writeback data, destination
//              register index, and write enable between MEM and WB stages.
//              Supports synchronous reset, stall, and flush.
// ============================================================================

`timescale 1ns / 1ps

module mem_wb_reg (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        stall_i,
    input  logic        flush_i,
    input  logic        valid_i,
    input  logic [31:0] alu_result_i,
    input  logic [31:0] load_data_i,
    input  logic [31:0] pc_plus4_i,
    input  logic [4:0]  rd_addr_i,
    input  logic        reg_write_i,
    input  logic [1:0]  wb_sel_i,

    output logic        valid_o,
    output logic [4:0]  rd_addr_o,
    output logic        reg_write_o,
    output logic [31:0] wb_data_o
);

    // Writeback Source Selects
    localparam [1:0] WB_ALU = 2'b00;
    localparam [1:0] WB_MEM = 2'b01;
    localparam [1:0] WB_PC4 = 2'b10;

    logic [31:0] selected_wb_data;

    // Combinational selection of writeback data based on wb_sel
    always_comb begin
        case (wb_sel_i)
            WB_ALU:  selected_wb_data = alu_result_i;
            WB_MEM:  selected_wb_data = load_data_i;
            WB_PC4:  selected_wb_data = pc_plus4_i;
            default: selected_wb_data = alu_result_i;
        endcase
    end

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            valid_o     <= 1'b0;
            rd_addr_o   <= 5'd0;
            reg_write_o <= 1'b0;
            wb_data_o   <= 32'h0000_0000;
        end else if (flush_i) begin
            valid_o     <= 1'b0;
            rd_addr_o   <= 5'd0;
            reg_write_o <= 1'b0;
            wb_data_o   <= 32'h0000_0000;
        end else if (!stall_i) begin
            valid_o     <= valid_i;
            rd_addr_o   <= rd_addr_i;
            reg_write_o <= reg_write_i;
            wb_data_o   <= selected_wb_data;
        end
    end

endmodule
