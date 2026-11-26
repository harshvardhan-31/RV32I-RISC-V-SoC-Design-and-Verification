// ============================================================================
// File: register_file.sv
// Project: RV32I RISC-V SoC (Phase 2 - CPU Core)
// Description: 32x32-bit Integer Register File.
//              - Two combinational (asynchronous) read ports (rs1, rs2).
//              - One synchronous rising-edge write port (rd).
//              - Register x0 is permanently hardwired to 32'h0000_0000.
//              - Writes to x0 are ignored.
// ============================================================================

`timescale 1ns / 1ps

module register_file (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic [4:0]  rs1_addr_i,
    input  logic [4:0]  rs2_addr_i,
    input  logic        we_i,
    input  logic [4:0]  rd_addr_i,
    input  logic [31:0] rd_data_i,
    output logic [31:0] rs1_data_o,
    output logic [31:0] rs2_data_o
);

    // 31 physical registers (x1 to x31), x0 is hardwired to 0
    logic [31:0] regs [1:31];

    // Combinational read ports: x0 unconditionally returns 32'd0
    assign rs1_data_o = (rs1_addr_i == 5'd0) ? 32'h0000_0000 : regs[rs1_addr_i];
    assign rs2_data_o = (rs2_addr_i == 5'd0) ? 32'h0000_0000 : regs[rs2_addr_i];

    // Synchronous write port: writes occur on rising clock edge
    integer i;
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            for (i = 1; i < 32; i = i + 1) begin
                regs[i] <= 32'h0000_0000;
            end
        end else if (we_i && (rd_addr_i != 5'd0)) begin
            regs[rd_addr_i] <= rd_data_i;
        end
    end

endmodule
