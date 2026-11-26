// ============================================================================
// File: load_store_unit.sv
// Project: RV32I RISC-V SoC (Phase 2 - CPU Core)
// Description: Load Store Unit (LSU) for Memory (MEM) stage.
//              Interfaces with the SoC custom data bus.
//              - Supports LB, LH, LW, LBU, LHU, SB, SH, SW.
//              - Implements byte enable generation and little-endian steering.
//              - Sign-extends and zero-extends read data.
//              - Manages request/ready handshake and holds pipeline when busy.
// ============================================================================

`timescale 1ns / 1ps

module load_store_unit (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        valid_i,
    input  logic        mem_read_i,
    input  logic        mem_write_i,
    input  logic [2:0]  funct3_i,
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] load_data_o,
    output logic        busy_o,
    output logic        error_o,

    // Bus Master Interface
    output logic        dmem_req_o,
    output logic [31:0] dmem_addr_o,
    output logic        dmem_we_o,
    output logic [31:0] dmem_wdata_o,
    output logic [3:0]  dmem_be_o,
    input  logic        dmem_ready_i,
    input  logic [31:0] dmem_rdata_i,
    input  logic        dmem_error_i
);

    // Active memory request from a valid instruction
    logic req_active;
    assign req_active = valid_i && (mem_read_i || mem_write_i);

    // Bus request outputs
    assign dmem_req_o  = req_active;
    assign dmem_we_o   = mem_write_i;
    assign dmem_addr_o = {addr_i[31:2], 2'b00}; // Word-aligned base address

    // Busy signal: active when transaction is outstanding waiting for ready
    assign busy_o  = req_active && !dmem_ready_i;
    assign error_o = req_active && dmem_ready_i && dmem_error_i;

    // Byte lane selection and write data replication
    always_comb begin
        case (funct3_i)
            3'b000: begin // SB - Store Byte
                dmem_be_o    = 4'b0001 << addr_i[1:0];
                dmem_wdata_o = {4{wdata_i[7:0]}};
            end
            3'b001: begin // SH - Store Halfword
                dmem_be_o    = addr_i[1] ? 4'b1100 : 4'b0011;
                dmem_wdata_o = {2{wdata_i[15:0]}};
            end
            3'b010: begin // SW - Store Word
                dmem_be_o    = 4'b1111;
                dmem_wdata_o = wdata_i;
            end
            default: begin
                dmem_be_o    = 4'b0000;
                dmem_wdata_o = wdata_i;
            end
        endcase
    end

    // Read data extraction, steering, and sign/zero extension
    logic [7:0]  byte_sel;
    logic [15:0] half_sel;

    always_comb begin
        case (addr_i[1:0])
            2'b00: byte_sel = dmem_rdata_i[7:0];
            2'b01: byte_sel = dmem_rdata_i[15:8];
            2'b10: byte_sel = dmem_rdata_i[23:16];
            2'b11: byte_sel = dmem_rdata_i[31:24];
        endcase

        half_sel = addr_i[1] ? dmem_rdata_i[31:16] : dmem_rdata_i[15:0];
    end

    always_comb begin
        case (funct3_i)
            3'b000: load_data_o = {{24{byte_sel[7]}}, byte_sel}; // LB (sign-extended)
            3'b001: load_data_o = {{16{half_sel[15]}}, half_sel}; // LH (sign-extended)
            3'b010: load_data_o = dmem_rdata_i;                   // LW (32-bit word)
            3'b100: load_data_o = {24'd0, byte_sel};              // LBU (zero-extended)
            3'b101: load_data_o = {16'd0, half_sel};              // LHU (zero-extended)
            default: load_data_o = dmem_rdata_i;
        endcase
    end

endmodule
