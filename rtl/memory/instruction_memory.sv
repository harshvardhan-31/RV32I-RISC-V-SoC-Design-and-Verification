// ============================================================================
// File: instruction_memory.sv
// Project: RV32I RISC-V SoC (Phase 4 — Memory Subsystem and Peripheral Integration)
// Description: Synthesizable 64 KiB Instruction RAM with single-cycle synchronous
//              read response. Accessible only through the dedicated CPU instruction
//              fetch port. Supports initialization via optional hex file.
//
// Memory Map:  0x0000_0000 - 0x0000_FFFF (64 KiB, 16384 x 32-bit words)
// ============================================================================

`timescale 1ns / 1ps

module instruction_memory #(
    parameter [31:0] BASE_ADDR      = 32'h0000_0000,
    parameter int    MEM_SIZE_BYTES = 65536,
    parameter        INIT_FILE      = ""
) (
    input  logic        clk_i,
    input  logic        rst_ni,

    // Instruction Fetch Port
    input  logic        req_i,
    input  logic [31:0] addr_i,
    output logic [31:0] rdata_o,
    output logic        ready_o,
    output logic        error_o
);

    localparam int NUM_WORDS = MEM_SIZE_BYTES / 4;

    // 16,384 x 32-bit word storage array
    logic [31:0] mem [0:NUM_WORDS-1];

    // Optional firmware initialization from file (simulation & synthesis ROM inference)
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    // Address decoding & alignment checks
    logic [31:0] addr_offset;
    logic        addr_in_range;
    logic        addr_misaligned;

    assign addr_offset     = addr_i - BASE_ADDR;
    assign addr_in_range   = (addr_i >= BASE_ADDR) && (addr_offset < MEM_SIZE_BYTES);
    assign addr_misaligned = (addr_i[1:0] != 2'b00);

    // Synchronous 1-cycle read response
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            ready_o <= 1'b0;
            error_o <= 1'b0;
            rdata_o <= 32'h0000_0000;
        end else begin
            if (req_i) begin
                ready_o <= 1'b1;
                if (addr_in_range && !addr_misaligned) begin
                    rdata_o <= mem[addr_offset[15:2]];
                    error_o <= 1'b0;
                end else begin
                    // Out-of-bounds or misaligned instruction fetch address
                    rdata_o <= 32'h0000_0000;
                    error_o <= 1'b1;
                end
            end else begin
                ready_o <= 1'b0;
                error_o <= 1'b0;
            end
        end
    end

endmodule
